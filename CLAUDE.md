# Keep In Touch - iOS Personal CRM

## Project Overview

**App Name:** Keep In Touch (internally "StayInTouch" - module, directories, Core Data model all use the old name)
**Bundle ID:** `slavins.co.KeepInTouch`
**Platform:** iOS 17.0+ | Swift + SwiftUI | No external dependencies
**Architecture:** Clean Architecture with Repository Pattern
**Persistence:** Core Data (V1), NSPersistentCloudKitContainer (V2)

Privacy-first iOS app that tracks "last touch" dates, organizes contacts into SLA cadence groups, and provides gentle reminders when relationships need attention.

## Key Documents

- **[FINAL-PRD.md](./FINAL-PRD.md)** - Complete product requirements
- **[Figma Mockup](./Figma%20Mockup/)** - Reference UI patterns

## Build & Test

```sh
# Build
xcodebuild -scheme StayInTouch -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' -sdk iphonesimulator build

# Test (316+ unit tests)
xcodebuild -scheme StayInTouch -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' -sdk iphonesimulator test
```

Background task ID: `com.slavins.keepintouch.refresh`

## Architecture

Four layers, dependency inward only:
1. **Domain** - Pure Swift entities and protocols. No SwiftUI or Core Data imports.
2. **Data** - Core Data repositories, entity-to-domain mappings (`Data/Mappings/`), Contacts framework integration
3. **UseCases** - SLA calculations, notification scheduling, contacts sync, demo data
4. **UI** - SwiftUI views + ObservableObject view models

Repository pattern: protocol in Domain, Core Data implementation in Data. UUID foreign keys (not NSManagedObject relationships) in V1.

## Core Data Schema

**Person** - `id: UUID`, `cnIdentifier: String?`, `displayName: String`, `nickname: String?`, `initials: String`, `avatarColor: String`, `groupId: UUID`, `tagIds: Transformable ([UUID])`, `lastTouchAt: Date?`, `lastTouchMethod: String?`, `lastTouchNotes: String?`, `nextTouchNotes: String?`, `isPaused: Bool`, `isTracked: Bool`, `notificationsMuted: Bool`, `customBreachTime: String?` (LocalTime JSON), `snoozedUntil: Date?`, `customDueDate: Date?`, `birthday: String?`, `birthdayNotificationsEnabled: Bool`, `groupAddedAt: Date?`, `contactUnavailable: Bool`, `isDemoData: Bool`, `createdAt: Date`, `modifiedAt: Date`, `sortOrder: Int64`

**Group** - `id: UUID`, `name: String`, `slaDays: Int64`, `warningDays: Int64`, `colorHex: String?`, `isDefault: Bool`, `sortOrder: Int64`, `createdAt: Date`, `modifiedAt: Date`

**Tag** - `id: UUID`, `name: String`, `colorHex: String`, `sortOrder: Int64`, `createdAt: Date`, `modifiedAt: Date`

**TouchEvent** - `id: UUID`, `personId: UUID`, `at: Date`, `method: String`, `notes: String?`, `createdAt: Date`, `modifiedAt: Date`

**AppSettings** (singleton) - `id: UUID`, `theme: String`, `notificationsEnabled: Bool`, `breachTimeOfDay: String` (LocalTime JSON), `digestEnabled: Bool`, `digestDay: String`, `digestTime: String` (LocalTime JSON), `dueSoonWindowDays: Int64`, `demoModeEnabled: Bool`, `lastContactsSyncAt: Date?`, `onboardingCompleted: Bool`, `appVersion: String`

## Coding Conventions

- Types: PascalCase. Properties/methods: camelCase. Enums: singular with `String` raw values, `CaseIterable`, `Codable`
- File order: imports, type definition, properties, initializers, public methods, private methods
- `guard let` for early returns, `if let` for conditional execution, no force unwrapping without documented reason
- `@StateObject` in parent views, `@ObservedObject` in children
- Extract subviews when body > 30 lines
- Views: `PersonDetailView`. Modals: `LogTouchModal`. ViewModels: `HomeViewModel`
- `Result<Success, Failure>` for async, `throws` for sync. Custom error enum per domain
- Core Data: always use `context.perform {}` for thread safety
- Contacts: fetch on-demand via `cnIdentifier`, never store phone/email in Person entity
- Date math: always use `Calendar.current.dateComponents`, never manual interval division

## Dependencies

Built-in only: SwiftUI, Core Data, Contacts (CNContactStore), UserNotifications, BackgroundTasks (BGTaskScheduler). No CocoaPods, no SPM.

## Testing

- **Unit tests**: Repository implementations (in-memory Core Data), use case logic, view model state changes
- **UI tests**: Critical flows (onboarding, log touch, delete touch), navigation paths, empty states
- **Manual QA**: See FINAL-PRD.md section 7

## Accessibility

- All interactive elements need `.accessibilityLabel()`. Hints describe outcomes, not gestures.
- Dynamic Type only (system text styles, no fixed font sizes)
- Status colors meet WCAG AA (4.5:1). Never rely solely on color.
- Adaptive color tokens via `DesignSystem.swift` - no `colorScheme` conditionals in views

## Performance Targets

- Cold launch < 1s, warm < 0.3s
- 60 FPS scroll with 100+ contacts (lazy loading)
- < 50 MB baseline, < 100 MB with demo data

## Privacy

- All data local in Core Data (encrypted at rest by iOS). No network, no analytics, no crash reporting in V1.
- Contacts/Notifications: request once, graceful degradation if denied
- Demo mode isolates fake data from real data

## Lessons File Maintenance

- `tasks/lessons.md` uses compact 1-2 line rule format, no narratives
- New lessons: add the prevention rule only. Archive verbose entry to `tasks/lessons-archive.md` if the narrative is worth preserving
- Consolidate when file exceeds 250 lines: deduplicate, promote frequent rules to CLAUDE.md, archive stale entries

## App Store Metadata

- **Name:** Keep In Touch | **Subtitle:** Never lose track of friends
- **Category:** Productivity | **Age Rating:** 4+
- **Keywords:** contacts, friends, relationships, CRM, reminders
