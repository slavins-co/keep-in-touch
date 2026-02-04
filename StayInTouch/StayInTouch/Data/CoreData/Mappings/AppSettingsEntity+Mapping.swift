//
//  AppSettingsEntity+Mapping.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

extension AppSettingsEntity {
    func toDomain() -> AppSettings {
        AppSettings(
            id: id ?? AppSettings.singletonId,
            theme: Theme(rawValue: theme ?? Theme.light.rawValue) ?? .light,
            notificationsEnabled: notificationsEnabled,
            breachTimeOfDay: breachTimeOfDay.flatMap(LocalTime.from(jsonString:)) ?? LocalTime(hour: 18, minute: 0),
            digestEnabled: digestEnabled,
            digestDay: DayOfWeek(rawValue: digestDay ?? DayOfWeek.friday.rawValue) ?? .friday,
            digestTime: digestTime.flatMap(LocalTime.from(jsonString:)) ?? LocalTime(hour: 18, minute: 0),
            notificationGrouping: NotificationGrouping(rawValue: notificationGrouping ?? NotificationGrouping.perType.rawValue) ?? .perType,
            dueSoonWindowDays: Int(dueSoonWindowDays),
            demoModeEnabled: demoModeEnabled,
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
        dueSoonWindowDays = Int64(settings.dueSoonWindowDays)
        demoModeEnabled = settings.demoModeEnabled
        lastContactsSyncAt = settings.lastContactsSyncAt
        onboardingCompleted = settings.onboardingCompleted
        appVersion = settings.appVersion
    }
}
