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

### 2026-02-04 - 🔧 Git - Commit Attribution Email Association

**What Happened:**
GitHub displayed commits as authored by "firmlyundecided" even after changing git author name to "slavins-co" because the email address (bradleyslavin+github@gmail.com) was associated with the firmlyundecided GitHub account.

**Root Cause:**
GitHub determines commit attribution by email address, not by the name in git config. An email can only be associated with one GitHub account. The old email was linked to a different account than the intended one.

**Solution:**
1. Update git config to use the email associated with the target GitHub account (slavintech@gmail.com)
2. Rewrite all commit history using `git filter-branch` to update both author name and email
3. Delete and recreate the repository to push clean commits with correct attribution

**Prevention Rule:**
Before pushing to GitHub, verify that git config user.email matches an email address associated with the target GitHub account. Check this with `gh auth status` and GitHub account settings. Email address determines attribution, not the name.

**Code Example:**
```bash
# Set git config to email associated with target GitHub account
git config --global user.email "slavintech@gmail.com"
git config --global user.name "slavins-co"

# Verify configuration
git config user.email
git config user.name

# Rewrite commit history if needed
git filter-branch -f --env-filter '
OLD_EMAIL="old@example.com"
CORRECT_NAME="correct-name"
CORRECT_EMAIL="correct@example.com"

if [ "$GIT_COMMITTER_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_COMMITTER_NAME="$CORRECT_NAME"
    export GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
fi
if [ "$GIT_AUTHOR_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_AUTHOR_NAME="$CORRECT_NAME"
    export GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
fi
' --tag-name-filter cat -- --branches --tags

# Clean up old refs
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Verify commits
git log --format="%an <%ae>"
```

### 2026-02-04 - 🎨 UI/UX - A-Z Sidebar Requires Layout Isolation

**What Happened:**
A-Z sidebar in contact picker views appeared non-functional. Tapping letters didn't scroll to sections, and the sidebar was catching scroll gestures from the main list.

**Root Cause:**
1. Using ZStack placed the sidebar inside the ScrollView/List's gesture handling area
2. ScrollView/List was intercepting all touch events before they reached the sidebar
3. Using `.onTapGesture` instead of Button made touch handling less reliable
4. No ScrollViewReader/scrollTo mechanism to enable programmatic scrolling

**Solution:**
1. Changed layout from ZStack to HStack to position sidebar outside the scroll container
2. Wrapped content in ScrollViewReader with proxy parameter
3. Changed sidebar items from Text with onTapGesture to Button components
4. Added .id() to section headers for scroll targeting
5. Implemented proxy.scrollTo(section, anchor: .top) with smooth animation

**Prevention Rule:**
When adding interactive overlays (like sidebars) to scrollable content:
- Use HStack/VStack to position them outside the scroll container, not ZStack over it
- Always use Button for tappable elements instead of onTapGesture when inside complex layouts
- Use ScrollViewReader + .id() for programmatic scrolling in SwiftUI
- Test touch interactions early - visual appearance doesn't guarantee functionality

**Code Example:**
```swift
// Bad - Sidebar inside scroll area with ZStack
ZStack(alignment: .trailing) {
    List { /* content */ }
    SectionIndexView { /* onTapGesture */ }
}

// Good - Sidebar outside scroll area with HStack
ScrollViewReader { proxy in
    HStack(spacing: 0) {
        List {
            Section(header: Text(section.0).id(section.0)) {
                /* content */
            }
        }
        SectionIndexView { section in
            proxy.scrollTo(section, anchor: .top)
        }
    }
}
```

### 2026-02-04 - 🎨 UI/UX - Duplicate Views Need Consistent Fixes

**What Happened:**
Fixed A-Z sidebar in ContactPickerView (onboarding) but user was testing NewContactsPickerView (Settings → Add from Contacts), which still had the bug.

**Root Cause:**
App has two similar contact picker views serving different purposes, and the fix was only applied to one of them.

**Solution:**
Applied the same fix to both ContactPickerView and NewContactsPickerView.

**Prevention Rule:**
When fixing a bug in a view:
1. Search codebase for similar/duplicate views with glob/grep
2. Check if the same pattern exists in multiple places
3. Apply the fix consistently across all instances
4. Ask user which view they're testing if uncertain

**Code Example:**
```bash
# Search for similar views
rg "struct.*ContactPicker.*View" --type swift
# or
fd -e swift -x grep -l "SectionIndexView"
```

### 2026-02-04 - 🔧 Git - GitHub CLI Authentication Scopes

**What Happened:**
Attempting to delete a GitHub repository with `gh repo delete` failed with HTTP 403 "Must have admin rights to Repository" even though the account owned the repository.

**Root Cause:**
GitHub CLI authentication tokens are scoped, and the initial authentication didn't include the `delete_repo` scope required for repository deletion.

**Solution:**
Refresh authentication with the required scope: `gh auth refresh -h github.com -s delete_repo`

**Prevention Rule:**
When using gh CLI for repository management operations (delete, transfer, etc.), ensure authentication includes the necessary scopes. Common scopes:
- `repo` - Full repository access (create, read, write)
- `delete_repo` - Delete repositories
- `workflow` - GitHub Actions management
- `admin:org` - Organization management

**Code Example:**
```bash
# Check current authentication status and scopes
gh auth status

# Refresh with additional scope
gh auth refresh -h github.com -s delete_repo

# Or authenticate with multiple scopes initially
gh auth login --scopes repo,delete_repo,workflow
```

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

