# iOS Personal CRM App - Claude Code Context

## Project Overview

**App Name:** Stay in Touch  
**Platform:** iOS 17.0+  
**Language:** Swift + SwiftUI  
**Architecture:** Clean Architecture with Repository Pattern  
**Persistence:** Core Data (V1), NSPersistentCloudKitContainer (V2)

## Mission Statement

Privacy-first iOS app that helps users maintain friendships by tracking "last touch" dates, organizing contacts into SLA cadence groups, and providing gentle reminders when relationships need attention.

---

## Workflow Orchestration & Principles

### Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests - then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

### Task Management
1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plans**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

### Core Principles
- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

---

## Key Documents

📋 **[FINAL-PRD.md](./FINAL-PRD.md)** - Complete product requirements (read first!)  
🎨 **[Figma Mockup](./Figma%20Mockup/)** - Reference implementation in React (for UI patterns)

---

## Project Structure

```
StayInTouch/
├── App/
│   ├── StayInTouchApp.swift
│   └── AppDelegate.swift
├── Domain/
│   ├── Entities/
│   │   ├── Person.swift
│   │   ├── Group.swift
│   │   ├── Tag.swift
│   │   ├── TouchEvent.swift
│   │   └── Settings.swift
│   ├── ValueObjects/
│   │   ├── TouchMethod.swift
│   │   ├── SLAStatus.swift
│   │   ├── Theme.swift
│   │   └── LocalTime.swift
│   └── Protocols/
│       ├── PersonRepository.swift
│       ├── GroupRepository.swift
│       ├── TagRepository.swift
│       └── TouchEventRepository.swift
├── Data/
│   ├── CoreData/
│   │   ├── StayInTouch.xcdatamodeld
│   │   ├── CoreDataStack.swift
│   │   └── Repositories/
│   │       ├── CoreDataPersonRepository.swift
│   │       ├── CoreDataGroupRepository.swift
│   │       ├── CoreDataTagRepository.swift
│   │       └── CoreDataTouchEventRepository.swift
│   └── Contacts/
│       └── ContactsFetcher.swift
├── UseCases/
│   ├── SLACalculator.swift
│   ├── NotificationScheduler.swift
│   ├── ContactsSyncUseCase.swift
│   └── DemoDataGenerator.swift
├── UI/
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   ├── WelcomeView.swift
│   │   │   ├── ContactsPermissionView.swift
│   │   │   ├── ContactPickerView.swift
│   │   │   ├── GroupsInfoView.swift
│   │   │   └── NotificationsPermissionView.swift
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── ContactCard.swift
│   │   │   └── ContactListSection.swift
│   │   ├── PersonDetail/
│   │   │   ├── PersonDetailView.swift
│   │   │   ├── LogTouchModal.swift
│   │   │   ├── EditTouchModal.swift
│   │   │   └── TagManagementModal.swift
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   ├── ManageGroupsView.swift
│   │   │   └── ManageTagsView.swift
│   │   └── Components/
│   │       ├── StatusBadge.swift
│   │       ├── AvatarView.swift
│   │       ├── TagPill.swift
│   │       └── EmptyStateView.swift
│   └── ViewModels/
│       ├── HomeViewModel.swift
│       ├── PersonDetailViewModel.swift
│       ├── SettingsViewModel.swift
│       └── ManageGroupsViewModel.swift
├── Utilities/
│   ├── Extensions/
│   │   ├── Date+SLA.swift
│   │   ├── String+Initials.swift
│   │   └── Color+Palette.swift
│   └── Helpers/
│       ├── DateFormatter+Shared.swift
│       └── NotificationHelper.swift
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    └── Info.plist
```

---

## Core Data Schema

### Entities

**Person**
- `id: UUID` (primary key)
- `cnIdentifier: String?`
- `displayName: String`
- `initials: String`
- `avatarColor: String`
- `groupId: UUID`
- `tagIds: Transformable ([UUID])`
- `lastTouchAt: Date?`
- `lastTouchMethod: String?` (enum raw value)
- `lastTouchNotes: String?`
- `isPaused: Bool`
- `isTracked: Bool`
- `notificationsMuted: Bool`
- `customBreachTime: String?` (LocalTime JSON)
- `createdAt: Date`
- `modifiedAt: Date`
- `sortOrder: Int64`

**Group**
- `id: UUID` (primary key)
- `name: String`
- `slaDays: Int64`
- `warningDays: Int64`
- `colorHex: String?`
- `isDefault: Bool`
- `sortOrder: Int64`
- `createdAt: Date`
- `modifiedAt: Date`

