//
//  AppIntent.swift
//  KeepInTouchWidget
//

import AppIntents
import WidgetKit

struct OverdueWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Keep In Touch" }
    static var description: IntentDescription { IntentDescription("Choose which group this widget shows.") }

    @Parameter(title: "Group")
    var group: GroupAppEntity?

    @Parameter(
        title: "Show Birthdays",
        description: "Fill empty space with upcoming birthdays when no one is overdue or due soon.",
        default: true
    )
    var showBirthdays: Bool
}
