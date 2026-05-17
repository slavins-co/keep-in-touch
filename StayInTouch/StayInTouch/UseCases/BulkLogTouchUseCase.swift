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
        let touchEventsWritten: Int
        let peopleUpdated: Int
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
            return Result(touchEventsWritten: 0, peopleUpdated: 0, skippedPersonIds: skipped)
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
            touchEventsWritten: touchEvents.count,
            peopleUpdated: personUpdates.count,
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
