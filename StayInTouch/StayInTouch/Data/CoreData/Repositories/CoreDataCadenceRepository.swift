//
//  CoreDataCadenceRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

// @unchecked Sendable: `context` is confined to its own queue — every access goes
// through `performAndWait`, which serializes on that queue. No `context` or
// managed object escapes a perform block.
final class CoreDataCadenceRepository: CadenceRepository, @unchecked Sendable {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch(id: UUID) -> Cadence? {
        return context.performAndWait {
            fetchEntityByID(request: GroupEntity.fetchRequest(), id: id, in: context)?.toDomain()
        }
    }

    func fetchAll() -> [Cadence] {
        context.performAndWait {
            let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            return (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
    }

    func fetchDefaultCadences() -> [Cadence] {
        context.performAndWait {
            let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDefault == YES")
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            return (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
    }

    func save(_ cadence: Cadence) throws {
        // Cadence mutations do not affect widget content; skip the refresh.
        try upsertEntity(
            id: cadence.id,
            fetchRequest: { GroupEntity.fetchRequest() },
            entityLabel: "Cadence",
            in: context,
            refreshWidgets: false
        ) { entity in
            entity.apply(cadence)
        }
    }

    func batchSave(_ cadences: [Cadence]) throws {
        try batchUpsertEntities(
            cadences,
            id: { $0.id },
            fetchRequest: { GroupEntity.fetchRequest() },
            entityLabel: "Cadence",
            in: context,
            refreshWidgets: false
        ) { cadence, entity in
            entity.apply(cadence)
        }
    }

    func delete(id: UUID) throws {
        try deleteEntityByID(
            fetchRequest: { GroupEntity.fetchRequest() },
            id: id,
            entityLabel: "Cadence",
            in: context,
            refreshWidgets: false
        )
    }
}
