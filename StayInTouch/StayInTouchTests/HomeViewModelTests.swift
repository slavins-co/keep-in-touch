//
//  HomeViewModelTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testFilterMatchesNameAndGroup() {
        let cadenceId = UUID()
        let groupId = UUID()

        let people = [
            makePerson(name: "Sarah Chen", cadenceId: cadenceId, groupIds: [groupId]),
            makePerson(name: "Mike", cadenceId: cadenceId, groupIds: [])
        ]
        let groups = [Group(id: groupId, name: "Work", colorHex: "#0A84FF", sortOrder: 0, createdAt: Date(), modifiedAt: Date())]

        let filtered = HomeViewModel.filterPeople(
            people: people,
            cadences: [makeCadence(id: cadenceId)],
            groups: groups,
            selectedCadenceId: nil,
            selectedGroupId: nil,
            searchText: "work"
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.displayName, "Sarah Chen")
    }

    func testRefreshFromContacts_setsIsRefreshingFalseAfterCompletion() async {
        let vm = HomeViewModel(
            personRepository: InMemoryPersonRepository(people: []),
            cadenceRepository: InMemoryCadenceRepository(cadences: []),
            groupRepository: InMemoryGroupRepository(groups: []),
            settingsRepository: InMemorySettingsRepository()
        )
        XCTAssertFalse(vm.isRefreshing, "isRefreshing should start false")

        await vm.refreshFromContacts()

        XCTAssertFalse(vm.isRefreshing, "isRefreshing should be false after refresh completes")
    }

    func testLoadUpdatesRefreshToken() {
        let vm = HomeViewModel(
            personRepository: InMemoryPersonRepository(people: []),
            cadenceRepository: InMemoryCadenceRepository(cadences: []),
            groupRepository: InMemoryGroupRepository(groups: []),
            settingsRepository: InMemorySettingsRepository()
        )
        let oldToken = vm.refreshToken
        vm.load()
        XCTAssertNotEqual(vm.refreshToken, oldToken, "load() must update refreshToken to force LazyVStack rebuild")
    }

    func testFilterByCadence() {
        let cadenceA = UUID()
        let cadenceB = UUID()
        let people = [
            makePerson(name: "A", cadenceId: cadenceA, groupIds: []),
            makePerson(name: "B", cadenceId: cadenceB, groupIds: [])
        ]

        let filtered = HomeViewModel.filterPeople(
            people: people,
            cadences: [makeCadence(id: cadenceA), makeCadence(id: cadenceB)],
            groups: [],
            selectedCadenceId: cadenceA,
            selectedGroupId: nil,
            searchText: ""
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.displayName, "A")
    }

    private func makePerson(name: String, cadenceId: UUID, groupIds: [UUID]) -> Person {
        Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: name,
            initials: String(name.prefix(2)),
            avatarColor: "#FF6B6B",
            cadenceId: cadenceId,
            groupIds: groupIds,
            lastTouchAt: nil,
            lastTouchMethod: nil,
            lastTouchNotes: nil,
            nextTouchNotes: nil,
            isPaused: false,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            snoozedUntil: nil,
            customDueDate: nil,
            birthday: nil,
            birthdayNotificationsEnabled: true,
            contactUnavailable: false,
            isDemoData: false,
            cadenceAddedAt: Date(),
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
    }

    private func makeCadence(id: UUID) -> Cadence {
        Cadence(
            id: id,
            name: "Weekly",
            frequencyDays: 7,
            warningDays: 2,
            colorHex: nil,
            isDefault: true,
            sortOrder: 0,
            createdAt: Date(),
            modifiedAt: Date()
        )
    }

    private struct InMemoryPersonRepository: PersonRepository {
        let people: [Person]
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
            fetchTracked(includePaused: includePaused).filter { $0.displayName.localizedCaseInsensitiveContains(query) }
        }
        func fetchOverdue(referenceDate: Date) -> [Person] { [] }
        func save(_ person: Person) throws {}
        func batchSave(_ persons: [Person]) throws {}
        func delete(id: UUID) throws {}
    }

    private struct InMemoryCadenceRepository: CadenceRepository {
        let cadences: [Cadence]
        func fetch(id: UUID) -> Cadence? { cadences.first { $0.id == id } }
        func fetchAll() -> [Cadence] { cadences }
        func fetchDefaultGroups() -> [Cadence] { cadences.filter { $0.isDefault } }
        func save(_ group: Cadence) throws {}
        func batchSave(_ groups: [Cadence]) throws {}
        func delete(id: UUID) throws {}
    }

    private struct InMemoryGroupRepository: GroupRepository {
        let groups: [Group]
        func fetch(id: UUID) -> Group? { groups.first { $0.id == id } }
        func fetchAll() -> [Group] { groups }
        func save(_ group: Group) throws {}
        func batchSave(_ groups: [Group]) throws {}
        func delete(id: UUID) throws {}
    }

    private struct InMemorySettingsRepository: AppSettingsRepository {
        func fetch() -> AppSettings? {
            AppSettings(
                id: AppSettings.singletonId,
                theme: .light,
                notificationsEnabled: false,
                breachTimeOfDay: LocalTime(hour: 18, minute: 0),
                digestEnabled: false,
                digestDay: .friday,
                digestTime: LocalTime(hour: 18, minute: 0),
                notificationGrouping: .perType,
                badgeCountShowDueSoon: false,
                dueSoonWindowDays: 3,
                demoModeEnabled: false,
                analyticsEnabled: true,
                hideContactNamesInNotifications: false,
                birthdayNotificationsEnabled: false,
                birthdayNotificationTime: LocalTime(hour: 9, minute: 0),
                birthdayIgnoreSnoozePause: true,
                lastContactsSyncAt: nil,
                onboardingCompleted: false,
                appVersion: ""
            )
        }
        func save(_ settings: AppSettings) throws {}
    }
}
