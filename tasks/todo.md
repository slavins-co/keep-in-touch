# TODO - iOS Personal CRM App (Open Tasks Only)

**Project Status:** V1.1.1 released, bug fixes in progress
**Last Updated:** February 16, 2026

---

## Completed Issues (V1.1.1)

### Tier 1: Simple, Fully Autonomous ✅

- [x] **#20** Remove trailing period from notification body text
- [x] **#18** Display dynamic app version/build in Settings
- [x] **#21** Replace notification titles with friendlier copy
- [x] **#19** Show due date in cadence section of detail view

### Tier 2: Medium, Mostly Autonomous ✅

- [x] **#7** Add forward-looking notes field to person detail
- [x] **#22** Add randomized notification copy variations
- [x] **#13** Add morning/afternoon/evening time picker to Log Touch
- [x] **#23** Add snooze/defer due date per contact
- [x] **#8** Add group assignment step when importing from Settings

### Post-Release Fixes ✅

- [x] **#25** Fix empty group assignment list in Settings import flow (SwiftUI sheet stacking bug)

---

## Open Issues

### Bug Fixes (from device testing feedback)

- [ ] **#26** Add "Done" button to dismiss keyboard on Next Time notes field
- [ ] **#27** Fix touch log sorting — most recent time-of-day should appear first (Evening → Morning)
- [ ] **#28** Fix double "Assign Groups" title on contact import screen

### Tier 3: Complex, Needs Human Input

- [ ] **#24** Redesign visual language — streamlined/modern (HIGH priority, 1-2 days, iterative review needed)
- [ ] **#9** Custom due dates per contact — largely overlaps with #23, evaluate after
- [ ] **#10** Self-guided tutorial — issue recommends deferring to V2

---

## Remaining MVP Milestones

### Milestone 8: Polish & Testing

- [ ] Accessibility (VoiceOver, Dynamic Type)
- [ ] Error handling + loading states
- [ ] Edge-case testing (contact deletion, timezone changes)
- [ ] Performance testing (100+ contacts, launch time)
- [ ] UI tests (onboarding/log/delete flows)
- [ ] App icon + screenshots
- [ ] TestFlight build
- [ ] Document demo mode behavior

---

## Post-V1 (Future)
- [ ] CloudKit sync
- [ ] Shortcuts integration
- [ ] Widgets
- [ ] Manual contact creation
- [ ] macOS companion app
