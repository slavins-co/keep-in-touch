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

            let cadences = CoreDataCadenceRepository(context: context).fetchAll()
            guard let defaultCadenceId = cadences.first(where: { $0.isDefault })?.id ?? cadences.first?.id else { return }
            let allGroups = CoreDataGroupRepository(context: context).fetchAll()

            let names = DemoDataSeeder.demoNames
            let now = Date()
            var sortOrder = existing.count

            for (index, name) in names.enumerated() {
                let cadenceId = cadences.indices.contains(index % max(1, cadences.count)) ? cadences[index % cadences.count].id : defaultCadenceId
                var groupIds: [UUID] = []
                if let group = allGroups.randomElement() {
                    groupIds.append(group.id)
                }

                let daysAgo = [0, 1, 3, 5, 8, 12, 20].randomElement() ?? 0
                let lastTouch = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)

                let person = Person(
                    identity: Person.Identity(
                        id: UUID(),
                        displayName: name,
                        initials: InitialsBuilder.initials(for: name),
                        avatarColor: AvatarColors.randomHex()
                    ),
                    cadenceId: cadenceId,
                    groupIds: groupIds,
                    isPaused: false,
                    isTracked: true,
                    touchState: Person.TouchState(
                        lastTouchAt: lastTouch,
                        lastTouchMethod: .text,
                        cadenceAddedAt: now
                    ),
                    notifications: Person.NotificationConfig(
                        notificationsMuted: false,
                        birthdayNotificationsEnabled: true
                    ),
                    metadata: Person.Metadata(
                        contactUnavailable: false,
                        isDemoData: true,
                        createdAt: now,
                        modifiedAt: now,
                        sortOrder: sortOrder
                    )
                )

                let assigned = AssignCadenceUseCase(referenceDate: now).assign(person: person, to: cadenceId)
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
