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
            let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            result = (try? context.fetch(request))?.first?.toDomain()
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
        do {
            try context.performAndWait {
                let entity = fetchEntity(id: group.id) ?? TagEntity(context: context)
                entity.apply(group)
                try context.save()
            }
            WidgetRefresher.reloadAllTimelines()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.saveFailed(entity: "Group", underlying: error)
        }
    }

    func batchSave(_ groups: [Group]) throws {
        do {
            try context.performAndWait {
                for group in groups {
                    let entity = fetchEntity(id: group.id) ?? TagEntity(context: context)
                    entity.apply(group)
                }
                try context.save()
            }
            WidgetRefresher.reloadAllTimelines()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.saveFailed(entity: "Group", underlying: error)
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
            throw RepositoryError.deleteFailed(entity: "Group", id: id, underlying: error)
        }
    }

    private func fetchEntity(id: UUID) -> TagEntity? {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
