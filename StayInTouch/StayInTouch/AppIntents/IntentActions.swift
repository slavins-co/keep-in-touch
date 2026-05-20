//
//  IntentActions.swift
//  KeepInTouch
//
//  Thin facade that intents call. Reuses the same recompute helper
//  (`BulkLogTouchUseCase.applyTouch`) that `PersonDetailViewModel.logTouch`
//  uses, so the headline `lastTouch*` rule and `snoozedUntil` /
//  `customDueDate` clearing stay in one place.
//
//  Side-effect sequence: TouchEvent save → applyTouch → Person save →
//  `.personDidChange` post. The repository layer handles WidgetRefresher;
//  the `.personDidChange` post triggers NotificationScheduler.scheduleAll().
//
//  Two intentional differences from `PersonDetailViewModel.logTouch`:
//   1. On TouchEvent save failure this throws `IntentError.saveFailed`
//      and skips the Person update. The UI path shows an error toast
//      and still attempts the Person update — but Siri/Shortcuts have
//      no toast surface, so the cleaner fail-fast is preferable.
//   2. Notes are trimmed (whitespace-only → nil) so Shortcuts users
//      can pass un-trimmed input from prior actions without polluting
//      the log.
//

import Foundation

struct IntentActions {
    let dependencies: AppDependencies
    let trackAnalytics: (_ signal: String, _ parameters: [String: String]) -> Void

    init(
        dependencies: AppDependencies = IntentContainer.current.dependencies,
        trackAnalytics: @escaping (String, [String: String]) -> Void = AnalyticsService.track
    ) {
        self.dependencies = dependencies
        self.trackAnalytics = trackAnalytics
    }

    /// Logs a touch for the given person id. Returns the updated Person
    /// (post `applyTouch`) for the caller to render a result snippet.
    /// Throws `IntentError` on failure paths intents should surface.
    @discardableResult
    func logTouch(
        personId: UUID,
        method: TouchMethod,
        notes: String?,
        date: Date,
        now: Date = Date()
    ) throws -> Person {
        guard let person = dependencies.personRepository.fetch(id: personId) else {
            throw IntentError.personNotFound
        }

        trackAnalytics(
            "connection.logged",
            ["method": method.rawValue, "source": "siri"]
        )

        let touch = TouchEvent(
            id: UUID(),
            personId: personId,
            at: date,
            method: method,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            timeOfDay: nil,
            createdAt: now,
            modifiedAt: now
        )

        do {
            try dependencies.touchEventRepository.save(touch)
        } catch {
            AppLogger.logError(
                error,
                category: AppLogger.viewModel,
                context: "IntentActions.logTouch (event save)"
            )
            throw IntentError.saveFailed
        }

        let updated = BulkLogTouchUseCase.applyTouch(to: person, event: touch, now: now)

        do {
            try dependencies.personRepository.save(updated)
        } catch {
            // Event was saved successfully; mirror the UI's behavior of
            // surfacing the failure but leaving the event in place
            // (`PersonDetailViewModel.logTouch` does the same).
            AppLogger.logError(
                error,
                category: AppLogger.viewModel,
                context: "IntentActions.logTouch (person save)"
            )
            throw IntentError.saveFailed
        }

        NotificationCenter.default.post(name: .personDidChange, object: updated.id)
        return updated
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
