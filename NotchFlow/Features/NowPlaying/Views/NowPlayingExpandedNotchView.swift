//
//  NowPlayingExpandedNotchView.swift
//  NotchFlow
//
//  Created by Евгений Петрукович on 4/14/26.
//

import SwiftUI

struct NowPlayingExpandedNotchView: View {
    @Environment(\.notchScale) var scale
    @Environment(\.isNotchlessScreen) var isNotchlessScreen
    @Environment(\.locale) private var locale
    
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var settings: MediaAndFilesSettingsStore
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    @ObservedObject private var badges = TrackBadgeProvider.shared
    
    let onOpenPlaybackSource: @MainActor () -> Void
    
    @State private var scrubProgress: CGFloat?
    private let detailedPresentationSource = "nowPlaying.notch.expanded"
    
    private var resolvedSnapshot: NowPlayingSnapshot {
        nowPlayingViewModel.snapshot ?? NowPlayingSnapshot(
            title: locale.nf("notch.nowPlaying.nothingPlaying", fallback: "Nothing Playing"),
            artist: locale.nf("notch.nowPlaying.startPlayback", fallback: "Start playback to see live metadata"),
            album: "Debug Preview",
            duration: 0,
            elapsedTime: 0,
            playbackRate: 0,
            artworkData: nil,
            refreshedAt: .now
        )
    }
    
    var body: some View {
        let snapshot = resolvedSnapshot

        return TimelineView(.periodic(from: .now, by: progressTick(for: snapshot))) { context in
            timelineContent(snapshot: snapshot, at: context.date)
        }
        .task(id: "\(snapshot.title)|\(snapshot.artist)|\(snapshot.album)|\(settings.nowPlayingTrackBadge.rawValue)") {
            badges.update(title: snapshot.title, artist: snapshot.artist, album: snapshot.album,
                          bundleIdentifier: snapshot.playbackSource?.bundleIdentifier,
                          badge: settings.nowPlayingTrackBadge)
        }
        .onAppear {
            nowPlayingViewModel.setDetailedPresentationActive(
                true,
                source: detailedPresentationSource
            )
        }
        .onDisappear {
            nowPlayingViewModel.setDetailedPresentationActive(
                false,
                source: detailedPresentationSource
            )
        }
    }

    private func timelineContent(snapshot: NowPlayingSnapshot, at date: Date) -> some View {
        let elapsedTime = nowPlayingViewModel.snapshot != nil ?
        nowPlayingViewModel.elapsedTime(at: date) :
        snapshot.elapsedTime
        let progress = progressValue(elapsedTime: elapsedTime, duration: snapshot.duration)
        let displayedProgress = min(max(scrubProgress ?? progress, 0), 1)
        let displayedElapsedTime = snapshot.duration > 0 ?
        TimeInterval(displayedProgress) * snapshot.duration :
        elapsedTime
        let appearance = settings.nowPlayingAppearanceOptions

        return VStack(spacing: 12) {
            headerSection(snapshot: snapshot, appearance: appearance)
            
            PlayerProgressBar(
                progress: displayedProgress,
                displayedElapsedTime: displayedElapsedTime,
                duration: snapshot.duration,
                isInteractive: snapshot.duration > 0,
                tintGradient: nil,
                primaryColor: .white.opacity(0.72),
                secondaryColor: .white.opacity(0.65),
                onScrubChanged: { newProgress in
                    scrubProgress = newProgress
                },
                onScrubEnded: { newProgress in
                    nowPlayingViewModel.seek(to: snapshot.duration * TimeInterval(newProgress))
                    scrubProgress = nil
                }
            )
            controlsSection(snapshot: snapshot, appearance: appearance)
            if appearance.showsVolumeControl {
                volumeControl(snapshot)
            }
        }
        .notchPagePadding(isNotchless: isNotchlessScreen, topCornerRadius: 34)
    }

