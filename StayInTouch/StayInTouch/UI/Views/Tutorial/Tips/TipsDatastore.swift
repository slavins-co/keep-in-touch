//
//  TipsDatastore.swift
//  KeepInTouch
//
//  TipKit's `Tips.resetDatastore()` only works BEFORE `Tips.configure()`,
//  so a runtime user-initiated reset can't take effect in the current
//  session. Workaround: configure TipKit with a versioned datastore
//  location whose path includes a `tipsDatastoreEpoch` counter from
//  UserDefaults. Bumping the epoch on "Reset Feature Tips" means the
//  next launch reads from a fresh empty directory — TipKit sees no
//  prior display history, so the rule-eligible tips fire again.
//

import Foundation
import TipKit

enum TipsDatastore {
    private static let epochKey = "TipsDatastoreEpoch"

    /// The current TipKit datastore epoch. Bump this via `bumpEpoch()` to
    /// invalidate the cached display history on the next launch.
    static var currentEpoch: Int {
        UserDefaults.standard.integer(forKey: epochKey)
    }

    /// Increment the epoch so the next launch uses a fresh datastore path.
    static func bumpEpoch() {
        UserDefaults.standard.set(currentEpoch + 1, forKey: epochKey)
    }

    /// Build the `DatastoreLocation` for the current epoch. Falls back to
    /// `.applicationDefault` if Application Support isn't reachable.
    static func location() -> Tips.ConfigurationOption {
        let fm = FileManager.default
        guard let supportRoot = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return .datastoreLocation(.applicationDefault)
        }
        let tipsDir = supportRoot.appendingPathComponent("TipKit-v\(currentEpoch)", isDirectory: true)
        if !fm.fileExists(atPath: tipsDir.path) {
            try? fm.createDirectory(at: tipsDir, withIntermediateDirectories: true)
        }
        return .datastoreLocation(.url(tipsDir))
    }
}
