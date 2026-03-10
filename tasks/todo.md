# TODO - Stay in Touch iOS App

**Project Status:** v0.3.2 (Build 8) — Pre-release Beta
**Last Updated:** March 9, 2026

> **TestFlight Status:** Code blockers resolved. Manual submission steps remain — see `tasks/testflight-guide.md`.
> When creating PRs, confirm TestFlight readiness is not regressed (deployment target 17.0, PrivacyInfo.xcprivacy present, UIBackgroundModes declared, build number incremented).

---

## v0.3.3 Triage — TestFlight Launch Scope

> **PRESERVE THIS SECTION.** Future sessions: mark items `[x]` as they ship. Do NOT remove, reorder, or overwrite the priority tiers until v0.3.3 is tagged and released. This is the authoritative scope for v0.3.3.

**Implementation order:** ~~#229~~ → ~~#237~~ → ~~#40~~ → ~~#236~~ → ~~#235~~ → #105 → ~~#106~~ → ~~#228~~

### Tier 1 — Must Ship (bugs + analytics)

- [x] **#229** Fix incorrect app version displayed in Settings *(XS — PR #238)*
- [x] **#237** Fix concurrency & redundant modifier warnings *(S — PR #238)*
- [x] **#228** Audit and update TelemetryDeck events after refactors *(M — PR #240)*

### Tier 2 — Should Ship (privacy + UX polish)

- [ ] **#105** Add screenshot blur protection on app background *(S — deferred, needs native UIKit approach)*
- [x] **#106** Add notification privacy setting to hide contact names *(S-M — PR #244)*
- [x] **#236** Display multiple groups on contact cards in list views *(S — PR #242)*
- [x] **#235** Add "Link to Contact" option when contact is unavailable *(S — PR #243)*
- [x] **#40** Reorder PersonDetailView CTAs — Log Connection as primary *(XS — already closed 2026-02-25)*

### Tier 3 — Nice to Have (stretch goals, if time allows)

- [ ] **#34** Swipe-to-log on home screen *(M-L — highest UX priority but gesture complexity)*
- [ ] **#230** Deduplicate breach + digest notifications for single person *(S — edge case polish)*
- [ ] **#231** Birthday push notifications with toggle and per-person settings *(M — extends #141)*
- [ ] **#134** Add CSV export option for spreadsheet use *(S — testers may want to review data)*
- [ ] **#37** Separate overdue tiers (Recently Due vs Long Overdue) *(S-M — UX improvement)*
- [x] **#232** Pull-to-refresh re-sync contact info from iOS Contacts *(S — PR #255)*

### Tier 4 — Deferred to v0.4+

