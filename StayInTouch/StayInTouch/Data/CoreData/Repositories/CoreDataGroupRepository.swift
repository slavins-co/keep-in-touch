//
//  CoreDataGroupRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

// @unchecked Sendable: `context` is confined to its own queue — every access goes
// through `performAndWait`, which serializes on that queue. No `context` or
// managed object escapes a perform block.
final class CoreDataGroupRepository: GroupRepository, @unchecked Sendable {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch(id: UUID) -> Group? {
        return context.performAndWait {
            fetchEntityByID(request: TagEntity.fetchRequest(), id: id, in: context)?.toDomain()
        }
    }

    func fetchAll() -> [Group] {
        context.performAndWait {
            let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            return (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
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
        context.performAndWait {
            let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
            // `count(for:)` returns the row count without faulting any
            // managed objects into memory — used by Settings to render
            // the group count badge without loading every Group (audit
            // E9, #317).
            return (try? context.count(for: request)) ?? 0
        }
    }
}
