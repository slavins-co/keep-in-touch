# Lessons Learned - iOS Personal CRM App

This file tracks patterns, corrections, and improvements discovered during development to prevent repeating mistakes.

## Date: [To be populated during development]

### Lesson Categories
- 🐛 **Bug Patterns** - Common mistakes and their fixes
- 🏗️ **Architecture** - Design decisions and their rationale
- 🎨 **UI/UX** - SwiftUI patterns and user experience insights
- 📊 **Data** - Core Data, Contacts framework, persistence lessons
- 🔔 **Notifications** - Local notification scheduling and handling
- ⚡ **Performance** - Optimization techniques that worked
- ✅ **Testing** - Effective testing approaches

---

## Template for New Lessons

```markdown
### [Date] - [Category] - [Brief Title]

**What Happened:**
[Description of the issue or correction]

**Root Cause:**
[Why did this happen?]

**Solution:**
[What was the fix?]

**Prevention Rule:**
[How to avoid this in the future - write as a rule for yourself]

**Code Example (if applicable):**
```swift
// Bad approach
...

// Corrected approach
...
```
```

---

## Active Lessons

### 2026-02-01 - 🏗️ Architecture - Contact Data Fetching

**What Happened:**
Initial spec stored phone/email directly in Person entity, causing sync drift with Apple Contacts.

**Root Cause:**
Treating Contacts data as owned by our app instead of reference data.

**Solution:**
Store only `cnIdentifier` and fetch phone/email on-demand from CNContactStore when needed.

**Prevention Rule:**
Never duplicate data that has a single source of truth elsewhere. Always fetch reference data on-demand and cache only for performance (with invalidation).

**Code Example:**
```swift
// Bad - Storing contact info
struct Person {
    let phone: String?
    let email: String?
}

// Good - Fetching on-demand
func getContactInfo(for person: Person) -> (phone: String?, email: String?)? {
    guard let cnId = person.cnIdentifier else { return nil }
    
    let store = CNContactStore()
    let keys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
    
    guard let contact = try? store.unifiedContact(withIdentifier: cnId, keysToFetch: keys) else {
        return nil
    }
    
    return (
        phone: contact.phoneNumbers.first?.value.stringValue,
        email: contact.emailAddresses.first?.value as String?
    )
}
```

### 2026-02-02 - 📊 Data - Group Assignment Timestamp

**What Happened:**
SLA calculations need a fallback date when a person has no touch history but is added to a group.

**Root Cause:**
Without a dedicated group-assignment timestamp, SLA status can drift or be inconsistent after group changes.

**Solution:**
Introduce `groupAddedAt` and enforce updates through a centralized `AssignGroupUseCase`.

**Prevention Rule:**
Any time a person changes groups (or is missing `groupAddedAt`), use `AssignGroupUseCase` so the timestamp is always set.

**Code Example (if applicable):**
```swift
let updated = AssignGroupUseCase().assign(person: person, to: newGroupId)
```

### 2026-02-02 - 📊 Data - Tag Transformable Safety

**What Happened:**
Transformable `tagIds` can be persisted as mixed types (UUID/NSUUID/String) and lead to decode errors.

**Root Cause:**
Core Data transformables don’t enforce a single concrete Swift type at runtime.

**Solution:**
Harden mapping to accept UUID, NSUUID, and String and ignore invalid entries.

**Prevention Rule:**
Always decode `tagIds` defensively and never assume a single concrete type from Core Data.

**Code Example (if applicable):**
```swift
// Mapping now normalizes UUID, NSUUID, and String values
let tags = decodeTagIds(tagIds)
```

### 2026-02-02 - 📊 Data - Contacts Fetch Keys

**What Happened:**
App crashed after granting Contacts access with `CNPropertyNotFetchedException` when using `CNContactFormatter`.

**Root Cause:**
`CNContactFormatter` accesses name components that weren’t included in the fetch request keys.

**Solution:**
Include `CNContactFormatter.descriptorForRequiredKeys(for: .fullName)` in fetch keys and use organization name as fallback.

**Prevention Rule:**
Whenever using `CNContactFormatter`, always include its required keys descriptor in the fetch request.

**Code Example (if applicable):**
```swift
let formatterKeys = CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
```

### 2026-02-02 - ⚡ Performance - Contacts Fetch Threading

**What Happened:**
Contacts enumeration warned about running on main thread, risking UI stalls.

**Root Cause:**
`CNContactStore.enumerateContacts` is synchronous and expensive on main.

**Solution:**
Run contact fetch on a background task and publish results back on the main actor.

**Prevention Rule:**
All contact fetches must be off main; only UI updates occur on main.

### 2026-02-02 - 🎨 UI/UX - Onboarding Cadence Selection

**What Happened:**
Initial onboarding let users select contacts and a single default group in the same screen, which didn’t match expected per-contact cadence selection.

**Root Cause:**
Flow design didn’t separate contact selection from per-contact group assignment.

**Solution:**
Split onboarding into two steps: select contacts first, then assign a cadence per contact.

**Prevention Rule:**
When a choice applies per-contact, collect contacts first and apply per-contact settings in a dedicated step.

### 2026-02-02 - 🧠 Swift - Type Name Collisions

**What Happened:**
Build failed because `Group {}` in SwiftUI was resolved to the domain `Group` type.

**Root Cause:**
Domain model name collided with `SwiftUI.Group`, causing confusing compiler errors.

**Solution:**
Explicitly reference `SwiftUI.Group` in views when ambiguity exists.

**Prevention Rule:**
When a domain model collides with a SwiftUI type, qualify the SwiftUI type (`SwiftUI.Group`) to avoid ambiguity.

