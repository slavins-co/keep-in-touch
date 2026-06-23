//
//  GrandfatherEvaluator.swift
//  KeepInTouch
//
//  One-time, write-once decision that grants free Pro to the pre-monetization
//  cohort — installs that predate the freemium build (#351).
//
//  Signal: `onboardingCompleted == true` at the first launch of the IAP build.
//  An existing user who already finished onboarding is grandfathered; a fresh
//  install (onboarding not yet complete at first launch) is not. The decision is
//  frozen via `proStatusEvaluated`, so completing onboarding *after* the freemium
//  build is installed never retroactively grandfathers a new user.
//

import Foundation

enum GrandfatherEvaluator {
    /// Pure evaluation. Returns settings with the grandfather decision applied.
    /// Idempotent: once `proStatusEvaluated` is true, the input is returned
    /// unchanged.
    static func evaluate(_ settings: AppSettings) -> AppSettings {
        guard !settings.proStatusEvaluated else { return settings }
        var updated = settings
        updated.isGrandfathered = settings.onboardingCompleted
        updated.proStatusEvaluated = true
        return updated
    }
}
