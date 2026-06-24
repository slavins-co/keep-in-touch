# Keep In Touch - iOS Personal CRM

## Project Overview

**App Name:** Keep In Touch (internally "StayInTouch" - module, directories, Core Data model all use the old name)
**Bundle ID:** `slavins.co.KeepInTouch`
**Platform:** iOS 17.0+ | Swift + SwiftUI | One external dependency (TelemetryDeck via SPM)
**Language mode:** Swift 6 (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete` on all targets, since #344). Data-race-safe; keep it that way - new code must compile clean under strict concurrency. Core Data repos are `@unchecked Sendable` (context confined to `performAndWait`); UI/singletons are `@MainActor`; lower layers stay nonisolated. `MainActor` default-isolation was evaluated and rejected for this single mixed-layer target (issue #344; tasks/ARCHITECTURE-REVIEW.md section 3.4)
**Architecture:** Clean Architecture with Repository Pattern
**Persistence:** Core Data (V1); CloudKit sync is a deferred V2 plan (#79), not implemented

Privacy-first iOS app that tracks "last touch" dates, organizes contacts into SLA cadence groups, and provides gentle reminders when relationships need attention.

## Key Documents

- **[FINAL-PRD.md](./FINAL-PRD.md)** - Complete product requirements
- **[Figma Mockup](./Figma%20Mockup/)** - Reference UI patterns

## Build & Test

```sh
# Build (run from repo root; -project is required since the project lives in StayInTouch/)
xcodebuild -project StayInTouch/StayInTouch.xcodeproj -scheme StayInTouch -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' -sdk iphonesimulator build

# Test
xcodebuild -project StayInTouch/StayInTouch.xcodeproj -scheme StayInTouch -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.3.1' -sdk iphonesimulator test
```

Background task ID: `com.slavins.keepintouch.refresh`

### Continuous Integration

`.github/workflows/ci.yml` builds the app and runs the **unit** suite (UI tests excluded) on every PR to `main` and on push to `main`, via the committed shared `StayInTouch.xcscheme`. Runner: `macos-26`, latest-stable Xcode, SwiftPM cache, runtime simulator selection (no hardcoded OS). ~10-13 min/run.

**`main` branch protection requires the `Build & Unit Test` check to pass before merge.** This is the only *mechanical* merge gate — enforced by GitHub itself, not by an agent. It is distinct from the `/code-review` + `/security-review` requirements below, which are conventions the agent must remember to run. `enforce_admins` is off, so a human admin can override in an emergency; agents and the normal merge button cannot.

### Cutting a release

The displayed app version comes from **build settings, not the git tag**. To release, global-replace both in `project.pbxproj` (each appears 8x: Debug/Release × App/Widget/Tests/UITests), then tag:
- `MARKETING_VERSION` → e.g. `0.5.0` (drives `CFBundleShortVersionString`, shown in Xcode Organizer + App Store Connect)
- `CURRENT_PROJECT_VERSION` → bump to a unique higher number (drives `CFBundleVersion`; must not collide with a prior TestFlight build)
- Then `git tag vX.Y.Z && git push origin vX.Y.Z`. The tag only feeds the in-app About-screen label (`GeneratedVersion.swift`) - it does **not** set the archive version.

## Git & Build Mechanics

- **Build-stamp noise before git ops** - Xcode can leave a "Recovered References" group in `project.pbxproj`, dirtying the tree before a checkout/merge/commit. Clear it first: `git checkout HEAD -- StayInTouch/StayInTouch/Utilities/GeneratedVersion.swift StayInTouch/StayInTouch.xcodeproj/project.pbxproj`. (`GeneratedVersion.swift` itself no longer churns per-commit - the build phase derives its build number from `CURRENT_PROJECT_VERSION`, not the git commit count.)
- **Read the PR base before git ops** - get it from `gh pr view --json baseRefName` before rebasing/merging/committing; don't assume `main`.
- **`tasks/` is gitignored** (`.gitignore` line 45). `tasks/todo.md` and `tasks/lessons.md` are already tracked and commit normally, but any NEW file under `tasks/` is ignored and needs `git add -f`. After a stash/pop across branch switches, take the target branch's version if these files conflict.
- **Crash + background-build diagnostics** - for an iOS crash, read `~/Library/Logs/DiagnosticReports/*.ips` for the exact file+line instead of chasing `simctl log show`. When running `xcodebuild` in the background, don't pipe through `tail` - tail's exit 0 masks xcodebuild's real status; capture xcodebuild's own exit code or read the result file.
- **xcodebuild fails right after an Xcode update** - the matching simulator runtime is likely uninstalled; install it (Xcode > Settings > Components, or `xcodebuild -downloadPlatform iOS`) before debugging further. Use the canonical `-project StayInTouch/StayInTouch.xcodeproj` command from Build & Test above.
- **Run review skills directly, not nested** - run `/code-review` and `/security-review` in the main session, never inside a sub-agent (nesting silently drops the parallel-reviewer fan-out and can exit without posting the PR comment). In a worktree, confirm `pwd` is inside the worktree before each edit.

## Architecture

Four layers, dependency inward only:
1. **Domain** - Pure Swift entities and protocols. No SwiftUI or Core Data imports.
2. **Data** - Core Data repositories, entity-to-domain mappings (`Data/Mappings/`), Contacts framework integration
3. **UseCases** - SLA calculations, notification scheduling, contacts sync, demo data
4. **UI** - SwiftUI views + ObservableObject view models

Repository pattern: protocol in Domain, Core Data implementation in Data. UUID foreign keys (not NSManagedObject relationships) in V1.

**Core Data ↔ domain naming quirk** (predates the #241 rename; read `Data/CoreData/Mappings/` before writing predicates): Core Data entity `Group`/`GroupEntity` = domain `Cadence`; Core Data entity `Tag`/`TagEntity` = domain `Group`; `PersonEntity.groupId` = domain `Person.cadenceId`; `PersonEntity.tagIds` = domain `Person.groupIds`.

## Core Data Schema

Current model version: **v10** (`Shared/StayInTouch.xcdatamodeld`; v1-v10 retained for lightweight migration). Entity names below are the **Core Data** names - see the naming quirk above for domain equivalents. This section mirrors the live `.xcdatamodel`; when adding attributes, update both.

**Person** (domain `Person`) - `id: UUID`, `cnIdentifier: String?`, `displayName: String`, `nickname: String?`, `initials: String`, `avatarColor: String`, `groupId: UUID` (cadence FK), `tagIds: Transformable [UUID]` (domain `groupIds`), `lastTouchAt: Date?`, `lastTouchMethod: String?`, `lastTouchNotes: String?`, `nextTouchNotes: String?`, `isPaused: Bool`, `isTracked: Bool`, `notificationsMuted: Bool`, `customBreachTime: String?` (LocalTime JSON), `snoozedUntil: Date?`, `customDueDate: Date?`, `birthday: String?` (Birthday JSON), `birthdayNotificationsEnabled: Bool` (default YES), `groupAddedAt: Date?`, `contactUnavailable: Bool`, `isDemoData: Bool`, `createdAt: Date`, `modifiedAt: Date`, `sortOrder: Int64`, `preferredMessenger: String?`

**Group** (domain `Cadence`) - `id: UUID`, `name: String`, `frequencyDays: Int64` (renamed from `slaDays`, renamingIdentifier set), `warningDays: Int64`, `colorHex: String?`, `isDefault: Bool`, `sortOrder: Int64`, `createdAt: Date`, `modifiedAt: Date`

**Tag** (domain `Group`) - `id: UUID`, `name: String`, `colorHex: String`, `sortOrder: Int64`, `createdAt: Date`, `modifiedAt: Date`

**TouchEvent** - `id: UUID`, `personId: UUID`, `at: Date`, `method: String`, `notes: String?`, `timeOfDay: String?`, `createdAt: Date`, `modifiedAt: Date`

**AppSettings** (singleton row) - `id: UUID`, `theme: String`, `notificationsEnabled: Bool`, `breachTimeOfDay: String` (LocalTime JSON), `digestEnabled: Bool`, `digestDay: String`, `digestTime: String` (LocalTime JSON), `notificationGrouping: String?`, `badgeCountShowDueSoon: Bool` (default NO), `dueSoonWindowDays: Int64`, `demoModeEnabled: Bool`, `analyticsEnabled: Bool` (default YES), `lastContactsSyncAt: Date?`, `onboardingCompleted: Bool`, `appVersion: String`, `hideContactNamesInNotifications: Bool` (default NO), `birthdayNotificationsEnabled: Bool` (default NO), `birthdayNotificationTime: String?` (LocalTime JSON), `birthdayIgnoreSnoozePause: Bool` (default YES), `tutorialCompleted: Bool` (default NO), `tutorialVersion: String?`, `lastSeenAppVersion: String?`

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

Apple frameworks: SwiftUI, Core Data, Contacts (CNContactStore), UserNotifications, BackgroundTasks (BGTaskScheduler), WidgetKit, AppIntents, TipKit, Charts. One third-party dependency: **TelemetryDeck SwiftSDK** (SPM, `upToNextMajor` from 2.11.0, app target only) for anonymous analytics. No CocoaPods.

## Apple Framework APIs

- **Docs-first, never from memory** - before writing any SwiftUI/UIKit/WidgetKit/App Intents symbol into a spec or code, confirm the exact name, availability, and return type via Context7 (`resolve-library-id` + `query-docs`) or Apple docs. Past misses (`.foregroundColor` vs `.foregroundStyle`, the widget accent modifiers, cross-window blur) surfaced only at build/review.
- **Lifecycle gotchas (App Intents, TipKit, SwiftUI, WidgetKit): see [docs/apple-framework-gotchas.md](docs/apple-framework-gotchas.md)** - when a framework fix isn't taking after one attempt, suspect wrong-lifecycle-point before iterating.

## Testing

- **Unit tests** (665 as of v0.5.0): repository implementations (in-memory Core Data), use cases, view models, notification scheduling, entity mappings, App Intents (via `IntentTestHarness`), widget snapshot logic
- **UI tests**: 3 launch-only smoke/perf tests (`-uiTesting` flag → in-memory store). Flow coverage (onboarding, log touch) does NOT exist yet - planned, see tasks/ARCHITECTURE-REVIEW.md step A5
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

- All user data local in Core Data (App Group container, `completeUntilFirstUserAuthentication` file protection). No cloud sync, no crash reporting.
- Only network egress: **TelemetryDeck** anonymous analytics (signal names + enum/count parameters, no PII). Opt-out via `AppSettings.analyticsEnabled` (default on); declared in `PrivacyInfo.xcprivacy` (ProductInteraction / Analytics / not linked / no tracking).
- Contacts/Notifications: request once, graceful degradation if denied. Phone/email never persisted - fetched on demand via `cnIdentifier`.
- Demo mode isolates fake data per-row via `isDemoData` flag (same store)

## Lessons File Maintenance

- `tasks/lessons.md` uses compact 1-2 line rule format, no narratives
- New lessons: add the prevention rule only. Archive verbose entry to `tasks/lessons-archive.md` if the narrative is worth preserving
- Consolidate when file exceeds 250 lines: deduplicate, promote frequent rules to CLAUDE.md, archive stale entries

## App Store Metadata

- **Name:** Keep In Touch | **Subtitle:** Never lose track of friends
- **Category:** Productivity | **Age Rating:** 4+
- **Keywords:** contacts, friends, relationships, CRM, reminders
