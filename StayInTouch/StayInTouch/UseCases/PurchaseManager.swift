//
//  PurchaseManager.swift
//  KeepInTouch
//
//  App-wide source of truth for Pro entitlement (#351). Computes
//  `isPro = grandfathered || owns the non-consumable`, publishes it for the UI,
//  and is the AUTHORITATIVE writer of the App Group entitlement cache — it can
//  both grant Pro and clear it (on refund/revocation), unlike the launch
//  bootstrap which is set-only.
//
//  StoreKit access is isolated behind `StoreKitGateway` so this type's logic is
//  unit-tested with a fake. Grandfather status is read from persisted AppSettings.
//

import Combine
import Foundation

@MainActor
final class PurchaseManager: ObservableObject {
    /// Effective Pro status: grandfathered OR owns the Pro non-consumable.
    @Published private(set) var isPro: Bool
    /// Display info for the Pro product (nil until loaded, or if loading failed).
    @Published private(set) var proProduct: ProProduct?
    /// True while a purchase or restore is in flight (drives paywall button state).
    @Published private(set) var isProcessing = false
    /// User-facing message for the most recent purchase/restore failure or pending
    /// state. Set for the paywall to surface; cleared when a new action starts.
    @Published var statusMessage: String?

    private let gateway: StoreKitGateway
    private let settingsRepository: AppSettingsRepository
    private let writeCache: (Bool) -> Void
    private let reloadWidgets: () -> Void
    /// TestFlight/sandbox beta override (#362). Defaulted from the real bundle for
    /// production; injected explicitly in tests so they never read the bundle.
    private let grantsProForTesting: Bool
    private var updatesTask: Task<Void, Never>?

    init(
        gateway: StoreKitGateway,
        settingsRepository: AppSettingsRepository,
        writeCache: @escaping (Bool) -> Void = { EntitlementCache.write(isPro: $0) },
        reloadWidgets: @escaping () -> Void = WidgetRefresher.reloadAllTimelines,
        grantsProForTesting: Bool = BuildEnvironment.grantsProForTesting
    ) {
        self.gateway = gateway
        self.settingsRepository = settingsRepository
        self.writeCache = writeCache
        self.reloadWidgets = reloadWidgets
        self.grantsProForTesting = grantsProForTesting
        // Seed immediately so the UI is never briefly wrong before entitlements
        // load: grandfather OR the beta override (both offline-safe; no purchase
        // state yet, so hasProPurchase is false here).
        self.isPro = Entitlements.isPro(
            isGrandfathered: settingsRepository.fetch()?.isGrandfathered ?? false,
            hasProPurchase: false,
            grantsProForTesting: grantsProForTesting
        )
    }

    deinit { updatesTask?.cancel() }

    /// Begin the entitlement listener and load product + current entitlements.
    /// Call once from the app root.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await _ in self.gateway.transactionUpdates() {
                await self.refreshEntitlements()
            }
        }
        Task { await self.loadProductAndRefresh() }
    }

    /// Load the Pro product display info and refresh entitlement state.
    func loadProductAndRefresh() async {
        await refreshEntitlements()
        do {
            let products = try await gateway.loadProducts(ids: [ProConfig.proProductID])
            proProduct = products.first(where: { $0.id == ProConfig.proProductID }) ?? products.first
        } catch {
            // Leave proProduct nil; the paywall surfaces a load-failure/retry state.
            proProduct = nil
        }
    }

    /// Recompute `isPro` from grandfather status + owned products and write the
    /// authoritative entitlement cache (this is the only place that may clear Pro).
    func refreshEntitlements() async {
        let owned = await gateway.ownedProductIDs()
        let isGrandfathered = settingsRepository.fetch()?.isGrandfathered ?? false
        let pro = Entitlements.isPro(
            isGrandfathered: isGrandfathered,
            hasProPurchase: owned.contains(ProConfig.proProductID),
            grantsProForTesting: grantsProForTesting
        )
        let changed = (pro != isPro)
        isPro = pro
        writeCache(pro)
        // A StoreKit purchase/restore writes only the App Group cache — no Core
        // Data save fires, so the repository-layer WidgetRefresher never runs.
        // Reload here so Pro-only widgets flip locked↔unlocked. Only on a real
        // change, to avoid thrashing widget timelines on every cold-launch refresh.
        if changed { reloadWidgets() }
    }

    /// Purchase the Pro unlock.
    func purchase() async {
        guard !isProcessing else { return }
        statusMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            let outcome = try await gateway.purchase(productID: ProConfig.proProductID)
            switch outcome {
            case .success:
                await refreshEntitlements()
                AnalyticsService.track("pro.purchased")
            case .pending:
                statusMessage = "Your purchase is pending approval. You'll get Pro once it's approved."
            case .cancelled:
                break
            }
        } catch {
            statusMessage = "Purchase couldn't be completed. Please try again."
            AnalyticsService.track("pro.purchase_failed")
        }
    }

    /// Restore a previous purchase (explicit user action).
    func restore() async {
        guard !isProcessing else { return }
        statusMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await gateway.sync()
            await refreshEntitlements()
            AnalyticsService.track("pro.restored", parameters: ["result": isPro ? "pro" : "none"])
            if !isPro {
                statusMessage = "No previous purchase found to restore."
            }
        } catch {
            statusMessage = "Restore couldn't be completed. Please try again."
            AnalyticsService.track("pro.restore_failed")
        }
    }
}
