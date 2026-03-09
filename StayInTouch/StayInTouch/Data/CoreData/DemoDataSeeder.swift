//
//  DemoDataSeeder.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import CoreData
import Foundation

final class DemoDataSeeder {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func seedIfNeeded() {
        context.performAndWait {
            let repo = CoreDataPersonRepository(context: context)
            let existing = repo.fetchAll()
            if existing.contains(where: { $0.isDemoData }) {
                return
            }

            let groups = CoreDataGroupRepository(context: context).fetchAll()
            guard let defaultGroupId = groups.first(where: { $0.isDefault })?.id ?? groups.first?.id else { return }
            let tags = CoreDataTagRepository(context: context).fetchAll()

            let names = DemoDataSeeder.demoNames
            let now = Date()
            var sortOrder = existing.count

            for (index, name) in names.enumerated() {
                let groupId = groups.indices.contains(index % max(1, groups.count)) ? groups[index % groups.count].id : defaultGroupId
                var tagIds: [UUID] = []
                if let tag = tags.randomElement() {
                    tagIds.append(tag.id)
                }

                let daysAgo = [0, 1, 3, 5, 8, 12, 20].randomElement() ?? 0
                let lastTouch = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)

                let person = Person(
                    id: UUID(),
                    cnIdentifier: nil,
                    displayName: name,
                    initials: InitialsBuilder.initials(for: name),
                    avatarColor: AvatarColors.randomHex(),
                    groupId: groupId,
                    tagIds: tagIds,
                    lastTouchAt: lastTouch,
                    lastTouchMethod: .text,
                    lastTouchNotes: nil,
                    nextTouchNotes: nil,
                    isPaused: false,
                    isTracked: true,
                    notificationsMuted: false,
                    customBreachTime: nil,
                    snoozedUntil: nil,
                    customDueDate: nil,
                    birthday: nil,
                    birthdayNotificationsEnabled: true,
                    contactUnavailable: false,
                    isDemoData: true,
                    groupAddedAt: now,
                    createdAt: now,
                    modifiedAt: now,
                    sortOrder: sortOrder
                )

                let assigned = AssignGroupUseCase(referenceDate: now).assign(person: person, to: groupId)
                try? repo.save(assigned)
                sortOrder += 1
            }
        }
    }

    private static let demoNames = [
        "Ava Brooks", "Liam Carter", "Mia Nguyen", "Noah Patel", "Sophia Kim",
        "Ethan Rivera", "Isabella Moore", "Lucas Reed", "Amelia Scott", "Mason Lee",
        "Harper Young", "Logan Clark", "Evelyn Lewis", "Elijah Walker", "Aria Hall",
        "James Allen", "Charlotte King", "Benjamin Wright", "Luna Green", "Henry Baker",
        "Grace Adams", "Jack Nelson", "Penelope Hill", "Oliver Turner", "Chloe Mitchell"
    ]
}
