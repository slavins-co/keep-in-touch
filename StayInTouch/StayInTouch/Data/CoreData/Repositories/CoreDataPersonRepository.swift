//
//  CoreDataPersonRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

// @unchecked Sendable: `context` is confined to its own queue — every access goes
// through `performAndWait`, which serializes on that queue. No `context` or
// managed object escapes a perform block.
final class CoreDataPersonRepository: PersonRepository, @unchecked Sendable {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch(id: UUID) -> Person? {
        return context.performAndWait {
            fetchEntityByID(request: PersonEntity.fetchRequest(), id: id, in: context)?.toDomain()
        }
    }

    func fetchAll() -> [Person] {
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            request.fetchBatchSize = 50
            return (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
    }

    func fetchTracked(includePaused: Bool) -> [Person] {
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            request.predicate = basePredicate(includePaused: includePaused)
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            request.fetchBatchSize = 50
            return (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
    }

    func fetchByCadence(id: UUID, includePaused: Bool) -> [Person] {
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                basePredicate(includePaused: includePaused),
                NSPredicate(format: "groupId == %@", id as CVarArg)
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            request.fetchBatchSize = 50
            return (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
    }

    func fetchByGroup(id: UUID, includePaused: Bool) -> [Person] {
        let people = fetchTracked(includePaused: includePaused)
        return people.filter { $0.groupIds.contains(id) }
    }

    func searchByName(_ query: String, includePaused: Bool) -> [Person] {
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            let namePredicate = NSPredicate(format: "displayName CONTAINS[cd] %@", query)
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                basePredicate(includePaused: includePaused),
                namePredicate
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true)]
            request.fetchBatchSize = 50
            return (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
    }

    func fetchOverdue(referenceDate: Date) -> [Person] {
        context.performAndWait {
            // Fetch all groups to build per-group cutoff predicates
            let groupRequest: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            let groups = (try? context.fetch(groupRequest))?.map { $0.toDomain() } ?? []
            guard !groups.isEmpty else { return [] }

            // Build a predicate per group: person's effective last-touch is before the cutoff
            let calendar = Calendar.current
            var perGroupPredicates: [NSPredicate] = []
            for group in groups {
                guard let cutoff = calendar.date(byAdding: .day, value: -group.frequencyDays, to: referenceDate) else { continue }

                // effectiveLastTouchDate = lastTouchAt ?? cadenceAddedAt
                // Overdue when effective date < cutoff
                let touchBeforeCutoff = NSPredicate(format: "groupId == %@ AND lastTouchAt != nil AND lastTouchAt < %@",
                                                     group.id as CVarArg, cutoff as NSDate)
                let fallbackBeforeCutoff = NSPredicate(format: "groupId == %@ AND lastTouchAt == nil AND groupAddedAt != nil AND groupAddedAt < %@",
                                                        group.id as CVarArg, cutoff as NSDate)
                perGroupPredicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [touchBeforeCutoff, fallbackBeforeCutoff]))
            }

            let overduePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: perGroupPredicates)
            let notSnoozed = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "snoozedUntil == nil"),
                NSPredicate(format: "snoozedUntil <= %@", referenceDate as NSDate)
            ])

            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                basePredicate(includePaused: false),
                notSnoozed,
                overduePredicate
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            request.fetchBatchSize = 50
            return (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
    }

    func save(_ person: Person) throws {
        try upsertEntity(
            id: person.id,
            fetchRequest: { PersonEntity.fetchRequest() },
            entityLabel: "Person",
            in: context
        ) { entity in
            entity.apply(person)
        }
    }

    func batchSave(_ persons: [Person]) throws {
        try batchUpsertEntities(
            persons,
            id: { $0.id },
            fetchRequest: { PersonEntity.fetchRequest() },
            entityLabel: "Person",
            in: context
        ) { person, entity in
            entity.apply(person)
        }
    }

    func delete(id: UUID) throws {
        try deleteEntityByID(
            fetchRequest: { PersonEntity.fetchRequest() },
            id: id,
            entityLabel: "Person",
            in: context
        )
    }

    func pausedCount() -> Int {
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isTracked == YES AND isPaused == YES")
            // `count(for:)` returns the row count from the underlying store
            // without faulting the matching managed objects into memory.
            // Equivalent to `fetchTracked(includePaused: true).filter(isPaused).count`
            // but without the materialization cost (audit E9, #317).
            return (try? context.count(for: request)) ?? 0
        }
    }

    func snoozedCount(referenceDate: Date = Date()) -> Int {
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            // Only *active* snoozes count — an expired snooze is effectively
            // un-snoozed. Matches the active-snooze convention used in
            // fetchOverdue (snoozedUntil <= referenceDate == not snoozed).
            request.predicate = NSPredicate(
                format: "isTracked == YES AND snoozedUntil != nil AND snoozedUntil > %@",
                referenceDate as NSDate
            )
            return (try? context.count(for: request)) ?? 0
        }
    }

    func trackedCount() -> Int {
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            // `isDemoData != YES` matches both stored-false and legacy-nil rows.
            // Paused people are included — a paused contact still occupies a slot.
            request.predicate = NSPredicate(format: "isTracked == YES AND isDemoData != YES")
            return (try? context.count(for: request)) ?? 0
        }
    }

    private func basePredicate(includePaused: Bool) -> NSPredicate {
        if includePaused {
            return NSPredicate(format: "isTracked == YES")
        }
        return NSPredicate(format: "isTracked == YES AND isPaused == NO")
    }
}
