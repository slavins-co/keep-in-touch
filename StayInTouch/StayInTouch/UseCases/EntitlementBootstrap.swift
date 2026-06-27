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
    /// TestFlight/sandbox beta override (#362). Defaulted from the real bundle for
    /// production; injected explicitly in tests so they never read the bundle. When
    /// true, a fresh (non-grandfathered) install still caches Pro at launch.
    var grantsProForTesting: Bool = BuildEnvironment.grantsProForTesting

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
            do {
                try settingsRepository.save(evaluated)
            } catch {
                // Don't silently swallow (project rule: zero silent failures). A
                // failed persist means the grandfather decision isn't frozen and
                // gets re-evaluated next launch — safe for existing users, whose
                // `onboardingCompleted` is stable and yields the same result.
                AppLogger.logError(error, category: AppLogger.coreData, context: "EntitlementBootstrap.save")
            }
        }

        let isPro = Entitlements.isPro(
            isGrandfathered: evaluated.isGrandfathered,
            hasProPurchase: false,
            grantsProForTesting: grantsProForTesting
        )
        // Set-only: write the cache here only to GRANT Pro (grandfather), never to
        // clear it. The authoritative writer that can also clear Pro (on refund /
        // entitlement revocation) is the StoreKit PurchaseManager added in a later
        // stage. Keeping this bootstrap set-only means it can never clobber a
        // purchased-but-not-grandfathered user's cached entitlement back to free.
        if isPro {
            writeCache(true)
        }
        return isPro
    }
}
