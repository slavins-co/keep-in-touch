//
//  PersonStatusServiceTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import XCTest
@testable import StayInTouch

final class PersonStatusServiceTests: XCTestCase {
    /// Person 4 days from due with cadence warningDays=5 should appear in dueSoon
    /// regardless of any global settings window. FrequencyCalculator is the single
    /// source of truth for Due Soon status.
    func testDueSoonUsesWarningDaysNotSettingsWindow() {
        let cadenceId = UUID()
        let now = Date()
        // 26 days into a 30-day cadence → 4 days until due → within warningDays(5)
        let reference = Calendar.current.date(byAdding: .day, value: 26, to: now) ?? now

        let person = Person(
            identity: Person.Identity(id: UUID(), displayName: "Alex", initials: "A", avatarColor: "#FF6B6B"),
            cadenceId: cadenceId,
            groupIds: [],
            isPaused: false,
            isTracked: true,
            touchState: Person.TouchState(lastTouchAt: now),
            notifications: Person.NotificationConfig(notificationsMuted: false, birthdayNotificationsEnabled: true),
            metadata: Person.Metadata(contactUnavailable: false, isDemoData: false, createdAt: now, modifiedAt: now, sortOrder: 0)
        )

        let cadence = Cadence(
            id: cadenceId,
            name: "Monthly",
            frequencyDays: 30,
            warningDays: 5,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: now,
            modifiedAt: now
        )

        let service = PersonStatusService(referenceDate: reference)
        let dueSoon = service.dueSoonPeople([person], cadences: [cadence])
        XCTAssertEqual(dueSoon.count, 1)
        XCTAssertEqual(dueSoon.first?.displayName, "Alex")
    }

    func testOverdueTieBreakByLastTouchOlderFirst() {
        let cadenceId = UUID()
        let now = Date()
        let reference = Calendar.current.date(byAdding: .day, value: 10, to: now) ?? now

        let older = Person(
            identity: Person.Identity(id: UUID(), displayName: "Bob", initials: "B", avatarColor: "#FF6B6B"),
            cadenceId: cadenceId,
            groupIds: [],
            isPaused: false,
            isTracked: true,
            touchState: Person.TouchState(lastTouchAt: Calendar.current.date(byAdding: .day, value: -10, to: reference)),
            notifications: Person.NotificationConfig(notificationsMuted: false, birthdayNotificationsEnabled: true),
            metadata: Person.Metadata(contactUnavailable: false, isDemoData: false, createdAt: now, modifiedAt: now, sortOrder: 0)
        )

        let newer = Person(
            identity: Person.Identity(id: UUID(), displayName: "Alex", initials: "A", avatarColor: "#FF6B6B"),
            cadenceId: cadenceId,
            groupIds: [],
            isPaused: false,
            isTracked: true,
            touchState: Person.TouchState(lastTouchAt: Calendar.current.date(byAdding: .day, value: -9, to: reference)),
            notifications: Person.NotificationConfig(notificationsMuted: false, birthdayNotificationsEnabled: true),
            metadata: Person.Metadata(contactUnavailable: false, isDemoData: false, createdAt: now, modifiedAt: now, sortOrder: 0)
        )

        let cadence = Cadence(
            id: cadenceId,
            name: "Weekly",
            frequencyDays: 7,
            warningDays: 2,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: now,
            modifiedAt: now
        )

        let service = PersonStatusService(referenceDate: reference)
        let overdue = service.overduePeople([newer, older], cadences: [cadence])
        XCTAssertEqual(overdue.first?.displayName, "Bob")
    }

    // MARK: - partition() — unify Home buckets (#310, audit R5)

