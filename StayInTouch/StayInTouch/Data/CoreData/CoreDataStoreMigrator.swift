//
//  CoreDataStoreMigrator.swift
//  KeepInTouch
//
//  Moves the Core Data store from the app's private default location to the
//  shared App Group container so the widget extension can read from it.
//  Runs once per install, before the persistent container is loaded.
//
//  Robustness model:
//  - A sentinel marker file is created only after every sidecar has been
//    copied successfully. "Migration complete" == "marker exists".
//  - If a prior run was killed mid-copy (no throw, no cleanup), the marker
//    will be absent. On the next launch we detect the partial target, clean
//    it up, and restart migration from the legacy source.
//  - Legacy source files are never deleted before the marker lands.
//

import Foundation

enum CoreDataStoreMigrator {

    /// The store filenames Core Data creates for a SQLite persistent store.
    /// All three must move together or the copy is worthless.
    static let sqliteSidecarSuffixes = ["", "-shm", "-wal"]

    /// Written alongside the target store only after every sidecar has been
    /// copied. Presence of this file is the single source of truth for
    /// "migration has fully completed".
    static let migrationMarkerFilename = ".StayInTouch-migration-complete"

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

    static func migrationMarkerURL(for targetURL: URL) -> URL {
        targetURL
            .deletingLastPathComponent()
            .appendingPathComponent(migrationMarkerFilename)
    }

    /// Migrates the legacy store into the app group container if and only if:
    /// - the legacy store exists, AND
    /// - the marker file does not yet exist (i.e. no prior successful migration).
    ///
    /// If an earlier run was interrupted (process kill, power loss) after
    /// some sidecars copied but before the marker was written, the partial
    /// target files are removed before the retry.
    ///
    /// If the copy phase throws part-way through, files already copied to
    /// the target are removed before the error is rethrown, and the marker
    /// is not written. Legacy files are never touched until after the marker
    /// is in place.
    ///
    /// - Parameters:
    ///   - legacyURL: the pre-migration store location
    ///   - targetURL: the app group store location
    ///   - fileManager: injection point for tests
    /// - Returns: `true` if files were moved on this call, `false` otherwise
    /// - Throws: if file IO fails. Target is cleaned up before the throw so
    ///   a subsequent call can retry cleanly. Legacy files are preserved.
    @discardableResult
    static func migrateIfNeeded(
        legacyURL: URL,
        targetURL: URL,
        fileManager: FileManager = .default
    ) throws -> Bool {
        let markerURL = migrationMarkerURL(for: targetURL)

        if fileManager.fileExists(atPath: markerURL.path) {
            return false
        }

        guard fileManager.fileExists(atPath: legacyURL.path) else {
            return false
        }

        cleanupTarget(targetURL, fileManager: fileManager)

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

        fileManager.createFile(
            atPath: markerURL.path,
            contents: Data(),
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )

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

    /// Removes any orphan target files from a prior incomplete migration.
    /// Called only when the marker is absent — a fully-migrated target is
    /// never touched here.
    private static func cleanupTarget(_ targetURL: URL, fileManager: FileManager) {
        for suffix in sqliteSidecarSuffixes {
            let url = URL(fileURLWithPath: targetURL.path + suffix)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                try fileManager.removeItem(at: url)
                AppLogger.logWarning(
                    "Cleaned up orphan Core Data file at \(url.path) from a prior incomplete migration",
                    category: AppLogger.coreData
                )
            } catch {
                AppLogger.logError(
                    error,
                    category: AppLogger.coreData,
                    context: "CoreDataStoreMigrator.cleanupTarget(\(url.lastPathComponent))"
                )
            }
        }
    }
}
