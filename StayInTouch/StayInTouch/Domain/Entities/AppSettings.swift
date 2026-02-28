//
//  AppSettings.swift
//  StayInTouch
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

    var lastContactsSyncAt: Date?
    var onboardingCompleted: Bool
    var appVersion: String
}
