//
//  CoreDataStoreMigratorTests.swift
//  KeepInTouchTests
//
//  Covers the pre-load migration from the legacy default store location to
//  the App Group container. This is the critical data-safety path for the
//  widget infrastructure rollout.
//

import XCTest
@testable import StayInTouch

final class CoreDataStoreMigratorTests: XCTestCase {

    private var legacyDir: URL!
    private var groupDir: URL!
    private var fileManager: FileManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileManager = FileManager.default

        let base = fileManager.temporaryDirectory.appendingPathComponent(
            "CoreDataStoreMigratorTests-\(UUID().uuidString)",
            isDirectory: true
        )
        legacyDir = base.appendingPathComponent("legacy", isDirectory: true)
        groupDir = base.appendingPathComponent("group", isDirectory: true)

        try fileManager.createDirectory(at: legacyDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        let parent = legacyDir.deletingLastPathComponent()
        try? fileManager.removeItem(at: parent)
        try super.tearDownWithError()
    }

    // MARK: - Fresh install

    func test_migrateIfNeeded_whenLegacyStoreAbsent_doesNothing() throws {
        let legacyURL = legacyDir.appendingPathComponent("StayInTouch.sqlite")
        let targetURL = groupDir.appendingPathComponent("StayInTouch.sqlite")

        let migrated = try CoreDataStoreMigrator.migrateIfNeeded(
            legacyURL: legacyURL,
            targetURL: targetURL,
            fileManager: fileManager
        )

        XCTAssertFalse(migrated)
        XCTAssertFalse(fileManager.fileExists(atPath: targetURL.path))
    }

    // MARK: - Upgrade path

    func test_migrateIfNeeded_whenLegacyStoreExists_copiesAllSidecarsAndRemovesLegacy() throws {
        let legacyURL = legacyDir.appendingPathComponent("StayInTouch.sqlite")
        let targetURL = groupDir.appendingPathComponent("StayInTouch.sqlite")

        try "main-db-bytes".write(to: legacyURL, atomically: true, encoding: .utf8)
        try "shm-bytes".write(
            to: URL(fileURLWithPath: legacyURL.path + "-shm"),
            atomically: true,
            encoding: .utf8
        )
        try "wal-bytes".write(
            to: URL(fileURLWithPath: legacyURL.path + "-wal"),
            atomically: true,
            encoding: .utf8
        )

        let migrated = try CoreDataStoreMigrator.migrateIfNeeded(
            legacyURL: legacyURL,
            targetURL: targetURL,
            fileManager: fileManager
        )

        XCTAssertTrue(migrated)

        XCTAssertEqual(try String(contentsOf: targetURL, encoding: .utf8), "main-db-bytes")
        XCTAssertEqual(
            try String(contentsOf: URL(fileURLWithPath: targetURL.path + "-shm"), encoding: .utf8),
            "shm-bytes"
        )
        XCTAssertEqual(
            try String(contentsOf: URL(fileURLWithPath: targetURL.path + "-wal"), encoding: .utf8),
            "wal-bytes"
        )

        XCTAssertFalse(fileManager.fileExists(atPath: legacyURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: legacyURL.path + "-shm"))
        XCTAssertFalse(fileManager.fileExists(atPath: legacyURL.path + "-wal"))
    }

    func test_migrateIfNeeded_whenLegacyHasOnlyMainFile_copiesOnlyMainFile() throws {
        let legacyURL = legacyDir.appendingPathComponent("StayInTouch.sqlite")
        let targetURL = groupDir.appendingPathComponent("StayInTouch.sqlite")

        try "main-db-bytes".write(to: legacyURL, atomically: true, encoding: .utf8)

        let migrated = try CoreDataStoreMigrator.migrateIfNeeded(
            legacyURL: legacyURL,
            targetURL: targetURL,
            fileManager: fileManager
        )

        XCTAssertTrue(migrated)
        XCTAssertTrue(fileManager.fileExists(atPath: targetURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: targetURL.path + "-shm"))
        XCTAssertFalse(fileManager.fileExists(atPath: targetURL.path + "-wal"))
    }

    // MARK: - Partial recovery

    func test_migrateIfNeeded_whenTargetAlreadyExists_doesNothing() throws {
        let legacyURL = legacyDir.appendingPathComponent("StayInTouch.sqlite")
        let targetURL = groupDir.appendingPathComponent("StayInTouch.sqlite")

        try fileManager.createDirectory(at: groupDir, withIntermediateDirectories: true)
        try "legacy-data".write(to: legacyURL, atomically: true, encoding: .utf8)
        try "existing-group-data".write(to: targetURL, atomically: true, encoding: .utf8)

        let migrated = try CoreDataStoreMigrator.migrateIfNeeded(
            legacyURL: legacyURL,
            targetURL: targetURL,
            fileManager: fileManager
        )

        XCTAssertFalse(migrated)
        XCTAssertEqual(
            try String(contentsOf: targetURL, encoding: .utf8),
            "existing-group-data",
            "Existing group store must never be overwritten"
        )
        XCTAssertTrue(
            fileManager.fileExists(atPath: legacyURL.path),
            "Legacy files must be preserved when migration is skipped"
        )
    }

    // MARK: - Idempotency

    func test_migrateIfNeeded_isIdempotent_onSecondCall() throws {
        let legacyURL = legacyDir.appendingPathComponent("StayInTouch.sqlite")
        let targetURL = groupDir.appendingPathComponent("StayInTouch.sqlite")

        try "main-db-bytes".write(to: legacyURL, atomically: true, encoding: .utf8)

        _ = try CoreDataStoreMigrator.migrateIfNeeded(
            legacyURL: legacyURL,
            targetURL: targetURL,
            fileManager: fileManager
        )

        let secondRun = try CoreDataStoreMigrator.migrateIfNeeded(
            legacyURL: legacyURL,
            targetURL: targetURL,
            fileManager: fileManager
        )

        XCTAssertFalse(secondRun)
        XCTAssertEqual(try String(contentsOf: targetURL, encoding: .utf8), "main-db-bytes")
    }

    // MARK: - Directory creation

    func test_migrateIfNeeded_createsTargetDirectoryIfMissing() throws {
        let legacyURL = legacyDir.appendingPathComponent("StayInTouch.sqlite")
        let targetURL = groupDir.appendingPathComponent("StayInTouch.sqlite")

        try "main-db-bytes".write(to: legacyURL, atomically: true, encoding: .utf8)
        XCTAssertFalse(fileManager.fileExists(atPath: groupDir.path))

        let migrated = try CoreDataStoreMigrator.migrateIfNeeded(
            legacyURL: legacyURL,
            targetURL: targetURL,
            fileManager: fileManager
        )

        XCTAssertTrue(migrated)
        XCTAssertTrue(fileManager.fileExists(atPath: groupDir.path))
        XCTAssertTrue(fileManager.fileExists(atPath: targetURL.path))
    }

    // MARK: - AppGroup identifier sanity

    func test_appGroupIdentifier_matchesEntitlement() {
        XCTAssertEqual(AppGroup.identifier, "group.slavins.co.KeepInTouch")
    }

    func test_appGroupCoreDataStoreURL_appendsCorrectFilename() {
        guard let containerURL = AppGroup.containerURL,
              let storeURL = AppGroup.coreDataStoreURL else {
            return
        }

        XCTAssertEqual(storeURL.lastPathComponent, "StayInTouch.sqlite")
        XCTAssertEqual(
            storeURL.deletingLastPathComponent().path,
            containerURL.path
        )
    }
}