### 2026-02-16 - 🎨 UI/UX - SwiftUI Sheet Stacking Timing Bug

**What Happened:**
Settings → Add from Contacts → Assign Groups showed an empty contact list. The `SettingsGroupAssignmentView` sheet appeared but no contacts were rendered.

**Root Cause:**
The `onImport` callback dismissed the picker sheet (`showNewContactsPicker = false`) and presented the group assignment sheet (`showGroupAssignment = true`) in the same render cycle. SwiftUI's `.sheet` content closure captured `selectedForImport` at its pre-update (empty) value because state mutations hadn't propagated yet.

Additionally, `NewContactsPickerView` called `dismiss()` after `onImport()`, creating a double-dismiss.

**Solution:**
Added a `shouldShowGroupAssignment` flag and used `.onChange(of: showNewContactsPicker)` to defer the second sheet presentation until after the first sheet fully dismissed.

**Prevention Rule:**
Never dismiss one sheet and present another in the same render cycle. Use `.onChange(of:)` to detect when the first sheet has fully dismissed, then present the second. This ensures all state mutations have propagated.

**Code Example:**
```swift
// Bad - Sheet stacking in same render cycle
onImport: { selected in
    selectedForImport = selected
    showSheet1 = false       // dismiss
    showSheet2 = true        // present — captures stale state!
}

// Good - Deferred presentation via .onChange
onImport: { selected in
    selectedForImport = selected
    shouldShowSheet2 = true
    showSheet1 = false
}
.onChange(of: showSheet1) { _, isPresented in
    if !isPresented && shouldShowSheet2 {
        shouldShowSheet2 = false
        showSheet2 = true    // state is settled
    }
}
```

### 2026-02-16 - 🏗️ Architecture - Person Struct Initializer Blast Radius

**What Happened:**
Adding `snoozedUntil: Date?` to `Person` required updating ~15 initializer call sites across the app and tests. Same pattern occurred with `timeOfDay: TimeOfDay?` on `TouchEvent` (~4 sites).

**Root Cause:**
Swift structs use memberwise initializers — every new property requires updating every call site.

**Solution:**
Used subagents with `replace_all` for consistent patterns (e.g., inserting `snoozedUntil: nil,` after `customBreachTime: nil,` across all files).

**Prevention Rule:**
When adding optional properties to domain entities:
1. Always add with default `nil` value
2. Use `grep` to find ALL initializer call sites before editing
3. For Person (~15 sites), use `replace_all` on a unique neighboring pattern
4. For TouchEvent (~4 sites), manual updates are fine
5. Always build after to catch any missed sites

### 2026-02-22 - 🎨 UI/UX - WCAG AA Color Contrast for Section Headers

**What Happened:**
Section headers in ContactListSection used colored text (e.g., green for "On Track", red for "Overdue") directly on white/dark backgrounds, failing WCAG AA 4.5:1 contrast ratio.

**Root Cause:**
Using color alone to convey section identity — many status colors (especially greens, yellows) don't have sufficient contrast against white backgrounds.

**Solution:**
Changed section headers to use `DS.Colors.primaryText` (always high contrast) paired with a small 8pt colored dot indicator: `Circle().fill(Color(hex: colorHex)).frame(width: 8, height: 8)`.

**Prevention Rule:**
Never use color alone to convey section identity in text. Always pair colored indicators (dots, icons) with high-contrast text. Test all color combinations against WCAG AA (4.5:1 for text under 18pt).

### 2026-02-22 - 🎨 UI/UX - Touch Target Size vs Layout Inflation

**What Happened:**
Adding `.frame(minWidth: 44, minHeight: 44)` to filter chip X buttons (dismiss icons) made the chips visibly taller when active, breaking visual consistency with inactive chips.

**Root Cause:**
Filter chips are ~32pt tall. Adding `minHeight: 44` to an inline child element inflates the parent's height to accommodate the 44pt minimum.

**Solution:**
Removed `minHeight: 44`, kept only `.frame(minWidth: 44)` with `.contentShape(Rectangle())` for horizontal tap area. Accepted ~32pt vertical target for a secondary dismiss action.

**Prevention Rule:**
When adding touch target sizing to inline elements inside compact containers (chips, pills, tags):
- `minWidth` is safe — it extends the tap area horizontally without visual impact
- `minHeight` will inflate the container height — always test visually
- For secondary actions (dismiss, close), horizontal-only expansion is an acceptable trade-off

### 2026-02-22 - 🎨 UI/UX - Font Weight as Legibility Lever

**What Happened:**
Section headers using `Font.subheadline.weight(.semibold)` (~15pt) lacked legibility in light mode against white backgrounds, even after fixing color to primaryText.

**Root Cause:**
`.semibold` at small sizes (15pt and below) doesn't provide enough visual weight to stand out as a section header, especially in light mode where the contrast ceiling is lower.

**Solution:**
Changed `DS.Typography.sectionHeader` from `.semibold` to `.bold`.

**Prevention Rule:**
For section-level headers at `subheadline` size or smaller, default to `.bold` minimum. Reserve `.semibold` for body-adjacent text that shouldn't compete with headers.

### 2026-02-22 - 🎨 UI/UX - Semantic Color Tier Selection (tertiaryText vs secondaryText)

