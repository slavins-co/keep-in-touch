//
//  IntentTestHarness.swift
//  KeepInTouchTests
//
//  Builds an IntentContainer wired to mock repositories so the AppIntent
//  perform() paths can be exercised in unit tests without spinning up
//  Core Data.
//

import Foundation
@testable import StayInTouch

/// PersonRepository mock that lets tests stage `fetchOverdue` results
/// and matches nicknames in `searchByName`. The shared `MockPersonRepository`
/// returns [] for fetchOverdue and ignores nicknames — both insufficient
/// for intent coverage.
final class IntentTestPersonRepository: PersonRepository {
    var people: [Person] = []
    var overdue: [Person] = []
    var savedPersons: [Person] = []
    var deletedIds: [UUID] = []
    private(set) var fetchOverdueCallCount = 0
    private(set) var searchByNameCalls: [String] = []

    func fetch(id: UUID) -> Person? { people.first { $0.id == id } }
    func fetchAll() -> [Person] { people }
    func fetchTracked(includePaused: Bool) -> [Person] {
        people.filter { $0.isTracked && (includePaused || !$0.isPaused) }
    }
    func fetchByCadence(id: UUID, includePaused: Bool) -> [Person] {
        fetchTracked(includePaused: includePaused).filter { $0.cadenceId == id }
    }
    func fetchByGroup(id: UUID, includePaused: Bool) -> [Person] {
        fetchTracked(includePaused: includePaused).filter { $0.groupIds.contains(id) }
    }
    func searchByName(_ query: String, includePaused: Bool) -> [Person] {
        searchByNameCalls.append(query)
        return fetchTracked(includePaused: includePaused).filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || ($0.nickname?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    func fetchOverdue(referenceDate: Date) -> [Person] {
        fetchOverdueCallCount += 1
        return overdue
    }
    func save(_ person: Person) throws {
        savedPersons.append(person)
        if let idx = people.firstIndex(where: { $0.id == person.id }) {
            people[idx] = person
        } else {
            people.append(person)
        }
    }
    func batchSave(_ persons: [Person]) throws {
        for p in persons { try save(p) }
    }
    func delete(id: UUID) throws {
        deletedIds.append(id)
        people.removeAll { $0.id == id }
    }
    func pausedCount() -> Int { people.filter { $0.isTracked && $0.isPaused }.count }
    func snoozedCount(referenceDate: Date) -> Int { people.filter { $0.isTracked && ($0.snoozedUntil.map { $0 > referenceDate } ?? false) }.count }
}

@MainActor
final class IntentTestHarness {
    let personRepo: IntentTestPersonRepository
    let cadenceRepo: MockCadenceRepository
    let groupRepo: MockGroupRepository
    let touchRepo: MockTouchEventRepository
    let settingsRepo: MockSettingsRepository
    let container: IntentContainer

    init(
        people: [Person] = [],
        overdue: [Person] = [],
        cadences: [Cadence] = [],
        groups: [Group] = [],
        touchEvents: [TouchEvent] = []
    ) {
        let personRepo = IntentTestPersonRepository()
        personRepo.people = people
        personRepo.overdue = overdue
        let cadenceRepo = MockCadenceRepository()
        cadenceRepo.cadences = cadences
        let groupRepo = MockGroupRepository()
        groupRepo.groups = groups
        let touchRepo = MockTouchEventRepository()
        touchRepo.events = touchEvents
        let settingsRepo = MockSettingsRepository()

        let deps = AppDependencies(
            personRepository: personRepo,
            cadenceRepository: cadenceRepo,
            groupRepository: groupRepo,
            touchEventRepository: touchRepo,
            settingsRepository: settingsRepo
        )
        self.personRepo = personRepo
        self.cadenceRepo = cadenceRepo
        self.groupRepo = groupRepo
        self.touchRepo = touchRepo
        self.settingsRepo = settingsRepo
        self.container = IntentContainer.make(dependencies: deps)
        IntentContainer.install(self.container)
    }

    func tearDown() {
        IntentContainer.reset()
    }
}
