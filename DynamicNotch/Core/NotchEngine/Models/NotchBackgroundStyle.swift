import SwiftUI

enum NotchBackgroundStyle: String, CaseIterable {
    case black
    case glass

    static var availableOptions: [Self] {
        return Array(allCases)
    }

    var title: LocalizedStringKey {
        switch self {
        case .black:
            return "settings.notch.backgroundStyle.black"
        case .glass:
            return "notchflow.notch.background.glass"
        }
    }

    var symbolName: String {
        switch self {
        case .black:
            return "circle.fill"
        case .glass:
            return "circle.lefthalf.filled"
        }
    }

    var isSupportedOnCurrentSystem: Bool {
        return true
    }

    func effectiveStyle(reduceTransparency: Bool) -> Self {
        reduceTransparency ? .black : self
    }

    static func resolved(_ rawValue: String?) -> NotchBackgroundStyle {
        guard let rawValue, let style = NotchBackgroundStyle(rawValue: rawValue) else {
            return .black
        }

        return style
    }
}
