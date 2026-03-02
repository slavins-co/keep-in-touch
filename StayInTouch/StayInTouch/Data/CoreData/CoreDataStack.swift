//
//  CoreDataStack.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

final class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer
    private let shouldSeedDefaults: Bool
    private(set) var loadError: Error?
    private(set) var isLoaded = false
    @Published private(set) var migrationFailed = false

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
                AppLogger.logError(error, category: AppLogger.coreData, context: "CoreDataStack.loadPersistentStores")
                self.loadError = error
                self.isLoaded = false
                self.migrationFailed = true
                NotificationCenter.default.post(name: .coreDataMigrationFailed, object: error)
                return
            }

            self.isLoaded = true
            self.seedDefaultsIfNeeded()
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    /// Deletes the persistent store and recreates it. Only call after explicit user confirmation.
    func resetStore() {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else { return }

        AppLogger.logWarning("User confirmed store reset — deleting persistent store", category: AppLogger.coreData)

        for store in container.persistentStoreCoordinator.persistentStores {
            try? container.persistentStoreCoordinator.remove(store)
        }
        try? FileManager.default.removeItem(at: storeURL)

        container.loadPersistentStores { [weak self] _, retryError in
            guard let self else { return }
            if let retryError = retryError {
                AppLogger.logError(retryError, category: AppLogger.coreData, context: "CoreDataStack.resetStore.retry")
                self.loadError = retryError
                self.isLoaded = false
            } else {
                AppLogger.logInfo("Successfully recreated store after user-confirmed reset", category: AppLogger.coreData)
                self.isLoaded = true
                self.migrationFailed = false
                self.loadError = nil
                self.seedDefaultsIfNeeded()
            }
        }
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
            AppLogger.logError(error, category: AppLogger.coreData, context: "CoreDataStack.seedDefaults")
            AppLogger.logWarning("App will continue without default groups/tags. User can create them manually.", category: AppLogger.coreData)
        }
    }
}
