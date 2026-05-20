//
//  GetDueSoonContactsIntent.swift
//  KeepInTouch
//
//  Returns contacts inside the user's "due soon" window — the cadence's
//  `warningDays` zone before breach. Classification matches the Home tab's
//  Due Soon section so Shortcut output stays consistent with the app UI.
//

import AppIntents
import Foundation

struct GetDueSoonContactsIntent: AppIntent {
    static var title: LocalizedStringResource { "Get Due-Soon Contacts" }
    static var description: IntentDescription {
        IntentDescription(
            "Returns your contacts who are due soon — inside the warning window before they go overdue.",
            categoryName: "Queries"
        )
    }

    static var openAppWhenRun: Bool { false }

    static var parameterSummary: some ParameterSummary {
        Summary("Get due-soon contacts")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[PersonAppEntity]> & ProvidesDialog {
        let deps = IntentContainer.current.dependencies
        // Both fetches hit Core Data independently — overlap them so cold
        // Siri launches don't pay the latency twice.
        async let peopleTask = Task { deps.personRepository.fetchTracked(includePaused: false) }.value
        async let cadencesTask = Task { deps.cadenceRepository.fetchAll() }.value
        let people = await peopleTask
        let cadences = await cadencesTask
        let dueSoon = PersonStatusService().dueSoonPeople(people, cadences: cadences)
        let entities = dueSoon.map(PersonAppEntity.init(person:))
        let dialog = PersonListDialog.make(
            for: entities,
            emptyMessage: "Nothing's coming due in your warning window.",
            singularSuffix: "is due soon",
            pluralPredicate: "are due soon"
        )
        return .result(value: entities, dialog: dialog)
    }
}
