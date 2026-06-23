//
//  StoreKitGateway.swift
//  KeepInTouch
//
//  A narrow seam over StoreKit 2 so `PurchaseManager`'s logic is fully testable
//  without StoreKit (which can't be faked — `Product`/`Transaction` have no public
//  initializers). The live adapter (`LiveStoreKitGateway`) is a thin, untested
//  wrapper; tests drive `PurchaseManager` through a fake conforming type. See #351.
//

import Foundation

/// A StoreKit product reduced to the fields the app/UI needs — keeps StoreKit
/// types out of the app and UI layers.
struct ProProduct: Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
}

/// The non-throwing outcomes of a purchase attempt. Genuine failures are thrown.
enum PurchaseOutcome: Equatable, Sendable {
    case success
    case pending
    case cancelled
}

enum PurchaseError: Error {
    case productNotFound
    case verificationFailed
}

protocol StoreKitGateway: Sendable {
    /// Load display info for the given product identifiers.
    func loadProducts(ids: [String]) async throws -> [ProProduct]

    /// The set of currently-owned (verified, non-revoked) product identifiers.
    func ownedProductIDs() async -> Set<String>

    /// Attempt to purchase a product. Throws on genuine failure; returns the
    /// non-error outcome (success / pending / cancelled) otherwise.
    func purchase(productID: String) async throws -> PurchaseOutcome

    /// Force a StoreKit account sync (the explicit "Restore Purchases" action).
    func sync() async throws

    /// Emits `()` whenever entitlements may have changed (Ask-to-Buy approvals,
    /// cross-device purchases, refunds). Each emission should prompt a re-read of
    /// `ownedProductIDs()`. The stream finishes when the listener is torn down.
    func transactionUpdates() -> AsyncStream<Void>
}
