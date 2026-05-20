//
//  GetOverdueContactsIntent.swift
//  KeepInTouch
//
//  Returns the list of contacts whose touch cadence has breached.
//  Designed for use in Shortcuts chains — pipe the result into Show
//  Notification, Speak, Send Message, etc.
//

import AppIntents
import Foundation

struct GetOverdueContactsIntent: AppIntent {
    static var title: LocalizedStringResource { "Get Overdue Contacts" }
    static var description: IntentDescription {
        IntentDescription(
            "Returns your contacts whose touch cadence has breached.",
            categoryName: "Queries"
        )
    }

    static var openAppWhenRun: Bool { false }

    static var parameterSummary: some ParameterSummary {
        Summary("Get overdue contacts")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[PersonAppEntity]> & ProvidesDialog {
        let repository = IntentContainer.current.dependencies.personRepository
        let people = repository.fetchOverdue(referenceDate: Date())
        let entities = people.map(PersonAppEntity.init(person:))
        let dialog = PersonListDialog.make(
            for: entities,
            emptyMessage: "Nothing's overdue right now.",
            singularSuffix: "is overdue",
            pluralPredicate: "are overdue"
        )
        return .result(value: entities, dialog: dialog)
    }
}