**Tag**
- `id: UUID` (primary key)
- `name: String`
- `colorHex: String`
- `sortOrder: Int64`
- `createdAt: Date`
- `modifiedAt: Date`

**TouchEvent**
- `id: UUID` (primary key)
- `personId: UUID`
- `at: Date`
- `method: String` (enum raw value)
- `notes: String?`
- `createdAt: Date`
- `modifiedAt: Date`

**AppSettings** (singleton)
- `id: UUID` (always same value)
- `theme: String` (enum raw value)
- `notificationsEnabled: Bool`
- `breachTimeOfDay: String` (LocalTime JSON)
- `digestEnabled: Bool`
- `digestDay: String` (enum raw value)
- `digestTime: String` (LocalTime JSON)
- `dueSoonWindowDays: Int64`
- `demoModeEnabled: Bool`
- `lastContactsSyncAt: Date?`
- `onboardingCompleted: Bool`
- `appVersion: String`

---

## Architecture Principles

### Clean Architecture Layers

1. **Domain Layer** (innermost)
   - Pure Swift entities and protocols
   - No dependencies on SwiftUI or Core Data
   - Business logic lives here

2. **Data Layer**
   - Core Data implementations
   - Repository pattern for data access
   - Contacts framework integration

3. **Use Cases Layer**
   - Application business logic
   - Orchestrates data layer operations
   - SLA calculations, notification scheduling

4. **UI Layer** (outermost)
   - SwiftUI views
   - View models (ObservableObject)
   - Navigation logic

### Repository Pattern

```swift
protocol PersonRepository {
    func fetch(id: UUID) -> Person?
    func fetchAll() -> [Person]
    func fetchTracked() -> [Person]
    func fetchOverdue() -> [Person]
    func save(_ person: Person) throws
    func delete(id: UUID) throws
}

// Implementation
class CoreDataPersonRepository: PersonRepository {
    private let context: NSManagedObjectContext
    
    // Implementation uses Core Data under the hood
}
```

### Benefits
- Testable (can mock repositories)
- Swappable persistence (Core Data → CloudKit in V2)
- Clean separation of concerns

---

## Coding Conventions

### Swift Style

**Naming:**
- Types: PascalCase (`PersonRepository`, `SLAStatus`)
- Properties/Methods: camelCase (`lastTouchAt`, `fetchOverdue()`)
- Constants: camelCase (`defaultGroups`, `avatarColors`)
- Enums: Singular (`TouchMethod`, not `TouchMethods`)

**Structure:**
```swift
// Order within files:
// 1. Imports
// 2. Type definition
// 3. Properties
// 4. Initializers
// 5. Public methods
// 6. Private methods
// 7. Extensions (in separate file if large)

import SwiftUI

struct PersonCard: View {
    // MARK: - Properties
    let person: Person
    @State private var isExpanded = false
    
    // MARK: - Body
    var body: some View {
        // Implementation
    }
    
    // MARK: - Private Methods
    private func formatDate() -> String {
        // Implementation
    }
}
```

**Error Handling:**
- Use `Result<Success, Failure>` for async operations
- Use `throws` for sync operations that can fail
- Custom error enum per domain:
  ```swift
  enum PersonError: Error {
      case notFound
      case invalidInput(String)
      case repositoryError(Error)
  }
  ```

**Optionals:**
- Prefer `guard let` for early returns
- Use `if let` for conditional execution
- Avoid force unwrapping (`!`) except for guaranteed cases (document why)

### SwiftUI Patterns

**State Management:**
```swift
// View state
@State private var showModal = false

// Observed objects
@StateObject private var viewModel = HomeViewModel()

// Environment
@Environment(\.colorScheme) var colorScheme

// Prefer @StateObject in parent, @ObservedObject in child
```

**View Composition:**
- Extract subviews when body > 30 lines
- Use computed properties for complex views
- Prefer view builders over conditional rendering

**Naming:**
- Views: `PersonDetailView`, `ContactCard`
- Modals: `LogTouchModal`, `EditGroupModal`
- View Models: `HomeViewModel`, `SettingsViewModel`

### Core Data Best Practices

**Fetching:**
```swift
// Use NSFetchRequest with predicates
let request: NSFetchRequest<PersonEntity> = PersonEntity.fetchRequest()
request.predicate = NSPredicate(format: "isTracked == YES AND isPaused == NO")
request.sortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true)]
```

**Saving:**
```swift
// Always save on background context for non-UI operations
context.perform {
    // Make changes
    try context.save()
}
```

**Relationships:**
- Use UUIDs for foreign keys (not NSManagedObject relationships in V1)
- V2 will migrate to proper Core Data relationships for CloudKit

---

## Key Algorithms

### SLA Status Calculation

