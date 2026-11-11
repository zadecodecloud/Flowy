import SwiftUI

struct MirrorNotchContent: NotchContentProtocol, DynamicIslandCustomizable {
    let id = NotchContentRegistry.Mirror.preview.id
    let camera: MirrorCameraController
    let nowPlaying: NowPlayingViewModel
    let settings: SettingsViewModel
    let selectPage: (NotchPage) -> Void
    let close: () -> Void

    var priority: Int { NotchContentPriority.nowPlaying }
    var isExpandable: Bool { true }
    var usesContentResizeEffect: Bool { false }
    func compactSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        CGSize(width: baseWidth + 70, height: baseHeight)
    }
    /// Approved "B · 560 pt" layout: wide enough for a usable 16:10 mirror.
    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        CGSize(width: max(560, baseWidth + 340), height: max(440, baseHeight + 405))
    }
    func expandedDynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        expandedSize(baseWidth: baseWidth, baseHeight: baseHeight)
    }
    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) { (MirrorLayout.topCornerRadius, NotchPageMetrics.bottomCornerRadius) }
    func expandedDynamicIslandCornerRadius(baseHeight: CGFloat) -> CGFloat { 34 }

    @MainActor func compactView() -> AnyView {
        AnyView(MirrorCompactView())
    }
    @MainActor func expandedView() -> AnyView {
        AnyView(MirrorNotchView(camera: camera, close: close))
    }
}

/// Shared spacing for the mirror page, on the notch's 4 pt grid.
enum MirrorLayout {
    /// Matches `expandedCornerRadius().top`; the page sits 20 pt inside the notch walls.
    static let topCornerRadius: CGFloat = 24
    static let bottomPadding: CGFloat = NotchPageMetrics.innerMargin
    static let spacing: CGFloat = NotchPageMetrics.blockSpacing
    /// Clearance below the hardware notch band before content starts.
    static let topClearance: CGFloat = 44
    static let notchlessTopClearance: CGFloat = 16
    static let controlHeight: CGFloat = 36
    static let previewCornerRadius: CGFloat = 16
}

private struct MirrorCompactView: View {
    @Environment(\.locale) private var locale
    var body: some View {
        HStack {
            Image(systemName: "camera.fill").font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(locale.nf("notchflow.mirror.title", fallback: "Mirror")).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
    }
}

struct MirrorNotchView: View {
    @Environment(\.isNotchlessScreen) private var isNotchlessScreen
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var camera: MirrorCameraController
    let close: () -> Void

