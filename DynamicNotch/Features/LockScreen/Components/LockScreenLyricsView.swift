import SwiftUI

struct LockScreenLyricsView: View {
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    let width: CGFloat
    var height: CGFloat = 520
    var fontSize: CGFloat = 32
    var referenceLayout = false

    var body: some View {
        content.frame(width: width, height: height)
    }

    @ViewBuilder private var content: some View {
        switch nowPlayingViewModel.lyricsState {
        case .idle, .loading:
            ProgressView().controlSize(.small).accessibilityLabel(Text("notchflow.lyrics.loading"))
        case .notFound:
            message("notchflow.lockscreen.lyrics.notFound")
        case .failed:
            VStack(spacing: 14) {
                message("notchflow.lockscreen.lyrics.failed")
                Button("notchflow.lyrics.retry") { nowPlayingViewModel.reloadLyrics() }
                    .buttonStyle(.glass)
            }
        case .loaded(let lyrics):
            if lyrics.isInstrumental {
                message("notchflow.lyrics.instrumental", symbol: "waveform")
            } else if lyrics.lines.isEmpty {
                message("notchflow.lockscreen.lyrics.notFound")
            } else if lyrics.isSynced, let snapshot = nowPlayingViewModel.snapshot {
                TimelineView(.explicit(lyrics.cueDates(for: snapshot, from: .now))) { tick in
                    FollowingLyrics(lyrics: lyrics, snapshot: snapshot,
                                    activeIndex: lyrics.activeLineIndex(at: snapshot.elapsedTime(at: tick.date)),
                                    height: height, fontSize: fontSize, referenceLayout: referenceLayout, seek: nowPlayingViewModel.seek(to:))
                }
                .id(lyrics.trackKey)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: fontSize * 0.58) {
                        ForEach(lyrics.lines) { line in
                            Text(verbatim: line.text).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.white.opacity(0.91))
                    .padding(.horizontal, 6)
                    .padding(.vertical, height * 0.11)
                }
                .scrollIndicators(.hidden)
                .mask(LyricsEdgeFade())
                .id(lyrics.trackKey)
            }
        }
    }

    private func message(_ title: LocalizedStringKey, symbol: String = "quote.bubble") -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 20)).accessibilityHidden(true)
            Text(title).font(.system(size: 18, weight: .medium)).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.78))
    }
}

private struct LyricsEdgeFade: View {
    var body: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.11),
                               .init(color: .black, location: 0.84), .init(color: .clear, location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }
}

private struct FollowingLyrics: View {
    let lyrics: TrackLyrics
    let snapshot: NowPlayingSnapshot
    let activeIndex: Int?
    let height: CGFloat
    let fontSize: CGFloat
    let referenceLayout: Bool
    let seek: (TimeInterval) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var browsing = false
    @State private var resumeAt: Date?
    private var activeID: Int { activeIndex.map { lyrics.lines[$0].id } ?? -1 }
    private let anchor = UnitPoint(x: 0.5, y: 0.37)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: max(12, fontSize * 0.5)) {
                    if (lyrics.lines.first?.startTime ?? 0) > 0 {
                        PassageDots(active: activeIndex == nil && snapshot.isPlaying)
                            .frame(height: fontSize).id(-1)
                    }
                    ForEach(lyrics.lines) { line in
                        LyricRow(line: line, snapshot: snapshot, fontSize: fontSize,
                                 distance: line.id - activeID, browsing: browsing, referenceLayout: referenceLayout) {
                            guard let time = line.startTime else { return }
                            resumeAt = nil
                            browsing = false
                            seek(time)
                            scroll(to: line.id, proxy: proxy)
                        }
                        .id(line.id)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, height * anchor.y)
                .padding(.bottom, height * (1 - anchor.y))
            }
            .scrollIndicators(.hidden)
            .mask(LyricsEdgeFade())
            .onScrollPhaseChange { _, phase in
                switch phase {
                case .tracking:
                    resumeAt = nil
                case .interacting, .decelerating:
                    browsing = true
                    resumeAt = nil
                case .idle where browsing:
                    resumeAt = Date().addingTimeInterval(6)
                default: break
                }
            }
            .onChange(of: activeID) { _, id in
                if !browsing { scroll(to: id, proxy: proxy) }
            }
            .onChange(of: browsing) { _, value in
                if !value { scroll(to: activeID, proxy: proxy) }
            }
            .task {
                await Task.yield()
                if !Task.isCancelled { proxy.scrollTo(activeID, anchor: anchor) }
            }
            .task(id: resumeAt) {
                guard let resumeAt else { return }
                do { try await Task.sleep(for: .seconds(max(0, resumeAt.timeIntervalSinceNow))) }
                catch { return }
                browsing = false
            }
            .overlay(alignment: .bottomLeading) {
                if browsing {
                    Button {
                        resumeAt = nil
                        browsing = false
                    } label: {
                        Label("notchflow.lyrics.follow", systemImage: "waveform")
                            .font(.callout.weight(.medium)).padding(.horizontal, 5)
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("lockscreen.lyrics.follow")
                    .padding(.leading, 6)
                }
            }
        }
    }

    private func scroll(to id: Int, proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.50, dampingFraction: 0.90)) {
            proxy.scrollTo(id, anchor: anchor)
        }
    }
}

