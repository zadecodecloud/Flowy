// NotchFlow modification: no fork support or donation channels configured.
import SwiftUI

struct SupportSettingsView: View {
    @Environment(\.locale) private var locale
    let onRequestInternetAccess: () -> Bool

    var body: some View {
        SettingsPageScrollView {
            SettingsCard {
                Text(locale.dn("notchflow.support.unconfigured", fallback: "Support links are not configured."))
            }
        }
    }
}
