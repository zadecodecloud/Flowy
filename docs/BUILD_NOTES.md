# Build notes

Targets: `NotchFlow`, `NotchFlowTests`, `NotchFlowUITests`. Shared schemes: `NotchFlow`, `NotchFlow Glass Preview`, `NotchFlow Lock Screen Preview`. Swift module: `NotchFlow`. Lottie 4.6.0 and Sparkle 2.9.4 are pinned.

Default language is English; Vietnamese and other languages are available in Settings.

The notch glass uses private Core Animation and AppKit glass APIs (`CABackdropLayer` variable blur, `NSGlassEffectView` lensing variant) with a SwiftUI glass fallback. Clicks on the compact notch are observed with a global event monitor (or an event tap when Input Monitoring/Accessibility is granted), because the menu-bar strip receives them first.

Unit tests: `xcodebuild test -scheme NotchFlow -only-testing:NotchFlowTests`. The UI test runner is not used on this Mac.
