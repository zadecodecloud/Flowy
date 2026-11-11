//
//  OnboardingSteps.swift
//  NotchFlow
//
//  Created by Евгений Петрукович on 4/13/26.
//

import SwiftUI

enum OnboardingSteps: String, Equatable, CaseIterable {
    case first
    case second
    case third
    case fourth
    
    static let stackID = NotchContentRegistry.Onboarding.stackID
    
    var liveActivityID: String {
        NotchContentRegistry.Onboarding.id(forStep: rawValue)
    }
    
    static func contains(id: String?) -> Bool {
        guard let id else { return false }
        return allCases.contains(where: { $0.liveActivityID == id })
    }
    
    /// The onboarding card size from notchflow-clean (≈ 480 × 240 pt, notch band included),
    /// the same for every step.
    func notchSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        CGSize(width: max(480, baseWidth + 180), height: max(240, baseHeight + 208))
    }

    func dynamicIslandSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        CGSize(width: max(480, baseWidth + 260), height: max(208, baseHeight + 176))
    }

    static let debugStackID = NotchContentRegistry.Onboarding.debugStackID
    
    var debugLiveActivityID: String {
        NotchContentRegistry.Onboarding.debugID(forStep: rawValue)
    }
    
    static func containsDebug(id: String?) -> Bool {
        guard let id else { return false }
        return allCases.contains(where: { $0.debugLiveActivityID == id })
    }
}
