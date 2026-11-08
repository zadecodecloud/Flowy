// NotchFlow modification: neutral welcome; upstream implementation remains credited in the project.
import SwiftUI

struct OnboardingNotchView: View {
    @Environment(\.locale) private var locale
    @Environment(\.isNotchlessScreen) private var isNotchlessScreen
    let step: OnboardingSteps
    let onStepChange: (OnboardingSteps) -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(locale.dn("notchflow.welcome.title", fallback: "Welcome to NotchFlow"))
                .font(.headline)
            Text(locale.dn("notchflow.welcome.description", fallback: "Choose the features and permissions you want in Settings."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button(locale.dn("notch.onboarding.exit", fallback: "Exit")) { NSApp.terminate(nil) }
                Spacer()
                Button(locale.dn("notchflow.welcome.start", fallback: "Get started"), action: onFinish)
            }
        }
        .padding(.top, isNotchlessScreen ? 10 : 30)
        .padding(.horizontal, isNotchlessScreen ? 15 : 35)
    }
}
