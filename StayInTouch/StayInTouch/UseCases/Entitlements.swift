//
//  Entitlements.swift
//  KeepInTouch
//
//  The single rule for effective Pro status (#351). Pro is granted if the user is
//  grandfathered (pre-monetization cohort — local and offline-safe) OR holds the
//  StoreKit non-consumable entitlement OR the build is a TestFlight/sandbox beta
//  (#362 — every beta tester gets Pro). Keeping this in one pure function means the
//  app, widgets, and intents all decide "is this user Pro?" identically.
//

import Foundation

enum Entitlements {
    static func isPro(
        isGrandfathered: Bool,
        hasProPurchase: Bool,
        grantsProForTesting: Bool
    ) -> Bool {
        isGrandfathered || hasProPurchase || grantsProForTesting
    }
}
