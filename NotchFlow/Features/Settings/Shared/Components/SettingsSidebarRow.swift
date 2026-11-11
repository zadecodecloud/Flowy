//
//  SettingsSidebarRow.swift
//  NotchFlow
//
//  Created by Евгений Петрукович on 4/4/26.
//

import SwiftUI

struct SettingsSidebarRow: View {
    let title: String
    let systemImage: String?
    let imageName: String?
    let tint: Color
    let iconColor: Color
    let stroke: Bool
    let showBadge: Bool

    init(title: String, systemImage: String, tint: Color, iconColor: Color = .white, stroke: Bool = false, showBadge: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.imageName = nil
        self.tint = tint
        self.iconColor = iconColor
        self.stroke = stroke
        self.showBadge = showBadge
    }

    init(title: String, imageName: String, tint: Color, iconColor: Color = .white, stroke: Bool = false, showBadge: Bool = false) {
        self.title = title
        self.systemImage = nil
        self.imageName = imageName
        self.tint = tint
        self.iconColor = iconColor
        self.stroke = stroke
        self.showBadge = showBadge
    }
    
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage ?? "circle")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 29, height: 29)
                .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
            if showBadge {
                Circle().fill(.red).frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
