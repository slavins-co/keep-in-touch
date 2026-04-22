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
            let request: NSFetchRequest<TouchEventEntity> = TouchEventEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            result = (try? context.fetch(request))?.first?.toDomain()
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
        do {
            try context.performAndWait {
                let entity = fetchEntity(id: touchEvent.id) ?? TouchEventEntity(context: context)
                entity.apply(touchEvent)
                try context.save()
            }
            WidgetRefresher.reloadAllTimelines()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.saveFailed(entity: "TouchEvent", underlying: error)
        }
    }

    func batchSave(_ touchEvents: [TouchEvent]) throws {
        do {
            try context.performAndWait {
                for touchEvent in touchEvents {
                    let entity = fetchEntity(id: touchEvent.id) ?? TouchEventEntity(context: context)
                    entity.apply(touchEvent)
                }
                try context.save()
            }
            WidgetRefresher.reloadAllTimelines()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.saveFailed(entity: "TouchEvent", underlying: error)
        }
    }

    func delete(id: UUID) throws {
        do {
            try context.performAndWait {
                guard let entity = fetchEntity(id: id) else { return }
                context.delete(entity)
                try context.save()
            }
            WidgetRefresher.reloadAllTimelines()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.deleteFailed(entity: "TouchEvent", id: id, underlying: error)
        }
    }

    private func fetchEntity(id: UUID) -> TouchEventEntity? {
        let request: NSFetchRequest<TouchEventEntity> = TouchEventEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
