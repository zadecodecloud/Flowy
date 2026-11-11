import SwiftUI
internal import AppKit
internal import OpenDirectory

/// Bottom-of-sidebar account chip (v2). macOS has no public Apple ID API, so this shows the
/// local Mac account (full name + login picture); the verified seal appears only with a Pro license.
struct SettingsAccountChip: View {
    let isPro: Bool

    private static let account = MacAccount.current

    var body: some View {
        HStack(spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(verbatim: Self.account.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if isPro {
                        VerifiedSeal()
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                (Text("settings.account.macAccount") + Text(verbatim: " · ")
                    + Text(isPro ? "settings.account.pro" : "settings.account.free"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .animation(.spring(duration: 0.35), value: isPro)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let image = Self.account.picture {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Color(white: 0.45), Color(white: 0.28)], startPoint: .top, endPoint: .bottom)
                    Text(verbatim: Self.account.initials)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// Animated blue verified seal: slowly rotating scalloped seal, static check, soft pulse ring.
private struct VerifiedSeal: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false
    @State private var pulsing = false

    private let blue = Color(red: 0x1D / 255, green: 0x9B / 255, blue: 0xF0 / 255)

    var body: some View {
        ZStack {
            Circle()
                .stroke(blue.opacity(pulsing ? 0 : 0.55), lineWidth: 1.5)
                .scaleEffect(pulsing ? 1.6 : 0.9)
            Image(systemName: "seal.fill")
                .font(.system(size: 13))
                .foregroundStyle(blue)
                .rotationEffect(.degrees(spinning ? 360 : 0))
            Image(systemName: "checkmark")
                .font(.system(size: 6.5, weight: .heavy))
                .foregroundStyle(.white)
        }
        .frame(width: 14, height: 14)
        .accessibilityElement()
        .accessibilityLabel(Text("settings.account.verified"))
        .onAppear { startAnimating() }
        .onChange(of: reduceMotion) { startAnimating() }
    }

    private func startAnimating() {
        guard !reduceMotion else {
            spinning = false
            pulsing = false
            return
        }
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { spinning = true }
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { pulsing = true }
    }
}

private struct MacAccount {
    let name: String
    let initials: String
    let picture: NSImage?

    static var current: MacAccount {
        let fullName = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()
        let initials = fullName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        return MacAccount(name: fullName, initials: initials.isEmpty ? "?" : initials, picture: loginPicture())
    }

    /// Reads the login picture from the local directory; nil when unavailable (e.g. sandboxed).
    private static func loginPicture() -> NSImage? {
        guard let node = try? ODNode(session: ODSession.default(), type: ODNodeType(kODNodeTypeLocalNodes)),
              let record = try? node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(), attributes: [kODAttributeTypeJPEGPhoto]),
              let values = try? record.values(forAttribute: kODAttributeTypeJPEGPhoto),
              let data = values.first as? Data else { return nil }
        return NSImage(data: data)
    }
}