    /// Partition must place a person in exactly the same bucket the old
    /// HomeViewModel computation would have. Covers all status outcomes:
    /// paused (excluded), snoozed (onTrack), overdue, dueSoon, onTrack,
    /// no-last-touch with no cadenceAddedAt (unknown → excluded).
    func testPartitionAssignsEachStatusToCorrectBucket() {
        let cadenceId = UUID()
        let now = Date()
        let cal = Calendar.current

        let cadence = Cadence(
            id: cadenceId,
            name: "Weekly",
            frequencyDays: 7,
            warningDays: 2,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: now,
            modifiedAt: now
        )

        // Cadence: 7-day frequency, 2-day warning window.
        // referenceDate is `now`.
        let overduePerson = makePerson(
            name: "Overdue",
            cadenceId: cadenceId,
            lastTouchAt: cal.date(byAdding: .day, value: -10, to: now)  // 3 days overdue
        )
        let dueSoonPerson = makePerson(
            name: "DueSoon",
            cadenceId: cadenceId,
            lastTouchAt: cal.date(byAdding: .day, value: -6, to: now)   // due in 1 day, warning=2
        )
        let onTrackPerson = makePerson(
            name: "OnTrack",
            cadenceId: cadenceId,
            lastTouchAt: cal.date(byAdding: .day, value: -1, to: now)   // due in 6 days, > warning
        )
        let pausedOverdue = makePerson(
            name: "PausedOverdue",
            cadenceId: cadenceId,
            lastTouchAt: cal.date(byAdding: .day, value: -100, to: now),
            isPaused: true
        )
        let snoozedOverdue = makePerson(
            name: "SnoozedOverdue",
            cadenceId: cadenceId,
            lastTouchAt: cal.date(byAdding: .day, value: -100, to: now),
            snoozedUntil: cal.date(byAdding: .day, value: 5, to: now)
        )
        let unknownPerson = makePerson(
            name: "Unknown",
            cadenceId: cadenceId,
            lastTouchAt: nil,
            cadenceAddedAt: nil
        )

        let people = [overduePerson, dueSoonPerson, onTrackPerson, pausedOverdue, snoozedOverdue, unknownPerson]
        let service = PersonStatusService(referenceDate: now)
        let buckets = service.partition(people, cadences: [cadence])

        XCTAssertEqual(buckets.overdue.map { $0.displayName }, ["Overdue"])
        XCTAssertEqual(buckets.dueSoon.map { $0.displayName }, ["DueSoon"])
        // Snoozed person classifies as onTrack (FrequencyCalculator behavior).
        XCTAssertEqual(Set(buckets.onTrack.map { $0.displayName }), Set(["OnTrack", "SnoozedOverdue"]))

        // Paused and unknown are excluded from all three buckets.
        let allBucketedIds = Set(
            (buckets.overdue + buckets.dueSoon + buckets.onTrack).map { $0.id }
        )
        XCTAssertFalse(allBucketedIds.contains(pausedOverdue.id), "Paused must be excluded")
        XCTAssertFalse(allBucketedIds.contains(unknownPerson.id), "Unknown status must be excluded")
    }

    func testPartitionBucketsAreDisjoint() {
        let cadenceId = UUID()
        let now = Date()
        let cal = Calendar.current

        let cadence = Cadence(
            id: cadenceId,
            name: "Weekly",
            frequencyDays: 7,
            warningDays: 2,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: now,
            modifiedAt: now
        )

        let people = (0..<20).map { i -> Person in
            // Spread last-touch from -20..-1 days so we get a mix of buckets.
            let lastTouch = cal.date(byAdding: .day, value: -i, to: now)
            return makePerson(name: "P\(i)", cadenceId: cadenceId, lastTouchAt: lastTouch)
        }

        let service = PersonStatusService(referenceDate: now)
        let buckets = service.partition(people, cadences: [cadence])

        let overdueIds = Set(buckets.overdue.map { $0.id })
        let dueSoonIds = Set(buckets.dueSoon.map { $0.id })
        let onTrackIds = Set(buckets.onTrack.map { $0.id })

        XCTAssertTrue(overdueIds.isDisjoint(with: dueSoonIds))
        XCTAssertTrue(overdueIds.isDisjoint(with: onTrackIds))
        XCTAssertTrue(dueSoonIds.isDisjoint(with: onTrackIds))

        // Union equals all input ids (no paused, no unknown in this set).
        let union = overdueIds.union(dueSoonIds).union(onTrackIds)
        XCTAssertEqual(union, Set(people.map { $0.id }))
    }

