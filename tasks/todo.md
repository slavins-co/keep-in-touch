# TODO - iOS Personal CRM App

**Project Status:** 📋 Ready for Implementation  
**Last Updated:** February 1, 2026

---

## Implementation Roadmap

### Pre-Implementation ✅
- [x] Complete PRD (FINAL-PRD.md)
- [x] Create CLAUDE.md handoff document
- [x] Document design system (ASSETS.md)
- [x] Set up tasks directory
- [ ] First session: Review all documents and ask clarifying questions

---

## Milestone 1: Core Data + Domain (Week 1)
**Goal:** Set up data persistence layer and domain models

### Tasks
- [ ] Create Xcode iOS project (iOS 17.0+, SwiftUI, Core Data enabled)
- [ ] Configure Info.plist permission strings
  - [ ] NSContactsUsageDescription
  - [ ] NSUserNotificationsUsageDescription
- [ ] Create folder structure per CLAUDE.md
- [ ] Define Core Data model (.xcdatamodeld)
  - [ ] Person entity (15 attributes)
  - [ ] Group entity (8 attributes)
  - [ ] Tag entity (4 attributes)
  - [ ] TouchEvent entity (6 attributes)
  - [ ] AppSettings entity (11 attributes)
- [ ] Implement CoreDataStack.swift
- [ ] Create domain model structs (Domain/Entities/)
- [ ] Define repository protocols (Domain/Protocols/)
- [ ] Implement Core Data repositories
  - [ ] CoreDataPersonRepository
  - [ ] CoreDataGroupRepository
  - [ ] CoreDataTagRepository
  - [ ] CoreDataTouchEventRepository
  - [ ] CoreDataSettingsRepository
- [ ] Unit tests for repositories (in-memory Core Data)
- [ ] Seed default groups and tags on first launch

**Verification:**
- [ ] Project builds without errors
- [ ] Core Data model visible in Xcode
- [ ] Repository tests pass
- [ ] Default data seeds correctly

---

## Milestone 2: Onboarding (Week 1)
**Goal:** Complete first-run user experience

### Tasks
- [ ] WelcomeView (benefits, app icon, CTA)
- [ ] ContactsPermissionView
  - [ ] Request CNContactStore access
  - [ ] Handle permission granted/denied
  - [ ] Skip flow implemented
- [ ] ContactPickerView
  - [ ] Fetch all CNContacts
  - [ ] Multi-select UI
  - [ ] Search/filter functionality
  - [ ] Create Person records from selections
- [ ] GroupsInfoView (informational screen)
- [ ] NotificationsPermissionView
  - [ ] Request UNUserNotificationCenter access
  - [ ] Handle permission states
- [ ] Onboarding navigation flow
- [ ] Set Settings.onboardingCompleted flag
- [ ] Route to Home after completion

**Verification:**
- [ ] First launch shows onboarding
- [ ] Subsequent launches skip onboarding
- [ ] Permission denial handled gracefully
- [ ] Contacts imported correctly
- [ ] Navigation flow smooth

---

## Milestone 3: Home Screen (Week 2)
**Goal:** Main contact list view with filtering

### Tasks
- [ ] HomeView layout (header, filters, sections, search)
- [ ] ContactCard component
  - [ ] Avatar with initials
  - [ ] Name, metadata, tags
  - [ ] Status indicator
  - [ ] Overdue badge
- [ ] ContactListSection (collapsible)
- [ ] Implement SLA status calculation
- [ ] Implement days overdue calculation
- [ ] Filter controls
  - [ ] Group dropdown
  - [ ] Sort dropdown (Status/Name)
  - [ ] Tag dropdown
- [ ] Search functionality (debounced)
- [ ] Empty states
  - [ ] No contacts
  - [ ] No search results
- [ ] Pull to refresh (Contacts re-sync)
- [ ] Navigation to Person Detail
- [ ] Navigation to Settings

