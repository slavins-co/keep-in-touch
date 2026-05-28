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

import Foundation

final class IntentContainer {
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

    private static var sharedOverride: IntentContainer?

    static var current: IntentContainer {
        sharedOverride ?? shared
    }

    /// Construct a container with a custom resolver — used in tests.
    static func make(dependencies: AppDependencies) -> IntentContainer {
        IntentContainer(resolver: { dependencies })
    }
}
