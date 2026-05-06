//
//  OverdueLockScreenWidget.swift
//  KeepInTouchWidget
//
//  Lock Screen + StandBy accessory widgets (issue #279).
//  Shares the same `OverdueTimelineProvider` and configuration intent
//  as `OverdueWidget`. Layout/copy decisions delegate to the pure
//  `AccessoryWidgetLogic` helper so the SwiftUI shells stay thin.
//

import SwiftUI
import WidgetKit

// MARK: - Widget configuration

struct OverdueLockScreenWidget: Widget {
    let kind: String = "OverdueLockScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: OverdueWidgetConfigurationIntent.self,
            provider: OverdueTimelineProvider()
        ) { entry in
            LockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("Keep In Touch (Lock Screen)")
        .description("Quick glance at who's overdue. Lock Screen, StandBy, and accessory surfaces.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Entry dispatch

struct LockScreenEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: OverdueEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                AccessoryCircularView(snapshot: entry.snapshot)
            case .accessoryRectangular:
                AccessoryRectangularView(snapshot: entry.snapshot)
            case .accessoryInline:
                AccessoryInlineView(snapshot: entry.snapshot)
            default:
                AccessoryInlineView(snapshot: entry.snapshot)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Circular

struct AccessoryCircularView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let snapshot: WidgetDataProvider.Snapshot

    var body: some View {
        let ring = AccessoryWidgetLogic.ring(
            overdueCount: snapshot.overdueCount,
            dueSoonCount: snapshot.dueSoonCount,
            hasTrackedPeople: snapshot.hasTrackedPeople
        )
        let digit = AccessoryWidgetLogic.centerDigit(
            overdueCount: snapshot.overdueCount,
            dueSoonCount: snapshot.dueSoonCount,
            hasTrackedPeople: snapshot.hasTrackedPeople
        )

        ZStack {
            ringView(for: ring)
            centerView(digit: digit)
        }
        .widgetURL(DeepLinkRoute.overdue.url())
    }

    @ViewBuilder
    private func ringView(for ring: AccessoryWidgetLogic.CircularRing) -> some View {
        switch ring {
        case .empty:
            EmptyView()
        case .binary(let color):
            ringStroke(from: 0, to: 1, color: tint(for: color))
                .accentedIfAvailable()
        case .twoTone(let overdueFraction):
            if renderingMode == .fullColor {
                // Two-tone red + orange. Red arc covers the overdue
                // fraction; orange arc covers the rest.
                ringStroke(from: 0, to: overdueFraction, color: .red)
                ringStroke(from: overdueFraction, to: 1, color: .orange)
            } else {
                // Accented zone — on iOS 18+ this picks up the
                // wallpaper-derived accent color on lock screen.
                ringStroke(from: 0, to: 1, color: .accentColor)
                    .accentedIfAvailable()
            }
        }
    }

    /// Single ring arc. `from` and `to` are 0...1 fractions of the
    /// circumference. Rotated -90° so trim(from: 0) starts at 12 o'clock.
    /// 4pt stroke is wide enough to read clearly without color in
    /// monochrome accented rendering modes.
    private func ringStroke(from: Double, to: Double, color: Color) -> some View {
        Circle()
            .trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }

    private func tint(for ringColor: AccessoryWidgetLogic.RingColor) -> Color {
        switch ringColor {
        case .overdue: return renderingMode == .fullColor ? .red : .accentColor
        case .dueSoon: return renderingMode == .fullColor ? .orange : .accentColor
        }
    }

    @ViewBuilder
    private func centerView(digit: String?) -> some View {
        if let digit {
            // Bigger digit dominates the widget; small people icon stays
            // for "this is people" context. The digit is marked
            // .widgetAccentedRenderingMode(.accented) on iOS 18+ so it
            // picks up the wallpaper-derived accent color instead of
            // pure white in monochrome contexts.
            VStack(spacing: 0) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(digit)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .accentedIfAvailable()
            }
        } else {
            Image(systemName: snapshot.hasTrackedPeople ? "hand.wave.fill" : "person.crop.circle.badge.plus")
                .font(.title2)
                .foregroundStyle(.primary)
        }
    }
}

private extension View {
    /// Marks this zone as accented so the system applies the
    /// wallpaper-derived accent treatment in monochrome contexts
    /// (Lock Screen, StandBy night). iOS 16+.
    func accentedIfAvailable() -> some View {
        self.widgetAccentable(true)
    }
}

// MARK: - Rectangular

struct AccessoryRectangularView: View {
    let snapshot: WidgetDataProvider.Snapshot

    var body: some View {
        let additionalAtRisk = max(0, snapshot.overdueCount + snapshot.dueSoonCount - 1)
        Group {
            if let featured = snapshot.featured.first {
                featuredContent(featured)
                    // When there are more at-risk people beyond the
                    // featured one, route taps to the overdue list so
                    // the user can see the full set. Only when the
                    // featured person is the only at-risk do we deep
                    // link directly to their detail page.
                    .widgetURL(
                        additionalAtRisk > 0
                            ? DeepLinkRoute.overdue.url()
                            : DeepLinkRoute.person(featured.id).url()
                    )
            } else if snapshot.hasTrackedPeople {
                Label("All caught up", systemImage: "hand.wave.fill")
                    .font(.headline)
                    .widgetURL(DeepLinkRoute.overdue.url())
            } else {
                Label("Add someone to track", systemImage: "person.crop.circle.badge.plus")
                    .font(.headline)
                    .widgetURL(DeepLinkRoute.overdue.url())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func featuredContent(_ featured: OverduePerson) -> some View {
        let additional = max(0, snapshot.overdueCount + snapshot.dueSoonCount - 1)
        let subtitle = AccessoryWidgetLogic.rectangularSubtitle(
            featuredStatus: featured.status,
            additionalAtRisk: additional
        )

        // person.crop.circle.fill matches the inline + circular widgets
        // — gives Keep In Touch a visual identity on the lock screen
        // without needing app-name copy. Status urgency stays in the
        // subtitle text.
        return Label(
            title: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(featured.displayShortName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            },
            icon: {
                Image(systemName: "person.crop.circle.fill")
            }
        )
    }
}

// MARK: - Inline

struct AccessoryInlineView: View {
    let snapshot: WidgetDataProvider.Snapshot

    var body: some View {
        let label = AccessoryWidgetLogic.inlineLabel(snapshot: snapshot)
        Label(label.text, systemImage: label.symbol)
            .widgetURL(tapTargetURL())
    }

    private func tapTargetURL() -> URL {
        if let featured = snapshot.featured.first {
            return DeepLinkRoute.person(featured.id).url()
        }
        return DeepLinkRoute.overdue.url()
    }
}

// MARK: - Previews

#Preview(as: .accessoryCircular) {
    OverdueLockScreenWidget()
} timeline: {
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .placeholder)
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .allCaughtUp)
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .empty)
}

#Preview(as: .accessoryRectangular) {
    OverdueLockScreenWidget()
} timeline: {
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .placeholder)
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .allCaughtUp)
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .empty)
}

#Preview(as: .accessoryInline) {
    OverdueLockScreenWidget()
} timeline: {
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .placeholder)
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .allCaughtUp)
    OverdueEntry(date: .now, configuration: OverdueWidgetConfigurationIntent(), snapshot: .empty)
}
