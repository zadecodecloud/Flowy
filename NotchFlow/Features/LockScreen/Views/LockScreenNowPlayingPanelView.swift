// NotchFlow: lock-screen media presentation.
import SwiftUI
internal import AppKit

struct LockScreenNowPlayingPanelView: View {
    static let panelSize = CGSize(width: 340, height: 180)
    private static let panelCenterYOffset: CGFloat = 170

    let snapshot: NowPlayingSnapshot
    let artworkImage: NSImage?
    let screen: NSScreen
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var lockScreenManager: LockScreenManager
    @ObservedObject var animator: LockScreenPanelAnimator
    @ObservedObject var presentation = LockScreenPresentationSession()
    var transitionResponse = LockScreenPanelAnimator.transitionDuration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    private var resolvedSnapshot: NowPlayingSnapshot { presentation.snapshot ?? snapshot }
    private var resolvedArtwork: NSImage? { presentation.artworkImage ?? artworkImage }
    private var isExpanded: Bool { animator.isArtworkExpanded }
    private var artworkExpansion: Binding<Bool> {
        Binding(get: { isExpanded }, set: { expanded in
            if expanded { animator.expandArtwork() } else { animator.closeExpandedPlayer() }
        })
    }
    private var showsLyrics: Bool { animator.showsLyrics && settingsViewModel.lockScreen.isLockScreenLyricsEnabled }

