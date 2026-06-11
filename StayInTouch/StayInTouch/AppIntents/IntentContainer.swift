//
//  IntentContainer.swift
//  KeepInTouch
//
//  Lazy dependency container for App Intents. Intents run in the main
//  app process (launched by Siri/Shortcuts if cold), so we reuse the
//  same Core Data stack and repositories the UI uses.
//
//  Resolution is lazy via a function so the container can be swapped
//  in tests without touching CoreDataStack.shared at import time.
//
//  N2 (audit #302) verification: this container does NOT instantiate a
//  fresh Core Data stack on each intent invocation. The default resolver
//  returns `AppDependencies.shared`, a process-wide singleton that
//  resolves once to `CoreDataStack.shared.viewContext`. The first call to
//  `dependencies` caches the resolved `AppDependencies`; every later
//  invocation reuses it. Cold-start cost on Siri/Shortcuts runs is the
//  one-time Core Data stack boot, identical to the UI cold path.
//

import Foundation

final class IntentContainer: @unchecked Sendable {
    static let shared = IntentContainer()

    private let resolver: () -> AppDependencies
    private let lock = NSLock()
    private var cached: AppDependencies?

    private init(resolver: @escaping () -> AppDependencies = { AppDependencies.shared }) {
        self.resolver = resolver
    }

    /// Test seam: replace the shared instance with one backed by mocks.
    static func install(_ container: IntentContainer) {
        sharedOverride = container
    }

    static func reset() {
        sharedOverride = nil
    }

    /// Lazily-resolved dependencies. Same instance for the lifetime of the
    /// container — repositories internally hold the Core Data context and
    /// can be reused across intent invocations.
    var dependencies: AppDependencies {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let resolved = resolver()
        cached = resolved
        return resolved
    }

    // MARK: - Test override plumbing

    nonisolated(unsafe) private static var sharedOverride: IntentContainer?

    static var current: IntentContainer {
        sharedOverride ?? shared
    }

    /// Construct a container with a custom resolver — used in tests.
    static func make(dependencies: AppDependencies) -> IntentContainer {
        IntentContainer(resolver: { dependencies })
    }
}
