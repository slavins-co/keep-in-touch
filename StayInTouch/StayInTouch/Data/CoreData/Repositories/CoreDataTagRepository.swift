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
        try context.performAndWait {
            let entity = fetchEntity(id: tag.id) ?? TagEntity(context: context)
            entity.apply(tag)
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

    private func fetchEntity(id: UUID) -> TagEntity? {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
