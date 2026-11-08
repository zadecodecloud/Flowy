import SwiftUI

struct LockScreenExpandedPlayerView: View {
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    let fallbackSnapshot: NowPlayingSnapshot
    var includesMetadata = true
    var referenceLayout = false
    @State private var scrubTime: Double?
    @State private var isScrubbing = false

    var body: some View {
        let snapshot = nowPlayingViewModel.snapshot ?? fallbackSnapshot
        Group {
            if referenceLayout { referencePlayer(snapshot) } else {
        VStack(spacing: 12) {
            if includesMetadata {
                LockScreenTrackLabel(snapshot: snapshot, centered: true)
                    .padding(.horizontal, 22)
                    .frame(height: 43)
            }
            TimelineView(.animation(minimumInterval: 0.5, paused: !snapshot.isPlaying)) { tick in
                progress(snapshot, time: scrubTime ?? snapshot.elapsedTime(at: tick.date))
            }
            .frame(height: 26)
            MediaPlaybackRow(model: nowPlayingViewModel, isPlaying: snapshot.isPlaying,
                             expanded: true, identifierPrefix: "lockscreen") {
                auxiliary("shuffle", label: "notchflow.lockscreen.shuffle", id: "shuffle", selected: snapshot.isShuffled) {
                    nowPlayingViewModel.toggleShuffle()
                }
            } trailing: {
                auxiliary(snapshot.repeatMode == .one ? "repeat.1" : "repeat", label: "notchflow.lockscreen.repeat",
                          id: "repeat", selected: snapshot.repeatMode != .off) { nowPlayingViewModel.toggleRepeat() }
                    .accessibilityValue(String(describing: snapshot.repeatMode))
            }
            volumeControl(snapshot)
                .frame(height: 24)
        }
            }
        }
        .tint(.white.opacity(0.8))
        .foregroundStyle(.white.opacity(0.9))
        .contextMenu {
            Button { nowPlayingViewModel.toggleFavorite() } label: {
                Label(nowPlayingViewModel.isCurrentTrackFavorite ? "notchflow.lockscreen.favorite.remove" : "notchflow.lockscreen.favorite.add",
                      systemImage: nowPlayingViewModel.isCurrentTrackFavorite ? "heart.fill" : "heart")
            }
            .disabled(!nowPlayingViewModel.canToggleFavorite)
            Menu("notchflow.lockscreen.audioOutput") {
                ForEach(nowPlayingViewModel.audioOutputRoutes) { route in
                    Button { nowPlayingViewModel.switchAudioOutput(to: route) } label: {
                        Label(route.name, systemImage: route.isCurrent ? "checkmark" : route.systemImageName)
                    }
                }
            }
        }
        .onAppear { nowPlayingViewModel.refreshAudioOutputRoutes() }
        .onChange(of: snapshot.lyricsLookupKey) { scrubTime = nil; isScrubbing = false }
    }

