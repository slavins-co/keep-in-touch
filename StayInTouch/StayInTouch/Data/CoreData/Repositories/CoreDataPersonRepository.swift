//
//  CoreDataPersonRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

final class CoreDataPersonRepository: PersonRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch(id: UUID) -> Person? {
        var result: Person?
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            result = (try? context.fetch(request))?.first?.toDomain()
        }
        return result
    }

    func fetchAll() -> [Person] {
        var results: [Person] = []
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            request.fetchBatchSize = 50
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func fetchTracked(includePaused: Bool) -> [Person] {
        var results: [Person] = []
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            request.predicate = basePredicate(includePaused: includePaused)
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            request.fetchBatchSize = 50
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func fetchByCadence(id: UUID, includePaused: Bool) -> [Person] {
        var results: [Person] = []
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                basePredicate(includePaused: includePaused),
                NSPredicate(format: "groupId == %@", id as CVarArg)
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            request.fetchBatchSize = 50
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func fetchByGroup(id: UUID, includePaused: Bool) -> [Person] {
        let people = fetchTracked(includePaused: includePaused)
        return people.filter { $0.groupIds.contains(id) }
    }

    func searchByName(_ query: String, includePaused: Bool) -> [Person] {
        var results: [Person] = []
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            let namePredicate = NSPredicate(format: "displayName CONTAINS[cd] %@", query)
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                basePredicate(includePaused: includePaused),
                namePredicate
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true)]
            request.fetchBatchSize = 50
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func fetchOverdue(referenceDate: Date) -> [Person] {
        var results: [Person] = []
        context.performAndWait {
            // Fetch all groups to build per-group cutoff predicates
            let groupRequest: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            let groups = (try? context.fetch(groupRequest))?.map { $0.toDomain() } ?? []
            guard !groups.isEmpty else { return }

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
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func save(_ person: Person) throws {
        do {
            try context.performAndWait {
                let entity = fetchEntity(id: person.id) ?? PersonEntity(context: context)
                entity.apply(person)
                try context.save()
            }
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.saveFailed(entity: "Person", underlying: error)
        }
    }

    func batchSave(_ persons: [Person]) throws {
        do {
            try context.performAndWait {
                for person in persons {
                    let entity = fetchEntity(id: person.id) ?? PersonEntity(context: context)
                    entity.apply(person)
                }
                try context.save()
            }
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.saveFailed(entity: "Person", underlying: error)
        }
    }

    func delete(id: UUID) throws {
        do {
            try context.performAndWait {
                guard let entity = fetchEntity(id: id) else { return }
                context.delete(entity)
                try context.save()
            }
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.deleteFailed(entity: "Person", id: id, underlying: error)
        }
    }

    private func fetchEntity(id: UUID) -> PersonEntity? {
        let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func basePredicate(includePaused: Bool) -> NSPredicate {
        if includePaused {
            return NSPredicate(format: "isTracked == YES")
        }
        return NSPredicate(format: "isTracked == YES AND isPaused == NO")
    }
}
