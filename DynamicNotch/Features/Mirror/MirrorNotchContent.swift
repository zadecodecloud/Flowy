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
    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        CGSize(width: max(560, baseWidth + 340), height: max(440, baseHeight + 405))
    }
    func expandedDynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        CGSize(width: max(560, baseWidth + 340), height: max(440, baseHeight + 405))
    }
    func expandedCornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) { (24, 34) }
    func expandedDynamicIslandCornerRadius(baseHeight: CGFloat) -> CGFloat { 34 }

    @MainActor func compactView() -> AnyView {
        AnyView(HStack {
            Image(systemName: "camera.fill").font(.system(size: 14, weight: .semibold))
            Spacer()
            Text("notchflow.mirror.title").font(.system(size: 12, weight: .medium))
        }.foregroundStyle(.white).padding(.horizontal, 18))
    }
    @MainActor func expandedView() -> AnyView {
        AnyView(MirrorNotchView(camera: camera, nowPlaying: nowPlaying, settings: settings,
                                selectPage: selectPage, close: close))
    }
}

private struct MirrorNotchView: View {
    @Environment(\.isNotchlessScreen) private var isNotchlessScreen
    @Environment(\.locale) private var locale
    @ObservedObject var camera: MirrorCameraController
    @ObservedObject var nowPlaying: NowPlayingViewModel
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject private var license = LicenseStore.shared
    let selectPage: (NotchPage) -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill").font(.system(size: 15, weight: .medium)).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("notchflow.mirror.title").font(.system(size: 16, weight: .semibold))
                    Text("notchflow.mirror.frontCamera").font(.system(size: 11)).foregroundStyle(.white.opacity(0.68))
                }
                Spacer(minLength: 6)
                GlassEffectContainer(spacing: 0) {
                    HStack(spacing: 2) {
                        Button { camera.toggleMirrored() } label: {
                            Image(systemName: "arrow.left.and.right").font(.system(size: 14, weight: .semibold))
                        }.buttonStyle(MediaGlassButtonStyle(width: 38, height: 38, alwaysVisible: true, materialInset: 3))
                         .accessibilityLabel(Text("notchflow.mirror.flip"))
                        Button(action: close) {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                        }.buttonStyle(MediaGlassButtonStyle(width: 38, height: 38, alwaysVisible: true, materialInset: 3))
                         .accessibilityLabel(Text("notchflow.mirror.close"))
                    }
                }
            }
            .frame(height: 38)
            .foregroundStyle(.white)

            cameraArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 0.75))

            HStack(spacing: 0) {
                page(.media, symbol: "music.note", title: "notchflow.mirror.tab.music", enabled: nowPlaying.hasActiveSession && settings.isLiveActivityEnabled(.nowPlaying))
                page(.tray, symbol: "tray.full", title: "notchflow.mirror.tab.tray", enabled: license.hasPro && settings.isLiveActivityEnabled(.drop) && settings.mediaAndFiles.isTrayLiveActivityEnabled)
                page(.mirror, symbol: "camera", title: "notchflow.mirror.title", enabled: true)
            }
            .padding(3).frame(maxWidth: 310).frame(height: 34)
            .background(.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.6))
        }
        .padding(.top, isNotchlessScreen ? 18 : 42)
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }

    @ViewBuilder private var cameraArea: some View {
        ZStack {
            Color(white: 0.12)
            if camera.state == .running {
                MirrorCameraPreview(camera: camera)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: iconName)
                        .font(.system(size: 30, weight: .light)).foregroundStyle(.white.opacity(0.7))
                    Text(message).font(.system(size: 13, weight: .medium))
                        .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
                    if camera.state == .denied {
                        HStack(spacing: 8) {
                            Button("notchflow.mirror.openSettings") { camera.openCameraSettings() }
                            Button("notchflow.mirror.retry") { camera.retry() }
                        }.buttonStyle(.glass)
                    } else if camera.state == .unavailable || camera.state == .interrupted {
                        Button("notchflow.mirror.retry") { camera.retry() }
                            .buttonStyle(.glass)
                    }
                }.padding(20)
            }
        }
        .accessibilityIdentifier("notch.mirror.preview")
    }

    private var message: LocalizedStringKey {
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

    private func page(_ page: NotchPage, symbol: String, title: LocalizedStringKey, enabled: Bool) -> some View {
        Button { selectPage(page) } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                Text(title).font(.system(size: 11, weight: page == .mirror ? .semibold : .medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity).frame(height: 28)
            .foregroundStyle(.white.opacity(enabled ? (page == .mirror ? 1 : 0.75) : 0.35))
            .background(page == .mirror ? Color.white.opacity(0.17) : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).disabled(!enabled)
        .accessibilityIdentifier("notch.page." + page.rawValue)
    }
}
