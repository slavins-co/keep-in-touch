//
//  ExportModels.swift
//  KeepInTouch
//
//  Shared data structures for import/export services.
//

import Foundation

// MARK: - Export Structs

struct ExportCadence: Codable {
    let id: UUID
    let name: String
    let frequencyDays: Int
    let warningDays: Int
    let colorHex: String?
    let sortOrder: Int
    let isDefault: Bool

    static func from(_ group: Cadence) -> ExportCadence {
        ExportCadence(
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

struct ExportGroup: Codable {
    let id: UUID
    let name: String
    let colorHex: String
    let sortOrder: Int

    static func from(_ group: Group) -> ExportGroup {
        ExportGroup(
            id: group.id,
            name: group.name,
            colorHex: group.colorHex,
            sortOrder: group.sortOrder
        )
    }
}

struct ExportData: Codable {
    let version: Int
    let exportedAt: Date
    let cadences: [ExportCadence]
    let groups: [ExportGroup]
    let people: [ExportPerson]

    private enum CodingKeys: String, CodingKey {
        case version, exportedAt, cadences, groups, tags, people
    }

    init(version: Int, exportedAt: Date, cadences: [ExportCadence], groups: [ExportGroup], people: [ExportPerson]) {
        self.version = version
        self.exportedAt = exportedAt
        self.cadences = cadences
        self.groups = groups
        self.people = people
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        people = try c.decode([ExportPerson].self, forKey: .people)

        // Try new format first ("cadences" + "groups"), fall back to old format ("groups" + "tags")
        if let cad = try? c.decode([ExportCadence].self, forKey: .cadences) {
            cadences = cad
            groups = (try? c.decode([ExportGroup].self, forKey: .groups)) ?? []
        } else {
            // Old format: "groups" key held cadences, "tags" key held groups
            cadences = (try? c.decode([ExportCadence].self, forKey: .groups)) ?? []
            groups = (try? c.decode([ExportGroup].self, forKey: .tags)) ?? []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(exportedAt, forKey: .exportedAt)
        try c.encode(cadences, forKey: .cadences)
        try c.encode(groups, forKey: .groups)
        try c.encode(people, forKey: .people)
    }
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
    let cadenceId: UUID?
    let cadenceName: String?
    let groupIds: [UUID]
    let groupNames: [String]
    let lastTouchAt: Date?
    let isPaused: Bool
    let createdAt: Date
    let modifiedAt: Date
    let touchEvents: [ExportTouchEvent]?
    let birthday: String?
    let birthdayNotificationsEnabled: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, displayName, cadenceId, cadenceName, groupIds, groupNames
        case lastTouchAt, isPaused, createdAt, modifiedAt, touchEvents, birthday, birthdayNotificationsEnabled
        // Legacy keys for backward compat
        case legacyGroupId = "groupId"
        case legacyGroupName = "groupName"
        case legacyTagIds = "tagIds"
        case legacyTagNames = "tagNames"
    }

    init(id: UUID, displayName: String, cadenceId: UUID?, cadenceName: String?, groupIds: [UUID], groupNames: [String], lastTouchAt: Date?, isPaused: Bool, createdAt: Date, modifiedAt: Date, touchEvents: [ExportTouchEvent]?, birthday: String?, birthdayNotificationsEnabled: Bool?) {
        self.id = id; self.displayName = displayName; self.cadenceId = cadenceId; self.cadenceName = cadenceName
        self.groupIds = groupIds; self.groupNames = groupNames; self.lastTouchAt = lastTouchAt; self.isPaused = isPaused
        self.createdAt = createdAt; self.modifiedAt = modifiedAt; self.touchEvents = touchEvents
        self.birthday = birthday; self.birthdayNotificationsEnabled = birthdayNotificationsEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        cadenceId = (try? c.decode(UUID.self, forKey: .cadenceId)) ?? (try? c.decode(UUID.self, forKey: .legacyGroupId))
        cadenceName = (try? c.decode(String.self, forKey: .cadenceName)) ?? (try? c.decode(String.self, forKey: .legacyGroupName))
        groupIds = (try? c.decode([UUID].self, forKey: .groupIds)) ?? (try? c.decode([UUID].self, forKey: .legacyTagIds)) ?? []
        groupNames = (try? c.decode([String].self, forKey: .groupNames)) ?? (try? c.decode([String].self, forKey: .legacyTagNames)) ?? []
        lastTouchAt = try? c.decode(Date.self, forKey: .lastTouchAt)
        isPaused = (try? c.decode(Bool.self, forKey: .isPaused)) ?? false
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        modifiedAt = try c.decode(Date.self, forKey: .modifiedAt)
        touchEvents = try? c.decode([ExportTouchEvent].self, forKey: .touchEvents)
        birthday = try? c.decode(String.self, forKey: .birthday)
        birthdayNotificationsEnabled = try? c.decode(Bool.self, forKey: .birthdayNotificationsEnabled)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(displayName, forKey: .displayName)
        try c.encodeIfPresent(cadenceId, forKey: .cadenceId)
        try c.encodeIfPresent(cadenceName, forKey: .cadenceName)
        try c.encode(groupIds, forKey: .groupIds)
        try c.encode(groupNames, forKey: .groupNames)
        try c.encodeIfPresent(lastTouchAt, forKey: .lastTouchAt)
        try c.encode(isPaused, forKey: .isPaused)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(modifiedAt, forKey: .modifiedAt)
        try c.encodeIfPresent(touchEvents, forKey: .touchEvents)
        try c.encodeIfPresent(birthday, forKey: .birthday)
        try c.encodeIfPresent(birthdayNotificationsEnabled, forKey: .birthdayNotificationsEnabled)
    }

    static func from(_ person: Person, cadenceName: String?, groupNames: [String], touchEvents: [TouchEvent]) -> ExportPerson {
        let exportEvents: [ExportTouchEvent]? = touchEvents.isEmpty ? nil : touchEvents.map { ExportTouchEvent.from($0) }
        return ExportPerson(
            id: person.id,
            displayName: person.displayName,
            cadenceId: person.cadenceId,
            cadenceName: cadenceName,
            groupIds: person.groupIds,
            groupNames: groupNames,
            lastTouchAt: person.lastTouchAt,
            isPaused: person.isPaused,
            createdAt: person.createdAt,
            modifiedAt: person.modifiedAt,
            touchEvents: exportEvents,
            birthday: person.birthday?.toJsonString(),
            birthdayNotificationsEnabled: person.birthdayNotificationsEnabled
        )
    }
}

// MARK: - Import Structs

struct ImportPreview: Identifiable {
    let id = UUID()
    let newPeople: [ExportPerson]
    let updatedPeople: [ExportPerson]
    let skippedCount: Int
    let touchEventCount: Int
    /// Number of touch events that are genuinely new (not already in the database)
    let newTouchEventCount: Int
    let newCadences: [ExportCadence]
    let newGroups: [ExportGroup]
    let cadenceIdMap: [UUID: UUID]
    let groupIdMap: [UUID: UUID]
    /// Maps export person UUID -> existing tracked Person UUID (auto-matched via address book or name)
    var remappedIds: [UUID: UUID]
    /// Imported people that matched multiple tracked contacts -- user must disambiguate
    let ambiguousPeople: [(export: ExportPerson, candidates: [Person])]

    var totalPeople: Int { newPeople.count + updatedPeople.count + ambiguousPeople.count }
    var isEmpty: Bool { newPeople.isEmpty && updatedPeople.isEmpty && ambiguousPeople.isEmpty && newCadences.isEmpty && newGroups.isEmpty }
}

struct ImportResult {
    let importedPeople: [(id: UUID, displayName: String)]
    let totalPeople: Int
    let cadencesCreated: Int
    let groupsCreated: Int
}

struct ContactMatchSummary {
    let matched: Int
    let unmatchedPeople: [(id: UUID, displayName: String)]
    let total: Int
    let matchedNames: [String]
}