**What Happened:**
Settings section headers (FREQUENCY, GROUPS, NOTIFICATIONS) in PersonDetailView used `DS.Colors.tertiaryText` (~30% opacity), making them barely readable in both light and dark mode.

**Root Cause:**
`tertiaryText` is designed for hint/placeholder text, not for content that must be read. It was applied to section headers that serve as navigation landmarks.

**Solution:**
Changed all three settings section headers from `tertiaryText` to `secondaryText` (~60% opacity).

**Prevention Rule:**
- `primaryText` — main content, always readable
- `secondaryText` — supporting content that must still be read (labels, section headers, captions)
- `tertiaryText` — decorative/hint only (placeholders, disabled states, timestamps)
If in doubt, use `secondaryText`. Only use `tertiaryText` for text the user doesn't need to read.

### 2026-02-22 - 🏗️ Architecture - Terminology Mapping (Backend vs UI)

**What Happened:**
The app uses `Tag` in the backend model but the UI should display "Groups" (for people). All 8 user-facing "Tag"/"Tags" strings across 5 files needed systematic renaming.

**Root Cause:**
Backend model names were exposed directly in UI strings without a mapping layer. The terminology evolved during design review but the UI wasn't updated.

**Solution:**
Audited all Swift UI files with grep for user-facing "Tag"/"Tags" strings, identifying exactly 8 strings across 5 files. Changed all to "Group"/"Groups" while preserving backend model names.

**Prevention Rule:**
Maintain a terminology mapping:
- Backend `Tag` → UI "Group" (for organizing people)
- Backend `Group` → UI "Frequency" (for cadence settings)
- Backend `TouchEvent` → UI "Connection" (for contact logging)
Always grep for stale terms after any rename. Never expose backend model names directly in user-facing strings.

### 2026-02-22 - 🔧 Git - Synology Drive Permission Artifacts

**What Happened:**
Pre-merge check revealed 69 files showing as "changed" in git diff, but all had 0 insertions/0 deletions — only file permissions changed from `100644` to `100755`.

**Root Cause:**
Synology Drive cloud sync modifies file permissions during synchronization, adding execute bits to regular files.

**Solution:**
Reset with `git checkout -- StayInTouch/` to restore original permissions without affecting content.

**Prevention Rule:**
Before committing, always check `git diff --stat`. If files show 0 insertions/0 deletions, they're permission-only artifacts. Reset with `git checkout -- <directory>/` rather than committing. Consider adding `core.fileMode = false` to git config if this recurs frequently.

### 2026-02-22 - 🔧 Git - Pre-Beta Version Numbering Strategy

**What Happened:**
App was versioned as v1.x.x before reaching TestFlight, giving the impression of a mature release. Needed to revise to 0.x.x to signal active development.

**Root Cause:**
Version scheme wasn't established before the first release. Changing retroactively required updating 6 MARKETING_VERSION entries in .pbxproj, deleting old GitHub releases, and recreating them with new tags.

**Solution:**
Changed all versions: v1.1.1 → v0.1.1, then v0.2.0 on merge. Updated CURRENT_PROJECT_VERSION (build number) separately. Deleted and recreated GitHub releases.

**Prevention Rule:**
Establish version scheme before first release:
- 0.x.x = pre-beta / active development
- 1.0.0 = first public release / App Store submission
- MARKETING_VERSION appears 6 times in .pbxproj (3 Debug + 3 Release configs)
- CURRENT_PROJECT_VERSION = incrementing build number, independent of marketing version

### 2026-02-22 - 📋 Process - Apple HIG Evolves (Bottom Search Bar)

**What Happened:**
Design critique flagged the bottom search bar placement as a usability concern, recommending moving it to the top. User corrected: Apple now defaults to bottom search in Messages, Mail, Notes, and Settings.

**Root Cause:**
Applied outdated HIG knowledge — search bar conventions shifted in recent iOS versions.

**Solution:**
Disregarded the recommendation. Bottom search bar is now the Apple convention.

**Prevention Rule:**
Before critiquing UI placement against Apple HIG, verify the current convention in the latest iOS version. Apple's patterns evolve — check the actual system apps (Messages, Mail, Notes, Settings) as reference, not outdated documentation.

### 2026-02-22 - 📋 Process - License Selection for Commercial Apps

**What Happened:**
Repo was created with MIT license, which allows anyone to freely clone, modify, and ship a competing app — problematic for a potential paid App Store app.

**Root Cause:**
License was chosen by default without considering distribution intent.

**Solution:**
Changed to "All Rights Reserved" with a proprietary notice allowing viewing only. Repo stays public for portfolio purposes.

**Prevention Rule:**
Choose license based on distribution intent before making repo public:
- **MIT/Apache** — truly open source, anyone can use your code
- **FSL/BSL** — source-available, visible but restricted (converts to open source after 2-4 years)
- **All Rights Reserved** — proprietary, view-only, maximum protection for commercial apps
For potential paid apps, default to All Rights Reserved. Can always relicense later.

### 2026-02-24 - 🔧 Git - Discarding Uncommitted Work Requires Two Steps

**What Happened:**
Attempting to discard ~156 uncommitted files from a failed previous implementation with `git checkout -- .` left staged renames and additions persisting.

**Root Cause:**
`git checkout -- .` only reverts unstaged changes. Files previously staged with `git add` remain in the index.

**Solution:**
Always `git reset HEAD -- .` first (unstage all), then `git checkout HEAD -- .` (revert working tree to HEAD).

