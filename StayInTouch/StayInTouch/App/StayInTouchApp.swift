//
//  StayInTouchApp.swift
//  StayInTouch
//
//  Created by Bradley Slavin on 2/2/26.
//

import SwiftUI

@main
struct StayInTouchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let coreDataStack: CoreDataStack = {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            return CoreDataStack.make(inMemory: true, shouldSeedDefaults: false)
        }
        return CoreDataStack.shared
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataStack.viewContext)
        }
    }
}
