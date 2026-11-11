import Foundation

/// String lookup for NotchFlow's shipped languages.
/// Order: the requested language, then English, then the caller's fallback, then the key.
enum L10n {
    static func app(_ key: String, fallback: String? = nil) -> String {
        string(key, language: stored(GeneralSettingsStorage.Keys.appLanguage), fallback: fallback)
    }

    static func notch(_ key: String, fallback: String? = nil) -> String {
        string(key, language: stored(GeneralSettingsStorage.Keys.notchLanguage), fallback: fallback)
    }

    static func string(_ key: String, language: NotchLanguage, fallback: String? = nil) -> String {
        if let value = lookup(key, in: language) { return value }
        if language != .english, let value = lookup(key, in: .english) { return value }
        return fallback ?? key
    }

    static func string(_ key: String, locale: Locale, fallback: String? = nil) -> String {
        string(key, language: NotchLanguage(locale: locale), fallback: fallback)
    }

    static func format(_ key: String, locale: Locale, fallback: String? = nil, arguments: [CVarArg]) -> String {
        String(format: string(key, locale: locale, fallback: fallback), locale: locale, arguments: arguments)
    }

    private static func stored(_ key: String) -> NotchLanguage {
        NotchLanguage.resolved(UserDefaults.standard.string(forKey: key))
    }

    private static let missing = "\u{1}__missing__"

    private static func lookup(_ key: String, in language: NotchLanguage) -> String? {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        let value = bundle.localizedString(forKey: key, value: missing, table: nil)
        return value == missing ? nil : value
    }
}

extension Locale {
    /// Localized NotchFlow string for this locale's language.
    func nf(_ key: String, fallback: String? = nil) -> String {
        L10n.string(key, locale: self, fallback: fallback)
    }

    func nfFormat(_ key: String, fallback: String? = nil, _ arguments: CVarArg...) -> String {
        L10n.format(key, locale: self, fallback: fallback, arguments: arguments)
    }
}
