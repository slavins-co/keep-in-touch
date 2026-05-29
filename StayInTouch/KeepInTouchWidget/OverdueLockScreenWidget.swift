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
            trackedCount: snapshot.trackedCount,
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(circularAccessibilityLabel())
    }

    @ViewBuilder
    private func ringView(for ring: AccessoryWidgetLogic.CircularRing) -> some View {
        switch ring {
        case .empty:
            EmptyView()
        case .gauge(let overdueFraction, let dueSoonFraction):
            if renderingMode == .fullColor {
                // Red arc covers overdue portion; orange arc continues
                // for due-soon portion; remainder of the circumference
                // is the on-track portion (unfilled). Combined, the ring
                // shows both severity (color) and scale (fill).
                if overdueFraction > 0 {
                    ringStroke(from: 0, to: overdueFraction, color: .red)
                }
                if dueSoonFraction > 0 {
                    ringStroke(
                        from: overdueFraction,
                        to: overdueFraction + dueSoonFraction,
                        color: .orange
                    )
                }
            } else {
                // Monochrome lock screen / StandBy night — single tinted
                // arc fills the at-risk portion, giving a glanceable
                // gauge without color.
                ringStroke(
                    from: 0,
                    to: overdueFraction + dueSoonFraction,
                    color: .accentColor
                )
                .accentedIfAvailable()
            }
        }
    }

    private func circularAccessibilityLabel() -> String {
        let overdue = snapshot.overdueCount
        let dueSoon = snapshot.dueSoonCount
        let atRisk = overdue + dueSoon
        if atRisk == 0 {
            return snapshot.hasTrackedPeople
                ? "Keep In Touch. All caught up."
                : "Keep In Touch. Add someone to track."
        }
        var parts: [String] = []
        if overdue > 0 {
            parts.append("\(overdue) \(overdue == 1 ? "person" : "people") overdue")
        }
        if dueSoon > 0 {
            parts.append("\(dueSoon) due soon")
        }
        return "Keep In Touch. " + parts.joined(separator: ", ") + "."
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
        let birthday = AccessoryWidgetLogic.rectangularBirthday(snapshot: snapshot)
        Group {
            if let birthday {
                // An imminent birthday outranks the overdue line. Tap routes to
                // that person — or the overview when several share the day.
                birthdayContent(birthday)
                    .widgetURL(birthday.tapURL)
            } else if let featured = snapshot.featured.first {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rectangularAccessibilityLabel())
    }

    private func rectangularAccessibilityLabel() -> String {
        if let birthday = AccessoryWidgetLogic.rectangularBirthday(snapshot: snapshot) {
            let subject: String
            if birthday.sameDayAdditional > 0 {
                let others = birthday.sameDayAdditional
                subject = "\(birthday.name) and \(others) \(others == 1 ? "other" : "others") have birthdays \(birthday.dayPhrase)"
            } else {
                subject = "\(birthday.name)'s birthday is \(birthday.dayPhrase)"
            }
            if birthday.overdueCount > 0 {
                return "Keep In Touch. \(subject). \(birthday.overdueCount) \(birthday.overdueCount == 1 ? "person" : "people") need a reach-out."
            }
            return "Keep In Touch. \(subject)."
        }
        if let featured = snapshot.featured.first {
            let additional = max(0, snapshot.overdueCount + snapshot.dueSoonCount - 1)
            let primary: String
            switch featured.status {
            case .overdue(let days):
                primary = "\(featured.displayShortName), \(days) \(days == 1 ? "day" : "days") overdue"
            case .dueSoon(let days):
                primary = days == 0
                    ? "\(featured.displayShortName), due today"
                    : "\(featured.displayShortName), due in \(days) \(days == 1 ? "day" : "days")"
            }
            if additional > 0 {
                return "Keep In Touch. \(primary). \(additional) more \(additional == 1 ? "person" : "people") need a reach-out."
            }
            return "Keep In Touch. \(primary)."
        }
        if snapshot.hasTrackedPeople {
            return "Keep In Touch. All caught up."
        }
        return "Keep In Touch. Add someone to track."
    }

    private func birthdayContent(_ birthday: AccessoryWidgetLogic.RectangularBirthday) -> some View {
        let subtitle = AccessoryWidgetLogic.rectangularBirthdaySubtitle(birthday)
        return HStack(alignment: .center, spacing: 5) {
            Image(systemName: "birthday.cake.fill")
                .imageScale(.medium)
            VStack(alignment: .leading, spacing: 1) {
                Text(birthday.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private func featuredContent(_ featured: OverduePerson) -> some View {
        let additional = max(0, snapshot.overdueCount + snapshot.dueSoonCount - 1)
        let subtitle = AccessoryWidgetLogic.rectangularSubtitle(
            featuredStatus: featured.status,
            additionalAtRisk: additional
        )

        // Custom HStack instead of Label so we control the icon-to-text
        // gap (Label's default spacing eats lock-screen horizontal room
        // and truncates the subtitle). minimumScaleFactor lets SwiftUI
        // shrink the subtitle font slightly before clipping when names
        // run long.
        return HStack(alignment: .center, spacing: 5) {
            Image(systemName: "person.crop.circle.fill")
                .imageScale(.medium)
            VStack(alignment: .leading, spacing: 1) {
                Text(featured.displayShortName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }
}

// MARK: - Inline

struct AccessoryInlineView: View {
    let snapshot: WidgetDataProvider.Snapshot

    var body: some View {
        let label = AccessoryWidgetLogic.inlineLabel(snapshot: snapshot)
        Label(label.text, systemImage: label.symbol)
            .widgetURL(tapTargetURL())
            .accessibilityLabel(inlineAccessibilityLabel())
    }

    private func tapTargetURL() -> URL {
        if let featured = snapshot.featured.first {
            return DeepLinkRoute.person(featured.id).url()
        }
        return DeepLinkRoute.overdue.url()
    }

    private func inlineAccessibilityLabel() -> String {
        if let featured = snapshot.featured.first {
            let name = featured.displayShortName
            if snapshot.overdueCount > 0 {
                return "Keep In Touch. \(snapshot.overdueCount) overdue. \(name) is up next."
            }
            if snapshot.dueSoonCount > 0 {
                return "Keep In Touch. \(snapshot.dueSoonCount) due soon. \(name) is up next."
            }
        }
        if snapshot.hasTrackedPeople {
            return "Keep In Touch. All caught up."
        }
        return "Keep In Touch. Add someone to track."
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
