//
//  PersonEntity+Mapping.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

extension PersonEntity {
    func toDomain() -> Person {
        Person(
            id: id ?? UUID(),
            cnIdentifier: cnIdentifier,
            displayName: displayName ?? "",
            initials: initials ?? "",
            avatarColor: avatarColor ?? "",
            groupId: groupId ?? UUID(),
            tagIds: decodeTagIds(tagIds),
            lastTouchAt: lastTouchAt,
            lastTouchMethod: lastTouchMethod.flatMap(TouchMethod.init(rawValue:)),
            lastTouchNotes: lastTouchNotes,
            isPaused: isPaused,
            isTracked: isTracked,
            notificationsMuted: notificationsMuted,
            customBreachTime: customBreachTime.flatMap(LocalTime.from(jsonString:)),
            groupAddedAt: groupAddedAt,
            createdAt: createdAt ?? Date(),
            modifiedAt: modifiedAt ?? Date(),
            sortOrder: Int(sortOrder)
        )
    }

    func apply(_ person: Person) {
        id = person.id
        cnIdentifier = person.cnIdentifier
        displayName = person.displayName
        initials = person.initials
        avatarColor = person.avatarColor
        groupId = person.groupId
        tagIds = person.tagIds as NSArray
        lastTouchAt = person.lastTouchAt
        lastTouchMethod = person.lastTouchMethod?.rawValue
        lastTouchNotes = person.lastTouchNotes
        isPaused = person.isPaused
        isTracked = person.isTracked
        notificationsMuted = person.notificationsMuted
        customBreachTime = person.customBreachTime?.toJsonString()
        groupAddedAt = person.groupAddedAt
        createdAt = person.createdAt
        modifiedAt = person.modifiedAt
        sortOrder = Int64(person.sortOrder)
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
