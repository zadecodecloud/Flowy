internal import AppKit
import CoreGraphics
import ApplicationServices
import os

// Taken from notchflow-clean (`Input/NotchClickTap.swift`).

/// A pointer event in Cocoa screen coordinates.
enum PointerSignal {
    case down(NSPoint)
    case dragged(NSPoint)
    case up(start: NSPoint, end: NSPoint, duration: TimeInterval)
    case rightDown(NSPoint)
}

/// Observes mouse buttons anywhere on screen with a listen-only event tap, so a click on the
/// compact notch is seen even when it never reaches the notch window (the menu-bar strip
/// can swallow it). Events are never modified or dropped. Falls back to global and local
/// NSEvent monitors if the tap cannot be created (no Input Monitoring / Accessibility access).
final class NotchClickTap {
    typealias Handler = (PointerSignal) -> Void

    static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.notchflow.mac", category: "input")

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var fallbackMonitor: Any?
    private var localMonitor: Any?
    private var downLocation: NSPoint?
    private var downTime: TimeInterval = 0
    private let onEvent: Handler

    init(onEvent: @escaping Handler) {
        self.onEvent = onEvent
    }

    var isUsingEventTap: Bool { tap != nil }

    func start() {
        guard tap == nil, fallbackMonitor == nil, localMonitor == nil else { return }
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        // A tap only receives events with Input Monitoring / Accessibility access; without it
        // tapCreate still succeeds but stays silent, so check first.
        if CGPreflightListenEventAccess() || AXIsProcessTrusted(),
           let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                                       eventsOfInterest: mask, callback: notchClickTapCallback, userInfo: refcon),
           let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            self.tap = tap
            self.source = source
            Self.log.info("Pointer input: event tap")
            return
        }
        // No permission needed: global sees clicks delivered to other apps (the menu bar),
        // local sees clicks that do reach NotchFlow's own windows.
        let events: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown]
        fallbackMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
            let type = event.type, timestamp = event.timestamp
            MainActor.assumeIsolated { self?.record(type: type, timestamp: timestamp, source: "global") }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            let type = event.type, timestamp = event.timestamp
            MainActor.assumeIsolated { self?.record(type: type, timestamp: timestamp, source: "local") }
            return event
        }
        Self.log.info("Pointer input: NSEvent monitors (no event-tap access)")
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let fallbackMonitor { NSEvent.removeMonitor(fallbackMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        tap = nil; source = nil; fallbackMonitor = nil; localMonitor = nil
    }

    fileprivate func handle(type: CGEventType, timestamp: TimeInterval) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .leftMouseDown:
            record(type: .leftMouseDown, timestamp: timestamp, source: "tap")
        case .leftMouseUp:
            record(type: .leftMouseUp, timestamp: timestamp, source: "tap")
        case .leftMouseDragged:
            record(type: .leftMouseDragged, timestamp: timestamp, source: "tap")
        case .rightMouseDown:
            record(type: .rightMouseDown, timestamp: timestamp, source: "tap")
        default:
            break
        }
    }

    private func record(type: NSEvent.EventType, timestamp: TimeInterval, source: String) {
        let location = NSEvent.mouseLocation
        switch type {
        case .leftMouseDown:
            downLocation = location
            downTime = timestamp
            Self.log.debug("mouse down (\(source, privacy: .public)) at \(location.x), \(location.y)")
            onEvent(.down(location))
        case .leftMouseDragged:
            guard downLocation != nil else { return }
            onEvent(.dragged(location))
        case .leftMouseUp:
            guard let start = downLocation else { return }
            downLocation = nil
            onEvent(.up(start: start, end: location, duration: timestamp - downTime))
        case .rightMouseDown:
            onEvent(.rightDown(location))
        default:
            break
        }
    }

    deinit {
        if let tap { CFMachPortInvalidate(tap) }
    }
}

private let notchClickTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<NotchClickTap>.fromOpaque(refcon).takeUnretainedValue()
    let timestamp = TimeInterval(event.timestamp) / 1_000_000_000
    if Thread.isMainThread {
        MainActor.assumeIsolated { tap.handle(type: type, timestamp: timestamp) }
    }
    return Unmanaged.passUnretained(event)
}
