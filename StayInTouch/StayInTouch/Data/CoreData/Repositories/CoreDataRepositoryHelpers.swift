//
//  CoreDataRepositoryHelpers.swift
//  KeepInTouch
//
//  Generic CRUD helpers for Core Data repositories. Each public repository
//  (Person, TouchEvent, Group, Cadence) had ~60 lines of nearly-identical
//  upsert / delete / fetch-by-id boilerplate. These helpers centralize that
//  surface while preserving exact behavior:
//
//  - All access occurs inside `context.performAndWait` for thread safety.
//  - `WidgetRefresher.reloadAllTimelines()` fires on every successful save /
//    batchSave / delete by default. Callers that must not refresh widgets
//    (e.g. CadenceRepository, whose mutations do not affect widget content)
//    pass `refreshWidgets: false`.
//  - Errors are wrapped in `RepositoryError.saveFailed` / `.deleteFailed`
//    with the entity label supplied by the caller.
//
//  Helpers are free functions (not a base class) because the four repositories
//  conform to distinct protocols with different query surfaces; inheritance
//  would force generics across protocol boundaries without simplifying calls.
//
//  Callers supply a `fetchRequest:` closure that returns the codegen-generated
//  typed request (e.g. `PersonEntity.fetchRequest() as! NSFetchRequest<PersonEntity>`).
//  This is necessary because the Swift class names (e.g. `PersonEntity`,
//  `TagEntity`) do not match the `.xcdatamodel` entity names (`Person`, `Tag`),
//  so deriving the entity name from `String(describing:)` would be wrong.
//

import CoreData

// MARK: - Fetch one entity by UUID id

/// Fetches a single managed object by its `id` UUID using the supplied request.
///
/// Must be called from inside `context.perform` / `context.performAndWait`.
/// Used both by public `fetch(id:)` accessors (which wrap their own perform
/// block) and by internal upsert paths (which are already inside one).
func fetchEntityByID<Entity: NSManagedObject>(
    request: NSFetchRequest<Entity>,
    id: UUID,
    in context: NSManagedObjectContext
) -> Entity? {
    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    request.fetchLimit = 1
    return try? context.fetch(request).first
}

// MARK: - Save (upsert) one domain object

/// Upserts a domain object into its Core Data entity, saves the context, and
/// optionally reloads widget timelines.
///
/// - Parameters:
///   - id: Primary key on the entity (`id` attribute).
///   - fetchRequest: Factory returning a fresh typed fetch request for the
///     entity (e.g. `{ PersonEntity.fetchRequest() as! NSFetchRequest<PersonEntity> }`).
///     A new request is created per call so predicates don't leak between calls.
///   - entityLabel: Human-readable label used in `RepositoryError.saveFailed`.
///   - context: Backing context (used inside `performAndWait`).
///   - refreshWidgets: When true (default), fires `WidgetRefresher.reloadAllTimelines()`
///     after a successful save. Pass false for entities that do not affect widgets.
///   - apply: Closure that copies domain state onto a freshly-fetched-or-created entity.
func upsertEntity<Entity: NSManagedObject>(
    id: UUID,
    fetchRequest: @escaping () -> NSFetchRequest<Entity>,
    entityLabel: String,
    in context: NSManagedObjectContext,
    refreshWidgets: Bool = true,
    apply: @escaping (Entity) -> Void
) throws {
    do {
        try context.performAndWait {
            let entity = fetchEntityByID(request: fetchRequest(), id: id, in: context) ?? Entity(context: context)
            apply(entity)
            try context.save()
        }
        if refreshWidgets {
            WidgetRefresher.reloadAllTimelines()
        }
    } catch let error as RepositoryError {
        throw error
    } catch {
        throw RepositoryError.saveFailed(entity: entityLabel, underlying: error)
    }
}

// MARK: - Batch save (upsert) many domain objects

