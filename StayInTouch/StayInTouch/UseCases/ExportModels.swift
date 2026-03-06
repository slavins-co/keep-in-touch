//
//  ExportModels.swift
//  KeepInTouch
//
//  Shared data structures for import/export services.
//

import Foundation

// MARK: - Export Structs

struct ExportGroup: Codable {
    let id: UUID
    let name: String
    let frequencyDays: Int
    let warningDays: Int
    let colorHex: String?
    let sortOrder: Int
    let isDefault: Bool

    static func from(_ group: Group) -> ExportGroup {
        ExportGroup(
            id: group.id,
            name: group.name,
            frequencyDays: group.frequencyDays,
            warningDays: group.warningDays,
            colorHex: group.colorHex,
            sortOrder: group.sortOrder,
            isDefault: group.isDefault
        )
    }
}

struct ExportTag: Codable {
    let id: UUID
    let name: String
    let colorHex: String
    let sortOrder: Int

    static func from(_ tag: Tag) -> ExportTag {
        ExportTag(
            id: tag.id,
            name: tag.name,
            colorHex: tag.colorHex,
            sortOrder: tag.sortOrder
        )
    }
}

struct ExportData: Codable {
    let version: Int
    let exportedAt: Date
    let groups: [ExportGroup]
    let tags: [ExportTag]
    let people: [ExportPerson]
}

struct ExportTouchEvent: Codable {
    let id: UUID
    let at: Date
    let method: String
    let notes: String?

    static func from(_ event: TouchEvent) -> ExportTouchEvent {
        ExportTouchEvent(
            id: event.id,
            at: event.at,
            method: event.method.rawValue,
            notes: event.notes
        )
    }
}

struct ExportPerson: Codable {
    let id: UUID
    let displayName: String
    let groupId: UUID?
    let groupName: String?
    let tagIds: [UUID]
    let tagNames: [String]
    let lastTouchAt: Date?
    let isPaused: Bool
    let createdAt: Date
    let modifiedAt: Date
    let touchEvents: [ExportTouchEvent]?
    let birthday: String?

    static func from(_ person: Person, groupName: String?, tagNames: [String], touchEvents: [TouchEvent]) -> ExportPerson {
        let exportEvents: [ExportTouchEvent]? = touchEvents.isEmpty ? nil : touchEvents.map { ExportTouchEvent.from($0) }
        return ExportPerson(
            id: person.id,
            displayName: person.displayName,
            groupId: person.groupId,
            groupName: groupName,
            tagIds: person.tagIds,
            tagNames: tagNames,
            lastTouchAt: person.lastTouchAt,
            isPaused: person.isPaused,
            createdAt: person.createdAt,
            modifiedAt: person.modifiedAt,
            touchEvents: exportEvents,
            birthday: person.birthday?.toJsonString()
        )
    }
}

// MARK: - Import Structs

struct ImportPreview {
    let newPeople: [ExportPerson]
    let updatedPeople: [ExportPerson]
    let skippedCount: Int
    let touchEventCount: Int
    /// Number of touch events that are genuinely new (not already in the database)
    let newTouchEventCount: Int
    let newGroups: [ExportGroup]
    let newTags: [ExportTag]
    let groupIdMap: [UUID: UUID]
    let tagIdMap: [UUID: UUID]
    /// Maps export person UUID → existing tracked Person UUID (auto-matched via address book or name)
    var remappedIds: [UUID: UUID]
    /// Imported people that matched multiple tracked contacts — user must disambiguate
    let ambiguousPeople: [(export: ExportPerson, candidates: [Person])]

    var totalPeople: Int { newPeople.count + updatedPeople.count + ambiguousPeople.count }
    var isEmpty: Bool { newPeople.isEmpty && updatedPeople.isEmpty && ambiguousPeople.isEmpty && newGroups.isEmpty && newTags.isEmpty }
}

struct ImportResult {
    let importedPeople: [(id: UUID, displayName: String)]
    let totalPeople: Int
    let groupsCreated: Int
    let tagsCreated: Int
}

struct ContactMatchSummary {
    let matched: Int
    let unmatchedPeople: [(id: UUID, displayName: String)]
    let total: Int
    let matchedNames: [String]
}

// MARK: - Settings Defaults

struct AppSettingsDefaults {
    static func defaultSettings() -> AppSettings {
        AppSettings(
            id: AppSettings.singletonId,
            theme: .system,
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
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        )
    }
}
