import Foundation

/// The single list of Pro features. Feature code asks `LicenseStore.allows(_:)` where the feature
/// runs (not only in the UI). Everything not listed here is Free.
enum ProFeature: String, CaseIterable {
    /// Importing new files into the notch File Tray (existing files stay reachable on Free).
    case fileTray
    /// Sending files with AirDrop from the notch.
    case airDrop
    /// Music panel, lyrics and keep-awake on the lock screen.
    case lockScreenMusic
}

extension LicenseStore {
    func allows(_ feature: ProFeature) -> Bool { hasPro }
}
