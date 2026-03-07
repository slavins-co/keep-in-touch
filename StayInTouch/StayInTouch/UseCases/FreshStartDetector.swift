//
//  FreshStartDetector.swift
//  KeepInTouch
//

import Foundation

struct FreshStartDetector {

    struct Input {
        let trackedCount: Int
        let overdueCount: Int
        let lastAppOpenedAt: Date?
        let lastDismissedAt: Date?
        let referenceDate: Date
    }

    enum Result: Equatable {
        case showPrompt(reason: Reason)
        case doNotShow
    }

    enum Reason: Equatable, Identifiable {
        case overwhelmed
        case inactive
        case both

        var id: String {
            switch self {
            case .overwhelmed: return "overwhelmed"
            case .inactive:    return "inactive"
            case .both:        return "both"
            }
        }
    }

    // MARK: - Thresholds

    static let minimumTrackedContacts = 5
    static let inactivityDays = 14
    static let cooldownDays = 30

    static func overdueThreshold(for trackedCount: Int) -> Double {
        switch trackedCount {
        case ..<10:  return 0.80
        case ..<20:  return 0.70
        default:     return 0.60
        }
    }

    // MARK: - Evaluation

    func evaluate(_ input: Input) -> Result {
        guard input.trackedCount >= Self.minimumTrackedContacts else {
            return .doNotShow
        }

        if let dismissed = input.lastDismissedAt {
            let daysSinceDismissal = Calendar.current.dateComponents(
                [.day], from: dismissed, to: input.referenceDate
            ).day ?? 0
            if daysSinceDismissal < Self.cooldownDays {
                return .doNotShow
            }
        }

        let threshold = Self.overdueThreshold(for: input.trackedCount)
        let overdueRatio = Double(input.overdueCount) / Double(input.trackedCount)
        let isOverwhelmed = overdueRatio >= threshold

        var isInactive = false
        if let lastOpened = input.lastAppOpenedAt {
            let daysSinceOpen = Calendar.current.dateComponents(
                [.day], from: lastOpened, to: input.referenceDate
            ).day ?? 0
            isInactive = daysSinceOpen >= Self.inactivityDays
        }

        switch (isOverwhelmed, isInactive) {
        case (true, true):   return .showPrompt(reason: .both)
        case (true, false):  return .showPrompt(reason: .overwhelmed)
        case (false, true):  return .showPrompt(reason: .inactive)
        case (false, false): return .doNotShow
        }
    }
}