**Prevention Rule:**
When discarding all uncommitted work to start fresh:
```bash
git reset HEAD -- .       # unstage everything
git checkout HEAD -- .    # revert working tree
git clean -fd             # remove untracked files (if needed)
```

### 2026-02-24 - 📊 Data - CoreData renamingIdentifier for Lightweight Migration

**What Happened:**
Renaming CoreData attribute `slaDays` → `frequencyDays` required a versioned model (v1 → v2) with lightweight migration support.

**Root Cause:**
CoreData treats a renamed attribute as "delete old + add new" without explicit guidance, losing data.

**Solution:**
Added `renamingIdentifier="slaDays"` to the `frequencyDays` attribute in the v2 model. This tells CoreData the attribute was renamed, preserving existing data during migration.

**Prevention Rule:**
When renaming a CoreData attribute:
1. Create a new versioned model (never modify the current version in production)
2. Add `renamingIdentifier="oldAttributeName"` to the renamed attribute
3. Set the new model as `.xccurrentversion`
4. Ensure `shouldMigrateStoreAutomatically` and `shouldInferMappingModelAutomatically` are both true
5. Test migration with in-memory store to verify data survives

### 2026-02-24 - 📊 Data - CoreDataStack Should Never Auto-Delete on Failure

**What Happened:**
The original CoreDataStack silently deleted the SQLite store and recreated it when persistent store loading failed, destroying all user data without warning.

**Root Cause:**
The initial implementation used `fatalError()` or auto-delete as the store load failure handler — acceptable for development but catastrophic in production.

**Solution:**
Replaced auto-delete with:
1. `@Published migrationFailed` flag on CoreDataStack
2. `.coreDataMigrationFailed` notification
3. User-facing alert in StayInTouchApp with explicit "Reset App Data" / "Cancel" buttons
4. `resetStore()` method that only runs after explicit user confirmation

**Prevention Rule:**
Never auto-delete a persistent store on load failure. Always:
1. Surface the failure to the user with clear messaging
2. Require explicit user confirmation before destructive recovery
3. Log the error for debugging
4. Provide a "Cancel" option so the user can seek support

### 2026-02-24 - 🏗️ Architecture - Error Toast vs Logger Distinction

**What Happened:**
The app had ~20 `try?` patterns silently swallowing errors. User-initiated saves, deletes, and touch logs could fail without any feedback.

**Root Cause:**
No error presentation mechanism existed, so developers defaulted to `try?` everywhere.

**Solution:**
Created `ErrorToastManager` singleton + `ErrorToastModifier` overlay. Applied a clear rule:
- User-initiated operations → `ErrorToastManager.shared.show(.saveFailed("context"))`
- Background/batch operations → `AppLogger.logError()` only

**Prevention Rule:**
```
User taps a button → show error toast on failure
App does something in background → log error silently
```
Never use `try?` in user-initiated flows. Always catch and either show a toast or log.

### 2026-02-24 - 🏗️ Architecture - Person Struct Property Addition Blast Radius

**What Happened:**
Adding `contactUnavailable: Bool` to Person required updating 15 constructor call sites across 10 files (3 source, 7 test). Same pattern as the earlier `snoozedUntil` addition.

**Root Cause:**
Swift structs with memberwise initializers require every call site to include every property.

**Solution:**
Used a subagent to parallelize the bulk updates. The subagent read each file, found the `Person(` constructor, and inserted `contactUnavailable: false,` before `groupAddedAt:`.

**Prevention Rule:**
When adding a new property to `Person`:
1. Add the property to the struct definition
2. Update `PersonEntity+Mapping.swift` (toDomain + apply)
3. Use `grep "Person("` to find ALL call sites (~15 for Person)
4. Delegate to a subagent with explicit file list and insertion point
5. Build to catch any missed sites
6. If the property is in the CoreData model, update the v2+ model too

### 2026-02-24 - 📊 Data - ContactsSyncService Deleted Contact Detection

**What Happened:**
Needed to detect when a tracked person's underlying iOS contact was deleted or merged.

**Root Cause:**
The sync service only updated names for contacts it found — it silently skipped missing contacts.

**Solution:**
Changed the loop logic:
- If `cnIdentifier` exists in the system contacts → sync name + clear `contactUnavailable`
- If `cnIdentifier` is NOT found → set `contactUnavailable = true`
- If already marked unavailable → skip save (no redundant writes)

Also updated `PersonDetailViewModel.refreshContactInfo()` to catch `ContactsFetcherError.contactNotFound` and set the flag on individual contact views.

**Prevention Rule:**
When syncing external data, always handle the "missing" case explicitly. Don't just skip records that aren't found — they may represent deleted data that needs flagging.

### 2026-02-24 - 🔧 Git - Version Bumps Touch 6 Locations in pbxproj

**What Happened:**
Needed to bump `CURRENT_PROJECT_VERSION` (5→6) and `MARKETING_VERSION` (0.2.0→0.2.1) across the project.

**Root Cause:**
Xcode stores build settings in 6 separate configuration blocks (Debug/Release × App/Tests/UITests).

**Solution:**
Used `replace_all: true` with the Edit tool to update all 6 occurrences at once.

**Prevention Rule:**
Both `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` appear exactly 6 times in `project.pbxproj`. Always use a global replace. After editing, verify with grep that all 6 are updated.

