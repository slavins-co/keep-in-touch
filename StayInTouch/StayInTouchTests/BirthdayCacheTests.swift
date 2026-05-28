//
//  BirthdayCacheTests.swift
//  KeepInTouchTests
//
//  Covers the App Group birthday cache round-trip and graceful degradation
//  (#329). Uses a temp-file URL so the real shared container is untouched.
//

import XCTest
@testable import StayInTouch

final class BirthdayCacheTests: XCTestCase {

    private var tempURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("birthdayCacheTest-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        if let tempURL { try? FileManager.default.removeItem(at: tempURL) }
        tempURL = nil
        try super.tearDownWithError()
    }

    func testWriteThenRead_roundTrips() {
        let id1 = UUID()
        let id2 = UUID()
        let input: [UUID: Birthday] = [
            id1: Birthday(month: 3, day: 15, year: 1990),
            id2: Birthday(month: 12, day: 25, year: nil)
        ]

        XCTAssertTrue(BirthdayCache.write(input, to: tempURL))
        let output = BirthdayCache.read(from: tempURL)

        XCTAssertEqual(output, input)
    }

    func testRead_missingFile_returnsEmpty() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).json")
        XCTAssertTrue(BirthdayCache.read(from: missing).isEmpty)
    }

    func testRead_corruptJSON_returnsEmpty() throws {
        try Data("not json".utf8).write(to: tempURL)
        XCTAssertTrue(BirthdayCache.read(from: tempURL).isEmpty)
    }

    func testWrite_nilURL_returnsFalse() {
        XCTAssertFalse(BirthdayCache.write([:], to: nil))
    }

    func testRead_nilURL_returnsEmpty() {
        XCTAssertTrue(BirthdayCache.read(from: nil).isEmpty)
    }

    func testWrite_overwritesPrevious() {
        let id = UUID()
        BirthdayCache.write([id: Birthday(month: 1, day: 1, year: nil)], to: tempURL)
        BirthdayCache.write([id: Birthday(month: 6, day: 6, year: 2000)], to: tempURL)

        let output = BirthdayCache.read(from: tempURL)
        XCTAssertEqual(output[id], Birthday(month: 6, day: 6, year: 2000))
        XCTAssertEqual(output.count, 1)
    }
}
