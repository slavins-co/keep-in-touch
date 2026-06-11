//
//  WidgetDataProvider+Loader.swift
//  KeepInTouchWidget
//
//  Widget-only wrapper around the shared `WidgetDataProvider.snapshot`
//  that resolves the App Group Core Data context via `WidgetCoreData`.
//  Stays in the widget target because `WidgetCoreData` is not shared.
//

import CoreData
import Foundation

extension WidgetDataProvider {
    static func loadSnapshot(now: Date = Date(), groupFilter: UUID? = nil, showBirthdays: Bool = true) -> Snapshot {
        guard let context = WidgetCoreData.shared?.viewContext else {
            return Snapshot(
                overdueCount: 0,
                dueSoonCount: 0,
                featured: [],
                hasTrackedPeople: false,
                trackedCount: 0,
                themeOverride: nil,
                upcomingBirthdays: [],
                birthdaysFillWidget: showBirthdays
            )
        }
        return snapshot(context: context, now: now, groupFilter: groupFilter, showBirthdays: showBirthdays)
    }

    /// Loads upcoming birthdays for the dedicated Birthday widget, plus the
    /// app theme override so it renders with the same scheme as the overdue
    /// widget. Returns empty / nil when the App Group store is unavailable.
    static func loadBirthdays(
        now: Date = Date(),
        within days: Int = birthdayWindowDays,
        limit: Int = 5
    ) -> (birthdays: [BirthdaySummary], theme: String?) {
        guard let context = WidgetCoreData.shared?.viewContext else {
            return ([], nil)
        }
        return context.performAndWait {
            (upcomingBirthdays(context: context, now: now, within: days, limit: limit), themeOverride(context: context))
        }
    }
}
