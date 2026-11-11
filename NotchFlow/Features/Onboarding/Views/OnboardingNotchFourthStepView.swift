//
//  OnboardingNotchFourthStepView.swift
//  NotchFlow
//
//  Created by OpenAI on 4/22/26.
//

import SwiftUI

struct OnboardingNotchFourthStepView: View {
    @Environment(\.locale) private var locale
    @State private var contentAppear = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .shadow(color: .white.opacity(0.35), radius: 24)
                .scaleEffect(contentAppear ? 1 : 0.9)
                .opacity(contentAppear ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: contentAppear)

            VStack(alignment: .leading, spacing: 5) {
                Text(locale.nf("notchflow.onboarding.pages.title", fallback: "Swipe between pages"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(locale.nf("notchflow.onboarding.pages.desc", fallback: "Swipe sideways on the open notch to switch between music, files and the mirror."))
                    .foregroundColor(.gray.opacity(0.6))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(3)
                    .padding(.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                contentAppear = true
            }
        }
    }
}