    /// Equivalence test: partition() must produce the SAME sets the prior
    /// HomeViewModel.applyFilters() implementation produced — i.e. matches
    /// the existing `overduePeople`/`dueSoonPeople` helpers exactly, plus a
    /// "lastTouchAt desc" sort for the All Good bucket.
    func testPartitionMatchesLegacyComputation() {
        let cadenceId = UUID()
        let now = Date()
        let cal = Calendar.current

        let cadence = Cadence(
            id: cadenceId,
            name: "Weekly",
            frequencyDays: 7,
            warningDays: 2,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: now,
            modifiedAt: now
        )

        // Build a varied set: overdue, due-soon, on-track, snoozed, paused, unknown.
        let people: [Person] = [
            makePerson(name: "A", cadenceId: cadenceId, lastTouchAt: cal.date(byAdding: .day, value: -30, to: now)),  // overdue
            makePerson(name: "B", cadenceId: cadenceId, lastTouchAt: cal.date(byAdding: .day, value: -8, to: now)),   // overdue (1 day)
            makePerson(name: "C", cadenceId: cadenceId, lastTouchAt: cal.date(byAdding: .day, value: -6, to: now)),   // due soon
            makePerson(name: "D", cadenceId: cadenceId, lastTouchAt: cal.date(byAdding: .day, value: -1, to: now)),   // on track
            makePerson(name: "E", cadenceId: cadenceId, lastTouchAt: cal.date(byAdding: .day, value: -2, to: now)),   // on track
            makePerson(name: "F", cadenceId: cadenceId, lastTouchAt: cal.date(byAdding: .day, value: -100, to: now), isPaused: true),  // paused
            makePerson(name: "G", cadenceId: cadenceId, lastTouchAt: cal.date(byAdding: .day, value: -100, to: now),
                       snoozedUntil: cal.date(byAdding: .day, value: 3, to: now)),  // snoozed → onTrack
        ]

        let service = PersonStatusService(referenceDate: now)
        let buckets = service.partition(people, cadences: [cadence])

        // Legacy reference computation.
        let legacyOverdue = service.overduePeople(people, cadences: [cadence])
        let legacyDueSoon = service.dueSoonPeople(people, cadences: [cadence])
        let legacyAllGood = people
            .filter { !$0.isPaused }
            .filter { FrequencyCalculator(referenceDate: now).status(for: $0, in: [cadence]) == .onTrack }
            .sorted { ($0.lastTouchAt ?? .distantPast) > ($1.lastTouchAt ?? .distantPast) }

        XCTAssertEqual(buckets.overdue.map { $0.id }, legacyOverdue.map { $0.id }, "Overdue bucket must match legacy ordering and membership")
        XCTAssertEqual(buckets.dueSoon.map { $0.id }, legacyDueSoon.map { $0.id }, "Due Soon bucket must match legacy ordering and membership")
        XCTAssertEqual(buckets.onTrack.map { $0.id }, legacyAllGood.map { $0.id }, "All Good bucket must match legacy ordering and membership")
    }

    func testPartitionOnTrackSortedByLastTouchDescending() {
        let cadenceId = UUID()
        let now = Date()
        let cal = Calendar.current

        let cadence = Cadence(
            id: cadenceId,
            name: "Monthly",
            frequencyDays: 30,
            warningDays: 3,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: now,
            modifiedAt: now
        )

        let oldest = makePerson(name: "Oldest", cadenceId: cadenceId, lastTouchAt: cal.date(byAdding: .day, value: -10, to: now))
        let middle = makePerson(name: "Middle", cadenceId: cadenceId, lastTouchAt: cal.date(byAdding: .day, value: -5, to: now))
        let newest = makePerson(name: "Newest", cadenceId: cadenceId, lastTouchAt: cal.date(byAdding: .day, value: -1, to: now))

        let service = PersonStatusService(referenceDate: now)
        let buckets = service.partition([oldest, newest, middle], cadences: [cadence])

        XCTAssertEqual(buckets.onTrack.map { $0.displayName }, ["Newest", "Middle", "Oldest"])
    }

    func testPartitionEmptyInputReturnsEmptyBuckets() {
        let service = PersonStatusService(referenceDate: Date())
        let buckets = service.partition([], cadences: [])
        XCTAssertTrue(buckets.overdue.isEmpty)
        XCTAssertTrue(buckets.dueSoon.isEmpty)
        XCTAssertTrue(buckets.onTrack.isEmpty)
    }

    // MARK: - Helpers

    private func makePerson(
        name: String,
        cadenceId: UUID,
        lastTouchAt: Date?,
        isPaused: Bool = false,
        snoozedUntil: Date? = nil,
        cadenceAddedAt: Date? = Date()
    ) -> Person {
        Person(
            identity: Person.Identity(id: UUID(), displayName: name, initials: String(name.prefix(1)), avatarColor: "#FF6B6B"),
            cadenceId: cadenceId,
            groupIds: [],
            isPaused: isPaused,
            isTracked: true,
            touchState: Person.TouchState(lastTouchAt: lastTouchAt, snoozedUntil: snoozedUntil, cadenceAddedAt: cadenceAddedAt),
            notifications: Person.NotificationConfig(notificationsMuted: false, birthdayNotificationsEnabled: true),
            metadata: Person.Metadata(contactUnavailable: false, isDemoData: false, createdAt: Date(), modifiedAt: Date(), sortOrder: 0)
        )
    }
}
