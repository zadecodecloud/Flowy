import SwiftUI

// Onboarding card from notchflow-clean (`Setup/Onboarding.swift`): Welcome with its bloom
// animation, Permissions, Pages and Done, each with Next / Back and Skip, Done on the last.

extension OnboardingSteps {
    /// The step's text keys (strings copied from notchflow-clean, en + vi).
    fileprivate var textKey: String {
        switch self {
        case .first: return "welcome"
        case .second: return "permissions"
        case .third: return "pages"
        case .fourth: return "done"
        }
    }

    fileprivate var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    fileprivate var previous: Self? { index > 0 ? Self.allCases[index - 1] : nil }
    fileprivate var following: Self? { index + 1 < Self.allCases.count ? Self.allCases[index + 1] : nil }
}

struct OnboardingNotchView: View {
    @Environment(\.locale) private var locale
    @Environment(\.isNotchlessScreen) private var isNotchlessScreen
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let step: OnboardingSteps
    let onStepChange: (OnboardingSteps) -> Void
    let onFinish: () -> Void

    private func tr(_ key: String, _ fallback: String) -> String {
        locale.nf("nf.onboarding.\(key)", fallback: fallback)
    }

    private var isLastStep: Bool { step.following == nil }

    // Layout: the notch band on top stays empty; the illustration and text sit centred in
    // the space between the band and the button row; both rows share the same side margins,
    // which clear the notch's flared top corners and rounded bottom corners.
    private var bandHeight: CGFloat { isNotchlessScreen ? 8 : 34 }
    private var sideMargin: CGFloat { isNotchlessScreen ? 22 : 44 }
    private static let illustrationSize: CGFloat = 84

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: bandHeight)
            HStack(alignment: .center, spacing: 18) {
                illustration
                    .frame(width: Self.illustrationSize, height: Self.illustrationSize)
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: tr("\(step.textKey).title", "Welcome to Flowy"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: tr("\(step.textKey).body", ""))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if step == .second {
                        Button(tr("permissions.open", "Review permissions")) {
                            SettingsWindowController.shared.showWindow(
                                selecting: SettingsRootViewModel.Section.permissions)
                        }
                        .buttonStyle(OnboardingButtonStyle(prominent: false))
                        .padding(.top, 3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .id(step)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))

            HStack(spacing: 8) {
                StepDots(current: step.index, count: OnboardingSteps.allCases.count)
                    .accessibilityElement()
                    .accessibilityLabel(String(format: tr("progress", "Step %1$d of %2$d"), locale: locale,
                                               step.index + 1, OnboardingSteps.allCases.count))
                Spacer(minLength: 12)
                if !isLastStep {
                    Button(tr("skip", "Skip"), action: onFinish)
                        .buttonStyle(OnboardingButtonStyle(prominent: false))
                }
                if let previous = step.previous {
                    Button(tr("back", "Back")) { onStepChange(previous) }
                        .buttonStyle(OnboardingButtonStyle(prominent: false))
                }
                Button(tr(isLastStep ? "finish" : "next", isLastStep ? "Done" : "Next")) {
                    if let following = step.following { onStepChange(following) } else { onFinish() }
                }
                .buttonStyle(OnboardingButtonStyle(prominent: true))
            }
            .frame(height: 28)
        }
        .padding(.horizontal, sideMargin)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: step)
    }

    @ViewBuilder
    private var illustration: some View {
        switch step {
        case .first: WelcomeBloom()
        case .second: OnboardingSymbol(name: "hand.raised.fill")
        case .third: SwipeHint()
        case .fourth: OnboardingSymbol(name: "checkmark.circle.fill")
        }
    }
}

private struct OnboardingButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(prominent ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(prominent ? Color.white : Color.white.opacity(0.14)))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

private struct StepDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == current ? 0.95 : 0.3))
                    .frame(width: index == current ? 14 : 6, height: 6)
            }
        }
    }
}

private struct OnboardingSymbol: View {
    let name: String

    var body: some View {
        // A soft disc the size of the welcome bloom keeps every step's illustration the same
        // visual weight.
        ZStack {
            Circle().fill(.white.opacity(0.08))
            Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1)
            Image(systemName: name)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
        .padding(6)
        .accessibilityHidden(true)
    }
}

/// A hand swiping sideways between three page symbols (the Pages step).
private struct SwipeHint: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let phase = reduceMotion ? 0.5 : (sin(timeline.date.timeIntervalSinceReferenceDate * 2.2) + 1) / 2
            VStack(spacing: 10) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .offset(x: (phase - 0.5) * 36)
                HStack(spacing: 8) {
                    ForEach(["music.note", "tray.fill", "web.camera.fill"], id: \.self) { symbol in
                        Image(systemName: symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The welcome animation: a notch-shaped capsule that breathes open into a rounded panel
/// while three rings of light ripple out from it. With Reduce Motion it is a still frame.
struct WelcomeBloom: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 1.2 : timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for ring in 0..<3 {
                    let progress = ((t / 2.4) + Double(ring) / 3).truncatingRemainder(dividingBy: 1)
                    let radius = 18 + progress * Double(min(size.width, size.height)) * 0.42
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.35 * (1 - progress))),
                                   lineWidth: 1.5)
                }
                let open = (1 - cos(min(t, 1.2) / 1.2 * .pi)) / 2
                let breathe = reduceMotion ? 0 : sin(t * 1.6) * 0.04
                let width = (34 + 30 * open) * (1 + breathe)
                let height = (12 + 30 * open) * (1 + breathe)
                let panel = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
                let shape = Path(roundedRect: panel, cornerRadius: min(height / 2, 6 + 8 * open), style: .continuous)
                context.fill(shape, with: .linearGradient(Gradient(colors: [Color(white: 0.22), .black]),
                                                          startPoint: CGPoint(x: panel.midX, y: panel.minY),
                                                          endPoint: CGPoint(x: panel.midX, y: panel.maxY)))
                context.stroke(shape, with: .color(.white.opacity(0.6)), lineWidth: 1.2)
                let spark = Path { path in
                    let r = 7 * open
                    path.move(to: CGPoint(x: center.x, y: center.y - r))
                    path.addQuadCurve(to: CGPoint(x: center.x + r, y: center.y), control: center)
                    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + r), control: center)
                    path.addQuadCurve(to: CGPoint(x: center.x - r, y: center.y), control: center)
                    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - r), control: center)
                }
                context.fill(spark, with: .color(.white.opacity(open)))
            }
        }
        .accessibilityHidden(true)
    }
}
