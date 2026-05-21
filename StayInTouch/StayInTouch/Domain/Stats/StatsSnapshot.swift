//
//  StatsSnapshot.swift
//  KeepInTouch
//

import Foundation

struct StatsSnapshot: Equatable, Codable {
    let range: StatsRange
    let generatedAt: Date
    let state: State

    enum State: Equatable, Codable {
        /// No people, no events — first-run empty state.
        case empty
        /// People exist but no events landed in the selected range.
        case emptyForRange
        /// Ready to display.
        case ready(cadenceRows: [CadenceRow], methodRows: [MethodRow], totalEvents: Int)
    }

    struct CadenceRow: Equatable, Identifiable, Codable {
        let id: UUID            // Cadence id
        let name: String
        let frequencyDays: Int
        let trackedCount: Int
        let expected: Int
        let actual: Int
        /// `nil` means the row can't be expressed as a ratio — either
        /// no tracked people or the selected range is shorter than the
        /// cadence frequency. View renders an explanation instead of a bar.
        let ratio: Double?
    }

    struct MethodRow: Equatable, Identifiable, Codable {
        let method: TouchMethod
        let count: Int
        let percent: Double

        var id: String { method.rawValue }
    }
}
