//
//  AppSettings.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

struct AppSettings: Identifiable, Equatable {
    static let singletonId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    let id: UUID

    var theme: Theme

    var notificationsEnabled: Bool
    var breachTimeOfDay: LocalTime
    var digestEnabled: Bool
    var digestDay: DayOfWeek
    var digestTime: LocalTime
    var notificationGrouping: NotificationGrouping
    var badgeCountShowDueSoon: Bool
    var dueSoonWindowDays: Int

    var demoModeEnabled: Bool
    var analyticsEnabled: Bool
    var hideContactNamesInNotifications: Bool
    var birthdayNotificationsEnabled: Bool
    var birthdayNotificationTime: LocalTime
    var birthdayIgnoreSnoozePause: Bool

    /// When true, the home-screen widget back-fills empty space with
    /// upcoming birthdays once the overdue/due-soon list no longer fills it.
    /// Defaulted so existing `AppSettings(...)` call sites are unaffected.
    var birthdaysFillWidget: Bool = true

    var lastContactsSyncAt: Date?
    var onboardingCompleted: Bool
    var appVersion: String

    var tutorialCompleted: Bool = false
    var tutorialVersion: String? = nil
    var lastSeenAppVersion: String? = nil
}
