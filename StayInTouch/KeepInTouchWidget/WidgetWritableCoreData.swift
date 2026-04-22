//
//  WidgetWritableCoreData.swift
//  KeepInTouchWidget
//
//  Write-capable Core Data stack used exclusively by LogTouchIntent.
//  Separate from WidgetCoreData (read-only) so the common
//  timeline-provider path never accidentally opens a writable handle.
//

import CoreData

enum WidgetWritableCoreData {

    static let shared: Container? = makeContainer()

    final class Container {
        let container: NSPersistentContainer

        init(container: NSPersistentContainer) {
            self.container = container
        }

        func performWrite(_ work: @escaping (NSManagedObjectContext) throws -> Void) async throws {
            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            try await context.perform {
                try work(context)
            }
        }
    }

    private static func makeContainer() -> Container? {
        guard let storeURL = AppGroup.coreDataStoreURL else {
            return nil
        }

        let container = NSPersistentContainer(name: "StayInTouch")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = false
        description.shouldInferMappingModelAutomatically = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        guard loadError == nil else { return nil }

        container.viewContext.automaticallyMergesChangesFromParent = true
        return Container(container: container)
    }
}
