//
//  CoreDataGroupRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

final class CoreDataGroupRepository: GroupRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch(id: UUID) -> Group? {
        var result: Group?
        context.performAndWait {
            let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            result = (try? context.fetch(request))?.first?.toDomain()
        }
        return result
    }

    func fetchAll() -> [Group] {
        var results: [Group] = []
        context.performAndWait {
            let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func fetchDefaultGroups() -> [Group] {
        var results: [Group] = []
        context.performAndWait {
            let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDefault == YES")
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func save(_ group: Group) throws {
        try context.performAndWait {
            let entity = fetchEntity(id: group.id) ?? GroupEntity(context: context)
            entity.apply(group)
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

    private func fetchEntity(id: UUID) -> GroupEntity? {
        let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
