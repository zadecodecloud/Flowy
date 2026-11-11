import SwiftUI
internal import AppKit

/// Turns pointer input over the notch into notch actions. Modelled on notchflow-clean's
/// `ShellOverlayController`: the notch panel ignores mouse events everywhere except while
/// the pointer is over the visible shape, clicks come from `NotchClickTap` (they do not
/// reliably reach the notch window), and hover is tracked with event monitors plus a poll.
///
/// The decisions themselves (expand, idle tap, dismiss, restore) stay with
/// `NotchViewModel`, so the existing settings keep working.
final class NotchShellInputController {
    static let tapSlop: CGFloat = 8
    static let hoverCollapseDelay: TimeInterval = 0.4

    private weak var panel: NSPanel?
    private let notchViewModel: NotchViewModel
    private let hitRect: () -> CGRect?
    private let menuProvider: () -> NSMenu

    private var clickTap: NotchClickTap?
    private var moveMonitors: [Any] = []
    private var pollTimer: Timer?
    private var hoverWork: DispatchWorkItem?
    private var holdWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?
    private var holdFired = false
    private var pressStart: NSPoint?
    private var pressStartedExpanded = false
    private var lastDrag: NSPoint?
    private var dragFlick = VerticalFlick(source: .mouse)
    private(set) var pointerInside = false

    init(panel: NSPanel, notchViewModel: NotchViewModel,
         hitRect: @escaping () -> CGRect?, menuProvider: @escaping () -> NSMenu) {
        self.panel = panel
        self.notchViewModel = notchViewModel
        self.hitRect = hitRect
        self.menuProvider = menuProvider
    }

    // MARK: - Lifecycle

    func start() {
        guard clickTap == nil else { return }
        panel?.ignoresMouseEvents = true

        let tap = NotchClickTap { [weak self] event in self?.handlePointer(event) }
        tap.start()
        clickTap = tap

        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.trackPointer() }
        }) { moveMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: moves, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.trackPointer() }
            return event
        }) { moveMonitors.append(local) }
        // Safety net for pointer movement no monitor reports (for example over the notch itself).
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackPointer() }
        }
        trackPointer()
    }

    func stop() {
        clickTap?.stop(); clickTap = nil
        moveMonitors.forEach(NSEvent.removeMonitor); moveMonitors = []
        pollTimer?.invalidate(); pollTimer = nil
        cancelPending()
        resetPress()
        pointerInside = false
        notchViewModel.isHovering = false
    }

    /// Re-evaluates the pointer, for example after the window moved or the notch resized.
    func refresh() { trackPointer() }

    private func isInside(_ point: NSPoint) -> Bool {
        hitRect()?.contains(point) ?? false
    }

    private var isExpanded: Bool { notchViewModel.notchModel.isPresentingExpandedLiveActivity }

    private var canInteract: Bool {
        (!notchViewModel.isActivityPresentationHidden || notchViewModel.isLocked)
            || notchViewModel.notchModel.temporaryNotificationContent != nil
    }

    // MARK: - Hover

    private func trackPointer() {
        guard let panel, panel.isVisible else { return }
        let inside = isInside(NSEvent.mouseLocation)
        // Let the panel take events only over the visible shape, so clicks, drags and file
        // drops reach it there and pass through everywhere else.
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        guard inside != pointerInside else { return }
        pointerInside = inside
        notchViewModel.isHovering = inside
        if inside {
            collapseWork?.cancel()
            if notchViewModel.isNotchHoverHapticEnabled, notchViewModel.canExpandActiveLiveActivity, !isExpanded {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
            if notchViewModel.shouldExpandActiveContentOnHover, canInteract, !isExpanded {
                scheduleHoverOpen()
            }
        } else {
            hoverWork?.cancel()
            if pressStart == nil { scheduleHoverCollapse() }
        }
    }

    private func scheduleHoverOpen() {
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.pointerInside, self.pressStart == nil,
                  self.notchViewModel.shouldExpandActiveContentOnHover, self.canInteract,
                  !self.isExpanded else { return }
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            self.notchViewModel.handleActiveContentTap()
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + notchViewModel.notchHoverExpandDelay, execute: work)
    }

    private func scheduleHoverCollapse() {
        guard notchViewModel.shouldCollapseActiveContentOnHoverLeaves else { return }
        collapseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.pointerInside, self.pressStart == nil,
                  self.notchViewModel.shouldCollapseActiveContentOnHoverLeaves,
                  !self.isInside(NSEvent.mouseLocation) else { return }
            self.notchViewModel.handleOutsideClick()
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverCollapseDelay, execute: work)
    }

    // MARK: - Clicks, hold and mouse drags

    private func handlePointer(_ event: PointerSignal) {
        switch event {
        case .down(let point):
            // Clicks outside are handled by the outside-click monitor (it collapses).
            guard isInside(point) else { pressStart = nil; return }
            pressStart = point
            pressStartedExpanded = isExpanded
            lastDrag = point
            holdFired = false
            dragFlick.reset()
            guard !pressStartedExpanded else { return }
            notchViewModel.isPressed = true
            if notchViewModel.shouldExpandActiveContentOnPressAndHold { scheduleHoldOpen() }
        case .dragged(let point):
            guard pressStart != nil, let last = lastDrag else { return }
            lastDrag = point
            dragFlick.update(dx: point.x - last.x, up: point.y - last.y)
            setSwipeFeedback()
            if dragFlick.isVertical { holdWork?.cancel() }
        case .up(let start, let end, _):
            holdWork?.cancel()
            guard let pressed = pressStart else { return }
            let startedExpanded = pressStartedExpanded
            pressStart = nil
            lastDrag = nil
            resetPress()
            defer {
                notchViewModel.resetSwipeStretch()
                dragFlick.reset()
                if !isInside(NSEvent.mouseLocation) { scheduleHoverCollapse() }
            }
            if holdFired { return }
            if let outcome = dragFlick.outcome {
                perform(outcome)
                return
            }
            // Clicks on expanded content belong to its own controls.
            guard !startedExpanded,
                  hypot(end.x - start.x, end.y - start.y) < Self.tapSlop,
                  isInside(pressed), isInside(end) else { return }
            if notchViewModel.shouldExpandActiveContentOnClick {
                notchViewModel.handleActiveContentTap()
            } else if notchViewModel.isShowingOnlyAmbientContent {
                notchViewModel.handleIdleTap()
            } else {
                notchViewModel.openActiveWindowLink()
            }
        case .rightDown(let point):
            guard isInside(point) else { return }
            let menu = menuProvider()
            // Never run a menu's tracking loop inside an event-tap callback.
            DispatchQueue.main.async { menu.popUp(positioning: nil, at: point, in: nil) }
        }
    }

    private func scheduleHoldOpen() {
        holdWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.pressStart != nil,
                  self.notchViewModel.shouldExpandActiveContentOnPressAndHold,
                  !self.isExpanded else { return }
            self.holdFired = true
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            self.resetPress()
            self.notchViewModel.handleActiveContentTap()
        }
        holdWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + notchViewModel.notchPressHoldDuration, execute: work)
    }

    private func resetPress() {
        if notchViewModel.isPressed { notchViewModel.isPressed = false }
    }

    private func cancelPending() {
        hoverWork?.cancel(); holdWork?.cancel(); collapseWork?.cancel()
    }

    // MARK: - Dismiss and restore by mouse drag

    private func setSwipeFeedback() {
        let progress = dragFlick.progress
        if progress > 0, notchViewModel.canDismissWithMouseDrag {
            notchViewModel.updateSwipeStretch(for: .dismiss, progress: progress)
        } else if progress < 0, notchViewModel.canRestoreWithMouseDrag {
            notchViewModel.updateSwipeStretch(for: .restore, progress: -progress)
        } else {
            notchViewModel.resetSwipeStretch()
        }
    }

    private func perform(_ outcome: VerticalFlick.Outcome) {
        switch outcome {
        case .dismiss:
            if notchViewModel.canDismissWithMouseDrag { notchViewModel.dismissActiveContent() }
        case .restore:
            if notchViewModel.canRestoreWithMouseDrag { notchViewModel.restoreDismissedContent() }
        }
    }
}

