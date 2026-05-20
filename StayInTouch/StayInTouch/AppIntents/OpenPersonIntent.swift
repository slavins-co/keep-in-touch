//
//  OpenPersonIntent.swift
//  KeepInTouch
//
//  Deep-links into PersonDetailView for the chosen contact. Used as the
//  "open in app" step at the end of Shortcuts chains, and as a standalone
//  Siri command ("Open Mom in Keep In Touch").
//

import AppIntents
import Foundation

struct OpenPersonIntent: AppIntent {
    static var title: LocalizedStringResource { "Open Contact" }
    static var description: IntentDescription {
        IntentDescription(
            "Opens a contact's detail view in Keep In Touch.",
            categoryName: "Navigation"
        )
    }

    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Contact", description: "Who to open.")
    var person: PersonAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$person)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let repository = IntentContainer.current.dependencies.personRepository
        guard repository.fetch(id: person.id) != nil else {
            // Stale id (saved shortcut points at a now-deleted contact).
            // Re-prompt the user to pick a contact — the picker reads
            // more naturally than a "this contact was deleted" error,
            // and lets the user complete the action by choosing someone
            // else. The framework re-performs `perform()` with the new
            // value once a choice is made.
            throw $person.needsValueError(
                IntentDialog("That contact is no longer in Keep In Touch. Pick another to open.")
            )
        }
        DeepLinkRouter.shared.pending = .person(person.id)
        return .result()
    }
}
