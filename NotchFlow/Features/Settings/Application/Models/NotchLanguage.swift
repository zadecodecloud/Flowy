import SwiftUI

/// Languages NotchFlow ships and maintains. English is the default and the fallback for any
/// string that has no translation. Values from older builds (other languages, "system")
/// resolve to English.
enum NotchLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case vietnamese = "vi"

    static let defaultLanguage: NotchLanguage = .english
    /// Languages offered for notch activities (the same set as the app).
    static let notchLanguages: [NotchLanguage] = allCases

    static func resolved(_ rawValue: String?) -> NotchLanguage {
        rawValue.flatMap(NotchLanguage.init(rawValue:)) ?? defaultLanguage
    }

    /// Matches a locale's language code to a shipped language, defaulting to English.
    init(locale: Locale) {
        let code = locale.language.languageCode?.identifier
            ?? locale.identifier.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
        self = NotchLanguage(rawValue: code ?? "") ?? .defaultLanguage
    }

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var effectiveNotchLanguage: NotchLanguage { self }

    var titleKeyString: String {
        switch self {
        case .english: return "settings.language.option.english"
        case .vietnamese: return "settings.language.option.vietnamese"
        }
    }

    var titleKey: LocalizedStringKey { LocalizedStringKey(titleKeyString) }

    var flagAssetName: String? {
        switch self {
        case .english: return "english"
        case .vietnamese: return "vietnamese"
        }
    }

    var fallbackDisplayName: String {
        switch self {
        case .english: return "English"
        case .vietnamese: return "Vietnamese"
        }
    }

    var nativeDisplayName: String {
        switch self {
        case .english: return "English"
        case .vietnamese: return "Tiếng Việt"
        }
    }

    var accentColors: [Color] {
        switch self {
        case .english: return [.blue, .teal]
        case .vietnamese: return [.red, .yellow]
        }
    }
}
