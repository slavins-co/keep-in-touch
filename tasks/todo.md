# TODO - Stay in Touch iOS App

**Project Status:** v0.2.1 (Build 6) — Pre-release Beta
**Last Updated:** February 24, 2026

> **TestFlight Status:** Code blockers resolved. Manual submission steps remain — see `tasks/testflight-guide.md`.
> When creating PRs, confirm TestFlight readiness is not regressed (deployment target 17.0, PrivacyInfo.xcprivacy present, UIBackgroundModes declared, build number incremented).

---

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

- [ ] **#33** Add DS.Typography.heroTitle token for PersonDetailView
- [ ] **#34** ⭐ Swipe-to-log on home screen (highest priority UX improvement)
- [x] **#35** Surface errors with contextual banners (not silent failures) *(v0.2.1)*
- [ ] **#36** Add undo for destructive actions (delete contact/connection)
- [ ] **#37** Separate overdue tiers (Recently Due vs Long Overdue)
- [ ] **#38** Replace HStack filter chips with FlowLayout for overflow
- [ ] **#39** VoiceOver audit and accessibility labels
- [ ] **#40** Reorder PersonDetailView CTAs (Log Connection as primary)

### Design Review — Polish

- [ ] **#41** Add micro-animations (section expand, filter apply, card appear)
- [ ] **#42** Add empty state illustrations per section
- [ ] **#43** Implement skeleton loading states
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
