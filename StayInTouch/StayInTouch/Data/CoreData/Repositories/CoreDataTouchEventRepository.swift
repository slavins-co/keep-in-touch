//
//  CoreDataTouchEventRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

// @unchecked Sendable: `context` is confined to its own queue — every access goes
// through `performAndWait`, which serializes on that queue. No `context` or
// managed object escapes a perform block.
final class CoreDataTouchEventRepository: TouchEventRepository, @unchecked Sendable {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch(id: UUID) -> TouchEvent? {
        context.performAndWait {
            fetchEntityByID(request: TouchEventEntity.fetchRequest(), id: id, in: context)?.toDomain()
        }
    }

    func fetchAll(for personId: UUID) -> [TouchEvent] {
        context.performAndWait {
            let request: NSFetchRequest<TouchEventEntity> = TouchEventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "personId == %@", personId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "at", ascending: false)]
            return (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
    }

    func fetchAll(since: Date?) -> [TouchEvent] {
        context.performAndWait {
            let request: NSFetchRequest<TouchEventEntity> = TouchEventEntity.fetchRequest()
            if let since {
                request.predicate = NSPredicate(format: "at >= %@", since as NSDate)
            }
            request.sortDescriptors = [NSSortDescriptor(key: "at", ascending: false)]
            request.fetchBatchSize = 200
            return (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
    }

    func fetchMostRecent(for personId: UUID) -> TouchEvent? {
        context.performAndWait {
            let request: NSFetchRequest<TouchEventEntity> = TouchEventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "personId == %@", personId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "at", ascending: false)]
            request.fetchLimit = 1
            return (try? context.fetch(request))?.first?.toDomain()
        }
    }

    func save(_ touchEvent: TouchEvent) throws {
        try upsertEntity(
            id: touchEvent.id,
            fetchRequest: { TouchEventEntity.fetchRequest() },
            entityLabel: "TouchEvent",
            in: context
        ) { entity in
            entity.apply(touchEvent)
        }
    }

    func batchSave(_ touchEvents: [TouchEvent]) throws {
        try batchUpsertEntities(
            touchEvents,
            id: { $0.id },
            fetchRequest: { TouchEventEntity.fetchRequest() },
            entityLabel: "TouchEvent",
            in: context
        ) { touchEvent, entity in
            entity.apply(touchEvent)
        }
    }

    func delete(id: UUID) throws {
        try deleteEntityByID(
            fetchRequest: { TouchEventEntity.fetchRequest() },
            id: id,
            entityLabel: "TouchEvent",
            in: context
        )
    }

    func batchDelete(ids: [UUID]) throws {
        try batchDeleteEntitiesByID(
            fetchRequest: { TouchEventEntity.fetchRequest() },
            ids: ids,
            entityLabel: "TouchEvent",
            in: context
        )
    }
}