### 2026-02-24 - ⚡ Workflow - Subagents for Bulk File Edits

**What Happened:**
The #57 rename touched 21 files and #56 touched 15 constructor sites. Managing these in the main context caused "File has not been read yet" errors from context compression.

**Root Cause:**
Long editing sessions compress earlier Read calls out of context, making the Edit tool unable to verify file contents.

**Solution:**
Delegated bulk file edits to subagents with `bypassPermissions` mode. Each subagent has a fresh context window and can read+edit without compression issues.

**Prevention Rule:**
When an edit touches 5+ files:
1. Do core/architectural changes yourself (2-3 files)
2. Delegate mechanical updates (constructor sites, renames) to a subagent
3. Provide the subagent with an explicit file list and exact edit instructions
4. Build+test after the subagent completes to verify

### 2026-02-24 - 🐛 Bug - CNAuthorizationStatus.limited Requires iOS 18 Availability Check

**What Happened:**
Using `CNAuthorizationStatus == .limited` directly caused a build error: `'limited' is only available in iOS 18.0 or newer`. The app targets iOS 17.0.

**Root Cause:**
`.limited` was added to `CNAuthorizationStatus` in iOS 18. Using it without an availability check fails compilation against the iOS 17 deployment target.

**Solution:**
Created a `private static func isLimitedAccess(_ status: CNAuthorizationStatus) -> Bool` that wraps the check in `if #available(iOS 18.0, *)`.

**Prevention Rule:**
When using newer API enum cases (especially `.limited` for contacts, photos, etc.):
1. Check the API's availability annotation before using
2. Wrap in `#available` when the deployment target is lower
3. Provide a sensible fallback for older OS versions (typically `false` for opt-in features)

### 2026-02-24 - 🏗️ Architecture - UNCalendarNotificationTrigger Repeating with Minimal DateComponents

**What Happened:**
All notifications used `repeats: false` with full date components (year/month/day/hour/minute). They fired exactly once and were never rescheduled if the background refresh task didn't run.

**Root Cause:**
Using complete DateComponents with `repeats: true` would fire once a year (same date), not daily. Using `repeats: false` meant the notification system relied entirely on BGAppRefreshTask (unreliable 6-hour interval) for rescheduling.

**Solution:**
Changed to minimal DateComponents:
- Daily: only `hour` + `minute` → fires every day at that time with `repeats: true`
- Weekly: only `weekday` + `hour` + `minute` → fires every week on that day
- Added `applicationWillEnterForeground` rescheduling as a reliability layer
- `clearAll()` + re-schedule is safe since iOS deduplicates by identifier

**Prevention Rule:**
For `UNCalendarNotificationTrigger` with `repeats: true`:
- Daily: use only `hour` and `minute` components
- Weekly: use only `weekday`, `hour`, and `minute` components
- Never include `year`, `month`, or `day` for repeating triggers — it will fire at that exact calendar date only
- Always add a foreground rescheduling path as a fallback

### 2026-02-24 - 🏗️ Architecture - scenePhase for Detecting App Return After openURL

**What Happened:**
Needed to show an undo banner when the user returns to the app after tapping a quick action (Call/Message/Email) that opens an external app.

**Solution:**
Used `@Environment(\.scenePhase)` with `.onChange(of: scenePhase)` to detect when the app returns to `.active`. Stored the pending action in `@State` before openURL, then showed the undo banner on return.

**Prevention Rule:**
When implementing "do X when user returns to app" patterns:
1. Use `@Environment(\.scenePhase)` — cleaner than NotificationCenter for SwiftUI views
2. Store pending state before leaving (e.g., `pendingQuickActionMethod`)
3. In `.onChange(of: scenePhase)`, check for `.active` + pending state
4. Auto-dismiss transient UI with `Task.sleep` (5 seconds is standard for undo)
5. Handle edge cases: view deinit = implicit confirm, new action = replace old pending

### 2026-02-24 - 📊 Data - Never Sideload Broken Builds to Personal Devices

**What Happened:**
After v0.2.1 shipped with a clean v1→v2 CoreData migration, the user's personal device showed the "Data Update Required" migration failure alert. Migration worked fine on fresh installs and in tests.

**Root Cause:**
The user had previously sideloaded a development build from the failed first implementation attempt. That broken build modified the CoreData model in-flight (without proper versioning), writing a store whose model hash matched neither the clean v1 nor the new v2 model. CoreData couldn't find a source model to migrate from.

**Solution:**
Delete and reinstall the app. The user lost their first week of real data.

**Prevention Rule:**
1. NEVER sideload experimental/broken builds to a device with real data
2. Use the Simulator for development testing — it's disposable
3. Only sideload to a personal device from a known-good commit on `main`
4. If a broken build was sideloaded, warn the user that their device store may be corrupted before shipping a migration
5. Future: consider adding a store hash check that detects "unknown model" vs "known v1 needing migration" and provides a more helpful error message

### 2026-02-24 - 🔧 Git - One Issue Per Commit for Clean Bisection

