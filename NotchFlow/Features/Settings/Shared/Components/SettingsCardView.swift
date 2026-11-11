//
//  SettingsCardView.swift
//  NotchFlow
//
//  Created by Евгений Петрукович on 4/4/26.
//

import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: LocalizedStringKey?
    let titleText: Text?
    let spacing: CGFloat
    let padding: CGFloat
    
    private let content: Content
    
    init(
        title: LocalizedStringKey? = nil,
        spacing: CGFloat = 10,
        padding: CGFloat = 6,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.titleText = title.map { Text($0) }
        self.spacing = spacing
        self.padding = padding
        self.content = content()
    }

    init(
        verbatimTitle: String,
        spacing: CGFloat = 10,
        padding: CGFloat = 6,
        @ViewBuilder content: () -> Content
    ) {
        self.title = nil
        self.titleText = Text(verbatim: verbatimTitle)
        self.spacing = spacing
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            
        } label: {
            if let titleText {
                VStack(alignment: .leading) {
                    titleText
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .groupBoxStyle(SettingsCardGroupBoxStyle(padding: padding))
    }
}

private struct SettingsCardGroupBoxStyle: GroupBoxStyle {
    let padding: CGFloat
    

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.label
                .padding(.leading, 15)
            configuration.content
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    SettingsSolidCardSurface(cornerRadius: 16)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// v2 settings: glass stays on the floating sidebar only; content cards are solid (HIG Liquid Glass).
struct SettingsSolidCardSurface: View {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = colorScheme == .dark
        let border = isDark
            ? Color(red: 0x24 / 255, green: 0x25 / 255, blue: 0x2C / 255)
            : Color(red: 0xE5 / 255, green: 0xE5 / 255, blue: 0xEA / 255)
        shape
            .fill(isDark
                  ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0x17 / 255, green: 0x18 / 255, blue: 0x1D / 255),
                                                          Color(red: 0x12 / 255, green: 0x13 / 255, blue: 0x17 / 255)],
                                                 startPoint: .top, endPoint: .bottom))
                  : AnyShapeStyle(Color.white))
            .overlay(shape.strokeBorder(contrast == .increased ? Color.secondary : border, lineWidth: 1))
    }
}

struct SettingsResetCard: View {
    let targetName: String
    let action: () -> Void
    
    @State private var showingAlert = false
    @Environment(\.locale) private var locale
    
    var formattedTitle: String {
        locale.nfFormat("settings.reset.title", fallback: "Reset %@ settings?", targetName)
    }
    
    var body: some View {
        SettingsCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedTitle)
                        .font(.body)
                    Text("settings.reset.message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button(role: .destructive) {
                    showingAlert = true
                } label: {
                    Text("settings.reset.action")
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(formattedTitle),
                message: Text("settings.reset.message"),
                primaryButton: .destructive(Text("settings.reset.action")) {
                    action()
                },
                secondaryButton: .cancel()
            )
        }
    }
}
