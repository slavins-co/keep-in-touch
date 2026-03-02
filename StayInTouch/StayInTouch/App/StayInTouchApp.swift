//
//  StayInTouchApp.swift
//  StayInTouch
//
//  Created by Bradley Slavin on 2/2/26.
//

import SwiftUI

@main
struct KeepInTouchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let coreDataStack: CoreDataStack = {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return CoreDataStack.make(inMemory: true, shouldSeedDefaults: false)
        }
        return CoreDataStack.shared
    }()
    @State private var showMigrationAlert = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.viewContext)
                .onAppear {
                    if coreDataStack.migrationFailed {
                        showMigrationAlert = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .coreDataMigrationFailed)) { _ in
                    showMigrationAlert = true
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
