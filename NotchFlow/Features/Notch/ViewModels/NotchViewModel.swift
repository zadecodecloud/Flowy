import SwiftUI
import Combine

typealias NotchScreenMetrics = (width: CGFloat, topInset: CGFloat, notchSize: CGSize?)

@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var notchModel = NotchModel()
    @Published private(set) var swipeStretchProgress: CGFloat = 0
    @Published private(set) var swipeInteraction: SwipeInteraction?
    @Published private(set) var stagedNotchHeight: CGFloat = NotchModel().baseHeight
    @Published private(set) var isExpandingLiveActivityTransition = false
    @Published private(set) var isActivityPresentationHidden = false
    @Published private(set) var hasDisplayedContent = false
    @Published private(set) var topInset: CGFloat = 0
    
    @Published var isLocked = false
    @Published var isHoveringScrollableContent = false
    @Published var showNotch = false
    @Published var isPressed = false
    /// The pointer is over the notch shape (set by `NotchShellInputController`).
    @Published var isHovering = false
    @Published var cachedStrokeColor: Color = .clear
    @Published var pressScale: CGFloat = 1.0
    
    @Published var focusCloseStretchWidth: CGFloat = 0.0
    @Published var focusCloseStretchHeight: CGFloat = 0.0
    
    @Published var notchPulseWidth: CGFloat = 0.0
    @Published var notchPulseHeight: CGFloat = 0.0

    private let settings: NotchSettingsProviding
    private let engine: NotchEngine
    private let screenMetricsProvider: (any NotchSettingsProviding) -> NotchScreenMetrics?
    
    private var cancellables = Set<AnyCancellable>()
    private var expansionTransitionTask: Task<Void, Never>?
    private var swipeStretchResetWorkItem: DispatchWorkItem?
    private var restoreContentWorkItem: DispatchWorkItem?
    private var notchPulseResetWorkItem: DispatchWorkItem?
    private var isClosingHeightStaged = false
    private var isFocusCloseAnimating = false

    var animations: NotchAnimations {
        engine.animations
    }

    var surfaceSizeAnimation: Animation? {
        isSwipeInteractionActive ? nil : animations.updateContent
    }

    var displayedContent: NotchContentProtocol? {
        displayedNotchModel.content
    }

    var displayedPresentationID: String? {
        displayedNotchModel.presentationID
    }

    var isDynamicIsland: Bool {
        topInset == 0
    }

    var isDisplayingExpandedLiveActivity: Bool {
        displayedNotchModel.isPresentingExpandedLiveActivity
    }

    var hasRealDisplayedContent: Bool {
        displayedContent != nil
    }

    var shouldRenderStroke: Bool {
        hasRealDisplayedContent || isHoldingStrokeAfterContentHide
    }

    var shouldApplyPressScale: Bool {
        guard let content = displayedContent else { return true }
        guard !isDisplayingExpandedLiveActivity else { return false }

        return content.allowsPressScaleEffect && content.allowsCompactPressScaleEffect
    }

    /// Hover and press feedback from notchflow-clean: the shape grows slightly while hovered
    /// or pressed, × 1.08 on notch screens and × 1.14 in island mode, never while expanded.
    static let notchHoverScale: CGFloat = 1.08
    static let islandHoverScale: CGFloat = 1.14
    static let hoverAnimation = Animation.easeOut(duration: 0.18)

    var shellHoverScale: CGFloat {
        guard isHovering || isPressed, shouldApplyPressScale else { return 1 }
        return isDynamicIsland ? Self.islandHoverScale : Self.notchHoverScale
    }

    var displayedBaseNotchSize: CGSize {
        displayedNotchModel.size
    }

    var presentedNotchSize: CGSize {
        let size = interactiveNotchSize

        guard !isSwipeInteractionActive, isClosingHeightStaged else {
            return size
        }

        return CGSize(
            width: size.width,
            height: stagedNotchHeight
        )
    }

    var isSwipeInteractionActive: Bool {
        swipeInteraction != nil
    }
    
    var canExpandActiveLiveActivity: Bool {
        guard (!isActivityPresentationHidden || isLocked) || notchModel.temporaryNotificationContent != nil else { return false }
        if isLocked {
            guard notchModel.temporaryNotificationContent != nil || notchModel.liveActivityContent?.id == NotchContentRegistry.LockScreen.activity.id else {
                return false
            }
        }
        guard hasRealDisplayedContent else { return false }
        return engine.canExpandActiveLiveActivity
    }
    
    var shouldExpandActiveContentOnClick: Bool {
        settings.isNotchTapToExpandEnabled &&
        settings.notchExpandInteraction == .click &&
        canExpandActiveLiveActivity
    }

    var shouldExpandActiveContentOnPressAndHold: Bool {
        settings.isNotchTapToExpandEnabled &&
        settings.notchExpandInteraction == .pressAndHold &&
        canExpandActiveLiveActivity
    }

    var shouldExpandActiveContentOnHover: Bool {
        settings.isNotchTapToExpandEnabled &&
        settings.notchExpandInteraction == .hover &&
        canExpandActiveLiveActivity
    }

    var notchExpandInteraction: NotchExpandInteraction {
        settings.notchExpandInteraction
    }

    var shouldCollapseActiveContentOnHoverLeaves: Bool {
        settings.notchCollapseInteraction == .hoverLeaves &&
        isDisplayingExpandedLiveActivity
    }

    var notchPressHoldDuration: TimeInterval {
        settings.notchPressHoldDuration
    }

    var notchHoverExpandDelay: TimeInterval {
        settings.notchPressHoldDuration
    }
    
    var canRestoreDismissedContent: Bool {
        guard !isLocked else { return false }
        return engine.canRestoreDismissedContent
    }

    var canOpenActiveWindowLink: Bool {
        guard !isLocked else { return false }
        guard !isActivityPresentationHidden || notchModel.temporaryNotificationContent != nil else { return false }
        guard hasRealDisplayedContent else { return false }
        return engine.canOpenActiveWindowLink
    }
    
    var canDismissWithMouseDrag: Bool {
        settings.isNotchMouseDragGesturesEnabled &&
        settings.isNotchSwipeDismissEnabled &&
        (!isActivityPresentationHidden || isLocked || notchModel.temporaryNotificationContent != nil) &&
        hasRealDisplayedContent
    }
    
    var canRestoreWithMouseDrag: Bool {
        guard !isLocked else { return false }
        guard !notchModel.isLiveActivityExpanded else { return false }
        return settings.isNotchMouseDragGesturesEnabled &&
        settings.isNotchSwipeRestoreEnabled &&
        canRestoreDismissedContent
    }
    
    var canDismissWithTrackpadSwipe: Bool {
        settings.isNotchTrackpadSwipeGesturesEnabled &&
        settings.isNotchSwipeDismissEnabled &&
        (!isActivityPresentationHidden || isLocked || notchModel.temporaryNotificationContent != nil) &&
        hasRealDisplayedContent
    }
    
    var canRestoreWithTrackpadSwipe: Bool {
        guard !isLocked else { return false }
        guard !notchModel.isLiveActivityExpanded else { return false }
        return settings.isNotchTrackpadSwipeGesturesEnabled &&
        settings.isNotchSwipeRestoreEnabled &&
        canRestoreDismissedContent
    }
    
    var isNotchHoverHapticEnabled: Bool {
        settings.isNotchHoverHapticEnabled
    }
    
    var interactiveNotchSize: CGSize {
        let model = displayedNotchModel
        let baseSize = model.size
        let progress = easedSwipeStretchProgress
        let calculatedSize: CGSize
        
        switch swipeInteraction {
        case .dismiss:
            if model.isPresentingExpandedLiveActivity || baseSize.height > model.baseHeight + 1 {
                let heightCompression = min(
                    max(baseSize.height * SwipeFeedbackMetrics.expandedDismissHeightFactor, SwipeFeedbackMetrics.expandedDismissMinimumHeight),
                    SwipeFeedbackMetrics.expandedDismissMaximumHeight
                )
                
                calculatedSize = CGSize(
                    width: baseSize.width,
                    height: max(model.baseHeight, baseSize.height - (heightCompression * progress))
                )
            } else {
                let widthCompression = min(
                    max(baseSize.width * SwipeFeedbackMetrics.collapsedDismissWidthFactor, SwipeFeedbackMetrics.collapsedDismissMinimumWidth),
                    SwipeFeedbackMetrics.collapsedDismissMaximumWidth
                )
                
                calculatedSize = CGSize(
                    width: max(baseSize.height, baseSize.width - (widthCompression * progress)),
                    height: baseSize.height
                )
            }
            
        case .restore:
            calculatedSize = CGSize(
                width: baseSize.width,
                height: baseSize.height + (SwipeFeedbackMetrics.restoreHeightExpansion * progress)
            )
            
        case nil:
            calculatedSize = baseSize
        }

        return CGSize(
            width: calculatedSize.width + focusCloseStretchWidth + notchPulseWidth,
            height: calculatedSize.height + focusCloseStretchHeight + notchPulseHeight
        )
    }
    
    var interactiveCornerRadius: (top: CGFloat, bottom: CGFloat) {
        let model = displayedNotchModel
        let baseCornerRadius = model.cornerRadius
        let radiusOffset = (focusCloseStretchHeight + notchPulseHeight) * 0.3
        
        return (
            top: baseCornerRadius.top + radiusOffset,
            bottom: baseCornerRadius.bottom + radiusOffset
        )
    }
    
    var dynamicIslandCornerRadius: CGFloat {
        let height = swipeInteraction != nil ? displayedNotchModel.size.height : presentedNotchSize.height
        let baseRadius: CGFloat
        
        if isDisplayingExpandedLiveActivity {
            if let customizable = displayedContent {
                baseRadius = customizable.expandedDynamicIslandCornerRadius(baseHeight: height)
            } else {
                baseRadius = height * 0.2
            }
        } else {
            if let customizable = displayedContent {
                baseRadius = customizable.dynamicIslandCornerRadius(baseHeight: height)
            } else {
                baseRadius = height * 0.5
            }
        }
        
        let model = displayedNotchModel
        if isDynamicIsland && swipeInteraction != nil && model.size.height > model.baseHeight {
            let swipeRadiusExpansion = SwipeFeedbackMetrics.swipeCornerRadiusExpansion * easedSwipeStretchProgress
            return baseRadius + swipeRadiusExpansion
        }
        return baseRadius
    }
    
    var contentResizeBlurRadius: CGFloat {
        let progress = min(1.0, easedSwipeStretchProgress)
        
        switch swipeInteraction {
        case .dismiss:
            return SwipeFeedbackMetrics.dismissBlurRadius * progress
            
        case .restore:
            return SwipeFeedbackMetrics.restoreBlurRadius * progress
            
        case nil:
            return 0
        }
    }
    
    var contentResizeOpacity: Double {
        let progress = Double(easedSwipeStretchProgress)
        
        switch swipeInteraction {
        case .dismiss:
            return max(0, 1 - (SwipeFeedbackMetrics.dismissOpacityReduction * progress))
            
        case .restore:
            return max(0, 1 - (SwipeFeedbackMetrics.restoreOpacityReduction * progress))
            
        case nil:
            return 1
        }
    }
    
    init(
        settings: NotchSettingsProviding,
        animations: NotchAnimations? = nil,
        hideDelay: TimeInterval? = nil,
        queueDelay: TimeInterval? = nil,
        engine: NotchEngine? = nil,
        screenMetricsProvider: (((any NotchSettingsProviding) -> NotchScreenMetrics?))? = nil
    ) {
        self.settings = settings
        self.screenMetricsProvider = screenMetricsProvider ?? { settings in
            NSScreen.metrics(for: settings)
        }
        self.engine = engine ?? NotchEngine(
            animations: {
                animations ?? .balanced
            },
            hideDelay: hideDelay,
            queueDelay: queueDelay
        )
        updateDimensions(animated: false)
        bindEngine()
    }

    func updateDimensions(animated: Bool = true) {
        guard let screenMetrics = screenMetricsProvider(settings) else {
            return
        }
        
        self.topInset = screenMetrics.topInset
        
        let screenWidth = screenMetrics.width
        let baseScreenWidth: CGFloat = 1440.0
        let scale = max(0.35, screenWidth / baseScreenWidth)
        let widthScale = scale > 1.0 ? 1.0 + (scale - 1.0) * 0.35 : scale
        
        let isDynamicIsland = screenMetrics.topInset == 0
        let widthOffset = CGFloat(settings.notchWidth) + 2
        let heightOffset = CGFloat(settings.notchHeight)
        let baseHeightAdjustment: CGFloat = isDynamicIsland ? 5 : 0
        
        let finalWidth: CGFloat
        let finalHeight: CGFloat
        
        if let notchSize = screenMetrics.notchSize {
            let baseWidth = notchSize.width + 14.scaled(by: widthScale) + widthOffset
            finalWidth = isDynamicIsland ? baseWidth * 0.85 : baseWidth
            finalHeight = notchSize.height + heightOffset + baseHeightAdjustment
        } else {
            let baseWidthValue: CGFloat = isDynamicIsland ? 90 : 190
            let baseWidth = (baseWidthValue * widthScale) + widthOffset
            finalWidth = isDynamicIsland ? baseWidth * 0.85 : baseWidth
            finalHeight = 26 + heightOffset + baseHeightAdjustment
        }
        
        let applyGeometry = {
            self.engine.updateBaseGeometry(
                width: finalWidth,
                height: finalHeight,
                scale: scale,
                isDynamicIsland: isDynamicIsland
            )
        }
        
        if animated {
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                applyGeometry()
            }
        } else {
            applyGeometry()
        }
    }
    
    func selectPage(_ content: NotchContentProtocol) {
        engine.selectPage(content)
    }

    func send(_ notchState: NotchState) {
        engine.send(notchState)
    }

    func setActivityPresentationHidden(_ isHidden: Bool) {
        guard isActivityPresentationHidden != isHidden else { return }

        resetSwipeStretch()

        withAnimation(animations.notchVisibility) {
            isActivityPresentationHidden = isHidden
            hasDisplayedContent = hasRealDisplayedContent
        }
    }
    
    func hideTemporaryNotification() {
        engine.hideTemporaryNotification()
    }
    
    func dismissActiveContent() {
        if isLocked {
            resetSwipeStretch()
            return
        }

        if notchModel.isLiveActivityExpanded {
            engine.handleOutsideClick()
            return
        }
        
        engine.dismissActiveContent()
    }
    
    func restoreDismissedContent() {
        if isLocked {
            resetSwipeStretch()
            return
        }

        restoreContentWorkItem?.cancel()
        restoreContentWorkItem = nil

        if swipeStretchProgress > 0 || swipeInteraction != nil {
            applySwipeStretchReset()
            let workItem = DispatchWorkItem { [weak self] in
                self?.restoreContentWorkItem = nil
                self?.engine.restoreDismissedContent()
            }
            restoreContentWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
        } else {
            engine.restoreDismissedContent()
        }
    }

    func openActiveWindowLink() {
        guard let content = notchModel.content, content.windowLink != nil else {
            engine.openActiveWindowLink()
            return
        }
        
        if notchModel.temporaryNotificationContent != nil {
            engine.openActiveWindowLink()
            engine.hideTemporaryNotification()
            return
        }
        
        let isFocus = content.id == NotchContentRegistry.Focus.active.id || content.id == NotchContentRegistry.Focus.inactive.id
        if isFocus && settings.isCloseAtFocusLiveActivityEnabled {
            triggerFocusCloseAnimation(for: content.id) { [weak self] in
                self?.engine.openActiveWindowLink()
                self?.send(.hideLiveActivity(id: content.id))
            }
        } else {
            engine.openActiveWindowLink()
        }
    }

    func triggerFocusCloseAnimation(for id: String, completion: @escaping () -> Void) {
        guard !isFocusCloseAnimating else {
            completion()
            return
        }
        isFocusCloseAnimating = true
        
        let currentWidth = presentedNotchSize.width
        let currentHeight = presentedNotchSize.height

        let compressWidth = -max(20, currentWidth * 0.2)
        let stretchHeight = max(40, currentHeight * 0.2)

        // Squeeze-and-stretch timing from notchflow-clean: ease in over 0.1 s, then spring
        // back over ≈ 0.4 s.
        withAnimation(.easeOut(duration: Self.squeezeIn)) {
            self.focusCloseStretchWidth = compressWidth
            self.focusCloseStretchHeight = stretchHeight
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.squeezeIn) {
            withAnimation(.spring(response: Self.squeezeOut, dampingFraction: 0.6)) {
                self.focusCloseStretchWidth = 0
                self.focusCloseStretchHeight = 0
            }
            completion()

            DispatchQueue.main.asyncAfter(deadline: .now() + Self.squeezeOut) {
                self.isFocusCloseAnimating = false
            }
        }
    }

    static let squeezeIn: TimeInterval = 0.1
    static let squeezeOut: TimeInterval = 0.4
    /// Attention pulse from notchflow-clean: ≈ +30 × +10 pt, a quick spring out and back.
    static let pulseAnimation = Animation.spring(response: 0.22, dampingFraction: 0.55)
    static let pulseHold: TimeInterval = 0.22

    func pulseNotch(widthOffset: CGFloat = 30.0, heightOffset: CGFloat = 10.0) {
        notchPulseResetWorkItem?.cancel()
        withAnimation(Self.pulseAnimation) {
            self.notchPulseWidth = widthOffset
            self.notchPulseHeight = heightOffset
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(Self.pulseAnimation) {
                self.notchPulseWidth = 0
                self.notchPulseHeight = 0
            }
        }
        notchPulseResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pulseHold, execute: workItem)
    }
    
    func updateSwipeStretch(for interaction: SwipeInteraction, progress: CGFloat) {
        swipeStretchResetWorkItem?.cancel()
        swipeStretchResetWorkItem = nil

        let clampedProgress = max(progress, 0)
        guard swipeInteraction != interaction || abs(swipeStretchProgress - clampedProgress) > 0.001 else {
            return
        }

        swipeInteraction = interaction
        swipeStretchProgress = clampedProgress
    }
    
    func resetSwipeStretch() {
        guard swipeStretchProgress > 0 || swipeInteraction != nil else { return }

        swipeStretchResetWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.applySwipeStretchReset()
        }
        swipeStretchResetWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func applySwipeStretchReset() {
        swipeStretchResetWorkItem = nil
        guard swipeStretchProgress > 0 || swipeInteraction != nil else { return }

        withAnimation(animations.stretchReset) {
            swipeStretchProgress = 0
            swipeInteraction = nil
        }
    }
    
    /// Opens a page when the user clicks an empty notch. Set by `NotchEventCoordinator`.
    var onIdleTap: (() -> Void)?

    /// True when a click on the compact notch has nothing of its own to do: the notch is empty,
    /// or it only shows a status indicator (Hotspot, VPN…) that neither expands nor links anywhere.
    var isShowingOnlyAmbientContent: Bool {
        guard let content = displayedContent else { return true }
        return !content.isExpandable && content.widgetURL == nil && content.windowLink == nil
    }

    /// A click on an empty or indicator-only notch opens the default page instead of doing nothing.
    func handleIdleTap() {
        guard settings.isNotchTapToExpandEnabled, isShowingOnlyAmbientContent, !isLocked,
              notchModel.temporaryNotificationContent == nil else { return }
        onIdleTap?()
    }

    func handleActiveContentTap() {
        guard settings.isNotchTapToExpandEnabled,
              canExpandActiveLiveActivity else { return }

        performActiveLiveActivityExpansion()
    }

    func expandActiveLiveActivity() {
        guard canExpandActiveLiveActivity else { return }

        performActiveLiveActivityExpansion()
    }

    private func performActiveLiveActivityExpansion() {
        expansionTransitionTask?.cancel()
        isExpandingLiveActivityTransition = true

        expansionTransitionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: ExpansionTransitionTiming.preparationDelay)
            guard let self, !Task.isCancelled else { return }

            self.engine.handleActiveContentTap()

            try? await Task.sleep(nanoseconds: ExpansionTransitionTiming.resetDelay)
            guard !Task.isCancelled else { return }

            self.isExpandingLiveActivityTransition = false
            self.expansionTransitionTask = nil
        }
    }
    
    func handleOutsideClick() {
        engine.handleOutsideClick()
    }
    
    func handleStrokeVisibility() {
        engine.handleStrokeVisibility()
    }
    
    var easedSwipeStretchProgress: CGFloat {
        (1.5 * swipeStretchProgress) / (0.5 + swipeStretchProgress)
    }

    private var isHoldingStrokeAfterContentHide: Bool {
        showNotch &&
        !hasRealDisplayedContent &&
        notchModel.content == nil
    }

    private var displayedNotchModel: NotchModel {
        guard isActivityPresentationHidden, !isLocked else {
            return notchModel
        }

        var model = notchModel
        model.liveActivityContent = nil
        model.isLiveActivityExpanded = false
        return model
    }

    func contentTransition(
        notchWidth: CGFloat? = nil,
        notchHeight: CGFloat,
        baseWidth: CGFloat? = nil,
        baseHeight: CGFloat,
        isExpandedPresentation: Bool
    ) -> AnyTransition {
        // Content changes cross-fade like notchflow-clean's shell (`.transition(.opacity)`);
        // the shape itself carries the movement.
        if isExpandedPresentation {
            return .asymmetric(
                insertion: .opacity.animation(animations.expandedLiveActivityContentTransition),
                removal: .opacity.animation(animations.collapsedLiveActivityContentTransition)
            )
        } else {
            return .asymmetric(
                insertion: .opacity.animation(animations.showContent),
                removal: .opacity.animation(animations.hideContent)
            )
        }
    }
    
    private func bindEngine() {
        notchModel = engine.notchModel
        showNotch = engine.showNotch
        cachedStrokeColor = engine.cachedStrokeColor
        stagedNotchHeight = engine.notchModel.size.height
        isClosingHeightStaged = false
        hasDisplayedContent = hasRealDisplayedContent
        
        engine.$notchModel
            .dropFirst()
            .sink { [weak self] in
                guard let self else { return }
                self.scheduleStagedHeightUpdate(to: $0.size.height)
                self.notchModel = $0
                self.hasDisplayedContent = self.hasRealDisplayedContent
            }
            .store(in: &cancellables)
        
        engine.$showNotch
            .sink { [weak self] in
                self?.showNotch = $0
            }
            .store(in: &cancellables)
        
        engine.$cachedStrokeColor
            .sink { [weak self] in
                self?.cachedStrokeColor = $0
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .notchContentPrioritiesDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.engine.refreshLiveActivityPriorities()
            }
            .store(in: &cancellables)
    }

    private func scheduleStagedHeightUpdate(to targetHeight: CGFloat) {
        guard !isSwipeInteractionActive else {
            isClosingHeightStaged = false
            stagedNotchHeight = targetHeight
            return
        }

        let currentHeight = stagedNotchHeight

        guard abs(currentHeight - targetHeight) > 0.5 else {
            isClosingHeightStaged = false
            stagedNotchHeight = targetHeight
            return
        }

        guard targetHeight < currentHeight else {
            isClosingHeightStaged = false
            stagedNotchHeight = targetHeight
            return
        }

        isClosingHeightStaged = false
        applyStagedHeight(targetHeight, animated: true)
    }

    private func applyStagedHeight(_ targetHeight: CGFloat, animated: Bool) {
        guard animated, let animation = surfaceSizeAnimation else {
            stagedNotchHeight = targetHeight
            return
        }

        withAnimation(animation) {
            stagedNotchHeight = targetHeight
        }
    }
}

private enum ExpansionTransitionTiming {
    static let preparationDelay: UInt64 = 16_000_000
    static let resetDelay: UInt64 = 120_000_000
}
