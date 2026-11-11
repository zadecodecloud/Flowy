import Foundation

/// Product-level switches for whole features.
enum NotchFeatures {
    /// System volume / brightness / keyboard-backlight HUDs in the notch. Off: the notch only
    /// shows its own pages and activities, and macOS keeps its standard on-screen controls.
    /// Each HUD can still be turned off in Settings → HUD.
    static let isHardwareHUDEnabled = true
}