// Taken from notchflow-clean (`Input/VerticalFlick.swift`).

/// One vertical gesture on the notch: a trackpad two-finger scroll or a mouse drag. Up
/// dismisses, down restores. The axis locks after ≈ 12 pt, so a gesture that starts
/// horizontal never dismisses.
struct VerticalFlick {
    enum Outcome: Equatable { case dismiss, restore }
    enum Source {
        case trackpad, mouse
        /// "Mostly vertical": vertical movement must exceed this multiple of the horizontal.
        var dominance: CGFloat { self == .trackpad ? 1.25 : 1.15 }
    }

    static let threshold: CGFloat = 60
    static let axisLockDistance: CGFloat = 12

    let source: Source
    /// Accumulated movement; `up` is positive when the fingers or mouse move up.
    private(set) var horizontal: CGFloat = 0
    private(set) var up: CGFloat = 0
    private var axis: Axis?
    private enum Axis { case horizontal, vertical }

    init(source: Source) { self.source = source }

    var isVertical: Bool { axis == .vertical }

    mutating func reset() { horizontal = 0; up = 0; axis = nil }

    /// Adds movement and returns the feedback progress in -1…1 (positive = dismissing).
    @discardableResult
    mutating func update(dx: CGFloat, up dy: CGFloat) -> CGFloat {
        horizontal += dx
        up += dy
        if axis == nil {
            if abs(up) >= Self.axisLockDistance, abs(up) > abs(horizontal) * source.dominance { axis = .vertical }
            else if abs(horizontal) >= Self.axisLockDistance, abs(horizontal) > abs(up) { axis = .horizontal }
        }
        return progress
    }

    var progress: CGFloat {
        guard axis == .vertical else { return 0 }
        return max(-1, min(1, up / Self.threshold))
    }

    /// The action when the gesture ends, if any.
    var outcome: Outcome? {
        guard axis == .vertical, abs(up) > abs(horizontal) * source.dominance else { return nil }
        if up >= Self.threshold { return .dismiss }
        if up <= -Self.threshold { return .restore }
        return nil
    }
}
