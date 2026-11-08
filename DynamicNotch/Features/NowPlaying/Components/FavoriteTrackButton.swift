//
//  FavoriteTrackButton.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 4/14/26.
//

import SwiftUI

struct FavoriteTrackButton: View {
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel

    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat

    var body: some View {
        Button {
            nowPlayingViewModel.toggleFavorite()
        } label: {
            Image(systemName: nowPlayingViewModel.isCurrentTrackFavorite ? "heart.fill" : "heart")
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(iconColor)
        }
        .buttonStyle(MediaGlassButtonStyle(width: width, height: height))
        .disabled(!nowPlayingViewModel.canToggleFavorite)
        .accessibilityLabel(Text(nowPlayingViewModel.isCurrentTrackFavorite ? "notchflow.lockscreen.favorite.remove" : "notchflow.lockscreen.favorite.add"))
        .accessibilityAddTraits(nowPlayingViewModel.isCurrentTrackFavorite ? .isSelected : [])
        .help(Text(nowPlayingViewModel.isCurrentTrackFavorite ? "notchflow.lockscreen.favorite.remove" : "notchflow.lockscreen.favorite.add"))
    }

    private var iconColor: Color { .white.opacity(0.9) }
}