    @ViewBuilder
    private func headerSection(snapshot: NowPlayingSnapshot, appearance: NowPlayingAppearanceOptions) -> some View {
        HStack(spacing: 15) {
            Button(action: {
                openPlaybackSource()
            }) {
                ArtworkView(
                    nowPlayingViewModel: nowPlayingViewModel,
                    width: 60,
                    height: 60,
                    cornerRadius: 10,
                    usesFlipAnimation: appearance.usesArtwork3DEffect
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlaybackSourceButtonStyle())
            .disabled(!nowPlayingViewModel.canOpenPlaybackSource)

            GeometryReader { geometry in
                HStack(alignment: .center, spacing: 10) {
                    Button(action: {
                        openPlaybackSource()
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            MarqueeText(
                                .constant(displayTitle(for: snapshot)),
                                font: .system(size: 16, weight: .medium),
                                nsFont: .headline,
                                textColor: .white,
                                backgroundColor: .clear,
                                minDuration: 2.0,
                                frameWidth: max(1, geometry.size.width - 33 - badgeWidth(appearance.trackBadge))
                            )

                            MarqueeText(
                                .constant(displayArtist(for: snapshot)),
                                font: .system(size: 14),
                                nsFont: .headline,
                                textColor: .white.opacity(0.68),
                                backgroundColor: .clear,
                                minDuration: 3.0,
                                frameWidth: max(1, geometry.size.width - 33 - badgeWidth(appearance.trackBadge))
                            )
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlaybackSourceButtonStyle())
                    .disabled(!nowPlayingViewModel.canOpenPlaybackSource)

                    trackBadge(appearance.trackBadge)

                    LightweightNowPlayingEqualizerView(
                        isPlaying: snapshot.isPlaying,
                        colors: [
                            nowPlayingViewModel.artworkPalette.equalizerHighlightColor,
                            nowPlayingViewModel.artworkPalette.equalizerBaseColor
                        ],
                        barHeight: 23,
                        barWidth: 2.7
                    )
                    .frame(width: 23, height: 18)
                }
                .frame(height: geometry.size.height)
            }
            .frame(height: 60)
        }
        .frame(height: 60)
    }

    @ViewBuilder
    private func controlsSection(snapshot: NowPlayingSnapshot, appearance: NowPlayingAppearanceOptions) -> some View {
        MediaPlaybackRow(model: nowPlayingViewModel, isPlaying: snapshot.isPlaying) {
            if appearance.showsFavoriteButton {
                FavoriteTrackButton(nowPlayingViewModel: nowPlayingViewModel, width: 38, height: 38, fontSize: 18)
            } else { Color.clear }
        } trailing: {
            if appearance.showsOutputDeviceButton {
                AudioOutputRoutePickerButton(nowPlayingViewModel: nowPlayingViewModel, width: 38, height: 38, fontSize: 18)
            } else { Color.clear }
        }
    }

    /// Room taken by the badge (plus spacing) so the marquee titles don't run under it.
    private func badgeWidth(_ badge: NowPlayingTrackBadge) -> CGFloat {
        switch badge {
        case .explicit: return badges.isExplicit ? 25 : 0
        case .format: return badges.audioFormat == nil ? 0 : 58
        case .none: return 0
        }
    }

    @ViewBuilder
    private func trackBadge(_ badge: NowPlayingTrackBadge) -> some View {
        switch badge {
        case .explicit where badges.isExplicit:
            Text(verbatim: "E")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 15, height: 15)
                .background(RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.75)))
                .accessibilityLabel(Text(verbatim: locale.language.languageCode?.identifier == "vi" ? "Nội dung nhạy cảm" : "Explicit"))
        case .format:
            if let format = badges.audioFormat {
                Text(verbatim: format.shortLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 5)
                    .frame(height: 15)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.5)))
                    .fixedSize()
                    .help(Text(verbatim: format.label))
                    .accessibilityLabel(Text(verbatim: format.label))
            }
        default:
            EmptyView()
        }
    }

    private func volumeControl(_ snapshot: NowPlayingSnapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
            Slider(value: Binding(get: { snapshot.volume ?? 0 }, set: { nowPlayingViewModel.setVolume($0) }), in: 0...1)
                .controlSize(.mini)
                .tint(.white)
                .disabled(!snapshot.supportsVolumeControl || snapshot.volume == nil)
                .accessibilityLabel(Text(verbatim: locale.language.languageCode?.identifier == "vi" ? "Âm lượng" : "Volume"))
                .accessibilityIdentifier("nowPlaying.volume")
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(0.6))
        .padding(.horizontal, 4)
    }

    private func displayTitle(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.title.trimmed.isEmpty ? locale.nf("notch.nowPlaying.unknownTrack", fallback: "Unknown Track") : snapshot.title
    }
    
    private func displayArtist(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.artist.trimmed.isEmpty ? locale.nf("notch.nowPlaying.unknownArtist", fallback: "Unknown Artist") : snapshot.artist
    }
    
    private func displayAlbum(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.album.trimmed.isEmpty ? locale.nf("notch.nowPlaying.unknownAlbum", fallback: "Unknown Album") : snapshot.album
    }
    
    private func progressValue(elapsedTime: TimeInterval, duration: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 0 }
        return min(max(CGFloat(elapsedTime / duration), 0), 1)
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "--:--" }
        
        let totalSeconds = max(0, Int(time.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func playbackStatusColor(for snapshot: NowPlayingSnapshot) -> Color {
        if nowPlayingViewModel.snapshot == nil {
            return .white.opacity(0.48)
        }
        
        return snapshot.isPlaying ?
        Color(red: 0.97, green: 0.73, blue: 0.32) :
            .white.opacity(0.48)
    }

    private func progressTick(for snapshot: NowPlayingSnapshot) -> TimeInterval {
        snapshot.isPlaying ? 0.25 : 30.0
    }

    private func openPlaybackSource() {
        guard nowPlayingViewModel.canOpenPlaybackSource else { return }
        nowPlayingViewModel.openPlaybackSource()
        onOpenPlaybackSource()
    }
}
