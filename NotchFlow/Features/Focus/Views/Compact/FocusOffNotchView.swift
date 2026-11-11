//
//  FocusOffNotchView.swift
//  NotchFlow
//
//  Created by Евгений Петрукович on 7/30/26.
//

import SwiftUI
internal import AppKit

struct FocusOffNotchView: View {
    @Environment(\.locale) private var locale
    let style: FocusAppearanceStyle
    let focusModeType: FocusModeType

    var body: some View {
        FocusStatusNotchView(title: locale.nf("notch.focus.off", fallback: "Off"), tint: .gray.opacity(0.6), style: style, icon: focusModeType.icon)
    }
}
