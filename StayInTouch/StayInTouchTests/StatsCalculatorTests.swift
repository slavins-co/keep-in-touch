//
//  StatsCalculatorTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class StatsCalculatorTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 22:13:20 UTC
    private let calc = StatsCalculator()

    // MARK: - Empty / EmptyForRange

    func testEmptyEventsAndPeopleReturnsEmpty() {
        let snapshot = calc.compute(now: now, range: .days30, events: [], people: [], cadences: [])
        XCTAssertEqual(snapshot.state, .empty)
    }

    func testPeopleExistButNoEventsInRangeReturnsEmptyForRange() {
        let cadence = TestFactory.makeCadence()
        let person = TestFactory.makePerson(cadenceId: cadence.id)
        let oldEvent = TestFactory.makeTouchEvent(
            personId: person.id,
            at: daysAgo(120)
        )

        let snapshot = calc.compute(
            now: now,
            range: .days30,
            events: [oldEvent],
            people: [person],
            cadences: [cadence]
        )

        XCTAssertEqual(snapshot.state, .emptyForRange)
    }

    // MARK: - Cadence rows

    func testRangeTooShortForCadenceYieldsNilRatio() {
        // 30-day range, quarterly (90-day) cadence: expectedPerPerson = 30/90 = 0
        let cadence = TestFactory.makeCadence(name: "Quarterly", frequencyDays: 90)
        let person = TestFactory.makePerson(cadenceId: cadence.id)
        let event = TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(5))

        let snapshot = calc.compute(
            now: now,
            range: .days30,
            events: [event],
            people: [person],
            cadences: [cadence]
        )

        guard case .ready(let rows, _, _) = snapshot.state else {
            return XCTFail("expected .ready state")
        }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].expected, 0)
        XCTAssertNil(rows[0].ratio)
    }

    func testRatioReflectsActualOverExpected() throws {
        // 30-day range, weekly cadence (7d). expectedPerPerson = 4. 1 person => expected=4.
        // 2 events in range => ratio 0.5
        let cadence = TestFactory.makeCadence(name: "Weekly", frequencyDays: 7)
        let person = TestFactory.makePerson(cadenceId: cadence.id)
        let events = [
            TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(2)),
            TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(10))
        ]

        let snapshot = calc.compute(
            now: now,
            range: .days30,
            events: events,
            people: [person],
            cadences: [cadence]
        )

        guard case .ready(let rows, _, _) = snapshot.state else {
            return XCTFail("expected .ready state")
        }
        XCTAssertEqual(rows[0].expected, 4)
        XCTAssertEqual(rows[0].actual, 2)
        XCTAssertEqual(try XCTUnwrap(rows[0].ratio), 0.5, accuracy: 0.001)
    }

    func testOverPerformingRatioIsNotClampedInData() throws {
        let cadence = TestFactory.makeCadence(frequencyDays: 7)
        let person = TestFactory.makePerson(cadenceId: cadence.id)
        // expected = 4, actual = 8 -> 2.0
        let events = (0..<8).map { i in
            TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(i * 3))
        }

        let snapshot = calc.compute(
            now: now,
            range: .days30,
            events: events,
            people: [person],
            cadences: [cadence]
        )

        guard case .ready(let rows, _, _) = snapshot.state else {
            return XCTFail("expected .ready state")
        }
        XCTAssertEqual(try XCTUnwrap(rows[0].ratio), 2.0, accuracy: 0.001)
    }

    func testPausedPeopleExcludedFromExpectedAndActual() {
        let cadence = TestFactory.makeCadence(frequencyDays: 7)
        let active = TestFactory.makePerson(cadenceId: cadence.id)
        let paused = TestFactory.makePerson(cadenceId: cadence.id, isPaused: true)
        let events = [
            TestFactory.makeTouchEvent(personId: active.id, at: daysAgo(2)),
            TestFactory.makeTouchEvent(personId: paused.id, at: daysAgo(2))  // should not count
        ]

        let snapshot = calc.compute(
            now: now,
            range: .days30,
            events: events,
            people: [active, paused],
            cadences: [cadence]
        )

        guard case .ready(let rows, _, _) = snapshot.state else {
            return XCTFail("expected .ready state")
        }
        XCTAssertEqual(rows[0].trackedCount, 1, "Only the active person is counted")
        XCTAssertEqual(rows[0].actual, 1, "Paused person's event should not count toward this cadence")
    }

    func testUntrackedPeopleExcluded() {
        let cadence = TestFactory.makeCadence(frequencyDays: 7)
        let tracked = TestFactory.makePerson(cadenceId: cadence.id, isTracked: true)
        let untracked = TestFactory.makePerson(cadenceId: cadence.id, isTracked: false)

        let events = [
            TestFactory.makeTouchEvent(personId: tracked.id, at: daysAgo(2)),
            TestFactory.makeTouchEvent(personId: untracked.id, at: daysAgo(2))
        ]

        let snapshot = calc.compute(
            now: now,
            range: .days30,
            events: events,
            people: [tracked, untracked],
            cadences: [cadence]
        )

        guard case .ready(let rows, _, let methodTotal) = snapshot.state else {
            return XCTFail("expected .ready state")
        }
        XCTAssertEqual(rows[0].trackedCount, 1)
        XCTAssertEqual(rows[0].actual, 1, "Untracked person's event excluded from cadence row")
        // Method breakdown uses ALL events in range (not just tracked-people events)
        // since "how you showed up" is about user behavior, not per-cadence
        XCTAssertEqual(methodTotal, 2)
    }

    func testMultipleCadencesComputedIndependently() {
        let weekly = TestFactory.makeCadence(name: "Weekly", frequencyDays: 7)
        let monthly = TestFactory.makeCadence(name: "Monthly", frequencyDays: 30)
        var weeklyCadence = weekly
        weeklyCadence.sortOrder = 0
        var monthlyCadence = monthly
        monthlyCadence.sortOrder = 1

        let weeklyPerson = TestFactory.makePerson(cadenceId: weeklyCadence.id)
        let monthlyPerson = TestFactory.makePerson(cadenceId: monthlyCadence.id)

        let events = [
            TestFactory.makeTouchEvent(personId: weeklyPerson.id, at: daysAgo(3)),
            TestFactory.makeTouchEvent(personId: weeklyPerson.id, at: daysAgo(10)),
            TestFactory.makeTouchEvent(personId: monthlyPerson.id, at: daysAgo(5))
        ]

        let snapshot = calc.compute(
            now: now,
            range: .days30,
            events: events,
            people: [weeklyPerson, monthlyPerson],
            cadences: [weeklyCadence, monthlyCadence]
        )

        guard case .ready(let rows, _, _) = snapshot.state else {
            return XCTFail("expected .ready state")
        }
        XCTAssertEqual(rows.count, 2)
        let weeklyRow = rows.first { $0.id == weeklyCadence.id }!
        let monthlyRow = rows.first { $0.id == monthlyCadence.id }!
        XCTAssertEqual(weeklyRow.expected, 4)
        XCTAssertEqual(weeklyRow.actual, 2)
        XCTAssertEqual(monthlyRow.expected, 1)
        XCTAssertEqual(monthlyRow.actual, 1)
    }

    // MARK: - Method breakdown

    func testMethodBreakdownPercentages() {
        let cadence = TestFactory.makeCadence(frequencyDays: 7)
        let person = TestFactory.makePerson(cadenceId: cadence.id)
        let events = [
            TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(1), method: .text),
            TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(2), method: .text),
            TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(3), method: .call)
        ]

        let snapshot = calc.compute(
            now: now,
            range: .days30,
            events: events,
            people: [person],
            cadences: [cadence]
        )

        guard case .ready(_, let methodRows, let total) = snapshot.state else {
            return XCTFail("expected .ready state")
        }
        XCTAssertEqual(total, 3)
        XCTAssertEqual(methodRows.count, 2)
        XCTAssertEqual(methodRows[0].method, .text)
        XCTAssertEqual(methodRows[0].count, 2)
        XCTAssertEqual(methodRows[0].percent, 2.0/3.0, accuracy: 0.001)
        XCTAssertEqual(methodRows[1].method, .call)
        XCTAssertEqual(methodRows[1].count, 1)
        XCTAssertEqual(methodRows[1].percent, 1.0/3.0, accuracy: 0.001)
    }

    func testMethodBreakdownExcludesMethodsWithZeroCount() {
        let cadence = TestFactory.makeCadence(frequencyDays: 7)
        let person = TestFactory.makePerson(cadenceId: cadence.id)
        let events = [TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(1), method: .irl)]

        let snapshot = calc.compute(
            now: now,
            range: .days30,
            events: events,
            people: [person],
            cadences: [cadence]
        )

        guard case .ready(_, let methodRows, _) = snapshot.state else {
            return XCTFail("expected .ready state")
        }
        XCTAssertEqual(methodRows.count, 1)
        XCTAssertEqual(methodRows[0].method, .irl)
    }

    // MARK: - Range filtering

    func testEventsOutsideRangeAreExcluded() {
        let cadence = TestFactory.makeCadence(frequencyDays: 7)
        let person = TestFactory.makePerson(cadenceId: cadence.id)
        let events = [
            TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(2)),
            TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(45)) // outside 30d
        ]

        let snapshot = calc.compute(
            now: now,
            range: .days30,
            events: events,
            people: [person],
            cadences: [cadence]
        )

        guard case .ready(let rows, _, let total) = snapshot.state else {
            return XCTFail("expected .ready state")
        }
        XCTAssertEqual(rows[0].actual, 1)
        XCTAssertEqual(total, 1)
    }

    // MARK: - Orphaned references

    func testPersonWithOrphanCadenceIdIsNotCounted() {
        let realCadence = TestFactory.makeCadence(frequencyDays: 7)
        // Person points to a cadence that doesn't exist in the cadences array
        let orphan = TestFactory.makePerson(cadenceId: UUID())
        let event = TestFactory.makeTouchEvent(personId: orphan.id, at: daysAgo(2))

        let snapshot = calc.compute(
            now: now,
            range: .days30,
            events: [event],
            people: [orphan],
            cadences: [realCadence]
        )

        guard case .ready(let rows, _, _) = snapshot.state else {
            return XCTFail("expected .ready state")
        }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].trackedCount, 0, "Orphan person not attached to any known cadence")
        XCTAssertEqual(rows[0].actual, 0)
        XCTAssertNil(rows[0].ratio)
    }

    // MARK: - Helpers

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: now)!
    }
}
