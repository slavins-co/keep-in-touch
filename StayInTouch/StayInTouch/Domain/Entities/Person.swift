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

    // MARK: - Nested Config Structs
    //
    // These group the 28 construction parameters into cohesive bundles so
    // adding a field touches one struct instead of every call site. They are
    // construction-only sugar: `Person`'s stored properties remain flat and
    // unchanged, so persistence, `Equatable`, and `Hashable` are unaffected.
    // Each field's default value matches the value the old flat initializer
    // used, so a `Person` built via the new init is identical to one built via
    // the old 28-param init with the same inputs.

    /// "Who is this" core identity.
    struct Identity {
        var id: UUID
        var cnIdentifier: String?
        var displayName: String
        var nickname: String?
        var initials: String
        var avatarColor: String

        init(
            id: UUID,
            cnIdentifier: String? = nil,
            displayName: String,
            nickname: String? = nil,
            initials: String,
            avatarColor: String
        ) {
            self.id = id
            self.cnIdentifier = cnIdentifier
            self.displayName = displayName
            self.nickname = nickname
            self.initials = initials
            self.avatarColor = avatarColor
        }
    }

    /// Touch history and scheduling state.
    struct TouchState {
        var lastTouchAt: Date?
        var lastTouchMethod: TouchMethod?
        var lastTouchNotes: String?
        var nextTouchNotes: String?
        var snoozedUntil: Date?
        var customDueDate: Date?
        var cadenceAddedAt: Date?

        init(
            lastTouchAt: Date? = nil,
            lastTouchMethod: TouchMethod? = nil,
            lastTouchNotes: String? = nil,
            nextTouchNotes: String? = nil,
            snoozedUntil: Date? = nil,
            customDueDate: Date? = nil,
            cadenceAddedAt: Date? = nil
        ) {
            self.lastTouchAt = lastTouchAt
            self.lastTouchMethod = lastTouchMethod
            self.lastTouchNotes = lastTouchNotes
            self.nextTouchNotes = nextTouchNotes
            self.snoozedUntil = snoozedUntil
            self.customDueDate = customDueDate
            self.cadenceAddedAt = cadenceAddedAt
        }
    }

    /// Notification / messaging preferences.
    struct NotificationConfig {
        var notificationsMuted: Bool
        var customBreachTime: LocalTime?
        var birthdayNotificationsEnabled: Bool
        var preferredMessenger: PreferredMessenger?

        init(
            notificationsMuted: Bool,
            customBreachTime: LocalTime? = nil,
            birthdayNotificationsEnabled: Bool,
            preferredMessenger: PreferredMessenger? = nil
        ) {
            self.notificationsMuted = notificationsMuted
            self.customBreachTime = customBreachTime
            self.birthdayNotificationsEnabled = birthdayNotificationsEnabled
            self.preferredMessenger = preferredMessenger
        }
    }

    /// Bookkeeping fields.
    struct Metadata {
        var contactUnavailable: Bool
        var isDemoData: Bool
        var createdAt: Date
        var modifiedAt: Date
        var sortOrder: Int

        init(
            contactUnavailable: Bool,
            isDemoData: Bool,
            createdAt: Date,
            modifiedAt: Date,
            sortOrder: Int
        ) {
            self.contactUnavailable = contactUnavailable
            self.isDemoData = isDemoData
            self.createdAt = createdAt
            self.modifiedAt = modifiedAt
            self.sortOrder = sortOrder
        }
    }

    init(
        identity: Identity,
        cadenceId: UUID,
        groupIds: [UUID],
        isPaused: Bool,
        isTracked: Bool,
        birthday: Birthday? = nil,
        touchState: TouchState = TouchState(),
        notifications: NotificationConfig,
        metadata: Metadata
    ) {
        self.id = identity.id
        self.cnIdentifier = identity.cnIdentifier
        self.displayName = identity.displayName
        self.nickname = identity.nickname
        self.initials = identity.initials
        self.avatarColor = identity.avatarColor
        self.cadenceId = cadenceId
        self.groupIds = groupIds
        self.lastTouchAt = touchState.lastTouchAt
        self.lastTouchMethod = touchState.lastTouchMethod
        self.lastTouchNotes = touchState.lastTouchNotes
        self.nextTouchNotes = touchState.nextTouchNotes
        self.isPaused = isPaused
        self.isTracked = isTracked
        self.notificationsMuted = notifications.notificationsMuted
        self.customBreachTime = notifications.customBreachTime
        self.snoozedUntil = touchState.snoozedUntil
        self.customDueDate = touchState.customDueDate
        self.birthday = birthday
        self.birthdayNotificationsEnabled = notifications.birthdayNotificationsEnabled
        self.contactUnavailable = metadata.contactUnavailable
        self.isDemoData = metadata.isDemoData
        self.cadenceAddedAt = touchState.cadenceAddedAt
        self.createdAt = metadata.createdAt
        self.modifiedAt = metadata.modifiedAt
        self.sortOrder = metadata.sortOrder
        self.preferredMessenger = notifications.preferredMessenger
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
