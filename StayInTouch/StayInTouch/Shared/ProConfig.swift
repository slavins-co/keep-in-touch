//
//  ProConfig.swift
//  KeepInTouch (Shared — compiled into main app + widget extension)
//
//  Central configuration for the freemium / Pro-unlock feature (#351).
//

import Foundation

enum ProConfig {
    /// App Store Connect product identifier for the one-time non-consumable Pro
    /// unlock. Must match the IAP created in App Store Connect and the local
    /// `.storekit` configuration used for development/testing.
    static let proProductID = "slavins.co.KeepInTouch.pro"

    /// Free-tier ceiling: the number of active tracked contacts a non-Pro user may
    /// keep. Counts `isTracked && !isDemoData`. Pause is a Pro feature, so paused
    /// contacts cannot exist for free users and never affect this count.
    static let freeContactLimit = 12
}
