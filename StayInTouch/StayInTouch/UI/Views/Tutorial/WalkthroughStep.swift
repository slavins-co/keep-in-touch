//
//  WalkthroughStep.swift
//  KeepInTouch
//
//  Steps in the post-onboarding tutorial walkthrough.
//  Walkthrough A covers the Home view; Walkthrough B covers a demo PersonDetail.
//

import SwiftUI

enum WalkthroughStep: String, CaseIterable, Identifiable {
    // Walkthrough A — Home (6 steps)
    case welcome
    case homeOverdue
    case homeDueSoon
    case homeAllGood
    case homeFilters
    case homeSearch

    // Walkthrough B — Demo PersonDetail (8 steps)
    case detailHero
    case detailQuickActions
    case detailLogTouch
    case detailNextTouchNotes
    case detailTimeline
    case detailCadenceGroupTags
    case detailSettingsMenu
    case detailWrap

    var id: String { rawValue }

    enum Phase { case homeA, detailB }

    var phase: Phase {
        switch self {
        case .welcome, .homeOverdue, .homeDueSoon, .homeAllGood,
             .homeFilters, .homeSearch:
            return .homeA
        case .detailHero, .detailQuickActions, .detailLogTouch,
             .detailNextTouchNotes, .detailTimeline, .detailCadenceGroupTags,
             .detailSettingsMenu, .detailWrap:
            return .detailB
        }
    }

    /// The anchor identifier that the spotlight cutout should target.
    /// nil = centered card with no cutout (welcome / wrap).
    var anchorID: String? {
        switch self {
        case .welcome, .detailWrap:
            return nil
        case .homeOverdue:        return TutorialAnchor.sectionOverdue
        case .homeDueSoon:        return TutorialAnchor.sectionDueSoon
        case .homeAllGood:        return TutorialAnchor.sectionAllGood
        case .homeFilters:        return TutorialAnchor.frequencyFilter
        case .homeSearch:         return TutorialAnchor.searchBar
        case .detailHero:         return TutorialAnchor.personHero
        case .detailQuickActions: return TutorialAnchor.personQuickActions
        case .detailLogTouch:     return TutorialAnchor.personLogTouch
        case .detailNextTouchNotes: return TutorialAnchor.personNextTouchNotes
        case .detailTimeline:     return TutorialAnchor.personTimeline
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
        case .detailHero:             return "Meet Alex"
        case .detailQuickActions:     return "Quick connect"
        case .detailLogTouch:         return "One-tap logging"
        case .detailNextTouchNotes:   return "Notes for next time"
        case .detailTimeline:         return "Connection history"
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
            return "Search by name or nickname when you need to log a touch in a hurry. Let's see what a contact looks like."
        case .detailHero:
            return "The header shows their nickname, birthday, and how long since you last connected."
        case .detailQuickActions:
            return "Message, call, or email straight from here — we'll log it to history automatically."
        case .detailLogTouch:
            return "Record any in-person catch-up or other connection in one tap. We'll keep a private history just for you."
        case .detailNextTouchNotes:
            return "Jot a thread to pick up later. We'll surface it the next time you're catching up."
        case .detailTimeline:
            return "Every text, call, and meetup — your private timeline. Tap an entry to edit or remove it."
        case .detailCadenceGroupTags:
            return "Change how often you'd like to stay in touch, what circle they're in, or add tags from this card."
        case .detailSettingsMenu:
            return "Snooze a reminder, pause check-ins entirely, or fine-tune notification timing here."
        case .detailWrap:
            return "Alex is a sample — they won't show up in your real list. Your contacts and history are yours alone, stored only on this device."
        }
    }

    var primaryCTA: LocalizedStringKey {
        switch self {
        case .welcome:        return "Show me around"
        case .homeSearch:     return "See a contact"
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
    static let sectionOverdue        = "section-overdue"
    static let sectionDueSoon        = "section-duesoon"
    static let sectionAllGood        = "section-allgood"
    static let frequencyFilter       = "frequency-filter"
    static let searchBar             = "search-bar"
    static let personHero            = "person-hero"
    static let personQuickActions    = "person-quick-actions"
    static let personLogTouch        = "person-log-touch"
    static let personNextTouchNotes  = "person-next-touch-notes"
    static let personTimeline        = "person-timeline"
    static let personCadenceRow      = "person-cadence-row"
    static let personMenuButton      = "person-menu-button"
}
