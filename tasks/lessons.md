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

---

## Historical Lessons

*This section will be populated as development progresses*

---

**Maintenance Notes:**
- Review this file at the start of each development session
- Add new lessons immediately after corrections from user
- Archive old lessons quarterly if no longer relevant
- Keep active lessons at top for quick reference
