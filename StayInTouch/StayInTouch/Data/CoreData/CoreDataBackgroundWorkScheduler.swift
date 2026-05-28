//
//  CoreDataBackgroundWorkScheduler.swift
//  KeepInTouch
//
//  Core Data implementation of `BackgroundWorkScheduler`. Spins up a
//  fresh background context (or accepts one for tests), constructs the
//  full set of Core Data repositories bound to it, and runs the caller's
//  closure inside `context.perform`.
//

import CoreData

struct CoreDataBackgroundWorkScheduler: BackgroundWorkScheduler {
    /// Factory for the background context. Defaults to the shared stack;
    /// tests inject a stable in-memory context.
    let contextFactory: () -> NSManagedObjectContext

    init(contextFactory: @escaping () -> NSManagedObjectContext = { CoreDataStack.shared.newBackgroundContext() }) {
        self.contextFactory = contextFactory
    }

    func perform(_ work: @escaping (BackgroundRepositoryScope) -> Void) async {
        let context = contextFactory()
        await context.perform {
            let scope = BackgroundRepositoryScope(
                personRepository: CoreDataPersonRepository(context: context),
                cadenceRepository: CoreDataCadenceRepository(context: context),
                groupRepository: CoreDataGroupRepository(context: context),
                touchEventRepository: CoreDataTouchEventRepository(context: context)
            )
            work(scope)
        }
    }
}
