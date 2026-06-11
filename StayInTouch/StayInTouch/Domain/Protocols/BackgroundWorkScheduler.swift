//
//  BackgroundWorkScheduler.swift
//  KeepInTouch
//
//  Domain-level abstraction for running batched persistence work off the
//  main actor. UseCases that need to perform many writes against a single
//  background scope (e.g. JSON import, contacts sync) depend on this
//  protocol; the Data layer provides the Core Data-backed implementation.
//
//  Domain MUST NOT import CoreData, so the protocol surface is opaque:
//  the scheduler hands the caller a `BackgroundRepositoryScope` —
//  repository protocol references bound to a private background context
//  — and serializes the closure body on that context for the caller.
//

import Foundation

/// Bundle of repository references scoped to a single background unit
/// of work. All repositories in the scope share the same private context
/// so saves coalesce into a single persistent-store write.
struct BackgroundRepositoryScope: Sendable {
    let personRepository: PersonRepository
    let cadenceRepository: CadenceRepository
    let groupRepository: GroupRepository
    let touchEventRepository: TouchEventRepository
}

/// Schedules work that needs a fresh background persistence scope. The
/// Data layer implementation wraps `NSManagedObjectContext.perform` and
/// constructs Core Data-backed repositories bound to that context;
/// UseCases never see the underlying types.
protocol BackgroundWorkScheduler {
    /// Run `work` on a fresh background scope, awaiting completion. The
    /// closure is serialized on the scope's underlying context, so all
    /// repository calls inside it are thread-safe.
    func perform<T: Sendable>(_ work: @escaping @Sendable (BackgroundRepositoryScope) -> T) async -> T
}