    var body: some View {
        VStack(spacing: MirrorLayout.spacing) {
            cameraArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: MirrorLayout.previewCornerRadius, style: .continuous))
                .overlay { previewBorder }
            controls
                .frame(height: MirrorLayout.controlHeight)
        }
        .padding(.top, isNotchlessScreen ? MirrorLayout.notchlessTopClearance : MirrorLayout.topClearance)
        .padding(.horizontal, NotchPageMetrics.horizontalPadding(topCornerRadius: MirrorLayout.topCornerRadius,
                                                                 isNotchless: isNotchlessScreen))
        .padding(.bottom, MirrorLayout.bottomPadding)
        .foregroundStyle(.white)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: camera.isRingLightOn)
    }

    // MARK: Preview

    @ViewBuilder private var cameraArea: some View {
        ZStack {
            Color(white: 0.1)
            if camera.state == .running {
                MirrorCameraPreview(camera: camera)
            } else {
                statusView
            }
        }
        .accessibilityIdentifier("notch.mirror.preview")
    }

    private var statusView: some View {
        VStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.72))
            Text(locale.nf(messageKey, fallback: messageKey))
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: 320)
            if camera.state == .denied {
                HStack(spacing: 8) {
                    Button(locale.nf("notchflow.mirror.openSettings", fallback: "Open Settings")) { camera.openCameraSettings() }
                    Button(locale.nf("notchflow.mirror.retry", fallback: "Try Again")) { camera.retry() }
                }
                .buttonStyle(.glass)
            } else if camera.state == .unavailable || camera.state == .interrupted {
                Button(locale.nf("notchflow.mirror.retry", fallback: "Try Again")) { camera.retry() }
                    .buttonStyle(.glass)
            }
        }
        .padding(20)
    }

    /// Hairline normally; a bright warm rim with glow when the ring light is on.
    @ViewBuilder private var previewBorder: some View {
        let shape = RoundedRectangle(cornerRadius: MirrorLayout.previewCornerRadius, style: .continuous)
        if camera.isRingLightOn {
            shape
                .strokeBorder(Color(red: 1, green: 0.97, blue: 0.9), lineWidth: 9)
                .shadow(color: Color(red: 1, green: 0.95, blue: 0.85).opacity(0.9), radius: 14)
                .allowsHitTesting(false)
        } else {
            shape
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.75)
                .allowsHitTesting(false)
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 10) {
            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 4) {
                    Button { camera.toggleMirrored() } label: {
                        Image(systemName: "arrow.left.and.right").font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(MediaGlassButtonStyle(width: MirrorLayout.controlHeight, height: MirrorLayout.controlHeight,
                                                       selected: camera.isMirrored, alwaysVisible: true, materialInset: 2))
                    .help(locale.nf("notchflow.mirror.flip", fallback: "Flip mirror"))
                    .accessibilityLabel(Text(locale.nf("notchflow.mirror.flip", fallback: "Flip mirror")))
                    .accessibilityIdentifier("notch.mirror.flip")

                    Button { camera.isRingLightOn.toggle() } label: {
                        Image(systemName: camera.isRingLightOn ? "light.max" : "light.min")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(MediaGlassButtonStyle(width: MirrorLayout.controlHeight, height: MirrorLayout.controlHeight,
                                                       selected: camera.isRingLightOn, alwaysVisible: true, materialInset: 2))
                    .help(locale.nf("notchflow.mirror.ringLight", fallback: "Ring light"))
                    .accessibilityLabel(Text(locale.nf("notchflow.mirror.ringLight", fallback: "Ring light")))
                    .accessibilityIdentifier("notch.mirror.ringLight")
                }
            }

            Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 20)

            HStack(spacing: 8) {
                Image(systemName: "minus.magnifyingglass").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Slider(value: $camera.zoom, in: MirrorCameraController.zoomRange)
                    .controlSize(.small)
                    .tint(.white)
                    .frame(width: 150)
                    .accessibilityLabel(Text(locale.nf("notchflow.mirror.zoom", fallback: "Zoom")))
                    .accessibilityIdentifier("notch.mirror.zoom")
                Image(systemName: "plus.magnifyingglass").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text(String(format: "%.1f×", camera.zoom))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 30, alignment: .leading)
            }

            Spacer(minLength: 0)

            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(MediaGlassButtonStyle(width: MirrorLayout.controlHeight, height: MirrorLayout.controlHeight,
                                               alwaysVisible: true, materialInset: 2))
            .help(locale.nf("notchflow.mirror.close", fallback: "Close mirror"))
            .accessibilityLabel(Text(locale.nf("notchflow.mirror.close", fallback: "Close mirror")))
            .accessibilityIdentifier("notch.mirror.close")
        }
    }

    private var messageKey: String {
        switch camera.state {
        case .inactive, .starting: return "notchflow.mirror.starting"
        case .requesting: return "notchflow.mirror.requesting"
        case .denied: return "notchflow.mirror.denied"
        case .interrupted: return "notchflow.mirror.interrupted"
        case .unavailable: return "notchflow.mirror.unavailable"
        case .running: return "notchflow.mirror.title"
        }
    }

    private var iconName: String {
        switch camera.state {
        case .denied: return "camera.slash.fill"
        case .interrupted: return "exclamationmark.triangle.fill"
        case .unavailable: return "video.slash.fill"
        default: return "camera"
        }
    }
}
