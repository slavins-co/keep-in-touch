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
        let dialog: IntentDialog
        switch entities.count {
        case 0:
            dialog = IntentDialog("Nothing's overdue right now.")
        case 1:
            dialog = IntentDialog("One contact is overdue: \(entities[0].displayName).")
        default:
            dialog = IntentDialog("\(entities.count) contacts are overdue.")
        }
        return .result(value: entities, dialog: dialog)
    }
}
