//
//  Date+Snooze.swift
//  KeepInTouch
//

import Foundation

extension Date {
    /// Initial date offered when the user opens the custom-due-date or
    /// snooze-date picker — 3 days from now. Computed (not stored) so the
    /// offset re-evaluates against `Date()` each time the picker opens.
    ///
    /// Falls back to `Date()` if the calendar math fails (it never does in
    /// practice — matches prior inline `?? Date()` behavior).
    ///
    /// **Byte-identical** to the prior inline:
    ///     Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    /// at PersonSettingsSection.swift:125 (custom due date picker) and :169
    /// (snooze date picker).
    static var defaultSnoozeStartDate: Date {
        Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    }
}
