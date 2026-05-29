//
//  BirthdayCacheRefresherTests.swift
//  KeepInTouchTests
//
//  Covers the pure cache-resolution mapping and the refresh() orchestration
//  (filtering, full-overwrite, widget reload) with injected collaborators —
//  no Contacts or App Group access (#329).
//

import XCTest
@testable import StayInTouch

final class BirthdayCacheRefresherTests: XCTestCase {

    // MARK: - resolveCache (pure)

    func testResolveCache_mapsByCnIdentifier() {
        let p1 = makePerson(cnIdentifier: "cn-1")
        let p2 = makePerson(cnIdentifier: "cn-2")
        let contacts = [
            "cn-1": Birthday(month: 3, day: 15, year: nil),
            "cn-2": Birthday(month: 12, day: 25, year: 1990),
        ]

        let result = BirthdayCacheRefresher.resolveCache(people: [p1, p2], contactBirthdays: contacts)

        XCTAssertEqual(result[p1.id], Birthday(month: 3, day: 15, year: nil))
        XCTAssertEqual(result[p2.id], Birthday(month: 12, day: 25, year: 1990))
    }

    func testResolveCache_dropsPeopleWithoutContactBirthday() {
        let withBirthday = makePerson(cnIdentifier: "cn-1")
        let withoutBirthday = makePerson(cnIdentifier: "cn-missing")
        let noCnId = makePerson(cnIdentifier: nil)
        let contacts = ["cn-1": Birthday(month: 1, day: 1, year: nil)]

        let result = BirthdayCacheRefresher.resolveCache(
            people: [withBirthday, withoutBirthday, noCnId],
            contactBirthdays: contacts
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertNotNil(result[withBirthday.id])
    }

    // MARK: - refresh() orchestration

    func testRefresh_writesResolvedCacheAndReloadsWidgets() {
        let candidate = makePerson(cnIdentifier: "cn-1", birthday: nil, birthdayNotificationsEnabled: true)
        var written: [UUID: Birthday]?
        var reloaded = false

        let sut = BirthdayCacheRefresher(
            fetchPeople: { [candidate] },
            fetchContactBirthdays: { ids in
                XCTAssertEqual(ids, ["cn-1"])
                return ["cn-1": Birthday(month: 5, day: 5, year: nil)]
            },
            isContactsAuthorized: { true },
            writeCache: { written = $0 },
            reloadWidgets: { reloaded = true }
        )

        sut.refresh()

        XCTAssertEqual(written?[candidate.id], Birthday(month: 5, day: 5, year: nil))
        XCTAssertTrue(reloaded)
    }

    func testRefresh_skipsWriteWhenContactsUnauthorized() {
        let candidate = makePerson(cnIdentifier: "cn-1", birthday: nil, birthdayNotificationsEnabled: true)
        var wrote = false
        var reloaded = false

        let sut = BirthdayCacheRefresher(
            fetchPeople: { [candidate] },
            fetchContactBirthdays: { _ in XCTFail("Contacts must not be queried when unauthorized"); return [:] },
            isContactsAuthorized: { false },
            writeCache: { _ in wrote = true },
            reloadWidgets: { reloaded = true }
        )

        sut.refresh()

        // Existing cache is preserved (not overwritten) when access is missing.
        XCTAssertFalse(wrote)
        XCTAssertFalse(reloaded)
    }

    func testRefresh_excludesStoredBirthdayOptedOutAndNoCnId() {
        let stored = makePerson(cnIdentifier: "cn-stored", birthday: Birthday(month: 1, day: 1, year: nil))
        let optedOut = makePerson(cnIdentifier: "cn-out", birthday: nil, birthdayNotificationsEnabled: false)
        let noCnId = makePerson(cnIdentifier: nil, birthday: nil)
        var fetchedIdentifiers: [String]?

        let sut = BirthdayCacheRefresher(
            fetchPeople: { [stored, optedOut, noCnId] },
            fetchContactBirthdays: { ids in
                fetchedIdentifiers = ids
                return [:]
            },
            writeCache: { _ in },
            reloadWidgets: {}
        )

        sut.refresh()

        // None of the three are eligible, so Contacts is never queried.
        XCTAssertNil(fetchedIdentifiers)
    }

    func testRefresh_writesEmptyCacheWhenNoCandidates() {
        var written: [UUID: Birthday]?
        let sut = BirthdayCacheRefresher(
            fetchPeople: { [] },
            fetchContactBirthdays: { _ in [:] },
            writeCache: { written = $0 },
            reloadWidgets: {}
        )

        sut.refresh()

        XCTAssertEqual(written, [:])
    }

    // MARK: - Fixture

    private func makePerson(
        cnIdentifier: String?,
        birthday: Birthday? = nil,
        birthdayNotificationsEnabled: Bool = true
    ) -> Person {
        TestFactory.makePerson(
            birthday: birthday,
            birthdayNotificationsEnabled: birthdayNotificationsEnabled,
            cnIdentifier: cnIdentifier
        )
    }
}
