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
    let groupRepository: GroupRepository
    let tagRepository: TagRepository
    let touchEventRepository: TouchEventRepository
    let settingsRepository: AppSettingsRepository

    init(context: NSManagedObjectContext) {
        self.personRepository = CoreDataPersonRepository(context: context)
        self.groupRepository = CoreDataGroupRepository(context: context)
        self.tagRepository = CoreDataTagRepository(context: context)
        self.touchEventRepository = CoreDataTouchEventRepository(context: context)
        self.settingsRepository = CoreDataAppSettingsRepository(context: context)
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
