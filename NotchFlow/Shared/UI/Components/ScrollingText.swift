import SwiftUI
import Combine

/// Single-line text that scrolls horizontally when it does not fit, the way Music and
/// Spotify show long titles: it rests for a moment, then loops seamlessly with soft edges.
/// Short text stays still. Reduce Motion falls back to tail truncation.
///
/// Driven by its own run-loop timer instead of `TimelineView`, because AppKit can treat the
/// lock-screen windows as occluded and pause view-driven animation schedules there.
struct ScrollingText: View {
    let text: String
    var font: Font
    var color: Color = .white
    var alignment: HorizontalAlignment = .leading
    /// Points per second.
    var speed: CGFloat = 30
    var pause: TimeInterval = 1.6
    var gap: CGFloat = 40

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @StateObject private var clock = ScrollingTextClock()

    private var overflows: Bool { containerWidth > 0 && textWidth > containerWidth + 0.5 }

    /// Horizontal offset at `elapsed` seconds: rest, then move one full cycle, then repeat.
    static func offset(elapsed: TimeInterval, textWidth: CGFloat, gap: CGFloat, speed: CGFloat,
                       pause: TimeInterval) -> CGFloat {
        guard speed > 0, textWidth > 0 else { return 0 }
        let travel = textWidth + gap
        let period = pause + Double(travel / speed)
        let phase = elapsed.truncatingRemainder(dividingBy: period)
        return phase < pause ? 0 : -CGFloat(phase - pause) * speed
    }

    var body: some View {
        let scrolling = overflows && !reduceMotion
        Text(verbatim: text)
            .font(font)
            .lineLimit(1)
            .hidden()
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .overlay(alignment: scrolling ? .leading : Alignment(horizontal: alignment, vertical: .center)) {
                if scrolling {
                    HStack(spacing: gap) { label; label }
                        .offset(x: Self.offset(elapsed: clock.elapsed, textWidth: textWidth, gap: gap,
                                               speed: speed, pause: pause))
                        .mask(edgeFade)
                } else {
                    Text(verbatim: text)
                        .font(font)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .clipped()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
            .background(alignment: .leading) {
                label.hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
            }
            .onChange(of: scrolling, initial: true) { _, active in clock.setActive(active) }
            .onChange(of: text) { clock.restart() }
            .onDisappear { clock.setActive(false) }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: text))
    }

    private var label: some View {
        Text(verbatim: text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }

    private var edgeFade: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.04),
                               .init(color: .black, location: 0.92), .init(color: .clear, location: 1)],
                       startPoint: .leading, endPoint: .trailing)
            .frame(width: containerWidth)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
final class ScrollingTextClock: ObservableObject {
    @Published private(set) var elapsed: TimeInterval = 0
    private var timer: Timer?
    private var startUptime: TimeInterval = 0

    func setActive(_ active: Bool) {
        guard active != (timer != nil) else { return }
        timer?.invalidate(); timer = nil
        guard active else { return }
        restart()
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.elapsed = ProcessInfo.processInfo.systemUptime - self.startUptime
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func restart() {
        startUptime = ProcessInfo.processInfo.systemUptime
        elapsed = 0
    }

    deinit { timer?.invalidate() }
}
