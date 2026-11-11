//
//  NotchOnboardingEventsHandler.swift
//  NotchFlow
//

import SwiftUI

@MainActor
final class NotchOnboardingEventsHandler {
    private let notchViewModel: NotchViewModel
    private let settingsViewModel: SettingsViewModel
    private let nowPlayingViewModel: NowPlayingViewModel
    private let mediaHandler: NotchMediaEventsHandler

    init(
        notchViewModel: NotchViewModel,
        settingsViewModel: SettingsViewModel,
        nowPlayingViewModel: NowPlayingViewModel,
        mediaHandler: NotchMediaEventsHandler
    ) {
        self.notchViewModel = notchViewModel
        self.settingsViewModel = settingsViewModel
        self.nowPlayingViewModel = nowPlayingViewModel
        self.mediaHandler = mediaHandler
    }

    var isOnboardingActive: Bool {
        OnboardingSteps.contains(id: notchViewModel.notchModel.liveActivityContent?.id) ||
        OnboardingSteps.contains(id: notchViewModel.notchModel.temporaryNotificationContent?.id) ||
        {
            return OnboardingSteps.containsDebug(id: notchViewModel.notchModel.liveActivityContent?.id) ||
            OnboardingSteps.containsDebug(id: notchViewModel.notchModel.temporaryNotificationContent?.id)
        }()
    }

    func checkFirstLaunch(onShowOnboarding: @escaping () -> Void) {
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

        if !hasSeenOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onShowOnboarding()
            }
        } else {
            restorePostOnboardingActivities()
        }
    }

    func hideOnboarding(markAsSeen: Bool = false) {
        if markAsSeen {
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        }

        OnboardingSteps.allCases.forEach { step in
            notchViewModel.send(.hideLiveActivity(id: step.liveActivityID))
        }

        OnboardingSteps.allCases.forEach { step in
            notchViewModel.send(.hideLiveActivity(id: step.debugLiveActivityID))
        }

        if markAsSeen {
            restorePostOnboardingActivities()
        }
    }

    func showOnboarding(step: OnboardingSteps = .first, coordinator: NotchEventCoordinator) {
        notchViewModel.send(
            .showLiveActivity(
                OnboardingNotchContent(
                    step: step,
                    notchEventCoordinator: coordinator
                )
            )
        )
    }

    func showDebugOnboardingPreview(step: OnboardingSteps = .first, coordinator: NotchEventCoordinator) {
        notchViewModel.send(
            .showLiveActivity(
                DebugOnboardingPreviewNotchContent(
                    step: step,
                    notchEventCoordinator: coordinator
                )
            )
        )
    }

    private func restorePostOnboardingActivities() {
        if nowPlayingViewModel.hasActiveSession &&
            settingsViewModel.isLiveActivityEnabled(.nowPlaying) {
            mediaHandler.handleNowPlaying(.started)
        }
    }
}