Calendar integration (#234), WhatsApp (#233), Dynamic Type (#202), architecture refactors (#203, #215, #216, #214, #168), VoiceOver picker/editor sheets (#197), full VoiceOver audit (#39), widget (#60), Siri Shortcuts (#80), iCloud sync (#79), iPad layout (#78), localization (#77), stats page (#138), tutorial (#10), UX direction (#45), design polish (#41, #42, #44).

### Not Code (human parallel track)

- [ ] **#65** Create App Store screenshots
- [ ] **#66** Write App Store description, subtitle, and keywords
- [ ] **#68** App Store submission checklist
- [ ] **#69** TestFlight beta validation plan
- [ ] **#70** Validate core loop retention during beta

---

## Completed — Session 2026-03-10b (Issue #246: Foreground Notifications)

- [x] **#246** Notifications silently suppressed when app is in foreground (PR #257)
  - Added `userNotificationCenter(_:willPresent:withCompletionHandler:)` to AppDelegate
  - Calls completion with `[.banner, .sound, .badge]` — applies to all notification types
  - 304 unit tests passing
- [x] Code review: PASS
- [x] Security review: PASS

---

## Completed — Session 2026-03-10 (Issues #248, #249, #232)

- [x] **#232** Pull-to-refresh re-sync contact info from iOS Contacts (PR #255, merged)
- [x] **#249** Fix blank import screen on first file selection (PR #251, merged)
- [x] **#248** Extract notifications section into NotificationSettingsView sub-screen (PR #256)
  - New `NotificationSettingsView` with 4 sections: Connection Reminders, Weekly Digest, Birthday Reminders, Privacy
  - SettingsView simplified to single NavigationLink
  - Post-review fixes: accessibility annotations on Reminder Time/Digest Day/Digest Time buttons, restored "Alert Time" sheet title
- [x] Code review: PASS
- [x] Security review: PASS

---

## Completed — Session 2026-03-09c (Issue #106: Notification Privacy)

- [x] **#106** Hide names in notifications — new `hideContactNamesInNotifications` AppSettings toggle (PR #244)
- [x] Core Data v5 → v6 lightweight migration for new boolean attribute
- [x] 4 new notification privacy tests, 280 total tests passing
- [ ] **#105** Screenshot blur — deferred after 3 failed approaches (SwiftUI overlay, separate UIWindow, key window subview). UIVisualEffectView cannot blur cross-window; key window subview still rendered opaque. Needs deeper investigation.
- [x] Code review: PASS
- [x] Security review: PASS

---

## Completed — Session 2026-03-09b (Issues #235, #236: UX Polish)

- [x] **#235** Fix HIG tap target compliance on unavailable contact banner (PR #243)
- [x] Added `DS.Spacing.tapTarget` (44pt) design system token
- [x] Restructured banner: info row on top, horizontal action row below with 44pt min-height buttons
- [x] **#236** Display multiple groups on contact cards (PR #242)
- [x] Code review: PASS (both PRs)
- [x] Security review: PASS (both PRs)

---

## Completed — Session 2026-03-09a (Issue #137: Fresh Start for Inactive Users)

- [x] **#137** Auto-prompt Fresh Start for inactive or overwhelmed users (PR #227)

---

## Completed — Session 2026-03-09 (Issues #229, #237, #228)

- [x] **#229** Fix app version display — replace PlistBuddy with build-phase-generated Swift file (PR #238)
- [x] **#237** Add `alwaysOutOfDate` to version build phase for incremental builds (PR #238)
- [x] **#228** Audit and update TelemetryDeck events after refactors (PR #240)
- [x] Swapped filter analytics parameters corrected: `selectedGroupId` → "group", `selectedTagId` → "tag"
- [x] Added new signals: `freshStart.confirmed`, `data.exported`, `data.imported`
- [x] Code review: PASS (all 3 PRs)
- [x] Security review: PASS (all 3 PRs)
- [x] **#241** Filed issue for backend terminology rename (Group→Cadence, Tag→Group) — post-beta
- [x] Updated TelemetryDeck dashboard JSON with all 25 signals (31 insights)

---

## Completed — Session 2026-03-06 (Issue #208: Contact Import State Enum)

- [x] **#208** Replace onChange modal chains with ContactImportStep enum (PR #221)
- [x] 7 @State variables → 2, 2 onChange chains → 0, single sheet(item:) with onDismiss
- [x] Code review: PASS
- [x] Security review: PASS
- [x] Defensive fix: clear pendingImportStep on all cancel paths

---

## Completed — Session 2026-03-06 (Issue #207: Extract SettingsViewModel Services)

- [x] **#207** Extract SettingsViewModel import/export into dedicated services (PR #220)
- [x] Created `ExportModels.swift` — shared data structures for import/export
- [x] Created `DataExportService.swift` — JSON export logic
- [x] Created `DataImportService.swift` — JSON import parsing, execution, contact matching
- [x] Created `ContactImportService.swift` — device address book contact import
- [x] SettingsViewModel reduced from 1,084 → ~400 lines (thin orchestrator)
- [x] Code review: PASS (no issues above threshold)
- [x] Security review: PASS
- [x] Post-review fixes: thread safety for viewContext access (score 75), AppSettingsDefaults placement (score 65)
- [x] All 22 SettingsViewModel tests pass unchanged

---

## Completed — Session 2026-03-04 (Issue #173: fullScreenCover Detail Presentation)

- [x] **#173** Change PersonDetailView from NavigationLink push to fullScreenCover with DismissableFullScreenCover wrapper
- [x] New DismissableFullScreenCover component: rounded top corners, drag handle, X button, drag-to-dismiss
- [x] Lifted selectedPerson state to MainTabView — single fullScreenCover serves Home + Contacts tabs
- [x] Deep link processing moved from HomeView to MainTabView
- [x] ContactListSection + ContactsListView: NavigationLink → Button with selectPerson closure
- [x] Code review: caught PausedContactsView nav trap — fixed by removing .navigationBarHidden(true)
- [x] Security review: PASS

---

## Completed — Session 2026-03-02 (Issue #152: Date Calculation Bug)

- [x] **#152** Fix "Today" shown for contacts touched yesterday — normalize to calendar days instead of 24-hour periods
- [x] FrequencyCalculator: `daysSinceLastTouch()`, `status()`, `daysOverdue()` all use `startOfDay` normalization
- [x] 3 new edge-case tests for calendar-day boundary scenarios, all pass

---

## Completed — Session 2026-03-01 (Issues #140 + #141: Birthday Display)

- [x] **#140** Remove "last connected" badge from PersonDetailView header
- [x] **#141** Add birthday display to contact detail page — cake icon + M/DD format, CNContact auto-pull, manual override, edit sheet
- [x] New `Birthday` value object, Core Data v4 model, ContactsFetcher birthday fetch, export/import support
- [x] 8 new Birthday tests + 4 ViewModel birthday tests, all tests pass

---

## Completed — Session 2026-02-27d (Onboarding UX Polish)

- [x] **PR 94 fixes** Fix onboarding progress bar and layout issues — custom capsule progress bar, unique fractions per step, vertical centering Spacers, hide bar on welcome, 8 new/updated progress tests

## Completed — Session 2026-02-27c (Contact Photos + Multi-value Picker + Onboarding Nav)

- [x] **#72** Display contact photos from iOS Contacts — on-demand thumbnail fetch with NSCache, initials fallback (PR #92)
- [x] **#51** Show picker when contact has multiple phone numbers or emails — LabeledValue struct, confirmationDialog pickers (PR #93)
- [x] **#58** Add back navigation and progress indicator to onboarding — history stack, progress bar, back button, 13 new tests (PR #94)

## Completed — Session 2026-02-27b (Notifications + Import)

- [x] **#71** Notification-tapped contact opens as navigation push instead of modal sheet (PR #90)
- [x] **#73** JSON import to complement existing export — file picker, preview screen, conflict resolution (PR #91)

## Completed — Session 2026-02-27 (Performance + Export + UX)

- [x] **#81** Optimize contact fetching — add `fetchBatchSize=50` to all fetch requests, rewrite `fetchOverdue()` with predicate-based filtering (PR #86)
- [x] **#74** Enrich data export — add `groupName`, `tagNames`, and `touchEvents` array to exported JSON (PR #87)
- [x] **#59** Add "Reset All Frequencies" emergency button in Settings with confirmation dialog (PR #88)
- [x] **#43** Add "Last connected Xd ago" timestamp to PersonDetailView hero zone (PR #89)

## Completed — v0.2.2 (Critical + Performance + UX)

- [x] **#62** Optimize FrequencyCalculator — single instance per render (was creating hundreds of instances in ForEach)
- [x] **#54** Auto-log touch after quick action with undo on return (Call/Message/Email now auto-log, undo banner on app return)
- [x] **#53** Handle limited contact access dead end (shows "grant full access" alert instead of "up to date")
- [x] **#61** Improve notification reliability with repeating triggers (daily/weekly notifications now fire reliably + foreground rescheduling)
- [x] **#33** Add DS.Typography.heroTitle token — PersonDetailView name uses design system font
- [x] **#63** Batch CoreData saves during contact import (single save instead of per-contact)
- [x] **#36** Add undo for person deletion with 5-second timed banner
- [x] **#75** Quick-log touch from notification action ("Log Connection" button on person reminders)
- [x] **#38** Replace WrapLayout stub and HStack filter chips with proper FlowLayout (Layout protocol)
- [x] Build number bumped to 8, version 0.2.2

## Completed — v0.2.1 (Critical Issues)

- [x] **#57** Reframe SLA terminology to consumer-friendly language (ContactStatus, FrequencyCalculator)
- [x] **#55** CoreData versioned migration strategy (v2 model, safe migration, no auto-delete)
- [x] **#35** Surface errors with contextual banners (ErrorToast system, ViewModel try? audit)
- [x] **#56** Handle deleted/merged contacts (contactUnavailable flag, sync detection, UI banner)
- [x] Build number bumped to 6, version 0.2.1

## Completed — v0.2.0 (UX Redesign)

- [x] **PR #29** Full UX redesign — centralized design system, modern filter patterns, streamlined info hierarchy
- [x] **#30** Rename all UI "Tags" → "Groups" (8 strings across 5 files)
- [x] **#31** Fix section header color contrast for WCAG AA (primaryText + colored dot)
- [x] **#32** Fix filter chip X button touch targets (minWidth: 44)
- [x] Bug fix: Section header font weight `.semibold` → `.bold` for light mode legibility
- [x] Bug fix: Filter chip height inflation from `minHeight: 44` — removed
- [x] Bug fix: Settings section headers (FREQUENCY/GROUPS/NOTIFICATIONS) `tertiaryText` → `secondaryText`
- [x] Version numbering revised from v1.x.x → v0.x.x (pre-beta)
- [x] GitHub releases recreated: v0.1.0, v0.1.1, v0.2.0 (all pre-release)
- [x] README streamlined from 525 → 81 lines
- [x] License changed from MIT → All Rights Reserved
- [x] `design-review.md` created with full critique

## Completed — v0.1.1

- [x] **#20** Remove trailing period from notification body text
- [x] **#18** Display dynamic app version/build in Settings
- [x] **#21** Replace notification titles with friendlier copy
- [x] **#19** Show due date in cadence section of detail view
- [x] **#7** Add forward-looking notes field to person detail
- [x] **#22** Add randomized notification copy variations
- [x] **#13** Add morning/afternoon/evening time picker to Log Touch
- [x] **#23** Add snooze/defer due date per contact
- [x] **#8** Add group assignment step when importing from Settings
- [x] **#25** Fix empty group assignment list (SwiftUI sheet stacking bug)
- [x] **#24** Redesign visual language (subsumed by PR #29)

---

## Milestone: TestFlight Readiness

### Resolved (Build 6+)
- [x] PrivacyInfo.xcprivacy, deployment target 17.0, UIBackgroundModes
- [x] Clean build, 278+ unit tests passing, app icon, error handling, safe migration, deleted contact handling

### Before App Store (not TestFlight blockers)
- [ ] Full accessibility audit (VoiceOver, Dynamic Type) — #39, #197, #202
- [ ] **#49** Create and host privacy policy URL
- [ ] App Store screenshots (use demo mode)
- [ ] Edge-case testing (timezone changes, large contact lists)
- [ ] Performance testing (100+ contacts, launch time)

### Manual Steps Remaining
See `tasks/testflight-guide.md`:
- [ ] Verify Apple Developer account enrollment
- [ ] Register App ID in Developer Portal
- [ ] Create App Store Connect record
- [ ] Archive and upload via Xcode
- [ ] Configure TestFlight and add testers

---

## Post-Beta (Future)

- [ ] **#241** Rename backend terminology: Group→Cadence, Tag→Group (tech debt)
- [ ] CloudKit sync
- [ ] Shortcuts integration
- [ ] Widgets
- [ ] Manual contact creation
- [ ] macOS companion app
