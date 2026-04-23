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
    static func loadSnapshot(now: Date = Date(), groupFilter: UUID? = nil) -> Snapshot {
        guard let context = WidgetCoreData.shared?.viewContext else {
            return Snapshot(
                overdueCount: 0,
                dueSoonCount: 0,
                featured: [],
                hasTrackedPeople: false,
                themeOverride: nil
            )
        }
        return snapshot(context: context, now: now, groupFilter: groupFilter)
    }
}
