//
//  MockRepositories.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/24/26.
//

import Foundation
@testable import StayInTouch

// MARK: - MockPersonRepository

final class MockPersonRepository: PersonRepository {
    var people: [Person] = []
    var savedPersons: [Person] = []
    var deletedIds: [UUID] = []

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
        fetchTracked(includePaused: includePaused).filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }
    func fetchOverdue(referenceDate: Date) -> [Person] { [] }

    func save(_ person: Person) throws {
        savedPersons.append(person)
        if let idx = people.firstIndex(where: { $0.id == person.id }) {
            people[idx] = person
        } else {
            people.append(person)
        }
    }
    var batchSaveCallCount = 0
    func batchSave(_ persons: [Person]) throws {
        batchSaveCallCount += 1
        for person in persons {
            try save(person)
        }
    }
    func delete(id: UUID) throws {
        deletedIds.append(id)
        people.removeAll { $0.id == id }
    }
}

// MARK: - MockGroupRepository

final class MockGroupRepository: GroupRepository {
    var groups: [Group] = []

    func fetch(id: UUID) -> Group? { groups.first { $0.id == id } }
    func fetchAll() -> [Group] { groups }
    func fetchDefaultGroups() -> [Group] { groups.filter { $0.isDefault } }
    func save(_ group: Group) throws {
        if let idx = groups.firstIndex(where: { $0.id == group.id }) {
            groups[idx] = group
        } else {
            groups.append(group)
        }
    }
    func batchSave(_ groups: [Group]) throws {
        for group in groups { try save(group) }
    }
    func delete(id: UUID) throws {
        groups.removeAll { $0.id == id }
    }
}

// MARK: - MockTagRepository

final class MockTagRepository: TagRepository {
    var tags: [Tag] = []

    func fetch(id: UUID) -> Tag? { tags.first { $0.id == id } }
    func fetchAll() -> [Tag] { tags }
    func save(_ tag: Tag) throws {
        if let idx = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[idx] = tag
        } else {
            tags.append(tag)
        }
    }
    func batchSave(_ tags: [Tag]) throws {
        for tag in tags { try save(tag) }
    }
    func delete(id: UUID) throws {
        tags.removeAll { $0.id == id }
    }
}

// MARK: - MockTouchEventRepository

final class MockTouchEventRepository: TouchEventRepository {
    var events: [TouchEvent] = []
    var savedEvents: [TouchEvent] = []
    var deletedIds: [UUID] = []

    func fetch(id: UUID) -> TouchEvent? { events.first { $0.id == id } }
    func fetchAll(for personId: UUID) -> [TouchEvent] {
        events.filter { $0.personId == personId }
    }
    func fetchMostRecent(for personId: UUID) -> TouchEvent? {
        events.filter { $0.personId == personId }
            .sorted { $0.at > $1.at }
            .first
    }
    func save(_ touchEvent: TouchEvent) throws {
        savedEvents.append(touchEvent)
        if let idx = events.firstIndex(where: { $0.id == touchEvent.id }) {
            events[idx] = touchEvent
        } else {
            events.append(touchEvent)
        }
    }
    func batchSave(_ touchEvents: [TouchEvent]) throws {
        for event in touchEvents {
            try save(event)
        }
    }
    func delete(id: UUID) throws {
        deletedIds.append(id)
        events.removeAll { $0.id == id }
    }
}

// MARK: - MockSettingsRepository

final class MockSettingsRepository: AppSettingsRepository {
    var settings: AppSettings?
    var saveCount = 0

    func fetch() -> AppSettings? { settings }
    func save(_ settings: AppSettings) throws {
        self.settings = settings
        saveCount += 1
    }
}

// MARK: - TestFactory

enum TestFactory {
    static func makePerson(
        id: UUID = UUID(),
        name: String = "Test Person",
        groupId: UUID = UUID(),
        tagIds: [UUID] = [],
        lastTouchAt: Date? = nil,
        lastTouchMethod: TouchMethod? = nil,
        lastTouchNotes: String? = nil,
        isPaused: Bool = false,
        isTracked: Bool = true,
        snoozedUntil: Date? = nil,
        customDueDate: Date? = nil,
        birthday: Birthday? = nil,
        birthdayNotificationsEnabled: Bool = true,
        cnIdentifier: String? = nil
    ) -> Person {
        Person(
            id: id,
            cnIdentifier: cnIdentifier,
            displayName: name,
            initials: String(name.prefix(2)),
            avatarColor: "#FF6B6B",
            groupId: groupId,
            tagIds: tagIds,
            lastTouchAt: lastTouchAt,
            lastTouchMethod: lastTouchMethod,
            lastTouchNotes: lastTouchNotes,
            nextTouchNotes: nil,
            isPaused: isPaused,
            isTracked: isTracked,
            notificationsMuted: false,
            customBreachTime: nil,
            snoozedUntil: snoozedUntil,
            customDueDate: customDueDate,
            birthday: birthday,
            birthdayNotificationsEnabled: birthdayNotificationsEnabled,
            contactUnavailable: false,
            isDemoData: false,
            groupAddedAt: Date(),
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
    }

    static func makeGroup(
        id: UUID = UUID(),
        name: String = "Weekly",
        frequencyDays: Int = 7,
        isDefault: Bool = true
    ) -> Group {
        Group(
            id: id,
            name: name,
            frequencyDays: frequencyDays,
            warningDays: 2,
            colorHex: nil,
            isDefault: isDefault,
            sortOrder: 0,
            createdAt: Date(),
            modifiedAt: Date()
        )
    }

    static func makeTag(
        id: UUID = UUID(),
        name: String = "Work"
    ) -> Tag {
        Tag(
            id: id,
            name: name,
            colorHex: "#0A84FF",
            sortOrder: 0,
            createdAt: Date(),
            modifiedAt: Date()
        )
    }

    static func makeTouchEvent(
        id: UUID = UUID(),
        personId: UUID,
        at: Date = Date(),
        method: TouchMethod = .call,
        notes: String? = nil,
        timeOfDay: TimeOfDay? = nil
    ) -> TouchEvent {
        TouchEvent(
            id: id,
            personId: personId,
            at: at,
            method: method,
            notes: notes,
            timeOfDay: timeOfDay,
            createdAt: at,
            modifiedAt: at
        )
    }

    static func makeSettings(
        onboardingCompleted: Bool = false,
        demoModeEnabled: Bool = false,
        theme: Theme = .system,
        birthdayNotificationsEnabled: Bool = false,
        birthdayNotificationTime: LocalTime = LocalTime(hour: 9, minute: 0),
        birthdayIgnoreSnoozePause: Bool = true
    ) -> AppSettings {
        AppSettings(
            id: AppSettings.singletonId,
            theme: theme,
            notificationsEnabled: false,
            breachTimeOfDay: LocalTime(hour: 18, minute: 0),
            digestEnabled: false,
            digestDay: .friday,
            digestTime: LocalTime(hour: 18, minute: 0),
            notificationGrouping: .perType,
            badgeCountShowDueSoon: false,
            dueSoonWindowDays: 3,
            demoModeEnabled: demoModeEnabled,
            analyticsEnabled: true,
            hideContactNamesInNotifications: false,
            birthdayNotificationsEnabled: birthdayNotificationsEnabled,
            birthdayNotificationTime: birthdayNotificationTime,
            birthdayIgnoreSnoozePause: birthdayIgnoreSnoozePause,
            lastContactsSyncAt: nil,
            onboardingCompleted: onboardingCompleted,
            appVersion: ""
        )
    }
}
