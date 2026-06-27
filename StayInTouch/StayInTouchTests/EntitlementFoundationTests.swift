//
//  EntitlementFoundationTests.swift
//  KeepInTouchTests
//
//  Covers the freemium entitlement foundation (#351, PR1): the pure grandfather
//  evaluation, the isPro rule, the App Group entitlement cache, the launch
//  bootstrap, and the Core Data v11 round-trip for the grandfather fields.
//

import CoreData
import XCTest
@testable import StayInTouch

final class EntitlementFoundationTests: XCTestCase {

    // MARK: - Helpers

    private func makeSettings(
        onboardingCompleted: Bool = false,
        isGrandfathered: Bool = false,
        proStatusEvaluated: Bool = false
    ) -> AppSettings {
        AppSettings(
            id: AppSettings.singletonId,
            theme: .system,
            notificationsEnabled: false,
            breachTimeOfDay: LocalTime(hour: 18, minute: 0),
            digestEnabled: false,
            digestDay: .friday,
            digestTime: LocalTime(hour: 18, minute: 0),
            notificationGrouping: .perType,
            badgeCountShowDueSoon: false,
            dueSoonWindowDays: 3,
            demoModeEnabled: false,
            analyticsEnabled: true,
            hideContactNamesInNotifications: false,
            birthdayNotificationsEnabled: false,
            birthdayNotificationTime: LocalTime(hour: 9, minute: 0),
            birthdayIgnoreSnoozePause: true,
            lastContactsSyncAt: nil,
            onboardingCompleted: onboardingCompleted,
            appVersion: "1.0",
            tutorialCompleted: false,
            tutorialVersion: nil,
            lastSeenAppVersion: nil,
            isGrandfathered: isGrandfathered,
            proStatusEvaluated: proStatusEvaluated
        )
    }

    /// In-memory `AppSettingsRepository` for bootstrap tests.
    private final class MockSettingsRepository: AppSettingsRepository, @unchecked Sendable {
        var stored: AppSettings?
        private(set) var saveCount = 0

        init(stored: AppSettings?) { self.stored = stored }

        func fetch() -> AppSettings? { stored }
        func save(_ settings: AppSettings) throws {
            stored = settings
            saveCount += 1
        }
    }

    // MARK: - GrandfatherEvaluator (the matrix)

    func testGrandfather_existingUser_isGrandfathered() {
        // Onboarding already complete, not yet evaluated → grandfathered.
        let result = GrandfatherEvaluator.evaluate(
            makeSettings(onboardingCompleted: true, proStatusEvaluated: false)
        )
        XCTAssertTrue(result.isGrandfathered)
        XCTAssertTrue(result.proStatusEvaluated)
    }

    func testGrandfather_freshInstall_isNotGrandfathered() {
        // Onboarding not complete at first launch of the IAP build → free tier.
        let result = GrandfatherEvaluator.evaluate(
            makeSettings(onboardingCompleted: false, proStatusEvaluated: false)
        )
        XCTAssertFalse(result.isGrandfathered)
        XCTAssertTrue(result.proStatusEvaluated)
    }

    func testGrandfather_alreadyEvaluated_isIdempotent() {
        // Once evaluated, the decision is frozen even if onboarding later completes.
        let input = makeSettings(
            onboardingCompleted: true,
            isGrandfathered: false,
            proStatusEvaluated: true
        )
        let result = GrandfatherEvaluator.evaluate(input)
        XCTAssertEqual(result, input, "Evaluation must not change an already-evaluated settings row")
        XCTAssertFalse(result.isGrandfathered)
    }

    func testGrandfather_alreadyGrandfathered_isPreserved() {
        let input = makeSettings(
            onboardingCompleted: false,
            isGrandfathered: true,
            proStatusEvaluated: true
        )
        let result = GrandfatherEvaluator.evaluate(input)
        XCTAssertEqual(result, input)
        XCTAssertTrue(result.isGrandfathered)
    }

    // MARK: - Entitlements.isPro rule

