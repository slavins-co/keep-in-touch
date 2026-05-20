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

// MARK: - SwiftUI Environment

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies(context: CoreDataStack.shared.viewContext)
}

extension EnvironmentValues {
    var dependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
