//
//  PersonEntity+Mapping.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

extension PersonEntity {
    func toDomain() -> Person {
        Person(
            id: requiredField(id, entity: "PersonEntity", field: "id", fallback: UUID()),
            cnIdentifier: cnIdentifier,
            displayName: requiredField(displayName, entity: "PersonEntity", field: "displayName", fallback: ""),
            initials: requiredField(initials, entity: "PersonEntity", field: "initials", fallback: ""),
            avatarColor: requiredField(avatarColor, entity: "PersonEntity", field: "avatarColor", fallback: ""),
            cadenceId: requiredField(groupId, entity: "PersonEntity", field: "groupId", fallback: UUID()),
            tagIds: decodeTagIds(tagIds),
            lastTouchAt: lastTouchAt,
            lastTouchMethod: lastTouchMethod.flatMap(TouchMethod.init(rawValue:)),
            lastTouchNotes: lastTouchNotes,
            nextTouchNotes: nextTouchNotes,
            isPaused: isPaused,
            isTracked: isTracked,
            notificationsMuted: notificationsMuted,
            customBreachTime: customBreachTime.flatMap(LocalTime.from(jsonString:)),
            snoozedUntil: snoozedUntil,
            customDueDate: customDueDate,
            birthday: birthday.flatMap(Birthday.from(jsonString:)),
            birthdayNotificationsEnabled: birthdayNotificationsEnabled,
            contactUnavailable: contactUnavailable,
            isDemoData: isDemoData,
            cadenceAddedAt: groupAddedAt,
            createdAt: requiredField(createdAt, entity: "PersonEntity", field: "createdAt", fallback: Date()),
            modifiedAt: requiredField(modifiedAt, entity: "PersonEntity", field: "modifiedAt", fallback: Date()),
            sortOrder: Int(sortOrder)
        )
    }

    func apply(_ person: Person) {
        id = person.id
        cnIdentifier = person.cnIdentifier
        displayName = person.displayName
        initials = person.initials
        avatarColor = person.avatarColor
        groupId = person.cadenceId
        tagIds = person.tagIds as NSArray
        lastTouchAt = person.lastTouchAt
        lastTouchMethod = person.lastTouchMethod?.rawValue
        lastTouchNotes = person.lastTouchNotes
        nextTouchNotes = person.nextTouchNotes
        isPaused = person.isPaused
        isTracked = person.isTracked
        notificationsMuted = person.notificationsMuted
        customBreachTime = person.customBreachTime?.toJsonString()
        snoozedUntil = person.snoozedUntil
        customDueDate = person.customDueDate
        birthday = person.birthday?.toJsonString()
        birthdayNotificationsEnabled = person.birthdayNotificationsEnabled
        contactUnavailable = person.contactUnavailable
        isDemoData = person.isDemoData
        groupAddedAt = person.cadenceAddedAt
        createdAt = person.createdAt
        modifiedAt = person.modifiedAt
        sortOrder = Int64(person.sortOrder)
    }

    /// Returns `value` if non-nil; otherwise logs a data-corruption warning and returns the fallback.
    private func requiredField<T>(_ value: T?, entity: String, field: String, fallback: @autoclosure () -> T) -> T {
        guard let value else {
            AppLogger.logWarning("\(entity) has nil required field '\(field)' — possible data corruption", category: AppLogger.coreData)
            return fallback()
        }
        return value
    }

    private func decodeTagIds(_ value: Any?) -> [UUID] {
        guard let value else { return [] }

        if let ids = value as? [UUID] { return ids }
        if let ids = value as? [NSUUID] { return ids.compactMap { UUID(uuidString: $0.uuidString) } }
        if let ids = value as? [String] { return ids.compactMap(UUID.init(uuidString:)) }
        if let ids = value as? [Any] {
            return ids.compactMap { element in
                if let uuid = element as? UUID { return uuid }
                if let nsuuid = element as? NSUUID { return UUID(uuidString: nsuuid.uuidString) }
                if let string = element as? String { return UUID(uuidString: string) }
                return nil
            }
        }
        return []
    }
}
