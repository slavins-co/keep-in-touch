//
//  PurchaseManagerTests.swift
//  KeepInTouchTests
//
//  Drives PurchaseManager through a fake StoreKitGateway (#351, PR2): isPro
//  computation (grandfather || owned), authoritative cache writes (incl. clear),
//  purchase outcomes, and restore.
//

import XCTest
@testable import StayInTouch

@MainActor
final class PurchaseManagerTests: XCTestCase {

    // MARK: - Fakes / helpers

    private final class FakeGateway: StoreKitGateway, @unchecked Sendable {
        var owned: Set<String> = []
        var products: [ProProduct] = [
            ProProduct(id: ProConfig.proProductID, displayName: "Pro", displayPrice: "$7.99")
        ]
        var nextOutcome: PurchaseOutcome = .success
        var grantOnSuccess = true
        var purchaseError: Error?
        var loadError: Error?
        private(set) var syncCalled = false

        func loadProducts(ids: [String]) async throws -> [ProProduct] {
            if let loadError { throw loadError }
            return products
        }
        func ownedProductIDs() async -> Set<String> { owned }
        func purchase(productID: String) async throws -> PurchaseOutcome {
            if let purchaseError { throw purchaseError }
            if nextOutcome == .success && grantOnSuccess { owned.insert(productID) }
            return nextOutcome
        }
        func sync() async throws { syncCalled = true }
        func transactionUpdates() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    }

    private final class StubSettingsRepository: AppSettingsRepository, @unchecked Sendable {
        var grandfathered: Bool
        init(grandfathered: Bool) { self.grandfathered = grandfathered }
        func fetch() -> AppSettings? { Self.make(grandfathered: grandfathered) }
        func save(_ settings: AppSettings) throws {}

        static func make(grandfathered: Bool) -> AppSettings {
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
                onboardingCompleted: true,
                appVersion: "1.0",
                isGrandfathered: grandfathered,
                proStatusEvaluated: true
            )
        }
    }

    private final class CacheRecorder {
        var values: [Bool] = []
        var last: Bool? { values.last }
    }

    private func makeManager(
        gateway: FakeGateway,
        grandfathered: Bool,
        recorder: CacheRecorder
    ) -> PurchaseManager {
        PurchaseManager(
            gateway: gateway,
            settingsRepository: StubSettingsRepository(grandfathered: grandfathered),
            writeCache: { recorder.values.append($0) }
        )
    }

    // MARK: - init seeding

    func testInit_grandfathered_seedsProTrue() {
        let manager = makeManager(gateway: FakeGateway(), grandfathered: true, recorder: CacheRecorder())
        XCTAssertTrue(manager.isPro)
    }

    func testInit_notGrandfathered_seedsProFalse() {
        let manager = makeManager(gateway: FakeGateway(), grandfathered: false, recorder: CacheRecorder())
        XCTAssertFalse(manager.isPro)
    }

    // MARK: - refreshEntitlements

    func testRefresh_ownsProduct_isProAndCachesTrue() async {
        let gateway = FakeGateway()
        gateway.owned = [ProConfig.proProductID]
        let recorder = CacheRecorder()
        let manager = makeManager(gateway: gateway, grandfathered: false, recorder: recorder)

        await manager.refreshEntitlements()

        XCTAssertTrue(manager.isPro)
        XCTAssertEqual(recorder.last, true)
    }

    func testRefresh_freeAndNotOwned_clearsProAndCachesFalse() async {
        let recorder = CacheRecorder()
        let manager = makeManager(gateway: FakeGateway(), grandfathered: false, recorder: recorder)

        await manager.refreshEntitlements()

        XCTAssertFalse(manager.isPro)
        // Authoritative writer: PurchaseManager may CLEAR the cache (unlike the bootstrap).
        XCTAssertEqual(recorder.last, false)
    }

    func testRefresh_grandfatheredWithoutPurchase_isProAndCachesTrue() async {
        let recorder = CacheRecorder()
        let manager = makeManager(gateway: FakeGateway(), grandfathered: true, recorder: recorder)

        await manager.refreshEntitlements()

        XCTAssertTrue(manager.isPro)
        XCTAssertEqual(recorder.last, true)
    }

    // MARK: - purchase

    func testPurchase_success_grantsPro() async {
        let gateway = FakeGateway()
        gateway.nextOutcome = .success
        let manager = makeManager(gateway: gateway, grandfathered: false, recorder: CacheRecorder())

        await manager.purchase()

        XCTAssertTrue(manager.isPro)
        XCTAssertFalse(manager.isProcessing)
    }

    func testPurchase_cancelled_staysFree() async {
        let gateway = FakeGateway()
        gateway.nextOutcome = .cancelled
        let manager = makeManager(gateway: gateway, grandfathered: false, recorder: CacheRecorder())

        await manager.purchase()

        XCTAssertFalse(manager.isPro)
        XCTAssertNil(manager.statusMessage)
    }

    func testPurchase_pending_setsStatusMessage() async {
        let gateway = FakeGateway()
        gateway.nextOutcome = .pending
        let manager = makeManager(gateway: gateway, grandfathered: false, recorder: CacheRecorder())

        await manager.purchase()

        XCTAssertFalse(manager.isPro)
        XCTAssertNotNil(manager.statusMessage)
    }

    func testPurchase_error_setsStatusMessageAndStaysFree() async {
        let gateway = FakeGateway()
        gateway.purchaseError = PurchaseError.verificationFailed
        let manager = makeManager(gateway: gateway, grandfathered: false, recorder: CacheRecorder())

        await manager.purchase()

        XCTAssertFalse(manager.isPro)
        XCTAssertNotNil(manager.statusMessage)
    }

    // MARK: - restore

    func testRestore_withPriorPurchase_grantsPro() async {
        let gateway = FakeGateway()
        gateway.owned = [ProConfig.proProductID]
        let manager = makeManager(gateway: gateway, grandfathered: false, recorder: CacheRecorder())

        await manager.restore()

        XCTAssertTrue(gateway.syncCalled)
        XCTAssertTrue(manager.isPro)
    }

    func testRestore_withNothing_setsStatusMessage() async {
        let gateway = FakeGateway()
        let manager = makeManager(gateway: gateway, grandfathered: false, recorder: CacheRecorder())

        await manager.restore()

        XCTAssertTrue(gateway.syncCalled)
        XCTAssertFalse(manager.isPro)
        XCTAssertNotNil(manager.statusMessage)
    }

    // MARK: - product loading

    func testLoadProduct_populatesProProduct() async {
        let gateway = FakeGateway()
        let manager = makeManager(gateway: gateway, grandfathered: false, recorder: CacheRecorder())

        await manager.loadProductAndRefresh()

        XCTAssertEqual(manager.proProduct?.id, ProConfig.proProductID)
        XCTAssertEqual(manager.proProduct?.displayPrice, "$7.99")
    }

    func testLoadProduct_failureLeavesProductNil() async {
        let gateway = FakeGateway()
        gateway.loadError = PurchaseError.productNotFound
        let manager = makeManager(gateway: gateway, grandfathered: false, recorder: CacheRecorder())

        await manager.loadProductAndRefresh()

        XCTAssertNil(manager.proProduct)
    }
}
