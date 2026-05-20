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
            // Surface a graceful error dialog rather than re-prompting
            // via `$person.needsValueError`. The re-prompt path shows a
            // bare "Contact" picker with no indication why — confusing
            // UX. A clear "no longer in Keep In Touch" error tells the
            // user what happened and lets them edit the shortcut to
            // point at someone else.
            throw IntentError.personNotFound
        }
        DeepLinkRouter.shared.pending = .person(person.id)
        return .result()
    }
}
