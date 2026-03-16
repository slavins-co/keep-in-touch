//
//  Person.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct Person: Identifiable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: UUID
    var cnIdentifier: String?
    var displayName: String
    var initials: String
    var avatarColor: String

    var cadenceId: UUID
    var tagIds: [UUID]

    var lastTouchAt: Date?
    var lastTouchMethod: TouchMethod?
    var lastTouchNotes: String?
    var nextTouchNotes: String?

    var isPaused: Bool
    var isTracked: Bool

    var notificationsMuted: Bool
    var customBreachTime: LocalTime?
    var snoozedUntil: Date?
    var customDueDate: Date?
    var birthday: Birthday?
    var birthdayNotificationsEnabled: Bool

    var contactUnavailable: Bool
    var isDemoData: Bool

    var cadenceAddedAt: Date?

    var createdAt: Date
    var modifiedAt: Date
    var sortOrder: Int
}