    func testIsPro_truthTable() {
        // #362 adds a third input (grantsProForTesting). Only all-false is free;
        // ANY input true grants Pro. All 8 combinations enumerated.
        XCTAssertFalse(Entitlements.isPro(isGrandfathered: false, hasProPurchase: false, grantsProForTesting: false))
        XCTAssertTrue(Entitlements.isPro(isGrandfathered: false, hasProPurchase: false, grantsProForTesting: true))
        XCTAssertTrue(Entitlements.isPro(isGrandfathered: false, hasProPurchase: true, grantsProForTesting: false))
        XCTAssertTrue(Entitlements.isPro(isGrandfathered: false, hasProPurchase: true, grantsProForTesting: true))
        XCTAssertTrue(Entitlements.isPro(isGrandfathered: true, hasProPurchase: false, grantsProForTesting: false))
        XCTAssertTrue(Entitlements.isPro(isGrandfathered: true, hasProPurchase: false, grantsProForTesting: true))
        XCTAssertTrue(Entitlements.isPro(isGrandfathered: true, hasProPurchase: true, grantsProForTesting: false))
        XCTAssertTrue(Entitlements.isPro(isGrandfathered: true, hasProPurchase: true, grantsProForTesting: true))
    }

    // MARK: - BuildEnvironment.grantsPro (pure detection core, #362)

    func testBuildEnvironment_grantsProOnlyForExistingSandboxReceipt() {
        // The single positive case: an existing receipt file named `sandboxReceipt`
        // (TestFlight / StoreKit sandbox).
        XCTAssertTrue(BuildEnvironment.grantsPro(receiptName: "sandboxReceipt", receiptExists: true))
        // Production App Store receipt is named `receipt` → never granted.
        XCTAssertFalse(BuildEnvironment.grantsPro(receiptName: "receipt", receiptExists: true))
        // No receipt file (simulator / dev) → never granted.
        XCTAssertFalse(BuildEnvironment.grantsPro(receiptName: nil, receiptExists: false))
        // Right name but file doesn't exist → never granted (both conditions required).
        XCTAssertFalse(BuildEnvironment.grantsPro(receiptName: "sandboxReceipt", receiptExists: false))
        // Belt-and-suspenders: production name w/o file, and a phantom existing file
        // with no name — neither grants.
        XCTAssertFalse(BuildEnvironment.grantsPro(receiptName: "receipt", receiptExists: false))
        XCTAssertFalse(BuildEnvironment.grantsPro(receiptName: nil, receiptExists: true))
    }

    // MARK: - EntitlementCache round-trip

    func testEntitlementCache_writeThenReadTrue() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("entitlement-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(EntitlementCache.write(isPro: true, to: url))
        XCTAssertTrue(EntitlementCache.readIsPro(from: url))
    }

    func testEntitlementCache_writeThenReadFalse() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("entitlement-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(EntitlementCache.write(isPro: false, to: url))
        XCTAssertFalse(EntitlementCache.readIsPro(from: url))
    }

