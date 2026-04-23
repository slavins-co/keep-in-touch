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
}
