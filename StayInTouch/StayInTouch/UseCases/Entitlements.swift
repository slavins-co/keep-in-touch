//
//  Entitlements.swift
//  KeepInTouch
//
//  The single rule for effective Pro status (#351). Pro is granted if the user is
//  grandfathered (pre-monetization cohort — local and offline-safe) OR holds the
//  StoreKit non-consumable entitlement. Keeping this in one pure function means
//  the app, widgets, and intents all decide "is this user Pro?" identically.
//

import Foundation

enum Entitlements {
    static func isPro(isGrandfathered: Bool, hasProPurchase: Bool) -> Bool {
        isGrandfathered || hasProPurchase
    }
}
