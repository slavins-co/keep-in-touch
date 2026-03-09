//
//  AppSettingsEntity+Mapping.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

extension AppSettingsEntity {
    func toDomain() -> AppSettings {
        AppSettings(
            id: id ?? AppSettings.singletonId,
            theme: Theme(rawValue: theme ?? Theme.system.rawValue) ?? .system,
            notificationsEnabled: notificationsEnabled,
            breachTimeOfDay: breachTimeOfDay.flatMap(LocalTime.from(jsonString:)) ?? LocalTime(hour: 18, minute: 0),
            digestEnabled: digestEnabled,
            digestDay: DayOfWeek(rawValue: digestDay ?? DayOfWeek.friday.rawValue) ?? .friday,
            digestTime: digestTime.flatMap(LocalTime.from(jsonString:)) ?? LocalTime(hour: 18, minute: 0),
            notificationGrouping: NotificationGrouping(rawValue: notificationGrouping ?? NotificationGrouping.perType.rawValue) ?? .perType,
            badgeCountShowDueSoon: badgeCountShowDueSoon,
            dueSoonWindowDays: Int(dueSoonWindowDays),
            demoModeEnabled: demoModeEnabled,
            analyticsEnabled: analyticsEnabled,
            hideContactNamesInNotifications: hideContactNamesInNotifications,
            birthdayNotificationsEnabled: birthdayNotificationsEnabled,
            birthdayNotificationTime: birthdayNotificationTime.flatMap(LocalTime.from(jsonString:)) ?? LocalTime(hour: 9, minute: 0),
            lastContactsSyncAt: lastContactsSyncAt,
            onboardingCompleted: onboardingCompleted,
            appVersion: appVersion ?? ""
        )
    }

    func apply(_ settings: AppSettings) {
        id = settings.id
        theme = settings.theme.rawValue
        notificationsEnabled = settings.notificationsEnabled
        breachTimeOfDay = settings.breachTimeOfDay.toJsonString()
        digestEnabled = settings.digestEnabled
        digestDay = settings.digestDay.rawValue
        digestTime = settings.digestTime.toJsonString()
        notificationGrouping = settings.notificationGrouping.rawValue
        badgeCountShowDueSoon = settings.badgeCountShowDueSoon
        dueSoonWindowDays = Int64(settings.dueSoonWindowDays)
        demoModeEnabled = settings.demoModeEnabled
        analyticsEnabled = settings.analyticsEnabled
        hideContactNamesInNotifications = settings.hideContactNamesInNotifications
        birthdayNotificationsEnabled = settings.birthdayNotificationsEnabled
        birthdayNotificationTime = settings.birthdayNotificationTime.toJsonString()
        lastContactsSyncAt = settings.lastContactsSyncAt
        onboardingCompleted = settings.onboardingCompleted
        appVersion = settings.appVersion
    }
}
