//
//  WidgetCoreData.swift
//  KeepInTouchWidget
//
//  Read-only Core Data stack for the widget extension. Points at the
//  shared App Group store the main app migrated to in #280.
//

import CoreData

enum WidgetCoreData {

    static let shared: NSPersistentContainer? = makeContainer()

    private static func makeContainer() -> NSPersistentContainer? {
        guard let storeURL = AppGroup.coreDataStoreURL else {
            return nil
        }

        let container = NSPersistentContainer(name: "StayInTouch")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.isReadOnly = true
        description.shouldMigrateStoreAutomatically = false
        description.shouldInferMappingModelAutomatically = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        guard loadError == nil else { return nil }

        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }
}
