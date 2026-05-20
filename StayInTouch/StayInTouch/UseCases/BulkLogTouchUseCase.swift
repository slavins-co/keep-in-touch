//
//  BulkLogTouchUseCase.swift
//  KeepInTouch
//

import Foundation

/// Writes one `TouchEvent` per selected person for a shared group hangout
/// and updates each person's denormalized `lastTouch*` headline fields
/// only when the new event is the newest one on record (the "newest wins"
/// rule). A back-dated group dinner still appears in every person's
/// timeline; it just doesn't bump someone's headline past a more recent
/// solo touch.
struct BulkLogTouchUseCase {
    struct Result: Equatable {
        /// Events actually persisted by the operation. The caller stashes
        /// these on the `BatchEditContext` so a subsequent reconcile knows
        /// which prior events to delete.
        let writtenEvents: [TouchEvent]
        let peopleUpdated: Int
        let skippedPersonIds: [UUID]

        var touchEventsWritten: Int { writtenEvents.count }
    }

    /// Result of a reconcile (wipe-and-rewrite) pass: how many net events
    /// were added versus removed from the prior batch, plus the new
    /// `writtenEvents` so the caller can stash them on a fresh
    /// `BatchEditContext` for the next round.
    struct ReconcileResult: Equatable {
        let writtenEvents: [TouchEvent]
        let added: Int
        let removed: Int
        let skippedPersonIds: [UUID]
    }

    enum Error: Swift.Error, Equatable {
        case batchSaveFailed
        case personUpdateFailed
    }

    private let personRepository: PersonRepository
    private let touchEventRepository: TouchEventRepository

    init(personRepository: PersonRepository, touchEventRepository: TouchEventRepository) {
        self.personRepository = personRepository
        self.touchEventRepository = touchEventRepository
    }

    /// Logs the same touch (method / date / notes / timeOfDay) for every
    /// person in `personIds`. Persons that no longer exist are skipped
    /// and returned in `skippedPersonIds`.
    ///
    /// Two-step commit:
    /// 1. `batchSave` all TouchEvents (atomic per Core Data save).
    /// 2. Update each Person's denormalized fields under the newest-wins
    ///    rule, then `batchSave` Persons. On step-2 failure, written
    ///    TouchEvents are rolled back so the caller can retry from a
    ///    clean state.
    @discardableResult
    func execute(
        personIds: [UUID],
        method: TouchMethod,
        notes: String?,
        date: Date,
        timeOfDay: TimeOfDay? = nil,
        now: Date = Date()
    ) throws -> Result {
        var touchEvents: [TouchEvent] = []
        var personUpdates: [Person] = []
        var skipped: [UUID] = []

        for personId in personIds {
            guard let person = personRepository.fetch(id: personId) else {
                skipped.append(personId)
                continue
            }
            let event = TouchEvent(
                id: UUID(),
                personId: personId,
                at: date,
                method: method,
                notes: notes,
                timeOfDay: timeOfDay,
                createdAt: now,
                modifiedAt: now
            )
            touchEvents.append(event)
            personUpdates.append(Self.applyTouch(to: person, event: event, now: now))
        }

        guard !touchEvents.isEmpty else {
            return Result(writtenEvents: [], peopleUpdated: 0, skippedPersonIds: skipped)
        }

        do {
            try touchEventRepository.batchSave(touchEvents)
        } catch {
            AppLogger.logError(error, category: AppLogger.repository, context: "BulkLogTouchUseCase.batchSaveEvents")
            throw Error.batchSaveFailed
        }

        do {
            try personRepository.batchSave(personUpdates)
        } catch {
            AppLogger.logError(error, category: AppLogger.repository, context: "BulkLogTouchUseCase.batchSavePersons")
            // Rollback the events so caller can retry from a clean state.
            for event in touchEvents {
                try? touchEventRepository.delete(id: event.id)
            }
            throw Error.personUpdateFailed
        }

        WidgetRefresher.reloadAllTimelines()
        return Result(
            writtenEvents: touchEvents,
            peopleUpdated: personUpdates.count,
            skippedPersonIds: skipped
        )
    }