/// Upserts a sequence of domain objects in a single save. Identical semantics
/// to `upsertEntity` but groups all writes into one `context.save()` and one
/// widget refresh at the end.
func batchUpsertEntities<Entity: NSManagedObject, Domain>(
    _ domains: [Domain],
    id: (Domain) -> UUID,
    fetchRequest: @escaping () -> NSFetchRequest<Entity>,
    entityLabel: String,
    in context: NSManagedObjectContext,
    refreshWidgets: Bool = true,
    apply: @escaping (Domain, Entity) -> Void
) throws {
    do {
        try context.performAndWait {
            for domain in domains {
                let entity = fetchEntityByID(request: fetchRequest(), id: id(domain), in: context) ?? Entity(context: context)
                apply(domain, entity)
            }
            try context.save()
        }
        if refreshWidgets {
            WidgetRefresher.reloadAllTimelines()
        }
    } catch let error as RepositoryError {
        throw error
    } catch {
        throw RepositoryError.saveFailed(entity: entityLabel, underlying: error)
    }
}

// MARK: - Delete by id

// MARK: - Batch delete by ids

/// Deletes all entities whose `id` is in the supplied list in a single
/// `context.save()` and fires one widget refresh at the end. Missing ids
/// are no-ops (matches the singular `deleteEntityByID` contract). Empty
/// input is a no-op — no save, no refresh, no error.
///
/// Implementation uses an `IN` predicate to fetch the entities in one
/// round-trip, then `context.delete` each. We do not use
/// `NSBatchDeleteRequest` here because:
///   1. The caller hands us a small, known-bounded set of ids (cascade on
///      person deletion: typically <100 touch events). The fetch+delete
///      cost is negligible vs the upside of running through the regular
///      managed-object change-tracking path (which keeps any in-memory
///      faults / fetched results controllers consistent without the
///      merge-into-viewContext dance NSBatchDeleteRequest requires).
///   2. The cost being optimized is N transactions → 1 transaction (the
///      audit finding), not N object loads → 0 loads.
func batchDeleteEntitiesByID<Entity: NSManagedObject>(
    fetchRequest: @escaping () -> NSFetchRequest<Entity>,
    ids: [UUID],
    entityLabel: String,
    in context: NSManagedObjectContext,
    refreshWidgets: Bool = true
) throws {
    guard !ids.isEmpty else { return }
    do {
        try context.performAndWait {
            let request = fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", ids as CVarArg)
            let entities = (try? context.fetch(request)) ?? []
            guard !entities.isEmpty else { return }
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
        }
        if refreshWidgets {
            WidgetRefresher.reloadAllTimelines()
        }
    } catch let error as RepositoryError {
        throw error
    } catch {
        // Reuse `.deleteFailed` shape — we surface the first id for diagnostics.
        // Callers don't need per-id failure detail; the whole batch is atomic.
        throw RepositoryError.deleteFailed(entity: entityLabel, id: ids.first ?? UUID(), underlying: error)
    }
}

// MARK: - Delete by id

/// Deletes the entity with the given id, saves, and optionally reloads widget
/// timelines. A missing entity is a no-op (matches prior behavior — repos do
/// not throw on delete-of-nonexistent).
func deleteEntityByID<Entity: NSManagedObject>(
    fetchRequest: @escaping () -> NSFetchRequest<Entity>,
    id: UUID,
    entityLabel: String,
    in context: NSManagedObjectContext,
    refreshWidgets: Bool = true
) throws {
    do {
        try context.performAndWait {
            guard let entity = fetchEntityByID(request: fetchRequest(), id: id, in: context) else { return }
            context.delete(entity)
            try context.save()
        }
        if refreshWidgets {
            WidgetRefresher.reloadAllTimelines()
        }
    } catch let error as RepositoryError {
        throw error
    } catch {
        throw RepositoryError.deleteFailed(entity: entityLabel, id: id, underlying: error)
    }
}
