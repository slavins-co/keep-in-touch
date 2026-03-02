# Keep In Touch

> Privacy-first iOS app to maintain friendships through gentle reminders and relationship tracking.

[![Platform](https://img.shields.io/badge/platform-iOS%2017.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-Proprietary-lightgrey.svg)](LICENSE)

**Version:** 0.3.0 (Build 8) | **Status:** Pre-release Beta

---

## What is Keep In Touch?

Never lose track of the people who matter. Keep In Touch helps you maintain friendships by:

- **Tracking when you last connected** with friends and family
- **Organizing contacts by frequency** (Weekly, Bi-Weekly, Monthly, Quarterly)
- **Sending gentle reminders** when it's time to reconnect
- **Keeping everything private** — all data stays on your device

---

## Current Status

V0.3.0 adds contact photos, JSON import/export, VoiceOver accessibility, and a round of security hardening. The app is feature-complete and preparing for TestFlight submission.

**Up next:** Swipe-to-log for faster connection logging, expanded accessibility, and the "Relationship Journal" UX direction. See [open issues](https://github.com/slavins-co/stay-in-touch-ios/issues) and [release history](https://github.com/slavins-co/stay-in-touch-ios/releases) for details.

---

## Features

**Core**
- Connection logging with method tracking (Text, Call, In Person, Email)
- Frequency-based contact groups with configurable cadences
- Contact photos from iOS Contacts with initials fallback
- Snooze and pause tracking per contact
- "Next Time" notes for conversation context
- Local notifications with quick-log actions
- Contact search, filtering by frequency and group
- Full connection history with edit and delete
- JSON import and export with conflict resolution
- Dark, light, and system theme support

**Privacy & Security**
- All data stored locally on device (Core Data, encrypted at rest by iOS)
- No cloud sync, no advertising, no cross-app tracking
- Anonymous usage analytics via [TelemetryDeck](https://telemetrydeck.com) (opt-out in Settings)
- Read-only Contacts access (fetched on-demand, never stored externally)
- No external dependencies — built entirely with Apple frameworks
- [Privacy policy](docs/privacy-policy.md)

---

## Tech Stack

**iOS 17+ · Swift · SwiftUI · Core Data · Clean Architecture**

No external dependencies beyond [TelemetryDeck](https://telemetrydeck.com) for anonymous analytics. Built with SwiftUI, Core Data, Contacts, UserNotifications, and BackgroundTasks.

---

## Getting Started

**TestFlight:** Preparing for submission — see [#69](https://github.com/slavins-co/stay-in-touch-ios/issues/69).

**Developers:** Clone the repo, open `StayInTouch/StayInTouch.xcodeproj` in Xcode 15+, and run. Grant Contacts and Notifications permissions when prompted.

---

## Issue Tracking

- [Report a bug](https://github.com/slavins-co/stay-in-touch-ios/issues/new?labels=bug-fix)
- [Request a feature](https://github.com/slavins-co/stay-in-touch-ios/issues/new?labels=feature-request)
- [Open issues](https://github.com/slavins-co/stay-in-touch-ios/issues) · [Releases](https://github.com/slavins-co/stay-in-touch-ios/releases)

---

## License

All rights reserved — see [LICENSE](LICENSE).

Built with [Claude Code](https://claude.com/claude-code) by Anthropic.
