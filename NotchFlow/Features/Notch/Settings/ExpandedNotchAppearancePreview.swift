import SwiftUI

/// An inert sample so changing the appearance never sends commands to a music app.
struct ExpandedNotchAppearancePreview: View {
    let style: NotchBackgroundStyle
    let transparency: Double

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .top) {
                Image("backgroundLight")
                    .resizable().scaledToFill()
                    .frame(width: width, height: geometry.size.height)
                    .clipped()
                    .overlay(.black.opacity(0.36))

                HStack {
                    Image(systemName: "apple.logo")
                    Spacer()
                    Image(systemName: "wifi")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 17)
                .frame(height: 27)
                .background(.black.opacity(0.10))

                ShellSurface(shape: NotchOutline(topRadius: 25, bottomRadius: 36), isExpanded: true,
                             style: style, transparency: transparency, outline: nil, bandHeight: 32)
                    .overlay(alignment: .top) { samplePlayer }
                    .frame(width: min(384, width * 0.88), height: 184)
                    .environment(\.colorScheme, .dark)
            }
        }
        .frame(height: 202)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var samplePlayer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                cover.frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Blue Hour").font(.system(size: 16, weight: .semibold))
                    Text(verbatim: "NotchFlow Sessions").font(.system(size: 12)).foregroundStyle(.white.opacity(0.68))
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    ForEach([7, 13, 18, 11, 6], id: \.self) { height in
                        Capsule().frame(width: 2, height: CGFloat(height))
                    }
                }
                .foregroundStyle(Color(red: 0.66, green: 0.78, blue: 0.89))
            }
            HStack(spacing: 6) {
                Text(verbatim: "0:24")
                GeometryReader { track in
                    Capsule().fill(.white.opacity(0.27))
                        .overlay(alignment: .leading) { Capsule().fill(.white).frame(width: track.size.width * 0.1) }
                }
                .frame(height: 3)
                Text(verbatim: "−3:36")
            }
            .font(.system(size: 10, weight: .medium)).monospacedDigit()
            .foregroundStyle(.white.opacity(0.77))
            HStack {
                ForEach(["heart", "backward.fill", "pause.fill", "forward.fill", "airplayaudio"], id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: symbol == "pause.fill" ? 20 : (symbol.hasSuffix(".fill") ? 15 : 13), weight: .medium))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 5)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 48)
        .padding(.top, 35)
    }

    private var cover: some View {
        Canvas { context, size in
            let s = size.width
            let sky = Gradient(colors: [Color(red: 0.10, green: 0.18, blue: 0.32),
                                        Color(red: 0.40, green: 0.56, blue: 0.70)])
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(sky, startPoint: .zero, endPoint: CGPoint(x: s, y: s)))
            context.fill(Path(ellipseIn: CGRect(x: s * 0.40, y: s * 0.34, width: s * 0.39, height: s * 0.39)),
                         with: .color(Color(red: 0.96, green: 0.75, blue: 0.52)))
            var hill = Path()
            hill.move(to: CGPoint(x: 0, y: s * 0.79))
            hill.addQuadCurve(to: CGPoint(x: s, y: s * 0.54), control: CGPoint(x: s * 0.65, y: s * 0.80))
            hill.addLine(to: CGPoint(x: s, y: s))
            hill.addLine(to: CGPoint(x: 0, y: s))
            hill.closeSubpath()
            context.fill(hill, with: .color(Color(red: 0.08, green: 0.17, blue: 0.23)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
