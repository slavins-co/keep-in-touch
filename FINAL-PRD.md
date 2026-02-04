# iOS Personal CRM App - Final Product Requirements Document

**Version:** 1.0 Final  
**Date:** February 1, 2026  
**Status:** Ready for Implementation  
**Target:** V1 TestFlight Release

---

## Executive Summary

### Mission
Privacy-first iOS app that helps users maintain friendships by tracking "last touch" dates, organizing contacts into SLA cadence groups, and providing gentle reminders when relationships need attention.

### Core Problem
"Out of sight, out of mind" - friendships get neglected without clear visibility into who you haven't contacted recently.

### V1 Scope
- Single-device iOS app (iOS 17+)
- Core Data local storage
- Manual touch logging with full edit history
- Local notifications (breach alerts + weekly digest)
- Tags for contact categorization
- Apple Contacts framework integration (fetch-only)
- Pause/resume tracking per contact
- Dark/Light theme support

### V2 Deferrals (Explicit Out of Scope)
- CloudKit multi-device sync
- macOS companion app
- Shortcuts/Siri integration
- Automatic detection via iMessage/call logs
- Contact sharing/collaboration
- Analytics dashboard
- Export to external CRMs

---

## 1. Data Model (Final Schema)

### 1.1 Person Entity

```swift
Person {
  // Identity
  id: UUID (primary key)
  cnIdentifier: String? (Contacts framework link - can be nil for manual entries)
  displayName: String (cached from Contacts or user-entered)
  initials: String (computed from displayName, 2 chars max)
  avatarColor: String (hex, randomly assigned on creation)
  
  // Grouping & Categorization
  groupId: UUID (foreign key to Group)
  tagIds: [UUID] (foreign keys to Tag, ordered array)
  
  // Touch Tracking
  lastTouchAt: Date? (most recent TouchEvent.at)
  lastTouchMethod: TouchMethod? (most recent TouchEvent.method)
  lastTouchNotes: String? (most recent TouchEvent.notes)
  
  // Status
  isPaused: Bool (default: false - paused contacts excluded from SLA calculations)
  isTracked: Bool (default: true - soft delete support)
  
  // Notification Overrides
  notificationsMuted: Bool (default: false)
  customBreachTime: LocalTime? (overrides Settings.breachTimeOfDay)
  
  // Metadata
  createdAt: Date
  modifiedAt: Date (for V2 CloudKit sync)
  sortOrder: Int (manual reordering, default: 0)
}

// Note: Phone and email are NOT stored. 
// They are fetched on-demand from CNContact using cnIdentifier.
```

**Constraints:**
- `displayName` required, max 100 chars
- `initials` auto-computed, fallback to first 2 chars of displayName
- `avatarColor` must be valid hex color
- `groupId` must reference existing Group
- If `cnIdentifier` is nil, contact is manually added (no Contacts sync)

---

### 1.2 Group Entity

```swift
Group {
  id: UUID (primary key)
  name: String (unique, max 50 chars)
  slaDays: Int (how often to connect, min: 1)
  warningDays: Int (show "due soon" this many days before breach, min: 0, must be < slaDays)
  colorHex: String (optional, for visual distinction)
  isDefault: Bool (default groups cannot be deleted)
  sortOrder: Int (manual reordering)
  
  // Metadata
  createdAt: Date
  modifiedAt: Date
}
```

**Default Groups (created on first launch):**
1. Weekly: 7 days, warning 2 days
2. Bi-Weekly: 14 days, warning 3 days  
3. Monthly: 30 days, warning 5 days
4. Quarterly: 90 days, warning 10 days

**Constraints:**
- `warningDays` must be < `slaDays`
- At least one default group must exist at all times
- Deleting a group reassigns all contacts to first default group

---

### 1.3 Tag Entity

```swift
Tag {
  id: UUID (primary key)
  name: String (unique, max 30 chars)
  colorHex: String (valid hex color)
  sortOrder: Int
  
  // Metadata
  createdAt: Date
  modifiedAt: Date
}
```

**Default Tags (created on first launch):**
1. Work: #0A84FF (SF Blue)
2. Family: #FF3B30 (SF Red)
3. Friend: #34C759 (SF Green)
4. Mentor: #FF9500 (SF Orange)

**Constraints:**
- User can create unlimited custom tags
- Deleting a tag removes it from all contacts
- Tag names must be unique

---

### 1.4 TouchEvent Entity

```swift
TouchEvent {
  id: UUID (primary key)
  personId: UUID (foreign key to Person)
  at: Date (when the touch occurred)
  method: TouchMethod (how they connected)
  notes: String? (optional context, max 500 chars)
  
  // Metadata
  createdAt: Date (when logged, may differ from 'at')
  modifiedAt: Date
}

enum TouchMethod: String {
  case text = "Text"
  case call = "Call"
  case irl = "IRL"
  case email = "Email"
  case other = "Other"
}
```

