import SwiftUI
import Combine
internal import AppKit

/// Opaque, edge-to-edge album ambience in a separate, mouse-transparent window.
struct LockScreenMediaBackgroundView: View {
    let artworkImage: NSImage?
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var animator: LockScreenPanelAnimator
    @ObservedObject var presentation = LockScreenPresentationSession()
    @StateObject private var clock = LockScreenAmbientClock()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var paletteRevision = 0
    @State private var colors = LockScreenAmbientMesh.fallbackColors

    private var style: LockScreenMediaPanelBackgroundStyle { settingsViewModel.lockScreen.mediaPanelBackgroundStyle }
    private var image: NSImage? { nowPlayingViewModel.artworkImage ?? presentation.artworkImage ?? artworkImage }
    private var isExpanded: Bool { animator.isPresented && animator.isArtworkExpanded }

    var body: some View {
        ZStack {
            if isExpanded {
                Color.black
                if style != .black {
                    LockScreenAmbientField(colors: colors, time: clock.elapsed)
                        .id(paletteRevision)
                        .transition(.opacity)
                    if style == .staticArtwork {
                        NowPlayingArtworkBackground(artworkImage: image, blurRadius: 72,
                                                    darkeningOpacity: 0.30,
                                                    saturation: 1.0, scale: 1.08)
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.10)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    if animator.showsLyrics {
                        // A light scrim keeps white lyrics legible over the brighter field.
                        LinearGradient(stops: [.init(color: .clear, location: 0.3),
                                               .init(color: .black.opacity(0.14), location: 0.65),
                                               .init(color: .black.opacity(0.18), location: 1)],
                                       startPoint: .leading, endPoint: .trailing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: isExpanded, initial: true) { _, expanded in
            if expanded { updateColors(animate: false) }
            syncClock()
        }
        .onChange(of: image) { if isExpanded { updateColors(animate: true) } }
        .onChange(of: style) { syncClock() }
        .onChange(of: reduceMotion) { syncClock() }
        .onDisappear { clock.setActive(false) }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: isExpanded)
    }

    private func syncClock() {
        clock.setActive(isExpanded && style == .animatedArtwork && !reduceMotion)
    }

    private func updateColors(animate: Bool) {
        let palette = LockScreenAmbientMesh.colors(from: image)
        guard palette != colors else { return }
        withAnimation(animate && !reduceMotion ? .easeInOut(duration: 0.9) : nil) {
            colors = palette
            paletteRevision += 1
        }
    }
}

/// Uses the main run loop instead of TimelineView's visibility-driven animation schedule.
/// loginwindow owns the active space, so AppKit can report our delegated window as occluded.
@MainActor
final class LockScreenAmbientClock: ObservableObject {
    @Published private(set) var elapsed: TimeInterval = 0
    private var timer: Timer?
    private var previousTick: TimeInterval?
    var isRunning: Bool { timer != nil }

    func setActive(_ active: Bool) {
        guard active != isRunning else { return }
        timer?.invalidate(); timer = nil
        previousTick = nil
        guard active else { return }
        previousTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance(to: ProcessInfo.processInfo.systemUptime) }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func advance(to uptime: TimeInterval) {
        guard isRunning, let previousTick else { return }
        // Do not jump across sleep/wake or a blocked run loop.
        elapsed += min(0.1, max(0, uptime - previousTick))
        self.previousTick = uptime
    }

    deinit { timer?.invalidate() }
}

/// Overlapping soft color fields avoid the creases produced by a heavily deformed mesh.
/// The palette comes from the album; this view never draws text or controls into glass.
struct LockScreenAmbientField: View {
    let colors: [Color]
    let time: TimeInterval

    var body: some View {
        Canvas { context, size in
            let palette = colors.count == 9 ? colors : LockScreenAmbientMesh.fallbackColors
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(palette[4]))
            context.scaleBy(x: size.width, y: size.height)
            let fields = LockScreenAmbientMesh.fields(at: time)
            for (index, field) in fields.enumerated() {
                // The last two fields screen-blend as luminous highlights; the rest keep
                // the album colors saturated instead of washing out to pastel.
                context.blendMode = index >= fields.count - 2 ? .screen : .normal
                let center = field.center
                let radius = field.radius
                let slot = LockScreenAmbientMesh.fieldPaletteSlots[index % LockScreenAmbientMesh.fieldPaletteSlots.count]
                let color = palette[slot]
                let region = CGRect(x: center.x - radius, y: center.y - radius,
                                    width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: region), with: .radialGradient(
                    Gradient(stops: [.init(color: color.opacity(0.95), location: 0),
                                     .init(color: color.opacity(0.7), location: 0.4),
                                     .init(color: color.opacity(0), location: 1)]),
                    center: center, startRadius: 0, endRadius: radius))
            }
        }
        .accessibilityHidden(true)
    }
}