```swift
func getSLAStatus(person: Person, groups: [Group]) -> SLAStatus {
    guard !person.isPaused else { return .inSLA }
    guard let group = groups.first(where: { $0.id == person.groupId }) else { 
        return .inSLA 
    }
    guard let lastTouch = person.lastTouchAt else { 
        return .unknown 
    }
    
    let daysSince = Calendar.current.dateComponents(
        [.day], 
        from: lastTouch, 
        to: Date()
    ).day ?? 0
    
    if daysSince >= group.slaDays {
        return .outOfSLA
    } else if daysSince >= group.slaDays - group.warningDays {
        return .dueSoon
    }
    return .inSLA
}
```

### Days Overdue Calculation

```swift
func getDaysOverdue(person: Person, groups: [Group]) -> Int {
    guard let group = groups.first(where: { $0.id == person.groupId }),
          let lastTouch = person.lastTouchAt else { 
        return 0 
    }
    
    let daysSince = Calendar.current.dateComponents(
        [.day], 
        from: lastTouch, 
        to: Date()
    ).day ?? 0
    
    return max(0, daysSince - group.slaDays)
}
```

### Notification Scheduling

```swift
func scheduleBreachNotification(for person: Person, at time: LocalTime) {
    let content = UNMutableNotificationContent()
    content.title = "Time to reconnect"
    content.body = "You haven't talked to \(person.displayName) in \(daysOverdue) days"
    content.sound = .default
    content.threadIdentifier = "breach-\(dateString)"
    content.userInfo = ["personId": person.id.uuidString]
    
    var dateComponents = DateComponents()
    dateComponents.hour = time.hour
    dateComponents.minute = time.minute
    
    let trigger = UNCalendarNotificationTrigger(
        dateMatching: dateComponents, 
        repeats: false
    )
    
    let request = UNNotificationRequest(
        identifier: "breach-\(person.id.uuidString)-\(dateString)",
        content: content,
        trigger: trigger
    )
    
    UNUserNotificationCenter.current().add(request)
}
```

---

## Testing Strategy

### Unit Tests
- Repository implementations (use in-memory Core Data)
- Use case logic (SLA calculations, notification scheduling)
- View model state changes

### UI Tests
- Critical flows: onboarding, log touch, delete touch
- Navigation paths
- Empty states

### Manual QA Checklist
See FINAL-PRD.md section 7 (Acceptance Criteria)

---

## Development Workflow

### Getting Started

1. **Xcode Setup**
   - Create new iOS App project
   - Minimum deployment: iOS 17.0
   - Interface: SwiftUI
   - Language: Swift
   - Enable Core Data checkbox

2. **Info.plist Keys**
   ```xml
   <key>NSContactsUsageDescription</key>
   <string>We need access to your contacts to help you stay in touch with the people who matter.</string>
   
   <key>NSUserNotificationsUsageDescription</key>
   <string>We'll send you gentle reminders when it's time to reconnect with someone.</string>
   ```

3. **Build Phases**
   - Configure Core Data model
   - Add default groups/tags seeding logic
   - Set up background task scheduler

### Milestone Breakdown

**M1: Core Data + Domain (Week 1)**
- Set up Core Data stack
- Define all entities
- Implement repositories
- Create domain models
- Unit tests for repositories

**M2: Onboarding (Week 1)**
- Welcome screen
- Contacts permission flow
- Contact picker
- Groups info
- Notifications permission

**M3: Home Screen (Week 2)**
- HomeView layout
- Contact cards
- Filtering/sorting
- Search
- Empty states
- Pull to refresh

**M4: Person Detail (Week 2)**
- Detail view layout
- Quick actions (fetch from Contacts)
- Touch history display
- Pause/resume

**M5: Touch Logging (Week 3)**
- Log touch modal
- Edit touch modal
- Delete confirmation
- TouchEvent CRUD operations
- SLA recalculation on save

**M6: Settings & Management (Week 3)**
- Settings screen
- Manage Groups CRUD
- Manage Tags CRUD
- Theme toggle
- Export data

**M7: Notifications (Week 4)**
- Breach notification scheduling
- Weekly digest
- Background task setup
- Deep link handling
- Notification grouping

**M8: Polish & Testing (Week 4)**
- Dark/light theme refinement
- Accessibility labels
- Error handling
- Demo mode
- TestFlight build

---

## Common Gotchas

