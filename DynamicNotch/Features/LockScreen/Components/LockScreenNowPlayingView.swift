//
//  LockScreenNowPlayingView.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 5/13/26.
//

import SwiftUI

struct LockScreenNowPlayingView: View {
    @Environment(\.notchScale) var scale
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var mediaSettings: MediaAndFilesSettingsStore
    @Binding var onTapArtwork: Bool
    let fallbackSnapshot: NowPlayingSnapshot
    var fallbackArtworkImage: NSImage? = nil
    var showsArtwork = true
    var isImmersive = false
    var contentWidth: CGFloat = 340
    
    @State private var scrubProgress: CGFloat?
    
    private var resolvedSnapshot: NowPlayingSnapshot {
        nowPlayingViewModel.snapshot ?? fallbackSnapshot
    }
    
    var body: some View {
        let snapshot = resolvedSnapshot
        
        return TimelineView(.periodic(from: .now, by: progressTick(for: snapshot))) { context in
            timelineContent(snapshot: snapshot, at: context.date)
        }
    }
    
    private func timelineContent(snapshot: NowPlayingSnapshot, at date: Date) -> some View {
        let elapsedTime = nowPlayingViewModel.snapshot != nil ?
        nowPlayingViewModel.elapsedTime(at: date) :
        snapshot.elapsedTime(at: date)
        let progress = progressValue(elapsedTime: elapsedTime, duration: snapshot.duration)
        let displayedProgress = min(max(scrubProgress ?? progress, 0), 1)
        let displayedElapsedTime = snapshot.duration > 0 ?
        TimeInterval(displayedProgress) * snapshot.duration :
        elapsedTime
        let appearance = mediaSettings.nowPlayingAppearanceOptions
        
        return VStack {
            HStack(spacing: 15) {
                if !onTapArtwork || !showsArtwork {
                    Button(action: {withAnimation(.spring(response: 0.6)) { onTapArtwork = true }}) {
                        ArtworkView(
                            nowPlayingViewModel: nowPlayingViewModel,
                            width: 60,
                            height: 60,
                            cornerRadius: 10,
                            usesFlipAnimation: false,
                            fallbackImage: fallbackArtworkImage,
                            dimsWhenPaused: false, scalesWhenPaused: false
                        )
                        .opacity(showsArtwork ? 1 : 0)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlaybackSourceButtonStyle())
                    .accessibilityLabel(Text("notchflow.lockscreen.artwork.expand"))
                    .accessibilityIdentifier("lockscreen.artwork.expand")
                }
                
                GeometryReader { geometry in
                    HStack(alignment: .center, spacing: 8) {
                        Button(action: {withAnimation(.spring(response: 0.6)) { onTapArtwork.toggle() }}) {
                            VStack(alignment: .leading, spacing: 2) {
                                MarqueeText(
                                    .constant(displayTitle(for: snapshot)),
                                    font: .system(size: isImmersive ? 21 : 16, weight: .semibold),
                                    nsFont: .headline,
                                    textColor: .white.opacity(0.95),
                                    backgroundColor: .clear,
                                    minDuration: 2.0,
                                    frameWidth: max(1, geometry.size.width - 26)
                                )

                                MarqueeText(
                                    .constant(displayArtist(for: snapshot)),
                                    font: .system(size: isImmersive ? 17 : 14),
                                    nsFont: .headline,
                                    textColor: .white.opacity(0.75),
                                    backgroundColor: .clear,
                                    minDuration: 3.0,
                                    frameWidth: max(1, geometry.size.width - 26)
                                )
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlaybackSourceButtonStyle())
                        .accessibilityLabel("\(displayTitle(for: snapshot)) — \(displayArtist(for: snapshot))")
                        .accessibilityIdentifier("lockscreen.metadata")

                        LightweightNowPlayingEqualizerView(
                            isPlaying: snapshot.isPlaying,
                            color: NSColor.white.withAlphaComponent(0.7),
                            barHeight: 20,
                            barWidth: 2.2
                        )
                        .frame(width: 13, height: 15)
                    }
                    .frame(height: geometry.size.height)
                }
                .frame(height: 60)
                .padding(.trailing, 5)
                .shadow(color: .black.opacity(0.55), radius: 1, y: 1)
            }
            .frame(height: 60)
            Spacer()
            
            PlayerProgressBar(
                progress: displayedProgress,
                displayedElapsedTime: displayedElapsedTime,
                duration: snapshot.duration,
                isInteractive: snapshot.duration > 0,
                tintGradient: nil,
                primaryColor: .white.opacity(0.9),
                secondaryColor: .white.opacity(0.72),
                onScrubChanged: { newProgress in
                    scrubProgress = newProgress
                },
                onScrubEnded: { newProgress in
                    nowPlayingViewModel.seek(to: snapshot.duration * TimeInterval(newProgress))
                    scrubProgress = nil
                }
            )
            
            Spacer()
            
            MediaPlaybackRow(model: nowPlayingViewModel, isPlaying: snapshot.isPlaying, identifierPrefix: "lockscreen") {
                if appearance.showsFavoriteButton {
                    FavoriteTrackButton(nowPlayingViewModel: nowPlayingViewModel, width: 38, height: 38, fontSize: 18)
                } else { Color.clear }
            } trailing: {
                if appearance.showsOutputDeviceButton {
                    AudioOutputRoutePickerButton(nowPlayingViewModel: nowPlayingViewModel, width: 38, height: 38, fontSize: 18)
                } else { Color.clear }
            }
        }
        .padding(isImmersive ? 8 : 18)
    }
    
    private func displayTitle(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.title.trimmed.isEmpty ? "Unknown Track" : snapshot.title
    }
    
    private func displayArtist(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.artist.trimmed.isEmpty ? "Unknown Artist" : snapshot.artist
    }
    
    private func displayAlbum(for snapshot: NowPlayingSnapshot) -> String {
        snapshot.album.trimmed.isEmpty ? "Unknown Album" : snapshot.album
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

    private func progressTick(for snapshot: NowPlayingSnapshot) -> TimeInterval {
        snapshot.isPlaying ? 1.0 : 30.0
    }
    
    private func playbackStatusColor(for snapshot: NowPlayingSnapshot) -> Color {
        if nowPlayingViewModel.snapshot == nil {
            return .white.opacity(0.48)
        }
        
        return snapshot.isPlaying ?
        Color(red: 0.97, green: 0.73, blue: 0.32) :
            .white.opacity(0.48)
    }
}
