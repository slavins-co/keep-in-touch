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

    /// Free-tier ceiling: the number of tracked contacts a non-Pro user may keep.
    /// Counts `isTracked && !isDemoData`, paused INCLUDED — a paused contact still
    /// occupies a slot (matters for a grandfathered/ex-Pro user, since pause is a
    /// Pro feature and free users can't create paused contacts in the first place).
    static let freeContactLimit = 12
}