**Verification:**
- [ ] Contacts display correctly
- [ ] Filtering works (group + tag + sort)
- [ ] Search filters as expected
- [ ] Section collapse/expand smooth
- [ ] Empty states appropriate
- [ ] Navigation functional

---

## Milestone 4: Person Detail (Week 2)
**Goal:** Individual contact view with history

### Tasks
- [ ] PersonDetailView layout
- [ ] Header (avatar, name, status)
- [ ] Cadence card with group picker
- [ ] Tags card with tag manager
- [ ] Contact history section
  - [ ] Display TouchEvents
  - [ ] Show/hide full history
  - [ ] Edit/delete buttons per entry
- [ ] Quick Actions section
  - [ ] Fetch phone/email from Contacts
  - [ ] Message/Call/Email buttons
  - [ ] Handle CNContact fetch errors
- [ ] Pause/Resume button
- [ ] Log Touch button (fixed bottom)
- [ ] Change group modal
- [ ] Manage tags modal
- [ ] Back navigation

**Verification:**
- [ ] All sections render correctly
- [ ] CNContact data fetches on-demand
- [ ] Quick actions launch native apps
- [ ] Pause/resume updates status
- [ ] Navigation works

---

## Milestone 5: Touch Logging (Week 3)
**Goal:** Create, edit, delete touch events

### Tasks
- [ ] LogTouchModal component
  - [ ] Method picker (radio buttons)
  - [ ] Notes text area
  - [ ] Done/Cancel buttons
- [ ] Create TouchEvent logic
  - [ ] Save to Core Data
  - [ ] Update Person.lastTouchAt
  - [ ] Recalculate SLA status
- [ ] EditTouchModal component
  - [ ] Pre-fill existing data
  - [ ] Date field (read-only)
  - [ ] Method picker
  - [ ] Notes text area
- [ ] Edit TouchEvent logic
  - [ ] Update method and notes
  - [ ] Update Person if most recent
- [ ] Delete confirmation dialog
- [ ] Delete TouchEvent logic
  - [ ] Remove from history
  - [ ] Update Person if most recent
  - [ ] Handle last event deletion
- [ ] Toast notifications ("Logged touch", "Touch updated", etc.)

**Verification:**
- [ ] Log touch creates event correctly
- [ ] SLA status recalculates
- [ ] Edit preserves date, updates method/notes
- [ ] Delete removes event
- [ ] Person data updates correctly
- [ ] Edge cases handled (last event delete)

---

## Milestone 6: Settings & Management (Week 3)
**Goal:** App configuration and data management

### Tasks
- [ ] SettingsView layout
  - [ ] Appearance section (theme toggle)
  - [ ] Groups section (navigate to manage)
  - [ ] Tags section (navigate to manage)
  - [ ] Notifications section (toggles, time/day pickers)
  - [ ] Data section (export, sync, demo mode)
  - [ ] About section
- [ ] ManageGroupsView
  - [ ] List groups with contact counts
  - [ ] Add group modal
  - [ ] Edit group modal
  - [ ] Delete group (reassign contacts)
  - [ ] Validation (unique names, warning < SLA)
- [ ] ManageTagsView
  - [ ] List tags with contact counts
  - [ ] Add tag modal (name + color picker)
  - [ ] Edit tag modal
  - [ ] Delete tag (remove from contacts)
- [ ] Export data functionality
  - [ ] Generate JSON
  - [ ] Share sheet
- [ ] Contacts re-sync functionality
  - [ ] Update displayNames from CNContact
  - [ ] Progress indicator
- [ ] Demo mode toggle
  - [ ] Generate 25 fake contacts
  - [ ] Backup real data
  - [ ] Restore on disable
- [ ] Theme switching (dark/light)

**Verification:**
- [ ] All settings persist
- [ ] Theme changes immediately
- [ ] Group CRUD works
- [ ] Tag CRUD works
- [ ] Default groups cannot be deleted
- [ ] Export generates valid JSON
- [ ] Sync updates names
- [ ] Demo mode isolates data