**What Happened:**
Implemented 4 issues (#57, #55, #35, #56) each as an isolated commit with build+test verification after each.

**Root Cause:**
N/A — this was the planned approach.

**Solution:**
Each commit addresses exactly one issue: rename, migration, error toasts, deleted contacts. The version bump is a 5th commit. All commits on a feature branch, merged via PR.

**Prevention Rule:**
For multi-issue branches:
1. One commit per issue, in dependency order
2. Build + run ALL tests after each commit
3. Commit message starts with issue number: `#57: Short description`
4. Version bump as final separate commit
5. This makes `git bisect` trivial if a regression appears later

### 2026-02-27 - ⚡ Performance - fetchBatchSize for All Core Data Requests

**What Happened:**
`CoreDataPersonRepository` had no `fetchBatchSize` on any fetch request, meaning Core Data faulted all matching objects into memory at once.

**Root Cause:**
Default `fetchBatchSize` of 0 means "fetch everything into memory." For lists with 100+ contacts, this wastes memory faulting objects the user hasn't scrolled to yet.

**Solution:**
Added `request.fetchBatchSize = 50` to every `NSFetchRequest<PersonEntity>` in the repository. This tells Core Data to fault objects in batches of 50, keeping memory proportional to what's on-screen.

**Prevention Rule:**
Every `NSFetchRequest` that returns a list (not a single item via `fetchLimit = 1`) should set `fetchBatchSize = 50`. This is a zero-risk optimization — behavior is identical, only memory footprint changes.

### 2026-02-27 - ⚡ Performance - Push Filtering into Core Data Predicates

**What Happened:**
`fetchOverdue()` loaded ALL tracked people into memory, then filtered in Swift code using `FrequencyCalculator`. This worked for small datasets but wouldn't scale.

**Root Cause:**
The overdue check requires joining person → group (to get `frequencyDays`), which seems hard to express in a single predicate. The initial implementation took the easy path of filtering in memory.

**Solution:**
Fetch all groups first (small dataset, ~5 groups), compute per-group cutoff dates, then build a compound OR predicate:
```swift
// For each group, compute cutoff = referenceDate - frequencyDays
// Predicate: (groupId == g1 AND lastTouchAt < cutoff1) OR (groupId == g2 AND lastTouchAt < cutoff2) ...
```
This handles the `effectiveLastTouchDate` fallback (groupAddedAt) and snooze filtering entirely at the SQL level.

**Prevention Rule:**
Before filtering Core Data results in Swift, ask: "Can this be expressed as a compound predicate?" Even complex multi-table logic can often be pushed to SQL by pre-fetching the small lookup table (groups) and building per-key predicates.

### 2026-02-27 - 📊 Data - Export Should Include Human-Readable Names

**What Happened:**
The data export only included UUIDs for groupId and tagIds, making the JSON unreadable without the app.

**Root Cause:**
Export was implemented as a direct mapping from the `Person` struct, which stores foreign keys (UUIDs) rather than denormalized names.

**Solution:**
Added `groupName: String?` and `tagNames: [String]` alongside existing UUID fields. Also added full `touchEvents` array per contact. Backward compatible — existing fields unchanged, new fields added.

**Prevention Rule:**
Any user-facing data export should be self-contained and human-readable. Include denormalized names alongside foreign keys. Add ISO 8601 date encoding and pretty-printed JSON for readability.

### 2026-02-27 - 🔧 Git - One Branch Per Issue for Multi-Issue Sessions

**What Happened:**
Implemented 4 issues (#81, #74, #59, #43) in a single session, each on its own branch from main with its own PR.

**Solution:**
For each issue: checkout main → create branch → implement → build → test → commit → push → PR → back to main. This keeps PRs atomic and reviewable.

**Prevention Rule:**
When implementing multiple issues in one session:
1. Start each from fresh `main` (not from a previous feature branch)
2. One branch per issue: `issue-N/short-description`
3. Build + test before committing
4. Create PR, then `git checkout main` before starting next issue
5. This avoids cross-contamination between unrelated changes

---

### 2026-02-27 - 🏗️ Architecture - NavigationPath for Deep Links

**What Happened:**
Notification deep links presented PersonDetailView as a `.sheet`, disconnecting from the app's normal NavigationStack flow. Needed to switch to programmatic navigation push.

**Root Cause:**
Original implementation used `@State private var deepLinkPerson: Person?` with `.sheet(item:)` instead of integrating with the NavigationStack.

**Solution:**
1. Add `Hashable` conformance to `Person` (based on `id` only — cheap, safe)
2. Replace `NavigationStack` with `NavigationStack(path: $navigationPath)`
3. Add `.navigationDestination(for: Person.self)` inside the stack
4. Deep link handler appends to `navigationPath` instead of setting sheet state

**Prevention Rule:**
When adding any deep link or programmatic navigation, always use `NavigationPath` + `navigationDestination(for:)` rather than sheets. Sheets are for modal workflows (create/edit), not for navigating to existing content.

---

### 2026-02-27 - 🏗️ Architecture - Backward-Compatible Codable Extensions

**What Happened:**
Added `touchEvents: [ExportTouchEvent]?` to `ExportPerson` struct for import feature. Needed to ensure existing exported JSON files (without this field) still decode correctly.

**Root Cause:**
Codable structs fail to decode if a non-optional field is missing from the JSON.

**Solution:**
Made the new field optional (`let touchEvents: [ExportTouchEvent]?`). Swift's `Codable` automatically treats missing optional keys as `nil` during decoding. Existing export tests continued passing without changes.

**Prevention Rule:**
When extending `Codable` types that have existing serialized data (files, APIs), always make new fields optional. This ensures backward compatibility with data written by older versions.

---

### 2026-02-27 - 📊 Data - Security-Scoped URLs from File Picker

**What Happened:**
`fileImporter` returns security-scoped URLs that require explicit access grants before reading.

**Solution:**
```swift
guard url.startAccessingSecurityScopedResource() else { return nil }
defer { url.stopAccessingSecurityScopedResource() }
let data = try Data(contentsOf: url)
```

**Prevention Rule:**
Always wrap `fileImporter` URL access with `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`. Without this, file reads silently fail on device (may work in simulator).

---

### 2026-02-27 - 📊 Data - Contact Photos: On-Demand with NSCache

**What Happened:**
Needed to display contact photos without storing image data in Core Data (same principle as phone/email).

**Solution:**
- `ContactsFetcher.fetchThumbnailImageData(identifier:)` returns `Data?` — nil on any permission issue or missing photo (no throw for optional enhancement)
- `NSCache<NSString, UIImage>` singleton in `ContactPhotoCache` for scroll performance
- SwiftUI `.task(id: cnIdentifier)` for async load with automatic cancellation
- Use `CNContactThumbnailImageDataKey` (pre-resized ~60x60pt by system, much smaller than full image)

**Prevention Rule:**
For any CNContact data displayed in UI: fetch on-demand, cache in memory (NSCache), never persist in Core Data. This prevents sync drift and keeps database lean.

---

### 2026-02-27 - 📊 Data - CNLabeledValue Label Extraction

**What Happened:**
Contact phone numbers and emails come as `CNLabeledValue` arrays. Labels are system constants (e.g., `_$!<Mobile>!$_`) that need human-readable conversion.

**Solution:**
```swift
let label = CNLabeledValue<NSString>.localizedString(forLabel: labeled.label ?? "")
```

**Prevention Rule:**
Always use `CNLabeledValue.localizedString(forLabel:)` to convert CNContact labels to display strings. Never display raw label constants to users.

---

### 2026-02-27 - 🏗️ Architecture - History Stack for Branching Navigation

**What Happened:**
Onboarding flow branches (contactsPermission → contactsRequired OR contactPicker), so "previous step" can't be computed from current step alone.

**Solution:**
- `private(set) var stepHistory: [Step] = []` — records actual path
- `pushAndNavigate(to:)` appends current step to history before transitioning
- `goBack()` pops from history
- All forward navigation methods refactored to use `pushAndNavigate(to:)` — single point of control

**Prevention Rule:**
For any multi-step flow with branching paths, use a history stack pattern (not step arithmetic). The history records what actually happened, not what could have happened.

---

### 2026-02-27 - ✅ Testing - Test Through Public API Only

**What Happened:**
Tried to write a test that set `sut.stepHistory` directly, but it was `private(set)`. Had to rewrite to drive through public methods instead.

**Solution:**
Rewrote test to navigate forward through public methods (`goToContactsPermission()`, `skipContactsPermission()`, etc.), then test `goBack()` behavior. Tests that exercise the actual navigation path are more meaningful than those that manipulate internal state.

**Prevention Rule:**
Always write tests that exercise the public API, not internal state. If you can't set up the state through public methods, the test scenario may not be reachable in practice.

### 2026-02-27 - 🔔 Notifications - App Icon Badge Requires Direct setBadgeCount() Call

**What Happened:**
Badge count setting (overdue only vs overdue + due soon) appeared to have no effect. Simulator always showed badge 1; personal device showed no badge at all.

**Root Cause:**
`NotificationScheduler.scheduleAll()` only set badge via `content.badge` on notification objects — this value only takes effect when iOS delivers the notification. No code called `UNUserNotificationCenter.current().setBadgeCount()` directly. Additionally, `AppDelegate.applicationWillEnterForeground` cleared badge to 0 unconditionally, and the subsequent `scheduleAll()` only embedded badge in future notifications.

Secondary issues: `NotificationClassifier` had asymmetric badge counting — `allOverdue` included custom breach time people but `dueSoon` excluded them. Also `.dueToday` (exactly at SLA boundary) wasn't counted in `allOverdue` despite the home screen showing them as overdue.

**Solution:**
1. Added `setBadgeCount(badgeCount)` directly in `scheduleAll()` after calculating the count
2. Removed unconditional `setBadgeCount(0)` from `applicationWillEnterForeground` — `scheduleAll()` now sets the correct count
3. Added `allDueSoon` array to `NotificationClassifier` (parallel to `allOverdue`) for symmetric badge counting
4. Included `.dueToday` in `allOverdue` to match `FrequencyCalculator`'s definition

**Prevention Rule:**
- `content.badge` on notifications only applies when the notification fires — always call `setBadgeCount()` directly for immediate badge updates
- Badge count arrays must be symmetric: if `allOverdue` includes custom breach time people, `allDueSoon` must too
- When the classifier and calculator disagree on boundary conditions (e.g., `>` vs `>=`), badge counts will diverge from the home screen — keep them aligned

---

### 2026-02-28 - 🔒 Security - Never Trust External Identifiers in Import

**What Happened:**
Security review of JSON import feature (PR #91) found 3 medium-severity vulnerabilities. The import trusted UUIDs and `cnIdentifier` values from external JSON files without validation, enabling silent data overwrite, touch history tampering, and arbitrary iOS Contact linking.

**Root Cause:**
Import code used file-supplied `event.id` UUIDs directly (enabling overwrite of existing events), matched contacts by `cnIdentifier` fallback (enabling overwrite of existing contact data), and stored `cnIdentifier` from JSON directly on new records (enabling linking to arbitrary iOS Contacts).

**Solution:**
Filed as issue #126. Recommended fixes:
1. Generate new UUIDs for imported touch events
2. Clear `cnIdentifier` on newly imported contacts (or validate against Contacts framework)
3. When matching via `cnIdentifier` fallback, skip overwriting `displayName` and show warning

**Prevention Rule:**
When implementing any data import feature, NEVER trust external identifiers. Always regenerate UUIDs for new records, and validate any cross-system identifiers (like `cnIdentifier`) before using them for matching or linking. Treat imported data as untrusted input at every field level, not just at the parsing stage.

### 2026-02-28 - 🔒 Security - Security Review Workflow for Batch PRs

**What Happened:**
Completed batch security review of 16 PRs merged in 24 hours. Used `/security-review` skill framework with subagents for each PR. Found that the `origin/HEAD` ref needed to be set (`git remote set-head origin main`) before the skill would work.

**Root Cause:**
The security-review skill template expects `origin/HEAD` to exist but it wasn't set in the local clone.

**Solution:**
Run `git remote set-head origin main` before starting batch security reviews.

**Prevention Rule:**
Before running batch security reviews, ensure `origin/HEAD` is set. For batch reviews, work sequentially and post each comment immediately after review. Track findings for issue creation at the end.

### 2026-03-04 - 🎨 SwiftUI - clipShape Nullifies Prior ignoresSafeArea

**What Happened:**
Applied `.ignoresSafeArea(.container, edges: .bottom)` inside `.background {}` to extend the card's background into the bottom safe area. No visual change — the card still stopped at the safe area boundary.

**Root Cause:**
`.clipShape()` applied after `.background {}` clips the rendered output to the view's **layout frame**, which respects safe area. Any safe area extension applied to content *before* the clip shape gets clipped away.

**Solution:**
Moved `.ignoresSafeArea(.container, edges: .bottom)` to *after* `.clipShape()`. The entire clipped view (including its shape) now extends through the bottom safe area to the screen edge.

**Prevention Rule:**
In SwiftUI, `.clipShape()` clips to layout bounds. Safe area modifiers must go AFTER clip shapes to take effect. Order: `.background()` → `.clipShape()` → `.ignoresSafeArea()`. Never place `.ignoresSafeArea` inside `.background {}` when a `.clipShape()` follows.

### 2026-03-04 - 🎨 UI/UX - NavigationLink Consumers When Changing Nav Bar Visibility

**What Happened:**
Changed PersonDetailView from NavigationLink push to fullScreenCover and added `.navigationBarHidden(true)`. Code review caught that PausedContactsView (in Settings) still uses NavigationLink to push PersonDetailView — users would be trapped with no back button.

**Root Cause:**
When modifying a shared view's navigation bar behavior, it's easy to miss all the call sites that push it via NavigationLink. The fullScreenCover path didn't need nav bar hiding (no NavigationStack), but the change broke the NavigationLink path.

**Solution:**
Removed `.navigationBarHidden(true)` entirely — unnecessary in fullScreenCover context (no NavigationStack) and harmful in NavigationLink context (hides back button).

**Prevention Rule:**
When changing a view's navigation bar behavior, grep for ALL `NavigationLink` references to that view. Test each navigation path. Prefer not hiding the nav bar if the view is used in both pushed and presented contexts.

### 2026-03-06 - 🏗️ Architecture - Thread Safety When Extracting from @MainActor

**What Happened:**
Extracted `matchImportedContacts` from `@MainActor SettingsViewModel` into a plain `struct DataImportService`. The method called `personRepository.save()` which uses the `viewContext` — but after extraction, these calls could run off the main thread.

**Root Cause:**
`@MainActor` on SettingsViewModel guaranteed all method bodies ran on the main thread. When moved to a non-isolated struct, `async` methods run in a non-isolated context. Even though the caller (SettingsViewModel) is `@MainActor`, the `await` call suspends and the service method runs elsewhere.

**Solution:**
Split responsibility: service only fetches data (renamed to `fetchContactMatches`), ViewModel handles all persistence on `@MainActor`. Rule: repo writes using `viewContext` must stay in `@MainActor` code.

**Prevention Rule:**
When extracting methods from `@MainActor` classes into plain structs/services, audit every repository call. If it uses `viewContext` (main thread context), either keep the write in the `@MainActor` caller or use a background context inside the service. Never assume the caller's actor isolation carries through an `await`.

**Code Example:**
```swift
// BAD: Service does viewContext writes off main thread
struct DataImportService {
    func matchImportedContacts(...) async -> ContactMatchSummary {
        // ... fetch matches ...
        personRepository.save(person) // viewContext — NOT on main thread!
    }
}

// GOOD: Service returns data, ViewModel writes on @MainActor
struct DataImportService {
    func fetchContactMatches(...) async -> [ContactMatchResult] { ... }
}

@MainActor class SettingsViewModel {
    func matchImportedContacts(...) async -> ContactMatchSummary {
        let results = await importService.fetchContactMatches(...)
        // Persistence here — guaranteed @MainActor
        try personRepository.save(person)
    }
}
```

---

## Historical Lessons

*This section will be populated as development progresses*

---

**Maintenance Notes:**
- Review this file at the start of each development session
- Add new lessons immediately after corrections from user
- Archive old lessons quarterly if no longer relevant
- Keep active lessons at top for quick reference
