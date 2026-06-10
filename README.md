# Keep In Touch

> Privacy-first iOS app to maintain friendships through gentle reminders and relationship tracking.

[![Platform](https://img.shields.io/badge/platform-iOS%2017.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-Proprietary-lightgrey.svg)](LICENSE)

**Version:** 0.5.0 (Build 14) | **Status:** Pre-release Beta

---

## What is Keep In Touch?

Never lose track of the people who matter. Keep In Touch helps you maintain friendships by:

- **Tracking when you last connected** with friends and family
- **Organizing contacts by frequency** (Weekly, Bi-Weekly, Monthly, Quarterly)
- **Sending gentle reminders** when it's time to reconnect
- **Keeping everything private** - all data stays on your device

---

## Current Status

V0.5.0 is the biggest release yet. Connection logging now works hands-free through **Siri Shortcuts and App Intents** ("Log a call with Sarah"), a new **Stats & Insights** dashboard shows how your real behavior compares to your intentions, and **Lock Screen + StandBy widgets** (plus upcoming birthdays in the widget family) keep relationships visible at a glance. A **self-guided tutorial** walks new users through the core flow, **group hangouts** can be logged for everyone at once, and a dedicated **Snoozed Contacts** view makes paused relationships easy to manage. Under the hood, a sweeping tech-debt audit (15+ PRs) delivered faster cold launches, batched saves, unified status logic, and concurrency-warning cleanup.

**Up next:** App Store submission. See [open issues](https://github.com/slavins-co/keep-in-touch/issues) and [release history](https://github.com/slavins-co/keep-in-touch/releases) for details.

---

## Features

**Core**
- Siri Shortcuts & App Intents - log touches, query overdue/due-soon, and open contacts hands-free
- Stats & Insights dashboard - performance vs. intent plus a method breakdown
- iOS home screen widget (small and medium) with interactive tap-to-log
- Lock Screen and StandBy accessory widgets
- Upcoming birthdays surfaced in the widget family
- Self-guided interactive tutorial with contextual tips (TipKit)
- Bulk "log connection" for group hangouts
- Snoozed Contacts management view
- Tab bar navigation with Home, Contacts, and Settings tabs
- Home screen with status summary cards, sticky sections, and floating search
- "All caught up" banner on Home when no contacts are overdue
- Nickname display and search across contact lists and detail
- A-Z Contacts tab with section index and search
- Full-screen contact detail with hero section, action buttons, and timeline history
- Connection logging with method tracking (Text, Call, In Person, Email, FaceTime, Other)
- FaceTime support and flexible messenger routing on the Call button
- Frequency-based contact groups with configurable cadences
- Custom due dates per contact (overrides group frequency)
- Contact photos from iOS Contacts with colorful initials fallback
- Birthday display from address book with manual override
- Birthday push notifications with per-person toggle and grouped alerts
- Notification privacy mode (hide contact names on lock screen)
- Foreground notification delivery (in-app banner)
- Snooze and pause tracking per contact
- Multiple groups per contact displayed on contact cards
- "Link to Contact" recovery for contacts unavailable in address book
- Fresh Start auto-prompt for inactive or overwhelmed users
- "Next Time" notes for conversation context
- Local notifications with quick-log actions
- Half-height picker sheets for dates, times, frequency, and groups
- Full connection history with edit and delete
- JSON import and export with deduplication and conflict resolution
- CSV export for spreadsheet use
- Centralized design system with adaptive dark/light mode tokens
- Portrait-only orientation on iPhone

**Privacy & Security**
- All data stored locally on device (Core Data, encrypted at rest by iOS)
- Screenshot blur protection when the app is backgrounded (hides contacts in the app switcher)
- No cloud sync, no advertising, no cross-app tracking
- Anonymous usage analytics via [TelemetryDeck](https://telemetrydeck.com) (opt-out in Settings)
- Read-only Contacts access (fetched on-demand, never stored externally)
- One third-party dependency (TelemetryDeck); everything else is Apple frameworks
- [Privacy policy](docs/privacy-policy.md)

---

## Tech Stack

**iOS 17+ · Swift · SwiftUI · Core Data · Clean Architecture**

No external dependencies beyond [TelemetryDeck](https://telemetrydeck.com) for anonymous analytics. Built with SwiftUI, Core Data, Contacts, UserNotifications, and BackgroundTasks.

---

## Getting Started

**TestFlight:** v0.5.0 (Build 14) available. Join via [TestFlight](https://testflight.apple.com/join/UY7Pgusg).

**Developers:** Clone the repo, open `StayInTouch/StayInTouch.xcodeproj` in Xcode 15+, and run. Grant Contacts and Notifications permissions when prompted.

---

## Issue Tracking

- [Report a bug](https://github.com/slavins-co/keep-in-touch/issues/new?labels=bug-fix)
- [Request a feature](https://github.com/slavins-co/keep-in-touch/issues/new?labels=feature-request)
- [Open issues](https://github.com/slavins-co/keep-in-touch/issues) · [Releases](https://github.com/slavins-co/keep-in-touch/releases)

---

## License

All rights reserved - see [LICENSE](LICENSE).

Built with the assistance of AI tools.
