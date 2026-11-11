//
//  BluetoothDetailedNotchView.swift
//  NotchFlow
//
//  Created by Евгений Петрукович on 4/14/26.
//

import SwiftUI

struct BluetoothDetailedNotchView: View {
    @Environment(\.isNotchlessScreen) var isNotchlessScreen
    @Environment(\.locale) var locale
    
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    @ObservedObject var settings: ConnectivitySettingsStore
    
    private var isBatteryStrokeActive: Bool {
        settings.isBluetoothBatteryStrokeEnabled
    }
    
    private var clampedLevel: Int? {
        bluetoothViewModel.batteryLevel.map { max(0, min(100, $0)) }
    }
    
    private func tint(for level: Int) -> Color {
        if level < 20 { return .red }
        if level < 50 { return .yellow }
        return .green
    }
    
    var body: some View {
        // The row sits below the camera band (anchored to the bottom with a fixed height),
        // so the physical notch never covers the icon, the text or the ring.
        HStack(spacing: 16) {
            deviceImage
            description
            Spacer(minLength: 8)
            indicator
        }
        .frame(height: Self.rowHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isNotchlessScreen ? .center : .bottom)
        .padding(.bottom, isNotchlessScreen ? 0 : Self.bottomInset)
        .padding(.horizontal, NotchPageMetrics.horizontalPadding(topCornerRadius: Self.topCornerRadius,
                                                                 isNotchless: isNotchlessScreen))
    }
    
    static let rowHeight: CGFloat = 52
    static let bottomInset: CGFloat = 14
    static let topCornerRadius: CGFloat = 20

    private var deviceImage: some View {
        Image(systemName: bluetoothViewModel.deviceType.sfSymbol)
            .font(.system(size: 30))
            .foregroundStyle(.white)
    }
    
    private var description: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(locale.nf("notch.bluetooth.connected", fallback: "Connected"))
                .lineLimit(1)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
            
            MarqueeText(
                $bluetoothViewModel.deviceName,
                font: .system(size: 15, weight: .regular),
                nsFont: .body,
                textColor: .white.opacity(0.8),
                backgroundColor: .clear,
                minDuration: 0.5,
                frameWidth: 150
            )
        }
    }
    
    private var indicator: some View {
        ZStack {
            BluetoothBatteryIndicatorView(
                batteryLevel: bluetoothViewModel.batteryLevel,
                circleSize: 45,
                circleLineWidth: 5.0,
                usesTintedTrackStroke: isBatteryStrokeActive
            )
            if let clampedLevel {
                Text(String(describing: clampedLevel))
                    .font(.system(size: 16))
                    .foregroundStyle(tint(for: clampedLevel))
            }
        }
    }
}