    var body: some View {
        GeometryReader { proxy in
            let layout = LockScreenMediaLayout(screenSize: proxy.size, showsLyrics: showsLyrics, wideLyrics: animator.mode == .lyricsWide)
            ZStack {
                // Keep the compact origin in the layout even when it is invisible.
                // A single cover above this hierarchy travels between all modes.
                compactPlayer
                    .offset(y: Self.panelCenterYOffset + CGFloat(settingsViewModel.lockScreen.mediaPanelVerticalOffset))
                    .opacity(isExpanded ? 0 : 1)
                    .allowsHitTesting(!isExpanded)
                    .accessibilityHidden(isExpanded)

                if isExpanded && showsLyrics {
                    LockScreenExpandedPlayerView(nowPlayingViewModel: nowPlayingViewModel,
                        fallbackSnapshot: resolvedSnapshot, referenceLayout: animator.mode == .lyricsWide)
                        .frame(width: layout.playerWidth, height: layout.playerHeight)
                        .offset(x: layout.playerX, y: layout.playerY)
                        .transition(.opacity.combined(with: .offset(y: 12)))
                }

                if showsLyrics {
                    LockScreenLyricsView(nowPlayingViewModel: nowPlayingViewModel,
                                         width: layout.lyricsWidth, height: layout.lyricsHeight,
                                         fontSize: layout.lyricsFontSize, referenceLayout: animator.mode == .lyricsWide)
                        .transition(.opacity)
                        .offset(x: layout.lyricsX, y: layout.lyricsY)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlay {
                let cover = layout.coverFrame(isExpanded: isExpanded,
                    verticalOffset: settingsViewModel.lockScreen.mediaPanelVerticalOffset)
                ArtworkView(nowPlayingViewModel: nowPlayingViewModel,
                            width: cover.width, height: cover.height,
                            cornerRadius: isExpanded ? (animator.mode == .lyricsWide ? 5 : 14) : 10,
                            usesFlipAnimation: false, fallbackImage: resolvedArtwork,
                            dimsWhenPaused: false, scalesWhenPaused: false, usesThumbnailCache: false)
                    .shadow(color: .black.opacity(isExpanded ? 0.35 : 0), radius: isExpanded ? 24 : 0, y: isExpanded ? 16 : 0)
                    .position(x: cover.midX, y: cover.midY)
                    .allowsHitTesting(false)
                    .accessibilityLabel(Text("notchflow.lockscreen.albumArtwork"))
                    .accessibilityIdentifier("lockscreen.artwork")
            }
            .overlay(alignment: .topTrailing) {
                if isExpanded {
                    GlassEffectContainer(spacing: 0) {
                        HStack(spacing: 2) {
                            if showsLyrics {
                                Button { animator.toggleLyricsSize() } label: {
                                    Image(systemName: animator.mode == .lyricsWide ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                                }
                                .buttonStyle(MediaGlassButtonStyle(width: 44, height: 44, alwaysVisible: true, materialInset: 4))
                                .accessibilityLabel(Text(animator.mode == .lyricsWide ? "notchflow.lyrics.size.compact" : "notchflow.lyrics.size.expand"))
                                .accessibilityIdentifier("lockscreen.lyrics.size")
                            }
                            if settingsViewModel.lockScreen.isLockScreenLyricsEnabled { lyricsToggle }
                            Button { animator.closeExpandedPlayer() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(MediaGlassButtonStyle(width: 44, height: 44, alwaysVisible: true, materialInset: 4))
                            .accessibilityLabel(Text("notchflow.lockscreen.expanded.close"))
                            .accessibilityIdentifier("lockscreen.expanded.close")
                            .help(Text("notchflow.lockscreen.expanded.close"))
                        }
                    }
                    .padding(.top, layout.collapseButtonFrame.minY)
                    .padding(.trailing, layout.actionInset)
                }
            }
            .overlay(alignment: .bottom) {
                if isExpanded && !showsLyrics {
                    artworkFooter(layout: layout)
                        .padding(.bottom, layout.bottomInset)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .opacity(animator.isPresented ? 1 : 0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: animator.isPresented)
        .animation(reduceMotion || animator.disablesTransitionAnimation ? nil : .spring(response: transitionResponse, dampingFraction: 1.0), value: animator.mode)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .environment(\.controlActiveState, .active)
        .environment(\.colorScheme, .dark)
        .environment(\.locale, settingsViewModel.application.notchLanguage.locale)
        .onAppear { syncLyricsPresentationState() }
        .onDisappear { nowPlayingViewModel.setLyricsPresentationActive(false) }
        .onChange(of: animator.mode) { syncLyricsPresentationState() }
        .onChange(of: settingsViewModel.lockScreen.isLockScreenLyricsEnabled) { _, enabled in
            if !enabled { animator.disableLyrics() }
            syncLyricsPresentationState()
        }
        .onChange(of: nowPlayingViewModel.snapshot?.lyricsLookupKey) { syncLyricsPresentationState() }
    }

    private var lyricsToggle: some View {
        Button { animator.toggleLyrics() } label: {
            Image(systemName: showsLyrics ? "quote.bubble.fill" : "quote.bubble")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        }
        .buttonStyle(MediaGlassButtonStyle(width: 44, height: 44, selected: showsLyrics,
                                          alwaysVisible: true, materialInset: 4))
        .accessibilityLabel(Text(showsLyrics ? "notchflow.lockscreen.lyrics.hide" : "notchflow.lockscreen.lyrics.show"))
        .accessibilityValue(showsLyrics ? "lyrics" : "artwork")
        .accessibilityAddTraits(showsLyrics ? .isSelected : [])
        .accessibilityIdentifier("lockscreen.lyrics.toggle")
        .help(Text(showsLyrics ? "notchflow.lockscreen.lyrics.hide" : "notchflow.lockscreen.lyrics.show"))
    }

    @ViewBuilder
    private func artworkFooter(layout: LockScreenMediaLayout) -> some View {
        if layout.usesStackedArtworkFooter {
            LockScreenExpandedPlayerView(nowPlayingViewModel: nowPlayingViewModel, fallbackSnapshot: resolvedSnapshot)
                .frame(width: layout.artworkControlsWidth, height: layout.artworkFooterHeight)
        } else {
            LockScreenExpandedPlayerView(nowPlayingViewModel: nowPlayingViewModel,
                fallbackSnapshot: resolvedSnapshot, includesMetadata: false)
                .frame(width: layout.artworkControlsWidth, height: layout.artworkFooterHeight)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottomLeading) {
                    LockScreenTrackLabel(snapshot: nowPlayingViewModel.snapshot ?? resolvedSnapshot, centered: false)
                        .frame(width: layout.artworkMetadataWidth, alignment: .leading)
                        .padding(.leading, layout.actionInset + 20)
                }
        }
    }

    private var compactPlayer: some View {
        LockScreenNowPlayingView(nowPlayingViewModel: nowPlayingViewModel,
                                 mediaSettings: settingsViewModel.mediaAndFiles,
                                 onTapArtwork: artworkExpansion, fallbackSnapshot: resolvedSnapshot,
                                 fallbackArtworkImage: resolvedArtwork, showsArtwork: false)
            .frame(width: Self.panelSize.width, height: Self.panelSize.height)
            .background {
                LockScreenWidgetSurface(style: settingsViewModel.lockScreen.widgetAppearanceStyle,
                                        tintStyle: settingsViewModel.lockScreen.widgetTintStyle,
                                        cornerRadius: 28,
                                        liquidGlassVariant: settingsViewModel.lockScreen.liquidGlassVariant)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.24), radius: 26, x: 0, y: 14)
    }

    private func syncLyricsPresentationState() {
        nowPlayingViewModel.setLyricsPresentationActive(showsLyrics)
    }
}
