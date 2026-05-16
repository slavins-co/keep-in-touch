//
//  WalkthroughStep.swift
//  KeepInTouch
//
//  Steps in the post-onboarding tutorial walkthrough.
//  Walkthrough A covers the Home view; Walkthrough B covers a demo PersonDetail.
//

import SwiftUI

enum WalkthroughStep: String, CaseIterable, Identifiable {
    // Walkthrough A — Home (7 steps)
    case welcome
    case homeOverdue
    case homeDueSoon
    case homeAllGood
    case homeFilters
    case homeSearch
    case homeSwipeDemo

    // Walkthrough B — Demo PersonDetail (5 steps)
    case detailHero
    case detailLogTouch
    case detailCadenceGroupTags
    case detailSettingsMenu
    case detailWrap

    var id: String { rawValue }

    enum Phase { case homeA, detailB }

    var phase: Phase {
        switch self {
        case .welcome, .homeOverdue, .homeDueSoon, .homeAllGood,
             .homeFilters, .homeSearch, .homeSwipeDemo:
            return .homeA
        case .detailHero, .detailLogTouch, .detailCadenceGroupTags,
             .detailSettingsMenu, .detailWrap:
            return .detailB
        }
    }

    /// The anchor identifier that the spotlight cutout should target.
    /// nil = centered card with no cutout (welcome / wrap / swipeDemo).
    var anchorID: String? {
        switch self {
        case .welcome, .homeSwipeDemo, .detailWrap:
            return nil
        case .homeOverdue:        return TutorialAnchor.sectionOverdue
        case .homeDueSoon:        return TutorialAnchor.sectionDueSoon
        case .homeAllGood:        return TutorialAnchor.sectionAllGood
        case .homeFilters:        return TutorialAnchor.frequencyFilter
        case .homeSearch:         return TutorialAnchor.searchBar
        case .detailHero:         return TutorialAnchor.personHero
        case .detailLogTouch:     return TutorialAnchor.personLogTouch
        case .detailCadenceGroupTags: return TutorialAnchor.personCadenceRow
        case .detailSettingsMenu: return TutorialAnchor.personMenuButton
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .welcome:                return "Welcome to Keep In Touch"
        case .homeOverdue:            return "Overdue"
        case .homeDueSoon:            return "Due Soon"
        case .homeAllGood:            return "All Good"
        case .homeFilters:            return "Focus by cadence"
        case .homeSearch:             return "Find someone fast"
        case .homeSwipeDemo:          return "Swipe to log a touch"
        case .detailHero:             return "Meet Alex"
        case .detailLogTouch:         return "One-tap logging"
        case .detailCadenceGroupTags: return "Set the rhythm"
        case .detailSettingsMenu:    return "More options here"
        case .detailWrap:             return "You're all set"
        }
    }

    var body: LocalizedStringKey {
        switch self {
        case .welcome:
            return "Let's take a quick tour so you can get the most out of it."
        case .homeOverdue:
            return "These are the folks you haven't reached out to in a while. They'll always sit at the top."
        case .homeDueSoon:
            return "Coming up on their next check-in. A gentle heads-up before they slip."
        case .homeAllGood:
            return "People you're on top of. Nothing needed right now."
        case .homeFilters:
            return "Filter to see just your close circle, or just your wider network."
        case .homeSearch:
            return "Search by name or nickname when you need to log a touch in a hurry."
        case .homeSwipeDemo:
            return "Right from this list — no taps to navigate."
        case .detailHero:
            return "The header shows their nickname, photo, and how long since you last connected."
        case .detailLogTouch:
            return "Record a call, text, or in-person meetup. We'll keep a private history just for you."
        case .detailCadenceGroupTags:
            return "Tap any of these to change how often you'd like to stay in touch, what circle they're in, or add tags."
        case .detailSettingsMenu:
            return "Snooze a reminder, pause check-ins entirely, or edit their birthday."
        case .detailWrap:
            return "Alex is a sample — they won't show up in your real list. Your contacts and history are yours alone, stored only on this device."
        }
    }

    var primaryCTA: LocalizedStringKey {
        switch self {
        case .welcome:        return "Show me around"
        case .homeSwipeDemo:  return "See a contact"
        case .detailWrap:     return "Start using Keep In Touch"
        default:              return "Got it"
        }
    }

    /// True for the very first step where the user can opt out before investing.
    var showsSkipButton: Bool {
        self == .welcome
    }

    /// True for steps rendered as a centered card with no spotlight cutout.
    var isCentered: Bool {
        anchorID == nil
    }
}

/// Stable identifiers for spotlight anchors. Views attach `.tutorialAnchor(TutorialAnchor.xxx)`
/// to make their bounds discoverable by the walkthrough overlay.
enum TutorialAnchor {
    static let sectionOverdue     = "section-overdue"
    static let sectionDueSoon     = "section-duesoon"
    static let sectionAllGood     = "section-allgood"
    static let frequencyFilter    = "frequency-filter"
    static let searchBar          = "search-bar"
    static let personHero         = "person-hero"
    static let personLogTouch     = "person-log-touch"
    static let personCadenceRow   = "person-cadence-row"
    static let personMenuButton   = "person-menu-button"
}
