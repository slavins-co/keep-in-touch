//
//  ContactCapGate.swift
//  KeepInTouch
//
//  Pure decision logic for the free-tier contact cap (#351). Pro users are never
//  capped. The count is of tracked, non-demo people (paused included). Adding is
//  block-all: if a batch would cross the cap, the whole batch is blocked and the
//  paywall is shown — never a partial add.
//

import Foundation

enum ContactCapGate {
    /// Whether adding `adding` tracked contacts would push a non-Pro user past the
    /// free-tier limit. Pro users are never capped.
    static func wouldExceedFreeLimit(currentTrackedCount: Int, adding: Int, isPro: Bool) -> Bool {
        guard !isPro else { return false }
        return currentTrackedCount + adding > ProConfig.freeContactLimit
    }

    /// Remaining free slots for a non-Pro user (clamped to >= 0); `nil` for Pro
    /// (unlimited). Used for the near-cap soft signal.
    static func remainingFreeSlots(currentTrackedCount: Int, isPro: Bool) -> Int? {
        guard !isPro else { return nil }
        return max(0, ProConfig.freeContactLimit - currentTrackedCount)
    }
}
