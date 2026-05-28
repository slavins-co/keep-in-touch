//
//  AppDependencies.swift
//  KeepInTouch
//
//  Created by Claude Code on 3/10/26.
//

import CoreData
import SwiftUI

/// Container for all repository dependencies.
///
/// Inject at the app root via `.environment(\.dependencies, ...)` and read in
/// views or view models with `@Environment(\.dependencies)`.
struct AppDependencies {
    let personRepository: PersonRepository
    let cadenceRepository: CadenceRepository
    let groupRepository: GroupRepository
    let touchEventRepository: TouchEventRepository
    let settingsRepository: AppSettingsRepository

    init(context: NSManagedObjectContext) {
        self.personRepository = CoreDataPersonRepository(context: context)
        self.cadenceRepository = CoreDataCadenceRepository(context: context)
        self.groupRepository = CoreDataGroupRepository(context: context)
        self.touchEventRepository = CoreDataTouchEventRepository(context: context)
        self.settingsRepository = CoreDataAppSettingsRepository(context: context)
    }

    /// Test seam — assemble dependencies from explicit (typically mock)
    /// repositories. Not used by the production wiring.
    init(
        personRepository: PersonRepository,
        cadenceRepository: CadenceRepository,
        groupRepository: GroupRepository,
        touchEventRepository: TouchEventRepository,
        settingsRepository: AppSettingsRepository
    ) {
        self.personRepository = personRepository
        self.cadenceRepository = cadenceRepository
        self.groupRepository = groupRepository
        self.touchEventRepository = touchEventRepository
        self.settingsRepository = settingsRepository
    }
}

// MARK: - Production resolver

extension AppDependencies {
    /// Production resolver — the single place that binds the app's
    /// repositories to `CoreDataStack.shared.viewContext`. Everything
    /// else (ViewModels, UseCases, Notifications, Intents) reads from
    /// this seam so the Core Data dependency is centralized in `App/`.
    ///
    /// Tests override by passing explicit repositories to a VM's
    /// designated initializer; SwiftUI previews and integration tests
    /// override by injecting `.environment(\.dependencies, ...)`.
    static let shared = AppDependencies(context: CoreDataStack.shared.viewContext)
}

// MARK: - SwiftUI Environment

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies.shared
}

extension EnvironmentValues {
    var dependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
