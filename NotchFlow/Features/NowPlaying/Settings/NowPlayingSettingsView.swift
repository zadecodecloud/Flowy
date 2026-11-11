import SwiftUI

struct NowPlayingSettingsView: View {
    @ObservedObject var settings: MediaAndFilesSettingsStore
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    
    private var temporaryActivityDurationRange: ClosedRange<Double> {
        Double(SettingsStoreBase.temporaryActivityDurationRange.lowerBound)...Double(SettingsStoreBase.temporaryActivityDurationRange.upperBound)
    }
    
    @Environment(\.locale) private var locale

    private func t(_ vi: String, _ en: String) -> String { V2.text(locale, vi, en) }

    var body: some View {
        V2Page {
            V2Row {
                V2Stage(height: 262) {
                    NowPlayingAppearancePreview(settings: settings, applicationSettings: applicationSettings)
                        .frame(maxHeight: .infinity, alignment: .top)
                } bar: {
                    V2Chips(options: Array(NowPlayingSourceFilter.allCases),
                            selection: $settings.nowPlayingSourceFilter,
                            title: { Text($0.title) },
                            identifier: "settings.activities.live.nowPlaying.sourceFilter")
                }
                .v2Span(2)

                V2Tile(title: t("Trang Nhạc", "Music page"),
                       hint: t("Nguồn phát chọn ở thanh dưới ảnh xem trước.", "Pick the source under the preview.")) {
                    V2ToggleList(items: [
                        .init(id: "nowPlaying", label: t("Bật trang Nhạc", "Show Music page"),
                              note: t("Khi có bài đang phát", "While something is playing"),
                              isOn: $settings.isNowPlayingLiveActivityEnabled),
                        .init(id: "artwork3D", label: t("Ảnh bìa 3D", "3D artwork"),
                              note: t("Nghiêng theo con trỏ", "Tilts with the pointer"),
                              isOn: $settings.isNowPlayingArtwork3DEffectEnabled)
                    ])
                }
            }

            V2Row(columns: 2) {
                V2Tile(title: t("Ẩn khi tạm dừng", "Hide when paused"),
                       hint: t("Đóng trang Nhạc sau một lúc tạm dừng.", "Close the Music page after a pause.")) {
                    V2Chips(options: [true, false],
                            selection: $settings.isNowPlayingPauseHideTimerEnabled,
                            title: { Text(verbatim: $0 ? t("Hẹn giờ", "After delay") : t("Không ẩn", "Never")) },
                            identifier: "settings.activities.live.nowPlaying.withoutCloseTimer")
                    HStack {
                        Slider(value: Binding(get: { Double(settings.nowPlayingPauseHideDelay) },
                                              set: { settings.nowPlayingPauseHideDelay = Int($0.rounded()) }),
                               in: temporaryActivityDurationRange, step: 1)
                            .tint(V2.blue)
                            .accessibilityLabel(Text(verbatim: t("Thời gian chờ", "Delay")))
                            .accessibilityIdentifier("settings.activities.live.nowPlaying.closeDelay")
                        Text(verbatim: t("\(settings.nowPlayingPauseHideDelay) giây", "\(settings.nowPlayingPauseHideDelay) s"))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 52, alignment: .trailing)
                    }
                    .disabled(!settings.isNowPlayingPauseHideTimerEnabled || !settings.isNowPlayingLiveActivityEnabled)
                    .opacity(settings.isNowPlayingPauseHideTimerEnabled && settings.isNowPlayingLiveActivityEnabled ? 1 : 0.5)
                }

                V2Tile(title: t("Nút hai đầu", "Side buttons"),
                       hint: t("Hai nút cạnh nút phát.", "The buttons beside play.")) {
                    V2ToggleList(items: [
                        .init(id: "favorite", label: t("Yêu thích", "Favorite"),
                              isOn: $settings.isNowPlayingFavoriteButtonVisible),
                        .init(id: "outputDevice", label: t("Thiết bị phát", "Output device"),
                              isOn: $settings.isNowPlayingOutputDeviceButtonVisible)
                    ])
                }
            }
        }
    }
}

private struct NowPlayingAppearancePreview: View {
    @ObservedObject var settings: MediaAndFilesSettingsStore
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    
    var body: some View {
        let appearance = settings.nowPlayingAppearanceOptions
        let showsNotchStroke = applicationSettings.isShowNotchStrokeEnabled
        
        SettingsNotchPreview(
            style: applicationSettings.notchBackgroundStyle,
            transparency: applicationSettings.notchGlassTransparency,
            width: 300,
            height: 170,
            previewHeight: 200,
            сornerRadius: 35,
            strokeColor: showsNotchStroke ? Color.white.opacity(0.2).opacity(applicationSettings.notchStrokeOpacity) : .clear,
            lightBackgroundImage: Image("backgroundLight"),
            darkBackgroundImage: Image("backgroundDark")
        ) {
            VStack(spacing: 13) {
                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .frame(width: 55, height: 55)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(verbatim: applicationSettings.appLanguage.locale.language.languageCode?.identifier == "vi" ? "Bài hát mẫu" : "Sample Song")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            LightweightNowPlayingEqualizerView(
                                isPlaying: true,
                                colors: [.gray],
                                barHeight: 23,
                                barWidth: 2.7
                            )
                            .frame(width: 23, height: 18)
                        }
                        Text(verbatim: applicationSettings.appLanguage.locale.language.languageCode?.identifier == "vi" ? "Nghệ sĩ" : "Artist")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(verbatim: "01:21")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.4))
                    
                    GeometryReader { proxy in
                        let trackHeight: CGFloat = 6
                        
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.15))
                                .frame(height: trackHeight)
                            
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.5))
                                .frame(width: proxy.size.width * 0.38, height: trackHeight)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 14)
                    
                    Text(verbatim: "03:34")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.4))
                }
                ZStack {
                    HStack(spacing: 22) {
                        previewControlButton(systemImage: "backward.fill", fontSize: 15)
                        previewControlButton(systemImage: "pause.fill", fontSize: 20)
                        previewControlButton(systemImage: "forward.fill", fontSize: 15)
                    }
                    HStack {
                        if appearance.showsFavoriteButton {previewSideButton(systemImage: "star")}
                        Spacer()
                        if appearance.showsOutputDeviceButton {previewSideButton(systemImage: "airplayaudio")}
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func previewControlButton(systemImage: String, fontSize: CGFloat) -> some View {
        ZStack {
            Image(systemName: systemImage)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 38, height: 38)
    }
    
    private func previewSideButton(systemImage: String) -> some View {
        ZStack {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: 34, height: 34)
    }
}
