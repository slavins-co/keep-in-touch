//
//  BuildEnvironment.swift
//  KeepInTouch (Shared — compiled into main app + widget extension)
//
//  Detects whether the running build is a TestFlight / StoreKit-sandbox build so
//  the freemium override (#362) can grant Pro to every beta tester — no 12-contact
//  cap, no paywall — while leaving production grandfather + purchase logic (#351)
//  completely untouched.
//
//  Signal (main-app process only): the App Store receipt at
//  `Bundle.main.appStoreReceiptURL` exists AND is named `sandboxReceipt`. That name
//  is used in TestFlight and the StoreKit sandbox; a production App Store receipt is
//  named `receipt`, and the simulator/dev flow has no receipt file at all. So this is
//  production-safe by construction: it can never grant Pro to a paying-customer build.
//
//  The widget extension's `Bundle.main` has no app-store receipt, so it can't detect
//  sandbox itself — it relies on the App Group `EntitlementCache` the main app writes.
//  That's why the override is applied app-side (EntitlementBootstrap / PurchaseManager)
//  and propagated through the cache, not read independently by the widget.
//

import Foundation

enum BuildEnvironment {
    /// Pure decision core — testable without touching the real bundle.
    /// Grants the testing override only for an existing receipt file named
    /// `sandboxReceipt` (TestFlight / StoreKit sandbox). Anything else — a
    /// production `receipt`, a missing file, or no receipt URL — returns false.
    static func grantsPro(receiptName: String?, receiptExists: Bool) -> Bool {
        receiptExists && receiptName == "sandboxReceipt"
    }

    /// Reads the real main-bundle App Store receipt and applies `grantsPro`.
    /// Isolated here (nonisolated static) so it can be used as a defaulted init
    /// argument from any isolation, and so callers inject the resolved `Bool` in
    /// tests instead of reading the bundle. False in the simulator/dev and in any
    /// out-of-process extension (no app-store receipt).
    static var grantsProForTesting: Bool {
        guard let url = Bundle.main.appStoreReceiptURL else { return false }
        let exists = FileManager.default.fileExists(atPath: url.path)
        return grantsPro(receiptName: url.lastPathComponent, receiptExists: exists)
    }
}
