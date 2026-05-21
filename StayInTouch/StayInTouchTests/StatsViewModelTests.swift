//
//  StatsViewModelTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

@MainActor
final class StatsViewModelTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeVM(
        people: [Person] = [],
        cadences: [Cadence] = [],
        events: [TouchEvent] = [],
        range: StatsRange = .days30
    ) -> StatsViewModel {
        let personRepo = MockPersonRepository()
        personRepo.people = people
        let cadenceRepo = MockCadenceRepository()
        cadenceRepo.cadences = cadences
        let touchRepo = MockTouchEventRepository()
        touchRepo.events = events

        return StatsViewModel(
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            touchEventRepository: touchRepo,
            range: range,
            now: { self.now }
        )
    }

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: now)!
    }

    // MARK: - Empty state

    func testLoadWithNoDataProducesEmptySnapshot() {
        let vm = makeVM()
        vm.load()

        XCTAssertEqual(vm.snapshot?.state, .empty)
        XCTAssertEqual(vm.loadState, .ready)
    }

    // MARK: - Range applied to snapshot

    func testLoadAppliesCurrentRangeToSnapshot() {
        let cadence = TestFactory.makeCadence(frequencyDays: 7)
        let person = TestFactory.makePerson(cadenceId: cadence.id)
        let event = TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(2))

        let vm = makeVM(people: [person], cadences: [cadence], events: [event], range: .days30)
        vm.load()

        XCTAssertEqual(vm.snapshot?.range, .days30)
    }

    // MARK: - Range change triggers manual reload via load()

    func testRangeChangeCausesRecomputeWithDifferentDayCount() {
        let cadence = TestFactory.makeCadence(name: "Quarterly", frequencyDays: 90)
        let person = TestFactory.makePerson(cadenceId: cadence.id)
        let event = TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(60))

        let vm = makeVM(people: [person], cadences: [cadence], events: [event], range: .days30)

        // 30d range: event at day 60 is OUTSIDE range -> emptyForRange
        vm.load()
        XCTAssertEqual(vm.snapshot?.state, .emptyForRange)

        // Switch to 90d range, reload: event is now INSIDE range -> ready
        vm.range = .days90
        vm.load()
        if case .ready = vm.snapshot?.state {
            // expected
        } else {
            XCTFail("expected .ready after expanding range to 90d, got \(String(describing: vm.snapshot?.state))")
        }
    }

    // MARK: - Events outside range do not show

    func testEventsOlderThanRangeAreFilteredOut() {
        let cadence = TestFactory.makeCadence(frequencyDays: 7)
        let person = TestFactory.makePerson(cadenceId: cadence.id)
        let inRange = TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(2))
        let outOfRange = TestFactory.makeTouchEvent(personId: person.id, at: daysAgo(60))

        let vm = makeVM(people: [person], cadences: [cadence], events: [inRange, outOfRange], range: .days30)
        vm.load()

        guard case .ready(_, _, let total) = vm.snapshot?.state else {
            return XCTFail("expected .ready state, got \(String(describing: vm.snapshot?.state))")
        }
        XCTAssertEqual(total, 1)
    }
}
