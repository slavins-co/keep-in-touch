//
//  FrequencyCalculatorProtocols.swift
//  KeepInTouch (Shared)
//
//  Narrow protocols that `FrequencyCalculator` reads from. Lets the
//  widget extension drive the same SLA logic using lightweight adapter
//  structs built from Core Data entities, without moving the full
//  Domain layer (`Person`, `Cadence`, etc.) into Shared/.
//

import Foundation

protocol FrequencyCalculatorPerson {
    var isPaused: Bool { get }
    var snoozedUntil: Date? { get }
    var cadenceId: UUID { get }
    var lastTouchAt: Date? { get }
    var customDueDate: Date? { get }
    var cadenceAddedAt: Date? { get }
}

extension FrequencyCalculatorPerson {
    /// Whether this person is currently snoozed at the given moment.
    /// Returns `true` only when `snoozedUntil` is set and is strictly in
    /// the future relative to `date`. Single source of truth — every
    /// caller that previously inlined `if let s = snoozedUntil, s > Date()`
    /// or `snoozedUntil.map { $0 > Date() } ?? false` should route through
    /// this method (see issue #307, audit finding R4).
    func isSnoozed(at date: Date = Date()) -> Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > date
    }
}

protocol FrequencyCalculatorCadence {
    var id: UUID { get }
    var frequencyDays: Int { get }
    var warningDays: Int { get }
}
