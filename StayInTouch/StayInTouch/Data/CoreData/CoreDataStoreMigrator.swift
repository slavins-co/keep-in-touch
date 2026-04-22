//
//  CoreDataStoreMigrator.swift
//  KeepInTouch
//
//  Moves the Core Data store from the app's private default location to the
//  shared App Group container so the widget extension can read from it.
//  Runs once per install, before the persistent container is loaded.
//

import Foundation

enum CoreDataStoreMigrator {

    /// The store filenames Core Data creates for a SQLite persistent store.
    /// All three must move together or the copy is worthless.
    static let sqliteSidecarSuffixes = ["", "-shm", "-wal"]

    /// Legacy default location — `NSPersistentContainer(name:)` used this by
    /// default before the App Group move.
    static func legacyStoreURL(fileManager: FileManager = .default) -> URL? {
        guard let libraryURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }
        return libraryURL.appendingPathComponent("StayInTouch.sqlite")
    }

    /// Migrates the legacy store into the app group container if and only if
    /// the legacy store exists and the target location does not. Safe to call
    /// on every launch — it short-circuits when migration is unnecessary.
    ///
    /// - Parameters:
    ///   - legacyURL: the pre-migration store location
    ///   - targetURL: the app group store location
    ///   - fileManager: injection point for tests
    /// - Returns: `true` if files were moved, `false` if nothing to do
    /// - Throws: if file IO fails mid-migration (partial state is possible;
    ///   caller should surface this as a migration failure)
    @discardableResult
    static func migrateIfNeeded(
        legacyURL: URL,
        targetURL: URL,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard fileManager.fileExists(atPath: legacyURL.path) else {
            return false
        }
        guard !fileManager.fileExists(atPath: targetURL.path) else {
            return false
        }

        try fileManager.createDirectory(
            at: targetURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        for suffix in sqliteSidecarSuffixes {
            let source = URL(fileURLWithPath: legacyURL.path + suffix)
            let destination = URL(fileURLWithPath: targetURL.path + suffix)

            guard fileManager.fileExists(atPath: source.path) else { continue }
            try fileManager.copyItem(at: source, to: destination)
        }

        for suffix in sqliteSidecarSuffixes {
            let source = URL(fileURLWithPath: legacyURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try? fileManager.removeItem(at: source)
        }

        return true
    }
}