**Rules:**
- TouchEvents are immutable in `at` field (can't change date after creation)
- Can edit `method` and `notes` after creation
- Deleting most recent TouchEvent updates Person.lastTouchAt to previous entry
- Full history retained (no automatic pruning in V1)

---

### 1.5 Settings Entity (Singleton)

```swift
Settings {
  id: UUID (always same ID, singleton pattern)
  
  // Appearance
  theme: Theme (dark | light)
  
  // Notifications
  notificationsEnabled: Bool
  breachTimeOfDay: LocalTime (default: 18:00)
  digestEnabled: Bool
  digestDay: DayOfWeek (default: Friday)
  digestTime: LocalTime (default: 18:00)
  dueSoonWindowDays: Int (default: 3, for Home screen filtering)
  
  // Features
  demoModeEnabled: Bool (populates fake data for screenshots)
  
  // Metadata
  lastContactsSyncAt: Date? (last time Contacts were refreshed)
  onboardingCompleted: Bool
  appVersion: String
}

enum Theme: String {
  case dark = "dark"
  case light = "light"
}

enum DayOfWeek: String {
  case monday, tuesday, wednesday, thursday, friday, saturday, sunday
}

struct LocalTime {
  hour: Int (0-23)
  minute: Int (0-59)
}
```

---

## 2. Screen Specifications

### 2.1 Onboarding Flow (New Users Only)

**Screen 1: Welcome**
- **Layout:**
  - App icon (SF Symbol: person.2.circle.fill)
  - Title: "Stay in Touch"
  - Subtitle: "Never lose track of the people who matter"
  - 3 benefit bullets:
    - "Track who you haven't talked to lately"
    - "Get gentle reminders to reach out"
    - "All your data stays private on your device"
  - Primary button: "Get Started"
  
**Screen 2: Contacts Permission**
- **Layout:**
  - Icon: SF Symbol person.crop.circle.badge.questionmark
  - Title: "Connect Your Contacts"
  - Body: "We'll help you select people you want to stay close with. Your contacts never leave your device."
  - Primary button: "Allow Access to Contacts"
  - Secondary link: "Skip for Now"
  
- **Logic:**
  - Button triggers `CNContactStore.requestAccess()`
  - If granted → proceed to Contact Picker
  - If denied → show alert: "You can add contacts manually in the app"
  - Skip → proceed to Default Groups with 0 contacts

**Screen 3: Contact Picker** (Only if permission granted)
- **Layout:**
  - Title: "Who Do You Want to Track?"
  - Search bar at top
  - Scrollable list of CNContacts with checkboxes
  - Multi-select enabled
  - Primary button: "Continue" (badge shows count selected)
  - Secondary link: "Skip - Add Later"
  
- **Logic:**
  - Fetch all CNContacts sorted alphabetically
  - User can select 0-N contacts
  - On Continue: Create Person records with cnIdentifier links
  - Default all to "Monthly" group initially

**Screen 4: Default Groups Setup**
- **Layout:**
  - Title: "How Often Should You Connect?"
  - List of 4 default groups (Weekly, Bi-Weekly, Monthly, Quarterly)
  - Each group shows: name, interval, example contacts
  - Info text: "You can customize these anytime in Settings"
  - Primary button: "Start Using App"
  
- **Logic:**
  - Groups are already created
  - This is informational only
  - Button sets `Settings.onboardingCompleted = true`
  - Navigate to Home

**Screen 5: Notifications Permission**
- **Layout:**
  - Icon: SF Symbol bell.badge.fill
  - Title: "Stay on Track with Reminders"
  - Body: "Get notified when it's time to reconnect with someone"
  - Primary button: "Enable Notifications"
  - Secondary link: "Not Now"
  
- **Logic:**
  - Button triggers `UNUserNotificationCenter.requestAuthorization()`
  - If granted → set `Settings.notificationsEnabled = true`
  - If denied → user can enable later in Settings
  - Navigate to Home regardless

---

### 2.2 Home Screen (Main Tab)

**Layout Sections:**
1. **Header**
   - Large title: "Stay in Touch"
   - Settings gear icon (top right)
   - Summary counts row:
     - Red dot + "X overdue"
     - Orange dot + "X due soon"
     - Green dot + "X all good"

2. **Filter Bar**
   - 3 horizontal dropdowns (equal width):
     - Group filter (All, Weekly, Bi-Weekly, etc.)
     - Sort (Status, Name)
     - Tag filter (All Tags, Work, Family, etc.)

3. **Contact List** (Grouped by SLA Status)
   - **Section: Overdue** (red, collapsible)
     - Header: "Overdue (X)" with chevron
     - Contact cards sorted by days overdue DESC
   - **Section: Due Soon** (orange, collapsible)
     - Header: "Due Soon (X)" with chevron
     - Contact cards sorted by days until due ASC
   - **Section: All Good** (green, collapsible)
     - Header: "All Good (X)" with chevron
     - Contact cards sorted by name or last touch

4. **Search Bar** (Fixed bottom)
   - Magnifying glass icon
   - Placeholder: "Search contacts..."
   - Clear button when typing

**Contact Card Layout:**
```
[Avatar] [Name                    ] [+Nd] [●] [>]
         [Group • Time • Method   ]
         [Tag] [Tag]
```

- Avatar: 44pt circle with initials
- Name: 17pt primary text, truncated
- Metadata: 13pt secondary text (Group name • "2d ago" • "Text")
- Tags: Pill badges with tag color
- +Nd: Red text if overdue (e.g., "+5d")
- Status dot: 10pt circle (red/orange/green)
- Chevron: 5pt disclosure indicator

**States:**

| State | Display |
|-------|---------|
| Empty (no tracked contacts) | Centered: 👋 emoji, "No contacts yet", "Add people you want to stay in touch with", "Add Contact" button |
| Empty (with search, no results) | Centered: 🔍 emoji, "No contacts found", "Try a different search" |
| Paused contacts | Hidden from all lists (never shown on Home) |
| All sections collapsed | Only section headers visible |

**Interactions:**
- Tap contact card → Navigate to Person Detail
- Tap section header → Toggle collapse/expand
- Tap Settings gear → Navigate to Settings
- Type in search → Filter contacts by displayName (debounced 300ms)
- Tap filter dropdown → Show modal picker
- Pull to refresh → Re-sync display names from Contacts framework

---

### 2.3 Person Detail Screen

**Header:**
- Back button: "< Back"
- Large avatar (72pt)
- Name (28pt bold)
- Status indicator: dot + label + overdue days
  - Example: "🔴 Overdue catch-up +5d"

**Sections:**

**1. Cadence Card**
```
CADENCE                    [Change]
Monthly
Connect every 30 days • 12d remaining
```
- Tap "Change" → Show group picker modal

**2. Tags Card**
```
TAGS                       [Manage]
[Work] [Friend]
```
- Shows current tags as removable pills
- Tap "Manage" → Show tag management modal

**3. Contact History**
```
CONTACT HISTORY           [See All (5)]

📅 2d ago via Text
   Wednesday, Jan 29, 2026
   "Discussed weekend plans"
   [✏️ Edit] [🗑️ Delete]
```
- Shows most recent by default
- "See All" expands to full history
- Each entry: date, method, notes, edit/delete buttons

**4. Quick Actions** (only if phone/email available from Contacts)
```
QUICK ACTIONS

💬 Message      (555) 123-4567
📞 Call         (555) 123-4567
✉️ Email        sarah@example.com
```
- Tapping opens Messages/Phone/Mail app with pre-populated contact
- Retrieved from CNContact on-demand (not stored)

**5. Pause/Resume**
```
⏸️ Pause Tracking
```
or
```
▶️ Resume Tracking
```

**Fixed Bottom:**
- Primary button: "Log Touch" (full width, blue)

**Interactions:**
- Tap "Log Touch" → Show log touch modal
- Tap "Change" cadence → Show group picker
- Tap "Manage" tags → Show tag manager
- Tap "See All" → Expand history
- Tap Edit on touch log → Show edit modal
- Tap Delete on touch log → Show confirmation alert
- Tap Quick Action → Open native app with contact info
- Tap Pause/Resume → Toggle immediately, refresh UI

---

### 2.4 Log Touch Modal (Bottom Sheet)

**Header:**
- Cancel (left)
- "Log Touch" (center)
- Done (right, blue, bold)

**Content:**

**1. Method Picker**
```
HOW DID YOU CONNECT?

☑ Text
○ Call
○ IRL
○ Email
○ Other
```
- Radio button list
- Default: Text

**2. Notes (Optional)**
```
NOTES (OPTIONAL)

[Text area: "What did you talk about?"]
```
- Multi-line text input
- Max 500 chars
- Placeholder text

**Behavior:**
- Done creates TouchEvent with current date
- Updates Person.lastTouchAt, lastTouchMethod, lastTouchNotes
- Inserts TouchEvent into history
- Recalculates SLA status
- Dismisses modal
- Shows toast: "Logged touch with [Name]"

---

### 2.5 Edit Touch Modal (Bottom Sheet)

**Header:**
- Cancel (left)
- "Edit Touch" (center)
- Save (right, blue, bold)

**Content:**

**1. Date (Read-Only)**
```
DATE

Wednesday, Jan 29, 2026
Date cannot be changed
```

**2. Method Picker** (same as Log Touch)
**3. Notes** (same as Log Touch, pre-filled)

**Behavior:**
- Save updates TouchEvent.method and .notes
- If editing most recent event, updates Person.lastTouchMethod and .lastTouchNotes
- Does NOT change TouchEvent.at (immutable)
- Shows toast: "Touch updated"

---

### 2.6 Delete Touch Confirmation Alert

**Modal Dialog:**
```
Delete Touch Entry?

This action cannot be undone.

[Delete] (red)
[Cancel] (blue)
```

**Behavior:**
- Delete removes TouchEvent
- If deleting most recent: updates Person to use 2nd most recent TouchEvent data
- If deleting only event: Person.lastTouchAt becomes nil
- Recalculates SLA status

---

### 2.7 Settings Screen

**Header:**
- Back button: "< Back"
- Large title: "Settings"

**Sections:**

**1. Appearance**
```
🌙 Dark Mode          [Toggle]
```
or
```
☀️ Light Mode         [Toggle]
```

**2. Cadence Groups**
```
👥 Manage Groups      4  >
```
- Badge shows count
- Navigates to Manage Groups

**3. Tags**
```
🏷️ Manage Tags        4  >
```
- Badge shows count
- Navigates to Manage Tags

**4. Notifications**
```
🔔 Daily Breach Alerts    [Toggle]
   Alert Time             18:00  >

📊 Weekly Digest          [Toggle]
   Digest Day             Friday >
```
- Toggles enable/disable
- Time/Day pickers only shown when enabled

**5. Data**
```
💾 Export Contacts    >
📱 Sync from Contacts >
🧪 Demo Mode          [Toggle]
```
- Export → Downloads JSON file
- Sync → Re-fetches displayNames from CNContact
- Demo Mode → Populates fake data

**6. About**
```
Stay in Touch v1.0
Privacy-first personal CRM
```

---

### 2.8 Manage Groups Screen

**Header:**
- Back: "< Settings"
- Large title: "Manage Groups"
- Add button: + (blue circle, top right)

**List:**
```
Weekly              [✏️] 
Every 7 days • 12 contacts

Bi-Weekly           [✏️]
Every 14 days • 8 contacts

Monthly (Default)   [✏️]
Every 30 days • 23 contacts

Quarterly           [✏️] [🗑️]
Every 90 days • 2 contacts
```

- Default groups show "(Default)" badge
- Default groups have no delete button
- Non-default groups show edit + delete

**Interactions:**
- Tap + → Show Add Group modal
- Tap Edit → Show Edit Group modal
- Tap Delete → Show confirmation if contacts assigned, else delete immediately

---

### 2.9 Add/Edit Group Modal

**Header:**
- Cancel / "New Group" or "Edit Group" / Save

**Fields:**
```
GROUP NAME
[Close Friends]

CHECK-IN INTERVAL (DAYS)
[14]

WARNING DAYS BEFORE DUE
[3]

Show "due soon" status this many days 
before the interval expires
```

**Validation:**
- Name required, max 50 chars, must be unique
- Interval min 1, max 365
- Warning must be < interval
- Save button disabled until valid

---

### 2.10 Delete Group Confirmation

**Alert (if contacts assigned):**
```
Delete Group?

5 contacts will be moved to the default group.

[Delete] (red)
[Cancel] (blue)
```

**Alert (if default group):**
```
Cannot Delete

Default groups cannot be deleted.

[OK]
```

---

### 2.11 Manage Tags Screen

(Similar to Manage Groups, substitute Tag entity)

**Header:**
- Back: "< Settings"
- Large title: "Manage Tags"
- Add button: +

**List:**
```
Work               [✏️] [🗑️]
Blue • 8 contacts

Family             [✏️] [🗑️]
Red • 12 contacts
```

**Add/Edit Modal:**
```
TAG NAME
[Colleague]

COLOR
[Color picker wheel]
```

**Delete:**
- Removes tag from all Person.tagIds arrays
- Shows confirmation if used by contacts

---

### 2.12 Tag Management Modal (from Person Detail)

**Header:**
- Cancel / "Manage Tags" / (empty)

**Sections:**

**Current Tags:**
```
[Work ✕] [Friend ✕]
```
- Tappable pills to remove

**Add Tags:**
```
[+ Family] [+ Mentor]
```
- Shows available tags not currently applied
- Tap to add

**Empty State:**
```
No tags yet
```

---

## 3. Interaction Specifications

### 3.1 Gestures & Tap Targets

| Element | Tap Target | Gesture | Action |
|---------|-----------|---------|--------|
| Contact card | Full card 44pt min height | Tap | Navigate to detail |
| Section header | Full width | Tap | Toggle collapse |
| Search field | Full width | Tap | Focus keyboard |
| Filter dropdown | Full width | Tap | Show picker modal |
| Tag pill | 44pt x 24pt min | Tap | Context-dependent |
| Avatar | 44pt circle | Tap | Navigate to detail |
| Quick action button | Full width row | Tap | Launch native app |

**Swipe Actions:**
None in V1 (defer to V2 for swipe-to-log-touch)

**Pull to Refresh:**
- Home screen only
- Triggers Contacts re-sync (updates displayNames)
- Shows loading spinner
- Toast on completion: "Contacts refreshed"

---

### 3.2 Confirmation Dialogs

**Required confirmations:**
1. Delete touch entry
2. Delete group (if contacts assigned)
3. Delete tag (if contacts assigned)
4. Pause tracking (first time only, with "Don't ask again" checkbox)

**No confirmation needed:**
- Log touch
- Edit touch
- Change group
- Add/remove tags
- Toggle settings

---

### 3.3 Loading States

**Home screen initial load:**
- Skeleton cards (3 shimmer rectangles)
- 300ms minimum display time

**Person detail:**
- Quick actions section shows spinner while fetching CNContact
- If CNContact fetch fails: hide Quick Actions section silently

**Settings sync:**
- "Syncing..." text in place of contact count
- Disabled interaction during sync

---

### 3.4 Error States

**Contacts permission denied:**
- Home empty state: "Enable Contacts access in Settings to import contacts"
- Tap opens Settings app

**Notification permission denied:**
- Settings toggle shows grayed out with "Enable in Settings" text

**Failed to fetch CNContact:**
- Person detail: Quick Actions section hidden
- No error message (graceful degradation)

**Group delete with orphaned contacts:**
- Should never happen (deletion reassigns first)
- If occurs: show alert, reassign to first default group

---

## 4. Notification Logic

### 4.1 Breach Notifications

**Trigger Conditions:**
```swift
person.isPaused == false
&& person.isTracked == true
&& daysSince(person.lastTouchAt) >= group.slaDays
&& !notificationFiredToday(person.id)
```

**Scheduling:**
- Checked daily at Settings.breachTimeOfDay (default 18:00)
- Use `UNCalendarNotificationTrigger` with `repeats: false`
- Schedule one notification per person per breach
- Reschedule daily via background task

**Content:**
```
Title: "Time to reconnect"
Body: "You haven't talked to Sarah in 35 days"
Sound: Default
Badge: Increment app badge
ThreadIdentifier: "breach-YYYYMMDD"
UserInfo: { personId: UUID }
```

**Grouping:**
- All same-day breach notifications grouped by `threadIdentifier`
- Summary format: "You have 3 overdue contacts"

**Deep Link:**
- Tap notification → Open app to Person Detail for that personId
- Tap grouped notification → Open app to Home filtered to Overdue

**Persistence:**
- Mark notification as fired in Person entity (add `lastBreachNotificationAt: Date?`)
- Only fire one breach notification per person per breach event
- Reset on next touch log

---

### 4.2 Weekly Digest

**Trigger:**
- Every Settings.digestDay at Settings.digestTime
- Only if Settings.digestEnabled == true

**Content:**
```
Title: "Weekly check-in reminder"
Body: "5 people to reconnect with: Sarah (+5d), Mike (+3d), Emily (+2d)..."
Sound: Default
Badge: Set to overdue count
ThreadIdentifier: "digest-weekly"
UserInfo: { type: "digest" }
```

**List Format:**
- Show up to 5 most overdue people
- Format: "Name (+Nd)"
- If more than 5: "...and X more"

**Deep Link:**
- Tap → Open app to Home filtered to Overdue

---

### 4.3 Per-Person Notification Overrides

**Fields:**
- `Person.notificationsMuted: Bool`
- `Person.customBreachTime: LocalTime?`

**Logic:**
```swift
if person.notificationsMuted {
  return // Don't schedule any notifications
}

let breachTime = person.customBreachTime ?? settings.breachTimeOfDay
```

**UI:**
Not exposed in V1 UI (field exists for future use)

---

### 4.4 Notification Permissions

**First Launch:**
- Request permission in onboarding (Screen 5)
- If denied: Settings.notificationsEnabled = false

**Settings Toggle:**
- If user toggles ON but permission denied:
  - Show alert: "Open Settings to enable notifications"
  - Provide deep link to app settings

**Background Refresh:**
- Required for daily breach checks
- Request `BGTaskScheduler` permission
- If denied: notifications may be delayed

---

### 4.5 Background Task Schedule

**Task ID:** `com.app.refreshSLA`

**Frequency:** Daily at 00:00 local time

**Work:**
1. Recalculate all Person SLA statuses
2. Schedule breach notifications for today
3. Schedule digest if today matches Settings.digestDay
4. Remove delivered notifications older than 7 days

**Constraints:**
- Requires device to be unlocked once after boot
- May not fire if Low Power Mode enabled
- Notifications will accumulate and fire when possible

---

## 5. Edge Cases & Error Handling

### 5.1 Contact Deleted from Phone

**Scenario:** User deletes contact from Apple Contacts app

**Detection:**
- Pull-to-refresh on Home triggers re-fetch
- `CNContactStore.unifiedContact(withIdentifier:)` throws error

**Handling:**
```
Person Detail:
  Show warning banner: "⚠️ Contact deleted from your phone"
  Options: 
    [Keep as Manual Entry] - Sets cnIdentifier = nil
    [Delete from App] - Soft delete Person
```

**Auto-cleanup:**
- None in V1 (manual decision required)
- V2: Batch cleanup tool in Settings

---

### 5.2 Group Deleted with Contacts

**Prevention:**
- Deletion triggers reassignment flow before delete

**Reassignment Logic:**
```swift
let defaultGroup = groups.first(where: { $0.isDefault })
persons.filter({ $0.groupId == deletedGroupId })
       .forEach({ $0.groupId = defaultGroup.id })
```

**User Flow:**
1. Tap delete on group
2. Show alert: "5 contacts will be moved to [Default Group]"
3. Confirm → Reassign → Delete group
4. Toast: "Group deleted, contacts moved"

---

### 5.3 Timezone Changes

**SLA Calculation:**
- Always use `Calendar.current.startOfDay(for: Date())`
- All dates stored as UTC in Core Data
- Display in user's current timezone

**Scenario:** User travels from PST to EST
- SLA calculations update immediately based on new timezone
- Breach notifications fire at breachTimeOfDay in new timezone
- No data migration needed

---

### 5.4 DST Transitions

**Breach Notifications:**
- Use `UNCalendarNotificationTrigger` with `DateComponents`
- System handles DST automatically
- Example: 18:00 always fires at 6 PM local, whether DST or not

---

### 5.5 First Launch (No Contacts)

**Flow:**
1. Onboarding completes with 0 contacts
2. Home shows empty state
3. No notifications scheduled
4. User can manually add contacts later

**Manual Add Contact:**
- V1: Not implemented (requires Contacts permission)
- Workaround: User must grant permission, then import from Contacts

**V2 Feature:** Manual contact creation form

---

### 5.6 Last Touch Event Deleted

**Scenario:** User deletes the only TouchEvent for a Person

**Handling:**
```swift
if person.history.isEmpty {
  person.lastTouchAt = nil
  person.lastTouchMethod = nil
  person.lastTouchNotes = nil
}
```

**UI:**
- Person Detail shows: "No contact history yet"
- SLA status: Cannot calculate, shows as "Unknown"
- Home: Hide from all status sections until first touch logged

---

### 5.7 Duplicate Contact Names

**Scenario:** Two contacts named "Sarah Chen"

**Handling:**
- Display as-is in contact list
- No automatic deduplication
- User must differentiate via tags or groups
- Future: Add optional "nickname" field in V2

---

### 5.8 Invalid cnIdentifier

**Scenario:** cnIdentifier exists but CNContact fetch fails

**Cause:** Contact was merged or deleted then re-added in Contacts app

**Handling:**
- Log warning to console
- Set cnIdentifier = nil
- Continue using cached displayName
- Show stale data indicator in Person Detail

---

### 5.9 App Deleted and Reinstalled

**Result:**
- All Core Data wiped
- Onboarding shown again
- No data recovery (V1 has no cloud backup)

**V2:** CloudKit sync enables restore

---

## 6. Settings & Configuration

### 6.1 Configurable Values

| Setting | Default | Range | Location |
|---------|---------|-------|----------|
| Theme | Dark | Dark/Light | Settings > Appearance |
| Breach Time | 18:00 | 00:00-23:59 | Settings > Notifications |
| Digest Enabled | True | Bool | Settings > Notifications |
| Digest Day | Friday | Mon-Sun | Settings > Notifications |
| Digest Time | 18:00 | 00:00-23:59 | Settings > Notifications |
| Due Soon Window | 3 days | 1-30 | Settings (hidden in V1) |

---

### 6.2 Demo Mode Behavior

**Purpose:** Generate realistic fake data for App Store screenshots

**Toggle:** Settings > Data > Demo Mode

**When Enabled:**
1. Generates 25 fake Person records with realistic names
2. Distributes across all groups
3. Assigns random tags
4. Creates TouchEvent history (5-20 events per person)
5. Sets varied lastTouchAt dates to show all SLA statuses
6. Replaces real data temporarily (reversible)

**When Disabled:**
- Deletes all demo data
- Restores real data from backup
- If no backup: prompts to re-import from Contacts

**Implementation:**
- Use `Settings.demoModeEnabled` flag
- Prefix all demo Person.id with `demo-` for easy filtering
- NSFetchRequest predicates check demoMode flag

---

### 6.3 Export Data Format

**Trigger:** Settings > Data > Export Contacts

**Format:** JSON

**Schema:**
```json
{
  "exportedAt": "2026-02-01T18:00:00Z",
  "appVersion": "1.0",
  "contacts": [
    {
      "id": "uuid",
      "name": "Sarah Chen",
      "group": "Weekly",
      "tags": ["Work", "Friend"],
      "lastTouch": "2026-01-29T14:30:00Z",
      "method": "Text",
      "notes": "Discussed project",
      "history": [
        {
          "date": "2026-01-29T14:30:00Z",
          "method": "Text",
          "notes": "Discussed project"
        }
      ]
    }
  ]
}
```

**Filename:** `stay-in-touch-export-YYYY-MM-DD.json`

**Delivery:** Share sheet (Save to Files, AirDrop, etc.)

---

### 6.4 Contacts Re-Sync

**Trigger:** Settings > Data > Sync from Contacts

**Behavior:**
1. For each Person with cnIdentifier:
   - Fetch CNContact
   - Update displayName if changed
   - Update initials (recompute)
2. Show progress: "Syncing X of Y..."
3. Toast on completion: "Updated 5 contacts"

**Frequency:**
- Manual only in V1
- Pull-to-refresh on Home also triggers
- V2: Automatic background sync

---

## 7. Acceptance Criteria

### 7.1 Onboarding

**AC-001:** Given a new user on first launch, when they complete onboarding, then they land on Home screen with onboardingCompleted = true

**AC-002:** Given onboarding completed, when app is relaunched, then onboarding is skipped

**AC-003:** Given user denies Contacts permission, when they proceed, then they can still use the app with 0 contacts

**AC-004:** Given user skips Contacts permission, when they enable it later in Settings, then they can import contacts

---

### 7.2 Home Screen

**AC-101:** Given 3 overdue contacts, when Home loads, then Overdue section shows count (3) and all 3 contacts sorted by days overdue DESC

**AC-102:** Given search query "Sarah", when typed, then only contacts matching "Sarah" in displayName are shown

**AC-103:** Given Group filter = "Weekly", when applied, then only contacts in Weekly group are shown

**AC-104:** Given paused contact, when Home loads, then contact is not visible in any section

**AC-105:** Given all sections collapsed, when user taps section header, then that section expands and others remain collapsed

---

### 7.3 Person Detail

**AC-201:** Given Person with phone number in Contacts, when Person Detail loads, then Quick Actions shows Message and Call options

**AC-202:** Given Person with no cnIdentifier, when Person Detail loads, then Quick Actions section is hidden

**AC-203:** Given Person with 5 TouchEvents, when "See All" is tapped, then all 5 events are displayed in reverse chronological order

**AC-204:** Given most recent TouchEvent, when user deletes it, then Person.lastTouchAt updates to 2nd most recent event

**AC-205:** Given Person.isPaused = false, when Pause button tapped, then isPaused = true and contact disappears from Home

---

### 7.4 Touch Logging

**AC-301:** Given Log Touch modal, when user selects "Call" and types "Caught up on life", then Done creates TouchEvent with method=Call and notes

**AC-302:** Given TouchEvent created, when Home reloads, then Person's SLA status recalculates immediately

**AC-303:** Given editing a TouchEvent, when user changes method from "Text" to "Call", then method updates but date remains unchanged

**AC-304:** Given deleting the only TouchEvent, when confirmed, then Person.lastTouchAt = nil and SLA status = unknown

---

### 7.5 Groups

**AC-401:** Given 4 default groups, when app first launches, then all 4 are created with isDefault = true

**AC-402:** Given custom group with 5 contacts, when deleted, then all 5 contacts reassign to first default group

**AC-403:** Given default group, when delete attempted, then alert shows "Cannot delete default groups"

**AC-404:** Given new group with slaDays=14 and warningDays=3, when created, then contacts in that group show "due soon" 3 days before breach

---

### 7.6 Tags

**AC-501:** Given 4 default tags, when app first launches, then all 4 are created

**AC-502:** Given Person with "Work" tag, when tag is deleted globally, then Person.tagIds removes "Work" reference

**AC-503:** Given Person Detail, when user adds "Family" tag, then tag pill appears immediately and persists

---

### 7.7 Notifications

**AC-601:** Given Person breached SLA at 18:00 today, when breach time passes, then notification fires with correct name and days overdue

**AC-602:** Given 3 breached Persons on same day, when notifications fire, then they are grouped with summary "3 overdue contacts"

**AC-603:** Given weekly digest enabled for Friday 18:00, when Friday 18:00 arrives, then digest notification lists up to 5 most overdue people

**AC-604:** Given Person.notificationsMuted = true, when breach occurs, then no notification fires for that Person

**AC-605:** Given notification tapped, when app opens, then navigates to Person Detail for that specific person

---

### 7.8 Settings

**AC-701:** Given theme = dark, when toggle switched, then entire app UI changes to light mode immediately

**AC-702:** Given Export Contacts tapped, when complete, then JSON file downloads with correct schema and all Person data

**AC-703:** Given Demo Mode enabled, when toggled ON, then 25 fake contacts appear and real contacts are hidden

**AC-704:** Given Demo Mode enabled, when toggled OFF, then fake contacts deleted and real contacts restore

---

### 7.9 Data Integrity

**AC-801:** Given Person.groupId references deleted Group, when app loads, then Person reassigns to default group automatically

**AC-802:** Given CNContact deleted from phone, when pull-to-refresh triggered, then Person shows warning banner with options

**AC-803:** Given timezone change from PST to EST, when SLA calculated, then uses EST as current timezone correctly

---

## 8. Out of Scope (V2 Explicit Deferrals)

### 8.1 Not in V1

**Sync & Multi-Device:**
- CloudKit sync
- macOS companion app
- iPad optimized layout
- Apple Watch complications

**Automation:**
- Shortcuts/Siri integration
- Automatic detection via iMessage/call logs
- Calendar integration (infer meetings as touches)
- Email integration

**Advanced Features:**
- Contact import from CSV
- Rich notes with photos/attachments
- Relationship strength scoring
- Analytics dashboard
- Recurring touch reminders (beyond breach/digest)
- Custom notification sounds
- Widget (Home screen/Lock screen)

**Social:**
- Contact sharing
- Collaboration mode
- CRM integrations (Salesforce, HubSpot)

**Data:**
- Cloud backup beyond CloudKit
- Advanced export formats (CSV, VCF)
- Data retention policies (auto-archive old events)

---

### 8.2 V2 Priorities (Ranked)

1. **CloudKit Sync** - Multi-device core value
2. **Shortcuts Integration** - Quick log via voice
3. **Widgets** - Glanceable overdue list
4. **Manual Contact Creation** - No Contacts permission required
5. **macOS Companion** - Messages DB auto-detection
6. **Rich Notes** - Photos, voice memos
7. **Analytics** - Trends, relationship health scores

---

## 9. Technical Constraints

### 9.1 Hard Requirements

- iOS 17.0+
- SwiftUI (no UIKit)
- Core Data (NSPersistentContainer)
- Contacts framework (read-only)
- UserNotifications framework
- SF Symbols for all icons
- Apple Human Interface Guidelines compliance

### 9.2 Prohibited

- Private APIs for iMessage/SMS/call logs
- Third-party analytics SDKs
- Network requests (except future CloudKit)
- Server backend
- Storing raw phone numbers/emails (fetch on-demand only)

### 9.3 Architecture Pattern

**Layers:**
1. **Domain** - Entities, enums, value objects
2. **Data** - Core Data models, repositories
3. **UseCases** - Business logic, SLA calculations
4. **UI** - SwiftUI views, view models
5. **Intents** - Notification handling, background tasks

**Repository Pattern:**
- PersonRepository, GroupRepository, TagRepository, TouchEventRepository
- Protocol-based for testability
- CoreData implementation for V1
- CloudKit implementation swappable in V2

---

## 10. Open Questions (Decisions Needed)

### 10.1 Resolved
All major decisions resolved via user confirmation.

### 10.2 Implementation Details (Claude Code Discretion)

**Minor Decisions:**
- Exact animation durations (standard iOS: 0.3s)
- Exact color values for avatars (randomize from palette)
- Search debounce timing (300ms recommended)
- Toast message durations (2s recommended)

**These do not require upfront decisions and can be handled during implementation.**

---

## 11. Success Metrics (Post-Launch)

**V1 Goals:**
- User creates 10+ tracked contacts
- Average 2+ touches logged per week
- 80%+ notification opt-in rate
- Zero crashes (App Store reviews)
- <5% bounce rate (delete within 7 days)

**Measurement:**
- V1: No analytics (privacy-first)
- V2: On-device analytics only (no external services)
- User feedback via App Store reviews + TestFlight feedback

---

## Appendix A: Color Palette

### System Colors (SF Symbols Standard)
- **Blue:** #0A84FF (primary actions, links)
- **Red:** #FF3B30 (overdue, destructive)
- **Orange:** #FF9500 (due soon, warnings)
- **Green:** #34C759 (all good, success)
- **Gray:** #8E8E93 (secondary text)

### Avatar Colors (Random Assignment)
- #FF6B6B, #4ECDC4, #95E1D3, #F38181
- #AA96DA, #FCBAD3, #FFD93D, #6BCB77

### Dark Mode
- Background: #000000
- Secondary BG: #1C1C1E
- Tertiary BG: #2C2C2E
- Text Primary: #FFFFFF
- Text Secondary: #8E8E93

### Light Mode
- Background: #FFFFFF
- Secondary BG: #F2F2F7
- Tertiary BG: #E5E5EA
- Text Primary: #000000
- Text Secondary: #6B6B6B

---

## Appendix B: SF Symbols Map

| UI Element | SF Symbol |
|------------|-----------|
| Settings gear | gearshape.fill |
| Search | magnifyingglass |
| Add | plus.circle.fill |
| Edit | pencil |
| Delete | trash.fill |
| Back | chevron.left |
| Disclosure | chevron.right |
| Collapse/Expand | chevron.up / chevron.down |
| Message | message.circle.fill |
| Call | phone.circle.fill |
| Email | envelope.circle.fill |
| Calendar | calendar |
| Bell | bell.fill |
| Moon | moon.fill |
| Sun | sun.max.fill |
| Users | person.2.fill |
| Tag | tag.fill |
| Download | arrow.down.circle.fill |
| Pause | pause.circle.fill |
| Play | play.circle.fill |

---

## Appendix C: Localization Notes (V2)

V1 ships English-only.

**V2 Localization:**
- All user-facing strings externalized to Localizable.strings
- Support: English, Spanish, French, German, Japanese, Chinese (Simplified)
- Date formatting respects locale
- Number formatting respects locale
- RTL support for Arabic/Hebrew

---

## Document Control

**Version History:**

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 Final | Feb 1, 2026 | Initial complete PRD | Brad (with Claude) |

**Status:** ✅ **APPROVED FOR IMPLEMENTATION**

**Next Steps:**
1. Create CLAUDE.md for Claude Code handoff
2. Generate asset list (colors, SF Symbols)
3. Define milestone breakdown
4. Begin implementation with Xcode project setup

---

**End of PRD**