private struct LyricRow: View {
    let line: LyricLine
    let snapshot: NowPlayingSnapshot
    let fontSize: CGFloat
    let distance: Int
    let browsing: Bool
    var referenceLayout = false
    let select: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovering = false

    private var active: Bool { distance == 0 }
    private var focused: Bool { active || hovering || browsing }
    private var opacity: Double {
        if active || hovering { return 1 }
        if browsing || contrast == .increased { return 0.78 }
        if referenceLayout { return abs(distance) == 1 ? 0.65 : 0.46 }
        return abs(distance) == 1 ? 0.55 : 0.35
    }

    var body: some View {
        Button(action: select) {
            Group {
                if line.text.isEmpty {
                    PassageDots(active: active && snapshot.isPlaying)
                } else if active && !line.segments.isEmpty && !reduceMotion {
                    TimedLyricText(line: line, snapshot: snapshot)
                } else {
                    Text(verbatim: line.text)
                }
            }
            .font(.system(size: fontSize, weight: .bold))
            .tracking(-fontSize * 0.025)
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .foregroundStyle(.white)
            .shadow(color: .white.opacity(active && contrast != .increased ? 0.24 : 0), radius: 4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .opacity(opacity)
            .blur(radius: referenceLayout || focused || contrast == .increased ? 0 : min(2.0, CGFloat(abs(distance)) * 0.65))
            .scaleEffect(focused || reduceMotion ? 1 : 0.975, anchor: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(line.text.isEmpty ? Text("notchflow.lyrics.instrumental") : Text(verbatim: line.text))
        .accessibilityAddTraits(active ? .isSelected : [])
        .accessibilityIdentifier("lockscreen.lyric.\(line.id)")
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: focused)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: distance)
    }
}

private struct PassageDots: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.white.opacity(0.72))
            .symbolEffect(.pulse, options: .repeating, isActive: active && !reduceMotion)
            .accessibilityLabel(Text("notchflow.lyrics.instrumental"))
    }
}

// Only the current, word-timed line draws between cue boundaries. Text performs the
// shaping and wrapping so accents, ligatures and bidirectional runs keep their layout.
private struct TimedLyricText: View {
    let line: LyricLine
    let snapshot: NowPlayingSnapshot

    var body: some View {
        let text = line.segments.enumerated().reduce(Text(verbatim: "")) { result, item in
            let (index, segment) = item
            let end = index + 1 < line.segments.count ? line.segments[index + 1].startTime : line.endTime
            let cue = WordCue(index: index, start: segment.startTime, end: end ?? segment.startTime)
            let piece = Text(verbatim: segment.text).customAttribute(cue)
            return Text("\(result)\(piece)")
        }
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !snapshot.isPlaying)) { tick in
            text.textRenderer(LyricSweep(position: snapshot.elapsedTime(at: tick.date)))
        }
        .accessibilityLabel(Text(verbatim: line.text))
    }
}

private struct WordCue: TextAttribute {
    let index: Int
    let start: TimeInterval
    let end: TimeInterval
}

private struct LyricSweep: TextRenderer {
    let position: TimeInterval

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var widths: [Int: CGFloat] = [:]
        for line in layout {
            for run in line {
                if let cue = run[WordCue.self] { widths[cue.index, default: 0] += run.typographicBounds.width }
            }
        }
        var drawn: [Int: CGFloat] = [:]
        for line in layout {
            for run in line {
                guard let cue = run[WordCue.self], let width = widths[cue.index] else {
                    context.draw(run)
                    continue
                }
                let bounds = run.typographicBounds.rect
                let previous = drawn[cue.index, default: 0]
                drawn[cue.index] = previous + bounds.width
                if position >= cue.end {
                    context.draw(run)
                    continue
                }
                var dim = context
                dim.opacity *= 0.43
                dim.draw(run)
                guard position > cue.start, cue.end > cue.start else { continue }
                let fraction = min(1, (position - cue.start) / (cue.end - cue.start))
                let fill = min(bounds.width, max(0, width * fraction - previous))
                guard fill > 0 else { continue }
                var lit = context
                let x = run.layoutDirection == .rightToLeft ? bounds.maxX - fill : bounds.minX
                lit.clip(to: Path(CGRect(x: x, y: bounds.minY - 2, width: fill, height: bounds.height + 4)))
                lit.draw(run)
            }
        }
    }
}
