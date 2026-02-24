//
//  DefaultDataSeeder.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

final class DefaultDataSeeder {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func seedIfNeeded() throws {
        try context.performAndWait {
            let (groupCount, tagCount, settingsCount) = try seedCounts()
            if groupCount == 0 { seedDefaultGroups() }
            if tagCount == 0 { seedDefaultTags() }
            if settingsCount == 0 { seedAppSettings() }
            if groupCount == 0 || tagCount == 0 || settingsCount == 0 {
                try context.save()
            }
        }
    }

    private func seedCounts() throws -> (Int, Int, Int) {
        let groupRequest: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
        groupRequest.fetchLimit = 1
        let groupCount = try context.count(for: groupRequest)

        let tagRequest: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        tagRequest.fetchLimit = 1
        let tagCount = try context.count(for: tagRequest)

        let settingsRequest: NSFetchRequest<AppSettingsEntity> = AppSettingsEntity.fetchRequest()
        settingsRequest.fetchLimit = 1
        let settingsCount = try context.count(for: settingsRequest)

        return (groupCount, tagCount, settingsCount)
    }

    private func seedDefaultGroups() {
        let now = Date()
        let defaults: [(name: String, frequencyDays: Int, warningDays: Int, colorHex: String?)] = [
            ("Weekly", 7, 2, nil),
            ("Bi-Weekly", 14, 3, nil),
            ("Monthly", 30, 5, nil),
            ("Quarterly", 90, 10, nil)
        ]

        for (index, item) in defaults.enumerated() {
            let entity = GroupEntity(context: context)
            entity.id = UUID()
            entity.name = item.name
            entity.slaDays = Int64(item.frequencyDays)
            entity.warningDays = Int64(item.warningDays)
            entity.colorHex = item.colorHex
            entity.isDefault = true
            entity.sortOrder = Int64(index)
            entity.createdAt = now
            entity.modifiedAt = now
        }
    }

    private func seedDefaultTags() {
        let now = Date()
        let defaults: [(name: String, colorHex: String)] = [
            ("Work", "#0A84FF"),
            ("Family", "#FF3B30"),
            ("Friend", "#34C759"),
            ("Mentor", "#FF9500")
        ]

        for (index, item) in defaults.enumerated() {
            let entity = TagEntity(context: context)
            entity.id = UUID()
            entity.name = item.name
            entity.colorHex = item.colorHex
            entity.sortOrder = Int64(index)
            entity.createdAt = now
            entity.modifiedAt = now
        }
    }

    private func seedAppSettings() {
        let entity = AppSettingsEntity(context: context)
        entity.id = AppSettings.singletonId
        entity.theme = Theme.light.rawValue
        entity.notificationsEnabled = false
        entity.breachTimeOfDay = LocalTime(hour: 18, minute: 0).toJsonString()
        entity.digestEnabled = false
        entity.digestDay = DayOfWeek.friday.rawValue
        entity.digestTime = LocalTime(hour: 18, minute: 0).toJsonString()
        entity.notificationGrouping = NotificationGrouping.perType.rawValue
        entity.dueSoonWindowDays = 3
        entity.demoModeEnabled = false
        entity.lastContactsSyncAt = nil
        entity.onboardingCompleted = false
        entity.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
