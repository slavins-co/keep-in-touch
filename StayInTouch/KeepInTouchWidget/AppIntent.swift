//
//  AppIntent.swift
//  KeepInTouchWidget
//
//  Configuration intent for the overdue widget. Currently has no
//  configurable parameters; group-filter parameter is added in a
//  follow-up commit.
//

import AppIntents
import WidgetKit

struct OverdueWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Keep In Touch" }
    static var description: IntentDescription { IntentDescription("Shows who needs a touch today.") }
}
