//
//  GetOverdueContactsIntent.swift
//  KeepInTouch
//
//  Returns the list of contacts whose connection cadence has breached.
//  Designed for use in Shortcuts chains — pipe the result into Choose
//  from List + Open, Show Notification, Speak, Send Message, etc.
//
//  Intentionally does NOT conform to ProvidesDialog. An always-on
//  "N contacts are overdue" banner showed even when the intent was
//  chained into another action, which is intrusive (manual QA on PR
//  #305 surfaced this). Downstream actions render the result however
//  the user wants.
//

import AppIntents
import Foundation

struct GetOverdueContactsIntent: AppIntent {
    static var title: LocalizedStringResource { "Get Overdue Contacts" }
    static var description: IntentDescription {
        IntentDescription(
            "Returns your contacts whose connection cadence has breached.",
            categoryName: "Queries"
        )
    }

    static var openAppWhenRun: Bool { false }

    static var parameterSummary: some ParameterSummary {
        Summary("Get overdue contacts")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[PersonAppEntity]> {
        let repository = IntentContainer.current.dependencies.personRepository
        let people = repository.fetchOverdue(referenceDate: Date())
        let entities = people.map(PersonAppEntity.init(person:))
        return .result(value: entities)
    }
}
