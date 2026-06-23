//
//  StayInTouchApp.swift
//  KeepInTouch
//
//  Created by Bradley Slavin on 2/2/26.
//

import CoreData
import SwiftUI
import TipKit

@main
struct KeepInTouchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let coreDataStack: CoreDataStack
    private let isUITesting: Bool
    @StateObject private var purchaseManager: PurchaseManager
    @State private var showMigrationAlert = false

    init() {
        // TipKit needs to be configured BEFORE any tip can render. The
        // `walkthroughCompleted` gate parameter is synced from AppSettings
        // in `ContentView.loadSettings()` once Core Data is up, so we don't
        // duplicate the fetch on the cold-launch critical path here.
        try? Tips.configure([
            .displayFrequency(.immediate),
            TipsDatastore.location(),
        ])

        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let stack: CoreDataStack = isUITesting
            ? CoreDataStack.make(inMemory: true, shouldSeedDefaults: false)
            : CoreDataStack.shared
        self.isUITesting = isUITesting
        self.coreDataStack = stack

        // Pro entitlement source of truth, bound to the same store the app uses
        // (so it reads the correct grandfather flag, including under UI testing).
        _purchaseManager = StateObject(wrappedValue: PurchaseManager(
            gateway: LiveStoreKitGateway(),
            settingsRepository: CoreDataAppSettingsRepository(context: stack.viewContext)
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.viewContext)
                .environment(\.dependencies, AppDependencies(context: coreDataStack.viewContext))
                .environmentObject(purchaseManager)
                .task {
                    // Start StoreKit entitlement loading + the updates listener.
                    // Skipped under UI testing to keep launch smoke tests hermetic.
                    if !isUITesting { purchaseManager.start() }
                }
                // Note: in `-uiTesting` runs the coreDataStack is in-memory,
                // so we pass it through explicitly here. Outside tests
                // `AppDependencies.shared` already resolves to the same
                // `CoreDataStack.shared.viewContext`.
                .onAppear {
                    if coreDataStack.migrationFailed {
                        showMigrationAlert = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .coreDataMigrationFailed)) { _ in
                    showMigrationAlert = true
                }
                .onOpenURL { url in
                    DeepLinkRouter.shared.handleURL(url)
                }
                .alert("Data Update Required", isPresented: $showMigrationAlert) {
                    Button("Reset App Data", role: .destructive) {
                        coreDataStack.resetStore()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Your data couldn't be loaded. You can reset the app to start fresh, or cancel and contact support.")
                }
        }
    }
}
