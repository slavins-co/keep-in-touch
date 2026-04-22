//
//  AppIntent.swift
//  KeepInTouchWidget
//
//  Configuration intent for the overdue widget. Lets the user scope a
//  widget instance to a single group, or leave it at "All groups".
//

import AppIntents
import WidgetKit

struct OverdueWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Keep In Touch" }
    static var description: IntentDescription { IntentDescription("Shows who needs a touch today.") }

    @Parameter(title: "Group", description: "Show only this group. Leave empty to show all.")
    var group: GroupAppEntity?
}