    private func referencePlayer(_ snapshot: NowPlayingSnapshot) -> some View {
        VStack(spacing: 4) {
            TimelineView(.animation(minimumInterval: 0.5, paused: !snapshot.isPlaying)) { tick in
                ReferenceMediaTimeline(time: snapshot.elapsedTime(at: tick.date), duration: snapshot.duration,
                                       seek: nowPlayingViewModel.seek(to:))
                    .id(snapshot.lyricsLookupKey)
            }
            VStack(spacing: 1) {
                Text(verbatim: snapshot.title).font(.system(size: 13, weight: .semibold))
                Text(verbatim: snapshot.artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.82))
            }
            .lineLimit(1).frame(height: 30)
            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 12) {
                    PlayerControlButton(systemImage: "backward.fill", fontSize: 13, width: 34, height: 34) { nowPlayingViewModel.previousTrack() }
                        .accessibilityLabel(Text("notchflow.player.previous"))
                    PlayerControlButton(systemImage: snapshot.isPlaying ? "pause.fill" : "play.fill", fontSize: 18, width: 34, height: 34) { nowPlayingViewModel.togglePlayPause() }
                        .accessibilityLabel(Text(snapshot.isPlaying ? "notchflow.player.pause" : "notchflow.player.play"))
                        .accessibilityIdentifier("lockscreen.reference.playPause")
                    PlayerControlButton(systemImage: "forward.fill", fontSize: 13, width: 34, height: 34) { nowPlayingViewModel.nextTrack() }
                        .accessibilityLabel(Text("notchflow.player.next"))
                }
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
    }

    private func progress(_ snapshot: NowPlayingSnapshot, time: Double) -> some View {
        VStack(spacing: 0) {
            Slider(value: Binding(get: { min(max(time, 0), max(snapshot.duration, 1)) },
                                  set: { value in
                                      if isScrubbing { scrubTime = value } else { nowPlayingViewModel.seek(to: value) }
                                  }),
                   in: 0...max(snapshot.duration, 1), onEditingChanged: { editing in
                isScrubbing = editing
                if !editing, let scrubTime {
                    nowPlayingViewModel.seek(to: scrubTime)
                    self.scrubTime = nil
                }
            })
            .controlSize(.mini)
            .disabled(snapshot.duration <= 0)
            .accessibilityLabel(Text("notchflow.lockscreen.position"))
            .accessibilityIdentifier("lockscreen.progress")
            HStack {
                Text(formattedTime(time))
                Spacer()
                Text(snapshot.duration > 0 ? "−" + formattedTime(max(0, snapshot.duration - time)) : "LIVE")
            }
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.5))
            .accessibilityHidden(true)
        }
    }

    private func volumeControl(_ snapshot: NowPlayingSnapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
            Slider(value: Binding(get: { snapshot.volume ?? 0 }, set: { nowPlayingViewModel.setVolume($0) }), in: 0...1)
                .controlSize(.mini)
                .disabled(!snapshot.supportsVolumeControl || snapshot.volume == nil)
                .accessibilityLabel(Text("notchflow.lockscreen.volume"))
                .accessibilityIdentifier("lockscreen.volume")
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(0.6))
        .padding(.horizontal, 4)
    }

    private func auxiliary(_ symbol: String, label: LocalizedStringKey, id: String,
                           selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(MediaGlassButtonStyle(width: 40, height: 40, selected: selected))
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier("lockscreen." + id)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(Text(label))
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "--:--" }
        let seconds = max(0, Int(time))
        return seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct LockScreenTrackLabel: View {
    let snapshot: NowPlayingSnapshot
    let centered: Bool
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 3) {
            Text(verbatim: snapshot.title.trimmed.isEmpty ? locale.dn("notch.nowPlaying.unknownTrack", fallback: "Unknown Track") : snapshot.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Text(verbatim: snapshot.artist.trimmed.isEmpty ? locale.dn("notch.nowPlaying.unknownArtist", fallback: "Unknown Artist") : snapshot.artist)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.68))
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lockscreen.metadata")
    }
}

/// A thin timeline like the reference, with a full-height pointer target.
private struct ReferenceMediaTimeline: View {
    let time: Double
    let duration: Double
    let seek: (Double) -> Void
    @State private var dragTime: Double?
    @State private var hovering = false
    private var elapsed: Double { min(max(dragTime ?? time, 0), max(duration, 0)) }
    private func label(_ value: Double) -> String {
        guard value.isFinite else { return "--:--" }
        let seconds = max(0, Int(value))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text(label(elapsed)); Spacer(); Text("−" + label(max(0, duration - elapsed))) }
                .font(.system(size: 9, weight: .medium)).monospacedDigit()
                .foregroundStyle(.white.opacity(0.8)).accessibilityHidden(true)
            GeometryReader { proxy in
                let fraction = duration > 0 ? elapsed / duration : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25)).frame(height: 2)
                    Capsule().fill(.white).frame(width: max(0, proxy.size.width * fraction), height: 2)
                    if hovering || dragTime != nil {
                        Circle().fill(.white).frame(width: 6, height: 6)
                            .offset(x: max(0, min(proxy.size.width - 6, proxy.size.width * fraction - 3)))
                    }
                }
                .frame(height: 20).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0 else { return }
                        dragTime = min(1, max(0, value.location.x / max(1, proxy.size.width))) * duration
                    }
                    .onEnded { _ in if let dragTime { seek(dragTime) }; dragTime = nil })
            }.frame(height: 20)
        }
        .onHover { hovering = $0 }
        .focusable()
        .onKeyPress(.leftArrow) {
            guard duration > 0 else { return .ignored }
            seek(max(0, elapsed - 5)); return .handled
        }
        .onKeyPress(.rightArrow) {
            guard duration > 0 else { return .ignored }
            seek(min(duration, elapsed + 5)); return .handled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("notchflow.lockscreen.position"))
        .accessibilityValue(label(elapsed))
        .accessibilityAdjustableAction { direction in
            guard duration > 0 else { return }
            seek(min(duration, max(0, elapsed + (direction == .increment ? 5 : -5))))
        }
        .accessibilityIdentifier("lockscreen.reference.progress")
    }
}
