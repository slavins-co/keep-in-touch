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
    var nickname: String?
    var initials: String
    var avatarColor: String

    var cadenceId: UUID
    var groupIds: [UUID]

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

    /// Nickname to display in UI. Returns nil when the stored nickname is
    /// absent, empty/whitespace, or equals `displayName` (trimmed, case-insensitive)
    /// so contacts whose Contacts-app nickname echoes their first name don't
    /// render a duplicate.
    var displayNickname: String? {
        guard let raw = nickname?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              raw.caseInsensitiveCompare(displayName.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame
        else { return nil }
        return raw
    }
}
