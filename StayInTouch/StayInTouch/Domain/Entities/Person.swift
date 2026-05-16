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

    /// User's chosen messenger app for the Message quick action.
    /// `nil` means use the app-wide default (iMessage in v1).
    /// We persist `nil` for "iMessage" so a future global-default
    /// setting can flip behavior without per-row migration.
    var preferredMessenger: PreferredMessenger?

    init(
        id: UUID,
        cnIdentifier: String? = nil,
        displayName: String,
        nickname: String? = nil,
        initials: String,
        avatarColor: String,
        cadenceId: UUID,
        groupIds: [UUID],
        lastTouchAt: Date? = nil,
        lastTouchMethod: TouchMethod? = nil,
        lastTouchNotes: String? = nil,
        nextTouchNotes: String? = nil,
        isPaused: Bool,
        isTracked: Bool,
        notificationsMuted: Bool,
        customBreachTime: LocalTime? = nil,
        snoozedUntil: Date? = nil,
        customDueDate: Date? = nil,
        birthday: Birthday? = nil,
        birthdayNotificationsEnabled: Bool,
        contactUnavailable: Bool,
        isDemoData: Bool,
        cadenceAddedAt: Date? = nil,
        createdAt: Date,
        modifiedAt: Date,
        sortOrder: Int,
        preferredMessenger: PreferredMessenger? = nil
    ) {
        self.id = id
        self.cnIdentifier = cnIdentifier
        self.displayName = displayName
        self.nickname = nickname
        self.initials = initials
        self.avatarColor = avatarColor
        self.cadenceId = cadenceId
        self.groupIds = groupIds
        self.lastTouchAt = lastTouchAt
        self.lastTouchMethod = lastTouchMethod
        self.lastTouchNotes = lastTouchNotes
        self.nextTouchNotes = nextTouchNotes
        self.isPaused = isPaused
        self.isTracked = isTracked
        self.notificationsMuted = notificationsMuted
        self.customBreachTime = customBreachTime
        self.snoozedUntil = snoozedUntil
        self.customDueDate = customDueDate
        self.birthday = birthday
        self.birthdayNotificationsEnabled = birthdayNotificationsEnabled
        self.contactUnavailable = contactUnavailable
        self.isDemoData = isDemoData
        self.cadenceAddedAt = cadenceAddedAt
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.sortOrder = sortOrder
        self.preferredMessenger = preferredMessenger
    }

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