**Code Example (if applicable):**
```swift
SwiftUI.Group { ... }
```

### 2026-02-02 - 🎨 UI/UX - Sort Scope Clarity

**What Happened:**
Sort toggle appeared ineffective because it only re-ordered items within sections.

**Root Cause:**
The UI didn’t clarify whether “Sort by Name” should flatten across SLA sections.

### 2026-02-03 - 🏗️ Architecture - Lightweight Migration Required

**What Happened:**
Adding new fields to Core Data (e.g., `notificationGrouping`) caused build/run risk without migration enabled.

**Root Cause:**
Persistent store descriptions weren’t configured for lightweight migration.

**Solution:**
Enable `shouldMigrateStoreAutomatically` and `shouldInferMappingModelAutomatically`.

**Prevention Rule:**
Any Core Data model change must include migration settings in `CoreDataStack` before shipping.

### 2026-02-03 - 🔔 Notifications - Custom Time Overrides Must Exclude Grouped Notifications

**What Happened:**
People with `customBreachTime` could receive duplicate reminders when grouped notifications were scheduled.

**Root Cause:**
Custom‑time people were classified for both grouped and custom schedules.

**Solution:**
Classify notifications so custom‑time people are excluded from grouped lists and still counted for badge totals.

**Prevention Rule:**
When per‑person overrides exist, ensure grouped scheduling explicitly excludes those people.

### 2026-02-03 - ✅ Testing - Domain Model Changes Require Test Updates

**What Happened:**
Adding `notificationGrouping` broke tests due to missing init arguments.

**Root Cause:**
Test fixtures weren’t updated to reflect the new required field.

**Solution:**
Update all AppSettings test builders/fixtures to include new fields.

**Prevention Rule:**
Any change to a domain entity must be reflected in all test factories/fixtures immediately.

### 2026-02-03 - 🎨 UI/UX - Empty State CTA Should Match Core Flow

**What Happened:**
Home empty state had no actionable path to import contacts.

**Root Cause:**
Empty state lacked a CTA even though the flow required “Add from Contacts.”

**Solution:**
Add “Add Contacts” CTA wired to the same import flow as Settings.

**Prevention Rule:**
Every empty state should provide the fastest path to resolve it.

### 2026-02-03 - 📊 Data - Demo Mode Must Be Applied Immediately

**What Happened:**
Toggling demo mode in Settings didn’t add/remove demo data in real time.

**Root Cause:**
The toggle only updated settings, not the data layer.

**Solution:**
Seed or remove demo data on toggle and notify UI on the main thread.

**Prevention Rule:**
Any settings toggle that affects data must trigger the data operation immediately.

### 2026-02-03 - 🧠 Swift - Multi‑Select Lists Must Be Explicitly Enabled

**What Happened:**
Multi‑select in the “Add Contacts to Tag” view didn’t work without edit mode.

**Root Cause:**
SwiftUI list selection requires edit mode for multi‑select.

**Solution:**
Force edit mode for multi‑select list screens.

**Prevention Rule:**
When a list uses `selection`, ensure edit mode is active or explicitly enforced.

### 2026-02-03 - 🧠 Swift - Sheet Item vs Flag for Edits

**What Happened:**
Edit buttons for groups/tags sometimes opened the “new” sheet instead of the selected item.

**Root Cause:**
Using a shared boolean to present the sheet allowed stale state when multiple actions fired quickly.

**Solution:**
Use `.sheet(item:)` for edit flows so the selected model drives presentation.

**Prevention Rule:**
For edit flows, prefer `.sheet(item:)` over boolean flags to avoid mismatched state.

### 2026-02-03 - 🎨 UI/UX - Settings Counts Refresh

**What Happened:**
Paused contacts count in Settings didn’t update after resuming from the paused list.

**Root Cause:**
Settings view didn’t listen for model changes outside its own screen.

**Solution:**
Post a change notification on resume and refresh counts on receive.

**Prevention Rule:**
When secondary screens change global counters, publish a notification and refresh on return.

### 2026-02-03 - ⚡ Performance - Settings Contact Sync Threading

**What Happened:**
Sync from Contacts produced a main-thread warning and appeared to do nothing.

**Root Cause:**
Contact enumeration ran on the main actor.

**Solution:**
Move contacts fetch to a detached task and apply updates on background context.

**Prevention Rule:**
Contact fetch must always happen off main; only UI updates should be on main.

**Solution:**
When Sort = Name, show a single globally sorted list regardless of SLA status.

**Prevention Rule:**
Sort options that change grouping must visually change grouping, not just order within groups.

### 2026-02-02 - 📊 Data - Detail View Reload

**What Happened:**
Tags appeared to vanish when navigating away and back to a person detail view.

**Root Cause:**
Detail view reused a stale in-memory `Person` instead of reloading from the repository.

**Solution:**
Reload the person from the repository on appear and after saves.

**Prevention Rule:**
Detail views should refresh their model from persistence when entering, not rely on navigation-passed snapshots.

### 2026-02-02 - ⚡ UX - Quick Action URL Handling

**What Happened:**
Quick action URLs failed to open in the simulator (tel/mail) without user feedback.

**Root Cause:**
Simulator/device limitations and un-sanitized phone strings.

**Solution:**
Sanitize phone numbers and show inline feedback when openURL fails.

**Prevention Rule:**
Treat external URL launches as fallible and provide user-visible feedback on failure.

---

## Historical Lessons

*This section will be populated as development progresses*

---

**Maintenance Notes:**
- Review this file at the start of each development session
- Add new lessons immediately after corrections from user
- Archive old lessons quarterly if no longer relevant
- Keep active lessons at top for quick reference
