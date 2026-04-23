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

protocol FrequencyCalculatorCadence {
    var id: UUID { get }
    var frequencyDays: Int { get }
    var warningDays: Int { get }
}
