//
//  CoreDataTagRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

final class CoreDataTagRepository: TagRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch(id: UUID) -> Tag? {
        var result: Tag?
        context.performAndWait {
            let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            result = (try? context.fetch(request))?.first?.toDomain()
        }
        return result
    }

    func fetchAll() -> [Tag] {
        var results: [Tag] = []
        context.performAndWait {
            let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func save(_ tag: Tag) throws {
        do {
            try context.performAndWait {
                let entity = fetchEntity(id: tag.id) ?? TagEntity(context: context)
                entity.apply(tag)
                try context.save()
            }
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.saveFailed(entity: "Tag", underlying: error)
        }
    }

    func batchSave(_ tags: [Tag]) throws {
        do {
            try context.performAndWait {
                for tag in tags {
                    let entity = fetchEntity(id: tag.id) ?? TagEntity(context: context)
                    entity.apply(tag)
                }
                try context.save()
            }
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.saveFailed(entity: "Tag", underlying: error)
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
            throw RepositoryError.deleteFailed(entity: "Tag", id: id, underlying: error)
        }
    }

    private func fetchEntity(id: UUID) -> TagEntity? {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
