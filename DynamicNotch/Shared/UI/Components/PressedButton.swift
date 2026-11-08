//
//  HoverButton.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 3/13/26.
//

import SwiftUI

struct PressedButtonStyle: ButtonStyle {
    var width: Double
    var height: Double
    var cornerRadius: CGFloat = 30
    var fontSize: CGFloat = 15
    var foreground: Color = .primary
    var hoverBackground: Color = .white.opacity(0.1)
    var glassInset: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        CustomButtonBody(
            configuration: configuration,
            width: width,
            height: height,
            cornerRadius: cornerRadius,
            fontSize: fontSize,
            foreground: foreground,
            hoverBackground: hoverBackground,
            glassInset: glassInset
        )
    }

    private struct CustomButtonBody: View {
        let configuration: ButtonStyle.Configuration
        let width: Double
        let height: Double
        let cornerRadius: CGFloat
        let fontSize: CGFloat
        let foreground: Color
        let hoverBackground: Color
        let glassInset: CGFloat

        @State private var isHovering: Bool = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: fontSize))
                .frame(width: max(1, width - 2 * glassInset), height: max(1, height - 2 * glassInset))
                .foregroundStyle(foreground)
                .background(backgroundColor.opacity(0.5), in: RoundedRectangle(cornerRadius: cornerRadius))
                .crystalGlassControl(cornerRadius: cornerRadius)
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(!reduceMotion && configuration.isPressed ? 0.96 : 1.0)
                .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.8), value: configuration.isPressed)
                .frame(width: width, height: height)
                .contentShape(Rectangle())
                #if os(macOS)
                .onHover { hover in
                    isHovering = hover
                }
                #endif
        }

        private var backgroundColor: Color {
            #if os(macOS)
            return isHovering ? hoverBackground : .clear
            #else
            return configuration.isPressed ? hoverBackground : .clear
            #endif
        }
    }
}
