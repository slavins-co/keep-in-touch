//
//  CoreDataAppSettingsRepository.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

final class CoreDataAppSettingsRepository: AppSettingsRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch() -> AppSettings? {
        var result: AppSettings?
        context.performAndWait {
            let request: NSFetchRequest<AppSettingsEntity> = AppSettingsEntity.fetchRequest()
            request.fetchLimit = 1
            result = (try? context.fetch(request))?.first?.toDomain()
        }
        return result
    }

    func save(_ settings: AppSettings) throws {
        try context.performAndWait {
            let entity = fetchEntity(id: settings.id) ?? AppSettingsEntity(context: context)
            entity.apply(settings)
            try context.save()
        }
    }

    private func fetchEntity(id: UUID) -> AppSettingsEntity? {
        let request: NSFetchRequest<AppSettingsEntity> = AppSettingsEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
