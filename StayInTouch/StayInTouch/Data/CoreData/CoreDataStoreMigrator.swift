//
//  CoreDataStoreMigrator.swift
//  KeepInTouch
//
//  Invariants:
//  - The marker file is written only after every sidecar copy succeeds.
//  - Legacy source files are never deleted until the marker is in place.
//

import Foundation

enum CoreDataStoreMigrator {

    /// SQLite writes data to three files in lockstep — main DB plus `-shm`
    /// (shared memory) and `-wal` (write-ahead log). All three must move
    /// together or uncheckpointed writes are lost.
    static let sqliteSidecarSuffixes = ["", "-shm", "-wal"]

    private static let migrationMarkerFilename = ".StayInTouch-migration-complete"

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

    /// Migrates the legacy store into the app group container if and only if
    /// the marker file does not yet exist and the legacy store is present.
    ///
    /// - Returns: `true` when files were moved on this call.
    /// - Throws: if the copy phase fails. Files already copied to the target
    ///   are removed before rethrowing; legacy files are preserved.
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