    /// Wipe-and-rewrite reconcile of a previously-committed batch. Used
    /// by the "Forgot someone?" / batch-edit flow.
    ///
    /// Semantics:
    /// 1. Delete every event in `priorEventIds` (these are the events
    ///    written by the prior pass we're now editing).
    /// 2. Write a fresh `TouchEvent` for every person in `finalPersonIds`
    ///    using the current form values (`method` / `date` / `notes` /
    ///    `timeOfDay`).
    /// 3. For every person in the affected set (`priorPersonIds ∪
    ///    finalPersonIds`), recompute the denormalized `lastTouch*`
    ///    fields from the now-current event history — newest event wins,
    ///    or nil if no events remain. This mirrors the recompute logic
    ///    used by single-event delete in `PersonDetailViewModel`.
    ///
    /// People whose record no longer exists are dropped from the rewrite
    /// (returned in `skippedPersonIds`); their prior events are still
    /// deleted.
    @discardableResult
    func reconcile(
        priorEventIds: [UUID],
        priorPersonIds: [UUID],
        finalPersonIds: [UUID],
        method: TouchMethod,
        notes: String?,
        date: Date,
        timeOfDay: TimeOfDay? = nil,
        now: Date = Date()
    ) throws -> ReconcileResult {
        // 1. SNAPSHOT prior events before deleting. If step 2 fails we
        // restore via `batchSave(snapshot)` so the user doesn't lose
        // their prior batch on a transient Core Data error.
        let snapshot: [TouchEvent] = priorEventIds.compactMap {
            touchEventRepository.fetch(id: $0)
        }
        for id in priorEventIds {
            try? touchEventRepository.delete(id: id)
        }

        // 2. Write fresh events for final people who still exist.
        var writtenEvents: [TouchEvent] = []
        var skipped: [UUID] = []
        for personId in finalPersonIds {
            guard personRepository.fetch(id: personId) != nil else {
                skipped.append(personId)
                continue
            }
            let event = TouchEvent(
                id: UUID(),
                personId: personId,
                at: date,
                method: method,
                notes: notes,
                timeOfDay: timeOfDay,
                createdAt: now,
                modifiedAt: now
            )
            writtenEvents.append(event)
        }
        if !writtenEvents.isEmpty {
            do {
                try touchEventRepository.batchSave(writtenEvents)
            } catch {
                AppLogger.logError(error, category: AppLogger.repository, context: "BulkLogTouchUseCase.reconcile.batchSave")
                // Rollback: re-save the snapshot we deleted in step 1.
                // Best-effort — if this also fails we have lost data,
                // but at least we log loudly so the failure is visible.
                if !snapshot.isEmpty {
                    do {
                        try touchEventRepository.batchSave(snapshot)
                    } catch let rollbackError {
                        AppLogger.logError(rollbackError, category: AppLogger.repository, context: "BulkLogTouchUseCase.reconcile.rollback.batchSave — DATA LOSS: \(snapshot.count) prior events not restored")
                    }
                }
                throw Error.batchSaveFailed
            }
        }

        // 3. Recompute `lastTouch*` for every affected person from their
        // current event history via the shared `recomputeLastTouch`
        // helper — the same helper PersonDetailViewModel.deleteTouch
        // uses, so single-event-undo and bulk-reconcile stay aligned.
        let affected = Set(priorPersonIds).union(finalPersonIds)
        var personUpdates: [Person] = []
        for personId in affected {
            guard let person = personRepository.fetch(id: personId) else { continue }
            let events = touchEventRepository.fetchAll(for: personId)
            personUpdates.append(Self.recomputeLastTouch(for: person, from: events, now: now))
        }
        if !personUpdates.isEmpty {
            do {
                try personRepository.batchSave(personUpdates)
            } catch {
                AppLogger.logError(error, category: AppLogger.repository, context: "BulkLogTouchUseCase.reconcile.batchSavePersons")
                // Events are already written; we can't cleanly roll back
                // step 2 without re-introducing the snapshot conflict.
                // Surface the failure so the caller knows the headline
                // recompute didn't complete.
                throw Error.personUpdateFailed
            }
        }

        WidgetRefresher.reloadAllTimelines()

        let unchangedCount = Set(priorPersonIds).intersection(finalPersonIds).count
        return ReconcileResult(
            writtenEvents: writtenEvents,
            added: writtenEvents.count - unchangedCount,
            removed: priorEventIds.count - unchangedCount,
            skippedPersonIds: skipped
        )
    }

    /// Newest-wins update of a person's denormalized `lastTouch*` fields.
    /// Exposed `static` so the single-touch path can adopt the same rule
    /// without duplicating it.
    ///
    /// Rule: only overwrite `lastTouch*` when the new event is at least
    /// as recent as the current `lastTouchAt` (treating `nil` as
    /// `.distantPast`). `snoozedUntil` and `customDueDate` are cleared
    /// only when the headline actually changes — back-dated touches
    /// shouldn't silently wipe a future snooze/due-date the user set.
    static func applyTouch(to person: Person, event: TouchEvent, now: Date) -> Person {
        var updated = person
        let existing = person.lastTouchAt ?? .distantPast
        if event.at >= existing {
            updated.lastTouchAt = event.at
            updated.lastTouchMethod = event.method
            updated.lastTouchNotes = event.notes
            updated.snoozedUntil = nil
            updated.customDueDate = nil
        }
        updated.modifiedAt = now
        return updated
    }

    /// Pure helper: returns a copy of `person` with denormalized
    /// `lastTouch*` headline fields set from the newest event in
    /// `events`, or cleared to nil if `events` is empty.
    ///
    /// Used by any operation that REMOVES events (single delete via
    /// `PersonDetailViewModel.deleteTouch`, bulk reconcile in
    /// `BulkLogTouchUseCase.reconcile`) so the recompute lives in one
    /// place. Sorts internally — caller doesn't have to pass a
    /// pre-sorted array. Does not touch `snoozedUntil` or
    /// `customDueDate` (matches the prior PersonDetailViewModel
    /// behavior — undoing a touch doesn't unsnooze).
    static func recomputeLastTouch(for person: Person, from events: [TouchEvent], now: Date) -> Person {
        var updated = person
        if let latest = events.max(by: { $0.at < $1.at }) {
            updated.lastTouchAt = latest.at
            updated.lastTouchMethod = latest.method
            updated.lastTouchNotes = latest.notes
        } else {
            updated.lastTouchAt = nil
            updated.lastTouchMethod = nil
            updated.lastTouchNotes = nil
        }
        updated.modifiedAt = now
        return updated
    }
}
