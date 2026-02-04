//
//  CoreDataPersonRepository.swift
//  StayInTouch
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
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func fetchByGroup(id: UUID, includePaused: Bool) -> [Person] {
        var results: [Person] = []
        context.performAndWait {
            let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                basePredicate(includePaused: includePaused),
                NSPredicate(format: "groupId == %@", id as CVarArg)
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func fetchByTag(id: UUID, includePaused: Bool) -> [Person] {
        let people = fetchTracked(includePaused: includePaused)
        return people.filter { $0.tagIds.contains(id) }
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
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func fetchOverdue(referenceDate: Date) -> [Person] {
        let calculator = SLACalculator(referenceDate: referenceDate)
        let people = fetchTracked(includePaused: false)

        // Batch fetch all groups to avoid N+1 query
        let groupIds = Set(people.map { $0.groupId })
        let groups = fetchGroupsByIds(Array(groupIds))
        let groupById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })

        return people.filter { person in
            guard let group = groupById[person.groupId] else { return false }
            return calculator.status(for: person, in: [group]) == .outOfSLA
        }
    }

    func save(_ person: Person) throws {
        try context.performAndWait {
            let entity = fetchEntity(id: person.id) ?? PersonEntity(context: context)
            entity.apply(person)
            try context.save()
        }
    }

    func delete(id: UUID) throws {
        try context.performAndWait {
            guard let entity = fetchEntity(id: id) else { return }
            context.delete(entity)
            try context.save()
        }
    }

    private func fetchEntity(id: UUID) -> PersonEntity? {
        let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchGroup(id: UUID) -> Group? {
        let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first?.toDomain()
    }

    private func fetchGroupsByIds(_ ids: [UUID]) -> [Group] {
        guard !ids.isEmpty else { return [] }
        var results: [Group] = []
        context.performAndWait {
            let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", ids)
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    private func basePredicate(includePaused: Bool) -> NSPredicate {
        if includePaused {
            return NSPredicate(format: "isTracked == YES")
        }
        return NSPredicate(format: "isTracked == YES AND isPaused == NO")
    }
}
