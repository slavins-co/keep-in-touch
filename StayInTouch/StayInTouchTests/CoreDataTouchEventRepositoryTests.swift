//
//  CoreDataTouchEventRepositoryTests.swift
//  KeepInTouchTests
//
//  Created by Claude on 3/6/26.
//

import CoreData
import XCTest
@testable import StayInTouch

final class CoreDataTouchEventRepositoryTests: XCTestCase {
    private var context: NSManagedObjectContext!
    private var repo: CoreDataTouchEventRepository!

    override func setUp() {
        super.setUp()
        let stack = CoreDataTestStack()
        context = stack.container.viewContext
        repo = CoreDataTouchEventRepository(context: context)
    }

    // MARK: - Fetch

    func testFetchNonExistentIdReturnsNil() {
        XCTAssertNil(repo.fetch(id: UUID()))
    }

    func testFetchAllForPersonOnEmptyReturnsEmpty() {
        XCTAssertTrue(repo.fetchAll(for: UUID()).isEmpty)
    }

    func testFetchAllReturnsSortedByDateDescending() throws {
        let personId = UUID()
        let older = TestFactory.makeTouchEvent(personId: personId, at: Date(timeIntervalSince1970: 1_000_000))
        let newer = TestFactory.makeTouchEvent(personId: personId, at: Date(timeIntervalSince1970: 2_000_000))

        try repo.save(older)
        try repo.save(newer)

        let results = repo.fetchAll(for: personId)
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results[0].at > results[1].at, "Newest event should be first")
    }

    func testFetchAllFiltersToCorrectPersonId() throws {
        let personA = UUID()
        let personB = UUID()

        try repo.save(TestFactory.makeTouchEvent(personId: personA))
        try repo.save(TestFactory.makeTouchEvent(personId: personB))
        try repo.save(TestFactory.makeTouchEvent(personId: personA))

        XCTAssertEqual(repo.fetchAll(for: personA).count, 2)
        XCTAssertEqual(repo.fetchAll(for: personB).count, 1)
    }

    func testFetchMostRecentReturnsLatestEvent() throws {
        let personId = UUID()
        let older = TestFactory.makeTouchEvent(personId: personId, at: Date(timeIntervalSince1970: 1_000_000))
        let newer = TestFactory.makeTouchEvent(personId: personId, at: Date(timeIntervalSince1970: 2_000_000))

        try repo.save(older)
        try repo.save(newer)

        let mostRecent = repo.fetchMostRecent(for: personId)
        XCTAssertEqual(mostRecent?.id, newer.id)
    }

    func testFetchMostRecentOnEmptyReturnsNil() {
        XCTAssertNil(repo.fetchMostRecent(for: UUID()))
    }

    // MARK: - fetchAll(since:)

    func testFetchAllSinceNilReturnsAllEvents() throws {
        let personA = UUID()
        let personB = UUID()
        try repo.save(TestFactory.makeTouchEvent(personId: personA, at: Date(timeIntervalSince1970: 1_000_000)))
        try repo.save(TestFactory.makeTouchEvent(personId: personB, at: Date(timeIntervalSince1970: 2_000_000)))

        let results = repo.fetchAll(since: nil)
        XCTAssertEqual(results.count, 2)
    }

    func testFetchAllSinceFiltersOutOlderEvents() throws {
        let personId = UUID()
        let oldDate = Date(timeIntervalSince1970: 1_000_000)
        let newDate = Date(timeIntervalSince1970: 2_000_000)
        let cutoff = Date(timeIntervalSince1970: 1_500_000)

        try repo.save(TestFactory.makeTouchEvent(personId: personId, at: oldDate))
        try repo.save(TestFactory.makeTouchEvent(personId: personId, at: newDate))

        let results = repo.fetchAll(since: cutoff)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.at, newDate)
    }

    func testFetchAllSinceReturnsDescendingByDate() throws {
        let personId = UUID()
        let oldest = TestFactory.makeTouchEvent(personId: personId, at: Date(timeIntervalSince1970: 1_000_000))
        let middle = TestFactory.makeTouchEvent(personId: personId, at: Date(timeIntervalSince1970: 1_500_000))
        let newest = TestFactory.makeTouchEvent(personId: personId, at: Date(timeIntervalSince1970: 2_000_000))

        try repo.save(middle)
        try repo.save(newest)
        try repo.save(oldest)

        let results = repo.fetchAll(since: nil)
        XCTAssertEqual(results.map(\.at), [newest.at, middle.at, oldest.at])
    }

    func testFetchAllSinceOnEmptyReturnsEmpty() {
        XCTAssertTrue(repo.fetchAll(since: nil).isEmpty)
        XCTAssertTrue(repo.fetchAll(since: Date()).isEmpty)
    }

    func testFetchAllSinceIncludesEventAtExactBoundary() throws {
        let personId = UUID()
        let boundary = Date(timeIntervalSince1970: 1_500_000)
        try repo.save(TestFactory.makeTouchEvent(personId: personId, at: boundary))

        let results = repo.fetchAll(since: boundary)
        XCTAssertEqual(results.count, 1, "Predicate is >= so an event at the exact boundary should be included")
    }

    // MARK: - Save / Batch

    func testBatchSaveMultipleEvents() throws {
        let personId = UUID()
        let events = [
            TestFactory.makeTouchEvent(personId: personId, method: .call),
            TestFactory.makeTouchEvent(personId: personId, method: .text),
            TestFactory.makeTouchEvent(personId: personId, method: .irl)
        ]

        try repo.batchSave(events)

        XCTAssertEqual(repo.fetchAll(for: personId).count, 3)
    }

    // MARK: - Delete

    func testDeleteNonExistentIdDoesNotThrow() {
        XCTAssertNoThrow(try repo.delete(id: UUID()))
    }
}
