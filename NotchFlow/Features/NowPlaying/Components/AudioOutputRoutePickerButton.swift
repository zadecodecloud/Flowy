//
//  AudioOutputRoutePickerButton.swift
//  NotchFlow
//
//  Created by Евгений Петрукович on 4/14/26.
//

import SwiftUI

struct AudioOutputRoutePickerButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    
    var width: CGFloat = 42
    var height: CGFloat = 42
    var fontSize: CGFloat = 20

    var body: some View {
        Menu {
            if nowPlayingViewModel.audioOutputRoutes.isEmpty {
                Text(locale.nf("nowPlaying.noAudioOutputs", fallback: "No audio outputs available"))
            } else {
                ForEach(nowPlayingViewModel.audioOutputRoutes) { route in
                    Button {
                        nowPlayingViewModel.switchAudioOutput(to: route)
                    } label: {
                        routeMenuLabel(route)
                    }
                }
            }
        } label: {
            Image(systemName: nowPlayingViewModel.currentAudioOutputRoute?.systemImageName ?? "airplayaudio")
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(.white)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: nowPlayingViewModel.currentAudioOutputRoute?.systemImageName)
        }
        .menuIndicator(.hidden)
        .accessibilityLabel(Text("notchflow.lockscreen.audioOutput"))
        .accessibilityValue(nowPlayingViewModel.currentAudioOutputRoute?.name ?? "")
        .accessibilityIdentifier("media.audioOutput")
        .help(nowPlayingViewModel.currentAudioOutputRoute?.name ?? locale.nf("notchflow.lockscreen.audioOutput", fallback: "Audio output"))
        .buttonStyle(MediaGlassButtonStyle(width: width, height: height))
        .onAppear {
            nowPlayingViewModel.refreshAudioOutputRoutes()
        }
    }

    private func routeMenuLabel(_ route: AudioOutputRoute) -> some View {
        HStack(spacing: 8) {
            Image(systemName: route.systemImageName)
                .frame(width: 18)

            Text(route.name)

            if route.isCurrent {
                Spacer(minLength: 12)
                Image(systemName: "checkmark")
            }
        }
    }
}
