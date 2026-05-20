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
            // Entity is stale (contact deleted since the shortcut was set
            // up). Route to Home so the app still surfaces something
            // useful and let the user re-pick.
            DeepLinkRouter.shared.pending = .home
            throw IntentError.personNotFound
        }
        DeepLinkRouter.shared.pending = .person(person.id)
        return .result()
    }
}
