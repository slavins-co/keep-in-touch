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
            result = fetchEntityByID(request: TagEntity.fetchRequest(), id: id, in: context)?.toDomain()
        }
        return result
    }

    func fetchAll() -> [Group] {
        var results: [Group] = []
        context.performAndWait {
            let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func save(_ group: Group) throws {
        try upsertEntity(
            id: group.id,
            fetchRequest: { TagEntity.fetchRequest() },
            entityLabel: "Group",
            in: context
        ) { entity in
            entity.apply(group)
        }
    }

    func batchSave(_ groups: [Group]) throws {
        try batchUpsertEntities(
            groups,
            id: { $0.id },
            fetchRequest: { TagEntity.fetchRequest() },
            entityLabel: "Group",
            in: context
        ) { group, entity in
            entity.apply(group)
        }
    }

    func delete(id: UUID) throws {
        try deleteEntityByID(
            fetchRequest: { TagEntity.fetchRequest() },
            id: id,
            entityLabel: "Group",
            in: context
        )
    }

    func count() -> Int {
        var count = 0
        context.performAndWait {
            let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
            // `count(for:)` returns the row count without faulting any
            // managed objects into memory — used by Settings to render
            // the group count badge without loading every Group (audit
            // E9, #317).
            count = (try? context.count(for: request)) ?? 0
        }
        return count
    }
}
