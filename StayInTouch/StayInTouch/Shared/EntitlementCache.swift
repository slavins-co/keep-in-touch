//
//  EntitlementCache.swift
//  KeepInTouch (Shared — compiled into main app + widget extension)
//
//  App Group-backed cache of the user's Pro entitlement so out-of-process
//  consumers (the widget extension, App Intents) can read `isPro` synchronously
//  without touching StoreKit — which only runs in the main app process.
//
//  The main app is the sole writer (on launch / purchase / restore / entitlement
//  change). Readers degrade to `false` (free tier) on any failure — missing file,
//  missing container, corrupt JSON — which is the safe default: never accidentally
//  grant Pro from a bad read.
//

import Foundation

enum EntitlementCache {
    static let filename = "entitlementCache.json"

    static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(filename)
    }

    private struct Payload: Codable {
        let isPro: Bool
    }

    /// Reads the cached Pro entitlement. Returns `false` on any failure.
    static func readIsPro(from url: URL? = fileURL) -> Bool {
        guard
            let url,
            let data = try? Data(contentsOf: url),
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return false }
        return payload.isPro
    }

    /// Writes the Pro entitlement atomically. Returns `false` if the container is
    /// unavailable or encoding/writing fails (non-fatal — readers keep the last
    /// successfully written value, or default to free).
    @discardableResult
    static func write(isPro: Bool, to url: URL? = fileURL) -> Bool {
        guard let url else { return false }
        guard let data = try? JSONEncoder().encode(Payload(isPro: isPro)) else { return false }
        do {
            // Pin the same protection class the Core Data store uses
            // (completeUntilFirstUserAuthentication) so the widget can read this on
            // the Lock Screen after first unlock; stricter `.complete` would break
            // lock-screen reads.
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }
}
