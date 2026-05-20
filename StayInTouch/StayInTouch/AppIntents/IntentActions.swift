//
//  IntentActions.swift
//  KeepInTouch
//
//  Thin facade that intents call. Mirrors the save-path side effects of
//  `PersonDetailViewModel.logTouch` step-for-step so logging via Siri,
//  Shortcuts, or the in-app modal produces identical state.
//
//  Specifically: TouchEvent save → BulkLogTouchUseCase.applyTouch →
//  Person save → `.personDidChange` post. The repository layer handles
//  WidgetRefresher; the `.personDidChange` post triggers
//  NotificationScheduler.scheduleAll() asynchronously.
//

import Foundation

struct IntentActions {
    let dependencies: AppDependencies

    init(dependencies: AppDependencies = IntentContainer.current.dependencies) {
        self.dependencies = dependencies
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

        AnalyticsService.track(
            "connection.logged",
            parameters: ["method": method.rawValue, "source": "siri"]
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
