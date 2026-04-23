//
//  WidgetCoreData.swift
//  KeepInTouchWidget
//
//  Core Data stack for the widget extension. Points at the shared App
//  Group store the main app migrated to in #280. Kept writable because
//  SQLite in WAL mode needs write access to the -shm/-wal sidecars even
//  for read-only queries; opening with isReadOnly = true caused load to
//  hang when the store had pending WAL entries.
//

import CoreData
import os

private let widgetLog = Logger(subsystem: "slavins.co.KeepInTouch.Widget", category: "CoreData")

enum WidgetCoreData {

    static let shared: NSPersistentContainer? = makeContainer()

    private static func makeContainer() -> NSPersistentContainer? {
        guard let storeURL = AppGroup.coreDataStoreURL else {
            widgetLog.error("AppGroup.coreDataStoreURL is nil — App Group entitlement likely missing")
            return nil
        }

        widgetLog.notice("Loading widget Core Data store at \(storeURL.path, privacy: .public)")

        let container = NSPersistentContainer(name: "StayInTouch")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = false
        description.shouldInferMappingModelAutomatically = false
        // Mirror the app's file-protection class for defensive symmetry.
        // The file's actual protection is set when the app first creates
        // it (see CoreDataStack), but asserting the same key here keeps
        // the two stacks' descriptions in sync.
        description.setOption(
            FileProtectionType.completeUntilFirstUserAuthentication.rawValue as NSString,
            forKey: NSPersistentStoreFileProtectionKey
        )
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            widgetLog.error("Widget Core Data load failed: \(loadError.localizedDescription, privacy: .public)")
            return nil
        }

        widgetLog.notice("Widget Core Data loaded successfully")
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }
}