    func testEntitlementCache_missingFileReadsFalse() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("entitlement-missing-\(UUID().uuidString).json")
        XCTAssertFalse(EntitlementCache.readIsPro(from: url))
    }

    // MARK: - EntitlementBootstrap

    func testBootstrap_existingUser_savesGrandfatherAndCachesPro() {
        let repo = MockSettingsRepository(stored: makeSettings(onboardingCompleted: true))
        var cached: Bool?
        let isPro = EntitlementBootstrap(settingsRepository: repo).run { cached = $0 }

        XCTAssertTrue(isPro)
        XCTAssertEqual(cached, true)
        XCTAssertEqual(repo.saveCount, 1)
        XCTAssertEqual(repo.stored?.isGrandfathered, true)
        XCTAssertEqual(repo.stored?.proStatusEvaluated, true)
    }

    func testBootstrap_freshInstall_savesEvaluatedAndDoesNotCachePro() {
        let repo = MockSettingsRepository(stored: makeSettings(onboardingCompleted: false))
        var cached: Bool?
        let isPro = EntitlementBootstrap(settingsRepository: repo).run { cached = $0 }

        XCTAssertFalse(isPro)
        // Set-only: a free user never triggers a cache write (readers default to
        // free, and the cache must not be clobbered for a purchased user later).
        XCTAssertNil(cached)
        XCTAssertEqual(repo.saveCount, 1)
        XCTAssertEqual(repo.stored?.isGrandfathered, false)
        XCTAssertEqual(repo.stored?.proStatusEvaluated, true)
    }

    func testBootstrap_freeAlreadyEvaluated_doesNotWriteCache() {
        // A non-grandfathered, already-evaluated user must not write the cache —
        // this is the guard that prevents clobbering a purchased user's cached Pro.
        let repo = MockSettingsRepository(
            stored: makeSettings(isGrandfathered: false, proStatusEvaluated: true)
        )
        var cacheWriteCount = 0
        let isPro = EntitlementBootstrap(settingsRepository: repo).run { _ in cacheWriteCount += 1 }

        XCTAssertFalse(isPro)
        XCTAssertEqual(repo.saveCount, 0)
        XCTAssertEqual(cacheWriteCount, 0)
    }

    func testBootstrap_alreadyEvaluated_doesNotResave() {
        let repo = MockSettingsRepository(
            stored: makeSettings(isGrandfathered: true, proStatusEvaluated: true)
        )
        var cached: Bool?
        let isPro = EntitlementBootstrap(settingsRepository: repo).run { cached = $0 }

        XCTAssertTrue(isPro)
        XCTAssertEqual(cached, true)
        XCTAssertEqual(repo.saveCount, 0, "No re-save when the decision is already frozen")
    }

    func testBootstrap_noSettingsRow_returnsFalseAndDoesNotWriteCache() {
        let repo = MockSettingsRepository(stored: nil)
        var cacheWriteCount = 0
        let isPro = EntitlementBootstrap(settingsRepository: repo).run { _ in cacheWriteCount += 1 }

        XCTAssertFalse(isPro)
        XCTAssertEqual(repo.saveCount, 0)
        XCTAssertEqual(cacheWriteCount, 0, "Cache untouched when there is no settings row to evaluate")
    }

    // MARK: - EntitlementBootstrap × testing override (#362)

    func testBootstrap_grantsProForTesting_cachesProForNonGrandfatheredFreshInstall() {
        // Brand-new (non-grandfathered) install in a TestFlight/sandbox build: the
        // override makes the bootstrap cache Pro at launch even though grandfather
        // evaluates false. Grandfather still evaluates + persists as usual.
        let repo = MockSettingsRepository(stored: makeSettings(onboardingCompleted: false))
        var cached: Bool?
        let isPro = EntitlementBootstrap(settingsRepository: repo, grantsProForTesting: true)
            .run { cached = $0 }

        XCTAssertTrue(isPro)
        XCTAssertEqual(cached, true)
        XCTAssertEqual(repo.saveCount, 1)
        XCTAssertEqual(repo.stored?.isGrandfathered, false, "Override grants Pro without changing the grandfather decision")
        XCTAssertEqual(repo.stored?.proStatusEvaluated, true)
    }

    func testBootstrap_grantsProForTestingFalse_freshInstall_doesNotCachePro() {
        // Regression guard: explicitly false → identical to production-free behavior
        // (monetization intact for non-grandfathered users in dev/production).
        let repo = MockSettingsRepository(stored: makeSettings(onboardingCompleted: false))
        var cached: Bool?
        let isPro = EntitlementBootstrap(settingsRepository: repo, grantsProForTesting: false)
            .run { cached = $0 }

        XCTAssertFalse(isPro)
        XCTAssertNil(cached)
        XCTAssertEqual(repo.saveCount, 1)
    }

    // MARK: - Core Data v11 round-trip (model + mapping)

    func testAppSettingsV11_grandfatherFieldsRoundTrip() throws {
        let stack = CoreDataTestStack()
        let repo = CoreDataAppSettingsRepository(context: stack.container.viewContext)

        try repo.save(makeSettings(
            onboardingCompleted: true,
            isGrandfathered: true,
            proStatusEvaluated: true
        ))

        let fetched = repo.fetch()
        XCTAssertEqual(fetched?.isGrandfathered, true)
        XCTAssertEqual(fetched?.proStatusEvaluated, true)
    }

    func testAppSettingsV11_defaultsAreFalseForFreshRow() throws {
        // A row saved without touching the new fields must read back false/false
        // (model-level defaults), i.e. a brand-new install is not grandfathered
        // and not yet evaluated.
        let stack = CoreDataTestStack()
        let repo = CoreDataAppSettingsRepository(context: stack.container.viewContext)

        try repo.save(makeSettings())

        let fetched = repo.fetch()
        XCTAssertEqual(fetched?.isGrandfathered, false)
        XCTAssertEqual(fetched?.proStatusEvaluated, false)
    }
}
