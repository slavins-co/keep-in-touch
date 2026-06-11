//
//  CoreDataAppSettingsRepository.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

// @unchecked Sendable: `context` is confined to its own queue — every access goes
// through `performAndWait`, which serializes on that queue. No `context` or
// managed object escapes a perform block.
final class CoreDataAppSettingsRepository: AppSettingsRepository, @unchecked Sendable {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch() -> AppSettings? {
        context.performAndWait {
            let request: NSFetchRequest<AppSettingsEntity> = AppSettingsEntity.fetchRequest()
            request.fetchLimit = 1
            return (try? context.fetch(request))?.first?.toDomain()
        }
    }

    func save(_ settings: AppSettings) throws {
        try context.performAndWait {
            let entity = fetchEntity(id: settings.id) ?? AppSettingsEntity(context: context)
            entity.apply(settings)
            try context.save()
        }
        WidgetRefresher.reloadAllTimelines()
    }

    private func fetchEntity(id: UUID) -> AppSettingsEntity? {
        let request: NSFetchRequest<AppSettingsEntity> = AppSettingsEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
