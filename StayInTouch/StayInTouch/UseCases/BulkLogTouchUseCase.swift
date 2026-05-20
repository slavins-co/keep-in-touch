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
        case reconcileFailed
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
        // 1. Delete prior events. Best-effort: a missing id (e.g. user
        // already deleted from history) doesn't fail the reconcile.
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
                throw Error.batchSaveFailed
            }
        }

        // 3. Recompute `lastTouch*` for every affected person from their
        // current event history. Newest event wins; if no events remain,
        // headline clears to nil (matches PersonDetailViewModel.deleteTouch).
        let affected = Set(priorPersonIds).union(finalPersonIds)
        var personUpdates: [Person] = []
        for personId in affected {
            guard var person = personRepository.fetch(id: personId) else { continue }
            let events = touchEventRepository.fetchAll(for: personId).sorted { $0.at > $1.at }
            if let latest = events.first {
                person.lastTouchAt = latest.at
                person.lastTouchMethod = latest.method
                person.lastTouchNotes = latest.notes
            } else {
                person.lastTouchAt = nil
                person.lastTouchMethod = nil
                person.lastTouchNotes = nil
            }
            person.modifiedAt = now
            personUpdates.append(person)
        }
        if !personUpdates.isEmpty {
            do {
                try personRepository.batchSave(personUpdates)
            } catch {
                AppLogger.logError(error, category: AppLogger.repository, context: "BulkLogTouchUseCase.reconcile.batchSavePersons")
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
}