---

## Milestone 7: Notifications (Week 4)
**Goal:** Local notification scheduling and handling

### Tasks
- [ ] NotificationScheduler service
- [ ] Breach notification logic
  - [ ] Check conditions (isPaused, isTracked, SLA breached)
  - [ ] Schedule at breachTimeOfDay
  - [ ] Group by threadIdentifier
  - [ ] Track last notification sent (Person.lastBreachNotificationAt)
- [ ] Weekly digest logic
  - [ ] Check if enabled
  - [ ] Compile overdue contacts
  - [ ] Format notification content
  - [ ] Schedule on correct day/time
- [ ] Deep link handling
  - [ ] Parse notification userInfo
  - [ ] Navigate to Person Detail
  - [ ] Navigate to Home filtered view
- [ ] Background task setup
  - [ ] Register BGTaskScheduler
  - [ ] Daily SLA recalculation
  - [ ] Notification rescheduling
  - [ ] Handle task expiration
- [ ] Notification content formatting
  - [ ] Privacy-friendly (first name only)
  - [ ] Actionable text
- [ ] Badge count management
- [ ] Test notifications on device

**Verification:**
- [ ] Breach notifications fire correctly
- [ ] Multiple breaches group properly
- [ ] Digest compiles correct list
- [ ] Deep links navigate correctly
- [ ] Background task runs
- [ ] Notifications respect muted setting
- [ ] Badge count accurate

---

## Milestone 8: Polish & Testing (Week 4)
**Goal:** Production-ready build

### Tasks
- [ ] Dark/light theme refinement
  - [ ] Check all screens in both modes
  - [ ] Verify color contrast
- [ ] Accessibility
  - [ ] VoiceOver labels
  - [ ] Dynamic type support
  - [ ] Color independence
- [ ] Error handling
  - [ ] CNContact fetch failures
  - [ ] Core Data save errors
  - [ ] Notification permission denied
- [ ] Loading states
  - [ ] Skeleton screens
  - [ ] Spinners where appropriate
- [ ] Animation polish
  - [ ] Smooth transitions
  - [ ] Standard durations
- [ ] Edge case testing
  - [ ] Contact deleted from phone
  - [ ] Group deleted with contacts
  - [ ] Timezone changes
  - [ ] First launch variations
- [ ] Performance testing
  - [ ] 100+ contacts scrolling
  - [ ] Memory leaks (Instruments)
  - [ ] Launch time
- [ ] Unit tests
  - [ ] Repository layer
  - [ ] Use cases
  - [ ] View models
- [ ] UI tests
  - [ ] Onboarding flow
  - [ ] Log touch flow
  - [ ] Delete touch flow
- [ ] App icon
- [ ] Screenshots (using demo mode)
- [ ] TestFlight build
  - [ ] Archive and upload
  - [ ] Internal testing
  - [ ] Beta tester feedback

**Verification:**
- [ ] All acceptance criteria pass (70+ in PRD)
- [ ] No crashes in testing
- [ ] Memory usage acceptable
- [ ] App Store submission checklist complete
- [ ] TestFlight build distributed

---

## Post-V1 (Future)

### V2 Features
- [ ] CloudKit sync
- [ ] Shortcuts integration
- [ ] Widgets
- [ ] Manual contact creation
- [ ] macOS companion app

---

## Review Section

*This section will be populated with summaries after completing each milestone*

### Milestone 1 Review
**Completion Date:** [TBD]  
**Highlights:**  
**Challenges:**  
**Lessons Learned:**

### Milestone 2 Review
**Completion Date:** [TBD]  
**Highlights:**  
**Challenges:**  
**Lessons Learned:**

---

**Maintenance Notes:**
- Update this file as tasks are completed
- Add blockers or issues as they arise
- Review weekly to adjust timeline
- Document decisions and rationale
- Keep SUMMARY.md in sync with major changes
