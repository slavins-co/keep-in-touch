# TODO - Stay in Touch iOS App

**Project Status:** v0.2.2 (Build 8) — Pre-release Beta
**Last Updated:** March 2, 2026

> **TestFlight Status:** Code blockers resolved. Manual submission steps remain — see `tasks/testflight-guide.md`.
> When creating PRs, confirm TestFlight readiness is not regressed (deployment target 17.0, PrivacyInfo.xcprivacy present, UIBackgroundModes declared, build number incremented).

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

## Open Issues

### Bug Fixes (Pre-existing) — All Resolved

- [x] **#26** Add "Done" button to dismiss keyboard on Next Time notes field *(closed)*
- [x] **#27** Fix touch log sorting — most recent time-of-day should appear first *(closed)*
- [x] **#28** Fix double "Assign Groups" title on contact import screen *(closed)*

### Design Review — Critical / Important

- [x] **#33** Add DS.Typography.heroTitle token for PersonDetailView *(v0.2.2)*
- [ ] **#34** ⭐ Swipe-to-log on home screen (highest priority UX improvement)
- [x] **#35** Surface errors with contextual banners (not silent failures) *(v0.2.1)*
- [x] **#36** Add undo for destructive actions (delete contact/connection) *(v0.2.2)*
- [ ] **#37** Separate overdue tiers (Recently Due vs Long Overdue)
- [x] **#38** Replace HStack filter chips with FlowLayout for overflow *(v0.2.2)*
- [ ] **#39** VoiceOver audit and accessibility labels
- [ ] **#40** Reorder PersonDetailView CTAs (Log Connection as primary)

### Design Review — Polish

- [ ] **#41** Add micro-animations (section expand, filter apply, card appear)
- [ ] **#42** Add empty state illustrations per section
- [x] **#43** Add "Last connected" timestamp to PersonDetailView hero *(2026-02-27)*
- [ ] **#44** Apply consistent 2pt/4pt sub-grid spacing rhythm

### UX Direction

- [ ] **#45** "Relationship Journal" UX direction for v0.3 — warm, narrative, action-oriented

### Pre-existing Backlog

- [ ] **#9** Custom due dates per contact (overlaps with #23, evaluate)
- [ ] **#10** Self-guided tutorial (defer to post-beta)

---

## Milestone: TestFlight Readiness

### Resolved (Build 6 — 2026-02-24)
- [x] **#46** Add PrivacyInfo.xcprivacy privacy manifest
- [x] **#47** Change deployment target from iOS 18.5 → 17.0
- [x] **#48** Add UIBackgroundModes to Info.plist
- [x] Build number bumped to 6
- [x] Clean build verified — zero errors
- [x] All 38+ unit tests passing (5 new migration tests in v0.2.1)
- [x] App icon exists (1024×1024 PNG, no alpha)
- [x] Error handling surfaced to users (#35)
- [x] CoreData migration is safe and versioned (#55)
- [x] Deleted contacts handled gracefully (#56)

### Not Needed for TestFlight (Fix Before App Store)
- [ ] Accessibility (VoiceOver, Dynamic Type) — #39 open
- [ ] Loading states — #43 open (error handling done in #35)
- [ ] **#49** Create and host privacy policy URL
- [ ] App Store screenshots (use demo mode)

### Recommended Before App Store
- [ ] Edge-case testing (timezone changes, large contact lists)
- [ ] Performance testing (100+ contacts, launch time)

### Manual Steps Remaining
See `tasks/testflight-guide.md` for step-by-step instructions:
- [x] Clean git state (Synology Drive artifacts — #50, solved with `core.fileMode false`)
- [x] Commit and push blocker fixes (v0.2.1 merged to main)
- [ ] Verify Apple Developer account enrollment
- [ ] Register App ID in Developer Portal
- [ ] Create App Store Connect record
- [ ] Archive and upload via Xcode
- [ ] Configure TestFlight and add testers

---

## Post-Beta (Future)

- [ ] CloudKit sync
- [ ] Shortcuts integration
- [ ] Widgets
- [ ] Manual contact creation
- [ ] macOS companion app
