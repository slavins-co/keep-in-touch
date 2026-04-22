//
//  KeepInTouchWidget.swift
//  KeepInTouchWidget
//
//  Placeholder scaffolding. Timeline provider fetches from Core Data
//  via the App Group container in a follow-up commit.
//

import SwiftUI
import WidgetKit

struct OverdueEntry: TimelineEntry {
    let date: Date
    let configuration: OverdueWidgetConfigurationIntent
}

struct OverdueTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OverdueEntry {
        OverdueEntry(date: Date(), configuration: OverdueWidgetConfigurationIntent())
    }

    func snapshot(for configuration: OverdueWidgetConfigurationIntent, in context: Context) async -> OverdueEntry {
        OverdueEntry(date: Date(), configuration: configuration)
    }

    func timeline(for configuration: OverdueWidgetConfigurationIntent, in context: Context) async -> Timeline<OverdueEntry> {
        let entry = OverdueEntry(date: Date(), configuration: configuration)
        let refreshAt = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(refreshAt))
    }
}

struct OverdueWidgetEntryView: View {
    var entry: OverdueEntry

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Keep In Touch")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(AppGroup.identifier)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct OverdueWidget: Widget {
    let kind: String = "OverdueWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: OverdueWidgetConfigurationIntent.self,
            provider: OverdueTimelineProvider()
        ) { entry in
            OverdueWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Keep In Touch")
        .description("Shows who needs a touch today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    OverdueWidget()
} timeline: {
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent())
}
