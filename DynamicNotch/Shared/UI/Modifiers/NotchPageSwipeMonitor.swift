import SwiftUI
internal import AppKit

/// One physical horizontal gesture produces at most one navigation action.
struct NotchPageSwipe {
    enum Direction { case left, right }
    private var x: CGFloat = 0
    private var y: CGFloat = 0
    private var didFire = false
    private var axis: Axis?
    private enum Axis { case horizontal, vertical }
    var hasHorizontalIntent: Bool { axis == .horizontal }

    mutating func reset() { x = 0; y = 0; didFire = false; axis = nil }

    mutating func update(x deltaX: CGFloat, y deltaY: CGFloat) -> Direction? {
        guard !didFire else { return nil }
        x += deltaX
        y += abs(deltaY)
        if axis == nil {
            if abs(x) >= 12, abs(x) > y * 1.5 { axis = .horizontal }
            else if y >= 12, y > abs(x) * 1.5 { axis = .vertical }
        }
        guard hasHorizontalIntent, abs(x) >= 60 else { return nil }
        didFire = true
        return x > 0 ? .right : .left
    }
}

/// Tracks the gesture from its starting point across the whole visible surface.
/// Claimed horizontal scrolling (including inertia) must not also scroll the tray.
struct NotchPageSwipeTracking {
    private var swipe = NotchPageSwipe()
    private var tracking = false
    private var consumesMomentum = false

    mutating func update(location: CGPoint, bounds: CGRect, x: CGFloat, y: CGFloat,
                         starts: Bool, ends: Bool, momentum: Bool) -> (direction: NotchPageSwipe.Direction?, consumes: Bool) {
        if momentum { return (nil, consumesMomentum) }
        if starts {
            swipe.reset()
            tracking = bounds.contains(location)
            consumesMomentum = false
        }
        guard tracking else { return (nil, false) }
        if ends {
            tracking = false
            return (nil, consumesMomentum)
        }
        let direction = swipe.update(x: x, y: y)
        consumesMomentum = swipe.hasHorizontalIntent
        return (direction, consumesMomentum)
    }
}

/// Once a gesture belongs to the file list or the pager, keep that owner until
/// the next gesture. This prevents a single swipe from both scrolling and paging.
struct NotchPageGestureArbiter {
    private enum Owner { case content, page }
    private var owner: Owner?

    mutating func usePage(starts: Bool, momentum: Bool, x: CGFloat, y: CGFloat,
                          canScroll: Bool) -> Bool {
        if starts && !momentum { owner = nil }
        if owner == nil, !momentum, abs(x) >= 2, abs(x) > abs(y) * 1.5 {
            owner = canScroll ? .content : .page
        }
        return owner != .content
    }

    static func canScroll(deltaX: CGFloat, visible: CGRect, document: CGRect) -> Bool {
        guard document.width > visible.width + 1, abs(deltaX) >= 2 else { return false }
        if deltaX > 0 { return visible.minX > document.minX + 1 }
        return visible.maxX < document.maxX - 1
    }
}

struct NotchPageSwipeMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let onSwipe: (NotchPageSwipe.Direction) -> Void

    func makeNSView(context: Context) -> MonitorView { MonitorView() }
    func updateNSView(_ view: MonitorView, context: Context) {
        view.enabled = isEnabled
        view.onSwipe = onSwipe
    }
    static func dismantleNSView(_ view: MonitorView, coordinator: ()) { view.stop() }

    final class MonitorView: NSView {
        var enabled = false {
            didSet { if !enabled { gesture = NotchPageSwipeTracking() } }
        }
        var onSwipe: ((NotchPageSwipe.Direction) -> Void)?
        private var monitor: Any?
        private var gesture = NotchPageSwipeTracking()
        private var arbiter = NotchPageGestureArbiter()
        private var lastScrollTime: TimeInterval = 0

        // Observe events without becoming a hit target over controls or file drops.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { stop(); return }
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event) == true ? nil : event
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            gesture = NotchPageSwipeTracking()
            arbiter = NotchPageGestureArbiter()
        }
        deinit { stop() }

        private func handle(_ event: NSEvent) -> Bool {
            guard enabled, let window, event.window === window,
                  event.hasPreciseScrollingDeltas else { return false }
            let startsUnphasedGesture = event.phase.isEmpty && event.timestamp - lastScrollTime > 0.25
            lastScrollTime = event.timestamp
            let factor: CGFloat = event.isDirectionInvertedFromDevice ? -1 : 1
            let starts = event.phase.contains(.began) || event.phase.contains(.mayBegin) || startsUnphasedGesture
            let momentum = !event.momentumPhase.isEmpty
            let local = convert(event.locationInWindow, from: nil)
            let canScroll = bounds.contains(local) && horizontalScrollView(at: event.locationInWindow).map {
                guard let document = $0.documentView else { return false }
                return NotchPageGestureArbiter.canScroll(deltaX: event.scrollingDeltaX,
                    visible: $0.documentVisibleRect, document: document.bounds)
            } == true
            guard arbiter.usePage(starts: starts, momentum: momentum,
                                  x: event.scrollingDeltaX, y: event.scrollingDeltaY,
                                  canScroll: canScroll) else { return false }
            let result = gesture.update(
                location: local, bounds: bounds,
                x: event.scrollingDeltaX * factor, y: event.scrollingDeltaY * factor,
                starts: starts,
                ends: event.phase.contains(.ended) || event.phase.contains(.cancelled),
                momentum: momentum)
            if let direction = result.direction { onSwipe?(direction) }
            return result.consumes
        }

        private func horizontalScrollView(at windowPoint: NSPoint) -> NSScrollView? {
            guard let root = window?.contentView else { return nil }
            let point = root.superview?.convert(windowPoint, from: nil) ?? windowPoint
            var candidate = root.hitTest(point)
            while let view = candidate {
                if let scroll = view as? NSScrollView, scroll.hasHorizontalScroller ||
                    (scroll.documentView?.bounds.width ?? 0) > scroll.documentVisibleRect.width + 1 {
                    return scroll
                }
                candidate = view.superview
            }
            return nil
        }
    }
}
