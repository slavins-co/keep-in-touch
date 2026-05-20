//
//  KeepInTouchShortcuts.swift
//  KeepInTouch
//
//  AppShortcutsProvider — curated phrases that make our intents
//  discoverable in Spotlight, the Action Button, and Siri without the
//  user having to wire them up in the Shortcuts app first.
//
//  iOS allows ~10 phrases per provider; keep this list focused on the
//  highest-leverage entry points.
//

import AppIntents

struct KeepInTouchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogTouchIntent(),
            phrases: [
                "Log a touch in \(.applicationName)",
                "Log touch with \(\.$person) in \(.applicationName)",
                "Record a touch in \(.applicationName)",
            ],
            shortTitle: "Log Touch",
            systemImageName: "checkmark.circle.fill"
        )

        AppShortcut(
            intent: GetOverdueContactsIntent(),
            phrases: [
                "Who's overdue in \(.applicationName)",
                "Show overdue contacts in \(.applicationName)",
                "Who needs attention in \(.applicationName)",
            ],
            shortTitle: "Overdue Contacts",
            systemImageName: "exclamationmark.circle.fill"
        )

        AppShortcut(
            intent: GetDueSoonContactsIntent(),
            phrases: [
                "Who's due soon in \(.applicationName)",
                "Show due-soon contacts in \(.applicationName)",
            ],
            shortTitle: "Due-Soon Contacts",
            systemImageName: "clock.fill"
        )

        AppShortcut(
            intent: OpenPersonIntent(),
            phrases: [
                "Open \(\.$person) in \(.applicationName)",
                "Show \(\.$person) in \(.applicationName)",
            ],
            shortTitle: "Open Contact",
            systemImageName: "person.crop.circle"
        )
    }
}
