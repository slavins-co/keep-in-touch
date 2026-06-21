//
//  LiveStoreKitGateway.swift
//  KeepInTouch
//
//  Thin StoreKit 2 adapter behind `StoreKitGateway`. Intentionally logic-light
//  (no entitlement decisions here — that's `PurchaseManager`); this only maps
//  StoreKit calls/types to the gateway's plain value types. See #351.
//

import Foundation
import StoreKit

struct LiveStoreKitGateway: StoreKitGateway {
    func loadProducts(ids: [String]) async throws -> [ProProduct] {
        let products = try await Product.products(for: ids)
        return products.map {
            ProProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice)
        }
    }

    func ownedProductIDs() async -> Set<String> {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }
            owned.insert(transaction.productID)
        }
        return owned
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else { throw PurchaseError.productNotFound }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            return .success
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    func transactionUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            // Iterate StoreKit's update stream off the main actor; finish each
            // transaction and signal the manager to re-read entitlements.
            let task = Task.detached {
                for await result in Transaction.updates {
                    guard case .verified(let transaction) = result else { continue }
                    await transaction.finish()
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.verificationFailed
        case .verified(let value):
            return value
        }
    }
}
