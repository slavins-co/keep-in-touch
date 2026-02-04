//
//  CoreDataStack.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer
    private let shouldSeedDefaults: Bool
    private(set) var loadError: Error?
    private(set) var isLoaded = false

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    static func make(inMemory: Bool, shouldSeedDefaults: Bool) -> CoreDataStack {
        CoreDataStack(inMemory: inMemory, shouldSeedDefaults: shouldSeedDefaults)
    }

    private init(inMemory: Bool = false, shouldSeedDefaults: Bool = true) {
        self.shouldSeedDefaults = shouldSeedDefaults
        container = NSPersistentContainer(name: "StayInTouch")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { [weak self] _, error in
            guard let self else { return }

            if let error = error as NSError? {
                // Log the error instead of crashing
                AppLogger.logError(error, category: AppLogger.coreData, context: "CoreDataStack.loadPersistentStores")
                self.loadError = error
                self.isLoaded = false

                // Attempt recovery: delete and recreate store
                if let storeURL = self.container.persistentStoreDescriptions.first?.url {
                    AppLogger.logWarning("Attempting to delete corrupted store and recreate", category: AppLogger.coreData)
                    try? FileManager.default.removeItem(at: storeURL)

                    // Retry loading after deletion
                    self.container.loadPersistentStores { _, retryError in
                        if let retryError = retryError {
                            AppLogger.logError(retryError, category: AppLogger.coreData, context: "CoreDataStack.retryLoad")
                            self.loadError = retryError
                            self.isLoaded = false
                        } else {
                            AppLogger.logInfo("Successfully recreated store after deletion", category: AppLogger.coreData)
                            self.isLoaded = true
                            self.seedDefaultsIfNeeded()
                        }
                    }
                }
                return
            }

            self.isLoaded = true
            self.seedDefaultsIfNeeded()
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    static var preview: CoreDataStack {
        CoreDataStack(inMemory: true, shouldSeedDefaults: false)
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    func saveViewContext() throws {
        let context = container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }

    private func seedDefaultsIfNeeded() {
        guard shouldSeedDefaults else { return }

        do {
            let context = container.newBackgroundContext()
            let seeder = DefaultDataSeeder(context: context)
            try seeder.seedIfNeeded()
            AppLogger.logInfo("Successfully seeded default data", category: AppLogger.coreData)
        } catch {
            // Log error but don't crash - app can function without default data
            AppLogger.logError(error, category: AppLogger.coreData, context: "CoreDataStack.seedDefaults")
            AppLogger.logWarning("App will continue without default groups/tags. User can create them manually.", category: AppLogger.coreData)
        }
    }
}