### Contacts Framework
```swift
// GOOD: Fetch on-demand when needed
func getContactInfo(for person: Person) -> (phone: String?, email: String?)? {
    guard let cnId = person.cnIdentifier else { return nil }
    
    let store = CNContactStore()
    let keys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
    
    guard let contact = try? store.unifiedContact(
        withIdentifier: cnId, 
        keysToFetch: keys
    ) else { return nil }
    
    let phone = contact.phoneNumbers.first?.value.stringValue
    let email = contact.emailAddresses.first?.value as String?
    
    return (phone, email)
}

// BAD: Storing phone/email in Person entity
// This causes sync drift when user updates contact in Phone app
```

### Core Data Thread Safety
```swift
// GOOD: Use perform/performAndWait
context.perform {
    let person = PersonEntity(context: context)
    // Set properties
    try? context.save()
}

// BAD: Accessing context from wrong thread
// Causes crashes in production
```

### Date Calculations
```swift
// GOOD: Use Calendar for day calculations
let days = Calendar.current.dateComponents(
    [.day], 
    from: startDate, 
    to: endDate
).day ?? 0

// BAD: Manual math
let days = Int((endDate.timeIntervalSince(startDate)) / 86400)
// Fails with DST, leap seconds, etc.
```

### SwiftUI State Updates
```swift
// GOOD: Update on main thread
DispatchQueue.main.async {
    self.contacts = newContacts
}

// BAD: Background thread updates
Task {
    self.contacts = await fetchContacts() // Crashes if not @MainActor
}
```

---

## Dependencies

### Built-in Frameworks
- SwiftUI (UI)
- Core Data (Persistence)
- Contacts (CNContactStore)
- UserNotifications (Local notifications)
- BackgroundTasks (BGTaskScheduler)

### No External Dependencies
- No CocoaPods
- No SPM packages
- Keep app lightweight and reviewable

---

## Accessibility Requirements

### VoiceOver Labels
- All interactive elements must have `.accessibilityLabel()`
- Contact cards: "Contact Sarah Chen, overdue by 5 days, tap to view details"
- Buttons: Descriptive labels ("Delete touch entry" not just "Delete")

### Dynamic Type
- Use system fonts (.body, .headline, etc.)
- Avoid fixed font sizes
- Test with largest accessibility sizes

### Color Contrast
- Status colors meet WCAG AA (4.5:1 minimum)
- Don't rely solely on color (use icons + text)

### Keyboard Navigation
- All modals dismissible with gesture or button
- Focus management when showing/hiding modals

---

## Performance Targets

### Launch Time
- Cold launch < 1 second
- Warm launch < 0.3 seconds

### Scroll Performance
- 60 FPS on Home screen with 100+ contacts
- Use lazy loading for long lists

### Memory
- < 50 MB baseline
- < 100 MB with demo data loaded

### Battery
- Minimal impact (notifications are local, no network)
- Background tasks < 1 second execution

---

## Privacy & Security

### Data Storage
- All data in Core Data (encrypted at rest by iOS)
- No network transmission in V1
- No analytics or crash reporting in V1

### Permissions
- Contacts: Request once, graceful degradation if denied
- Notifications: Request once, can be enabled later in Settings

### User Control
- Export all data as JSON
- Delete all data (V2 feature)
- Demo mode isolates fake data from real data

---

## App Store Submission Checklist

**Before TestFlight:**
- [ ] All acceptance criteria passing
- [ ] No crashes in Xcode testing
- [ ] Memory leaks checked (Instruments)
- [ ] Privacy policy URL added
- [ ] Support email configured
- [ ] Screenshots prepared (use demo mode)
- [ ] App icon added (1024x1024)

**Metadata:**
- App Name: "Stay in Touch"
- Subtitle: "Never lose track of friends"
- Keywords: "contacts, friends, relationships, CRM, reminders"
- Category: Productivity
- Age Rating: 4+

---

## Questions During Implementation?

**Contact:**
- GitHub Issues (preferred)
- Email: [your email]
- Slack: [your workspace]

**Resources:**
- Apple HIG: https://developer.apple.com/design/human-interface-guidelines/
- SwiftUI Docs: https://developer.apple.com/documentation/swiftui/
- Core Data Guide: https://developer.apple.com/documentation/coredata/

---

## First Task for Codex

**Set up the Xcode project scaffold:**

1. Create new iOS App project in Xcode
2. Enable Core Data at project creation
3. Configure Info.plist with required permission strings
4. Create folder structure as outlined above
5. Define Core Data model (.xcdatamodeld) with all entities
6. Implement CoreDataStack.swift with persistent container
7. Create a simple "Hello World" view to verify build
8. Run on simulator to confirm setup

**Verification:**
- Project builds without errors
- Core Data model visible in Xcode
- Info.plist has both permission strings
- Folder structure matches specification
- Simulator launches app successfully

Once scaffold is complete, ping for next task: **Implement domain models and repositories**.

---

**Good luck! 🚀**
