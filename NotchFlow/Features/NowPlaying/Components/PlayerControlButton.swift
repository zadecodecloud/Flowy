import SwiftUI

/// Shared optical feedback: the glyph stays still; the clear lens gently responds.
struct MediaGlassButtonStyle: ButtonStyle {
    var width: CGFloat = 38
    var height: CGFloat = 38
    var selected = false
    var alwaysVisible = false
    var materialInset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let visible = alwaysVisible || selected || (isEnabled && (hovering || configuration.isPressed))
        configuration.label
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
            .frame(width: max(0, width - materialInset * 2), height: max(0, height - materialInset * 2))
            // The glyph must be the glass content. A separate glass background
            // can be elevated above sibling glyphs by GlassEffectContainer.
            .crystalGlassControl(cornerRadius: max(0, min(width, height) / 2 - materialInset),
                                 selected: selected, isVisible: visible)
            .frame(width: width, height: height)
            .environment(\.controlActiveState, .active)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.95 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.88), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: visible)
            .onHover { hovering = $0 }
    }
}

struct PlayerControlButton: View {
    enum FeedbackStyle { case neutral, backward, playPause, forward }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let systemImage: String
    let fontSize: CGFloat
    let width: CGFloat
    let height: CGFloat
    var feedbackStyle: FeedbackStyle = .neutral
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(.white)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        }
        .buttonStyle(MediaGlassButtonStyle(width: width, height: height))
    }
}

/// Five equal hit regions keep Play centered even when accessory controls are hidden.
struct MediaPlaybackRow<Leading: View, Trailing: View>: View {
    @ObservedObject var model: NowPlayingViewModel
    let isPlaying: Bool
    var expanded = false
    var identifierPrefix = "notch.player"
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    private var size: CGFloat { expanded ? 40 : 38 }
    var body: some View {
        // Keep the lenses in one rendering group; zero proximity preserves separate controls.
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 0) {
                leading().frame(width: size, height: size)
                Spacer(minLength: 0)
                PlayerControlButton(systemImage: "backward.fill", fontSize: expanded ? 19 : 16,
                                    width: size, height: size, feedbackStyle: .backward) { model.previousTrack() }
                    .accessibilityLabel(Text("notchflow.player.previous"))
                    .accessibilityIdentifier(identifierPrefix + ".previous")
                    .help(Text("notchflow.player.previous"))
                Spacer(minLength: 0)
                PlayerControlButton(systemImage: isPlaying ? "pause.fill" : "play.fill", fontSize: expanded ? 24 : 22,
                                    width: size, height: size, feedbackStyle: .playPause) { model.togglePlayPause() }
                    .accessibilityLabel(Text(isPlaying ? "notchflow.player.pause" : "notchflow.player.play"))
                    .accessibilityValue(isPlaying ? "playing" : "paused")
                    .accessibilityIdentifier(identifierPrefix + ".playPause")
                    .help(Text(isPlaying ? "notchflow.player.pause" : "notchflow.player.play"))
                Spacer(minLength: 0)
                PlayerControlButton(systemImage: "forward.fill", fontSize: expanded ? 19 : 16,
                                    width: size, height: size, feedbackStyle: .forward) { model.nextTrack() }
                    .accessibilityLabel(Text("notchflow.player.next"))
                    .accessibilityIdentifier(identifierPrefix + ".next")
                    .help(Text("notchflow.player.next"))
                Spacer(minLength: 0)
                trailing().frame(width: size, height: size)
            }
            .frame(height: size)
        }
    }
}
