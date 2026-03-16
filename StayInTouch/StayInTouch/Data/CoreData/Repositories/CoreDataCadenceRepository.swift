//
//  CoreDataCadenceRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

final class CoreDataCadenceRepository: CadenceRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch(id: UUID) -> Cadence? {
        var result: Cadence?
        context.performAndWait {
            let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            result = (try? context.fetch(request))?.first?.toDomain()
        }
        return result
    }

    func fetchAll() -> [Cadence] {
        var results: [Cadence] = []
        context.performAndWait {
            let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func fetchDefaultCadences() -> [Cadence] {
        var results: [Cadence] = []
        context.performAndWait {
            let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            request.predicate = NSPredicate(format: "isDefault == YES")
            request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            results = (try? context.fetch(request))?.map { $0.toDomain() } ?? []
        }
        return results
    }

    func save(_ cadence: Cadence) throws {
        do {
            try context.performAndWait {
                let entity = fetchEntity(id: cadence.id) ?? GroupEntity(context: context)
                entity.apply(cadence)
                try context.save()
            }
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.saveFailed(entity: "Cadence", underlying: error)
        }
    }

    func batchSave(_ cadences: [Cadence]) throws {
        do {
            try context.performAndWait {
                for cadence in cadences {
                    let entity = fetchEntity(id: cadence.id) ?? GroupEntity(context: context)
                    entity.apply(cadence)
                }
                try context.save()
            }
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.saveFailed(entity: "Cadence", underlying: error)
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
            throw RepositoryError.deleteFailed(entity: "Cadence", id: id, underlying: error)
        }
    }

    private func fetchEntity(id: UUID) -> GroupEntity? {
        let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
