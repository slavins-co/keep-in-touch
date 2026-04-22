//
//  CoreDataStack.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import CoreData

final class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()

    /// Set once the app has successfully opened the persistent store at the
    /// App Group location. If this is `true` on a subsequent launch but the
    /// App Group container is unavailable (e.g. entitlement regression), we
    /// hard-fail rather than silently opening an empty default-location store
    /// and appearing to have lost the user's data.
    static let hasMigratedToAppGroupKey = "hasMigratedToAppGroup"

    /// Decides what to do when the App Group container may or may not be
    /// available. Pure function — extracted for unit testing.
    enum StoreURLResolution: Equatable {
        case useGroupURL(URL)
        case fallbackToDefault
        case hardFail(String)
    }

    static func resolveStoreURL(
        groupStoreURL: URL?,
        hasPreviouslyMigrated: Bool
    ) -> StoreURLResolution {
        if let groupStoreURL {
            return .useGroupURL(groupStoreURL)
        }
        if hasPreviouslyMigrated {
            return .hardFail(
                "App Group container is unavailable, but this install has previously migrated to it. Refusing to silently open an empty default-location store. Check entitlements."
            )
        }
        return .fallbackToDefault
    }

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
        } else {
            let resolution = Self.resolveStoreURL(
                groupStoreURL: AppGroup.coreDataStoreURL,
                hasPreviouslyMigrated: UserDefaults.standard.bool(forKey: Self.hasMigratedToAppGroupKey)
            )

            switch resolution {
            case .useGroupURL(let groupStoreURL):
                if let legacyURL = CoreDataStoreMigrator.legacyStoreURL() {
                    do {
                        let migrated = try CoreDataStoreMigrator.migrateIfNeeded(
                            legacyURL: legacyURL,
                            targetURL: groupStoreURL
                        )
                        if migrated {
                            AppLogger.logInfo(
                                "Migrated Core Data store from legacy default location to App Group container",
                                category: AppLogger.coreData
                            )
                        }
                    } catch {
                        AppLogger.logError(
                            error,
                            category: AppLogger.coreData,
                            context: "CoreDataStack.storeMigration"
                        )
                        self.loadError = error
                        self.isLoaded = false
                        self.migrationFailed = true
                        NotificationCenter.default.post(name: .coreDataMigrationFailed, object: error)
                        return
                    }
                }
                container.persistentStoreDescriptions.first?.url = groupStoreURL

            case .hardFail(let message):
                let error = NSError(
                    domain: "CoreDataStack",
                    code: -1001,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
                AppLogger.logError(
                    error,
                    category: AppLogger.coreData,
                    context: "CoreDataStack.appGroupUnavailableAfterMigration"
                )
                self.loadError = error
                self.isLoaded = false
                self.migrationFailed = true
                NotificationCenter.default.post(name: .coreDataMigrationFailed, object: error)
                return

            case .fallbackToDefault:
                AppLogger.logWarning(
                    "App Group container unavailable; falling back to default store location",
                    category: AppLogger.coreData
                )
            }
        }

        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true
        description?.setOption(
            FileProtectionType.completeUntilFirstUserAuthentication.rawValue as NSString,
            forKey: NSPersistentStoreFileProtectionKey
        )

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
            if !inMemory, AppGroup.coreDataStoreURL != nil {
                UserDefaults.standard.set(true, forKey: Self.hasMigratedToAppGroupKey)
            }
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
