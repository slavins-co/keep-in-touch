# Stay in Touch

> Privacy-first iOS app to maintain friendships through gentle reminders and relationship tracking.

[![Platform](https://img.shields.io/badge/platform-iOS%2017.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

**Version:** 0.2.0 (Build 4) | **Status:** Pre-release Beta

---

## What is Stay in Touch?

Never lose track of the people who matter. Stay in Touch helps you maintain friendships by:

- **Tracking when you last connected** with friends and family
- **Organizing contacts by frequency** (Weekly, Bi-Weekly, Monthly, Quarterly)
- **Sending gentle reminders** when it's time to reconnect
- **Keeping everything private** — all data stays on your device

---

## Current Status

V0.2.0 introduces a full UX redesign with a centralized design system, modern filter patterns, and streamlined information hierarchy. The app is feature-complete and preparing for TestFlight.

**Up next:** Swipe-to-log for faster connection logging, accessibility improvements, and the "Relationship Journal" UX direction. See [open issues](https://github.com/slavins-co/stay-in-touch-ios/issues) and [release history](https://github.com/slavins-co/stay-in-touch-ios/releases) for details.

---

## Features

**Core**
- Connection logging with method tracking (Text, Call, In Person, Email)
- Frequency-based contact groups with configurable cadences
- Snooze and pause tracking per contact
- "Next Time" notes for conversation context
- Local notifications with natural reminder copy
- Contact search, filtering by frequency and group
- Full connection history with edit and delete
- Dark, light, and system theme support
- Data export as JSON

**Privacy & Security**
- All data stored locally on device (Core Data, encrypted at rest by iOS)
- Zero network requests — no cloud, no analytics, no tracking
- Read-only Contacts access (fetched on-demand, never stored externally)
- No external dependencies — built entirely with Apple frameworks

---

## Tech Stack

**iOS 17+ · Swift · SwiftUI · Core Data · Clean Architecture**

No external dependencies. Built with SwiftUI, Core Data, Contacts, UserNotifications, and BackgroundTasks.

---

## Getting Started

**TestFlight:** Coming soon.

**Developers:** Clone the repo, open `StayInTouch/StayInTouch.xcodeproj` in Xcode 15+, and run. Grant Contacts and Notifications permissions when prompted.

---

## Issue Tracking

- [Report a bug](https://github.com/slavins-co/stay-in-touch-ios/issues/new?labels=bug-fix)
- [Request a feature](https://github.com/slavins-co/stay-in-touch-ios/issues/new?labels=feature-request)
- [Open issues](https://github.com/slavins-co/stay-in-touch-ios/issues) · [Releases](https://github.com/slavins-co/stay-in-touch-ios/releases)

---

## License

MIT License — see [LICENSE](LICENSE).

Built with [Claude Code](https://claude.com/claude-code) by Anthropic.
