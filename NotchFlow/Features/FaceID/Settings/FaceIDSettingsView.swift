// NotchFlow modification: remove unsupported login and password controls.
import SwiftUI
struct FaceIDSettingsView: View {
    @ObservedObject var settings: FaceIDSettingsStore
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    var notchViewModel: NotchViewModel?
    var body: some View {
        Text("Face authentication and automatic login are unavailable in Flowy.")
            .padding()
    }
}
