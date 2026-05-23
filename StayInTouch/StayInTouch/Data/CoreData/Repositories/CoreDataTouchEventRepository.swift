//
//  CoreDataTouchEventRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

final class CoreDataTouchEventRepository: TouchEventRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch(id: UUID) -> TouchEvent? {
        var result: TouchEvent?
        context.performAndWait {
            result = fetchEntityByID(request: TouchEventEntity.fetchRequest(), id: id, in: context)?.toDomain()
        }
        return result
    }

    func fetchAll(for personId: UUID) -> [TouchEvent] {
        var results: [TouchEvent] = []
        context.performAndWait {
            let request: NSFetchRequest<TouchEventEntity> = TouchEventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "personId == %@", personId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "at", ascending: false)]
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func fetchAll(since: Date?) -> [TouchEvent] {
        var results: [TouchEvent] = []
        context.performAndWait {
            let request: NSFetchRequest<TouchEventEntity> = TouchEventEntity.fetchRequest()
            if let since {
                request.predicate = NSPredicate(format: "at >= %@", since as NSDate)
            }
            request.sortDescriptors = [NSSortDescriptor(key: "at", ascending: false)]
            request.fetchBatchSize = 200
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func fetchMostRecent(for personId: UUID) -> TouchEvent? {
        var result: TouchEvent?
        context.performAndWait {
            let request: NSFetchRequest<TouchEventEntity> = TouchEventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "personId == %@", personId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "at", ascending: false)]
            request.fetchLimit = 1
            result = (try? context.fetch(request))?.first?.toDomain()
        }
        return result
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
}
