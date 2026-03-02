//
//  HomeViewModelTests.swift
//  StayInTouchTests
//
//  Created by Codex on 2/2/26.
//

import XCTest
@testable import StayInTouch

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testFilterMatchesNameAndTag() {
        let groupId = UUID()
        let tagId = UUID()

        let people = [
            makePerson(name: "Sarah Chen", groupId: groupId, tagIds: [tagId]),
            makePerson(name: "Mike", groupId: groupId, tagIds: [])
        ]
        let tags = [Tag(id: tagId, name: "Work", colorHex: "#0A84FF", sortOrder: 0, createdAt: Date(), modifiedAt: Date())]

        let filtered = HomeViewModel.filterPeople(
            people: people,
            groups: [makeGroup(id: groupId)],
            tags: tags,
            selectedGroupId: nil,
            selectedTagId: nil,
            searchText: "work"
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.displayName, "Sarah Chen")
    }

    func testFilterByGroup() {
        let groupA = UUID()
        let groupB = UUID()
        let people = [
            makePerson(name: "A", groupId: groupA, tagIds: []),
            makePerson(name: "B", groupId: groupB, tagIds: [])
        ]

        let filtered = HomeViewModel.filterPeople(
            people: people,
            groups: [makeGroup(id: groupA), makeGroup(id: groupB)],
            tags: [],
            selectedGroupId: groupA,
            selectedTagId: nil,
            searchText: ""
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.displayName, "A")
    }

    func testNameSortFlattensAcrossStatuses() {
        let groupId = UUID()
        let people = [
            makePerson(name: "Zoe", groupId: groupId, tagIds: []),
            makePerson(name: "Amy", groupId: groupId, tagIds: [])
        ]
        let viewModel = HomeViewModel(
            personRepository: InMemoryPersonRepository(people: people),
            groupRepository: InMemoryGroupRepository(groups: [makeGroup(id: groupId)]),
            tagRepository: InMemoryTagRepository(tags: []),
            settingsRepository: InMemorySettingsRepository()
        )

        viewModel.sortOption = .name
        viewModel.applyFilters()

        XCTAssertEqual(viewModel.nameSortedPeople.map { $0.displayName }, ["Amy", "Zoe"])
    }

    private func makePerson(name: String, groupId: UUID, tagIds: [UUID]) -> Person {
        Person(
            id: UUID(),
            cnIdentifier: nil,
            displayName: name,
            initials: String(name.prefix(2)),
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: tagIds,
            lastTouchAt: nil,
            lastTouchMethod: nil,
            lastTouchNotes: nil,
            nextTouchNotes: nil,
            isPaused: false,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            snoozedUntil: nil,
            birthday: nil,
            contactUnavailable: false,
            isDemoData: false,
            groupAddedAt: Date(),
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
    }

    private func makeGroup(id: UUID) -> Group {
        Group(
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
        func fetchByGroup(id: UUID, includePaused: Bool) -> [Person] {
            fetchTracked(includePaused: includePaused).filter { $0.groupId == id }
        }
        func fetchByTag(id: UUID, includePaused: Bool) -> [Person] {
            fetchTracked(includePaused: includePaused).filter { $0.tagIds.contains(id) }
        }
        func searchByName(_ query: String, includePaused: Bool) -> [Person] {
            fetchTracked(includePaused: includePaused).filter { $0.displayName.localizedCaseInsensitiveContains(query) }
        }
        func fetchOverdue(referenceDate: Date) -> [Person] { [] }
        func save(_ person: Person) throws {}
        func batchSave(_ persons: [Person]) throws {}
        func delete(id: UUID) throws {}
    }

    private struct InMemoryGroupRepository: GroupRepository {
        let groups: [Group]
        func fetch(id: UUID) -> Group? { groups.first { $0.id == id } }
        func fetchAll() -> [Group] { groups }
        func fetchDefaultGroups() -> [Group] { groups.filter { $0.isDefault } }
        func save(_ group: Group) throws {}
        func delete(id: UUID) throws {}
    }

    private struct InMemoryTagRepository: TagRepository {
        let tags: [Tag]
        func fetch(id: UUID) -> Tag? { tags.first { $0.id == id } }
        func fetchAll() -> [Tag] { tags }
        func save(_ tag: Tag) throws {}
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
                lastContactsSyncAt: nil,
                onboardingCompleted: false,
                appVersion: ""
            )
        }
        func save(_ settings: AppSettings) throws {}
    }
}
