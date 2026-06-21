//
//  EntitlementBootstrap.swift
//  KeepInTouch
//
//  Runs once early at launch — after the Core Data store is loaded and defaults
//  are seeded, so the AppSettings row is guaranteed to exist. It evaluates the
//  one-time grandfather decision, persists it if it changed, and refreshes the
//  App Group entitlement cache so out-of-process consumers see current Pro state.
//  See #351.
//
//  At this stage there is no StoreKit purchase state yet (added in a later stage),
//  so the cached `isPro` reflects grandfather status only; the PurchaseManager
//  updates the cache when entitlements load or change.
//

import Foundation

struct EntitlementBootstrap {
    let settingsRepository: AppSettingsRepository

    /// Evaluate + persist the grandfather decision and refresh the entitlement
    /// cache. `writeCache` is injectable so tests don't touch the App Group.
    /// - Returns: the effective Pro status after evaluation.
    @discardableResult
    func run(writeCache: (Bool) -> Void = { EntitlementCache.write(isPro: $0) }) -> Bool {
        guard let settings = settingsRepository.fetch() else {
            // No settings row yet — nothing to evaluate. Leave the cache untouched
            // (readers default to free); a later launch will evaluate once seeding
            // has created the row.
            return false
        }

        let evaluated = GrandfatherEvaluator.evaluate(settings)
        if evaluated != settings {
            try? settingsRepository.save(evaluated)
        }

        let isPro = Entitlements.isPro(
            isGrandfathered: evaluated.isGrandfathered,
            hasProPurchase: false
        )
        writeCache(isPro)
        return isPro
    }
}
