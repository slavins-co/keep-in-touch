//
//  LogTouchIntent.swift
//  KeepInTouch
//
//  Logs a touch event for a contact. Headline v1 intent — wired into
//  AppShortcutsProvider phrases for Siri, Spotlight, and the Action
//  Button.
//

import AppIntents
import Foundation

struct LogTouchIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Connection" }
    static var description: IntentDescription {
        IntentDescription(
            "Log a connection with a contact — the method (call, text, in person, etc.), optional notes, and the date.",
            categoryName: "Logging"
        )
    }

    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Contact", description: "Who you connected with.")
    var person: PersonAppEntity

    @Parameter(title: "Method", description: "How you connected.", default: .text)
    var method: TouchMethod

    @Parameter(
        title: "Notes",
        description: "Optional notes about this connection."
    )
    var notes: String?

    @Parameter(
        title: "Date",
        description: "When the connection happened. Defaults to now."
    )
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Log a \(\.$method) connection with \(\.$person)") {
            \.$date
            \.$notes
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let when = date ?? Date()
        do {
            let updated = try IntentActions().logTouch(
                personId: person.id,
                method: method,
                notes: notes,
                date: when
            )
            let dialog = IntentDialog("Logged a \(method.verb) with \(updated.displayName).")
            return .result(dialog: dialog)
        } catch let error as IntentError {
            throw error
        } catch {
            throw IntentError.saveFailed
        }
    }
}
