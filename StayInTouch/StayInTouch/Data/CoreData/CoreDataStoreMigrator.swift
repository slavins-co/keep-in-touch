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
        return libraryURL.appendingPathComponent(AppGroup.coreDataStoreFilename)
    }

    /// Migrates the legacy store into the app group container if and only if
    /// the legacy store exists and the target location does not. Safe to call
    /// on every launch — it short-circuits when migration is unnecessary.
    ///
    /// If the copy phase throws part-way through, any files already copied to
    /// the target are removed before the error is rethrown, so the next
    /// launch retries from a clean target rather than opening a partial store.
    ///
    /// - Parameters:
    ///   - legacyURL: the pre-migration store location
    ///   - targetURL: the app group store location
    ///   - fileManager: injection point for tests
    /// - Returns: `true` if files were moved, `false` if nothing to do
    /// - Throws: if file IO fails. Target is cleaned up before the throw so
    ///   a subsequent call can retry. Legacy files are preserved on throw.
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

        var copiedDestinations: [URL] = []
        do {
            for suffix in sqliteSidecarSuffixes {
                let source = URL(fileURLWithPath: legacyURL.path + suffix)
                let destination = URL(fileURLWithPath: targetURL.path + suffix)

                guard fileManager.fileExists(atPath: source.path) else { continue }
                try fileManager.copyItem(at: source, to: destination)
                copiedDestinations.append(destination)

                try? fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: destination.path
                )
            }
        } catch {
            for destination in copiedDestinations {
                try? fileManager.removeItem(at: destination)
            }
            throw error
        }

        for suffix in sqliteSidecarSuffixes {
            let source = URL(fileURLWithPath: legacyURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            do {
                try fileManager.removeItem(at: source)
            } catch {
                AppLogger.logWarning(
                    "Failed to remove legacy Core Data file at \(source.path): \(error.localizedDescription)",
                    category: AppLogger.coreData
                )
            }
        }

        return true
    }
}
