# Stay in Touch

> Privacy-first iOS app to maintain friendships through gentle reminders and relationship tracking.

[![Platform](https://img.shields.io/badge/platform-iOS%2017.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0-brightgreen.svg)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

**Version:** 0.2.0 (Build 4)
**Status:** 🧪 Pre-release Beta | 🧭 Planning V0.2.0

---

## What is Stay in Touch?

Never lose track of the people who matter. Stay in Touch helps you maintain friendships by:

- **Tracking "last touch" dates** with friends and family
- **Organizing contacts into SLA groups** (Weekly, Bi-Weekly, Monthly, Quarterly)
- **Sending gentle reminders** when it's time to reconnect
- **Keeping it private** - all data stays on your device

"Out of sight, out of mind" shouldn't apply to friendships. This app ensures you stay connected.

---

## Current Status

### ✅ V1.0 (February 2026)
- Full iOS app implementation with Clean Architecture
- 30+ passing unit tests
- Security audit completed, all critical issues resolved
- Device testing with real user feedback collected

### ✅ V1.1.0 (Released February 4, 2026)
6 UX improvements based on device testing feedback:
- [#1](https://github.com/slavins-co/stay-in-touch-ios/issues/1) Updated onboarding copy
- [#2](https://github.com/slavins-co/stay-in-touch-ios/issues/2) Simplified touch time display
- [#3](https://github.com/slavins-co/stay-in-touch-ios/issues/3) System theme auto-detection
- [#4](https://github.com/slavins-co/stay-in-touch-ios/issues/4) Animated group expand/collapse
- [#5](https://github.com/slavins-co/stay-in-touch-ios/issues/5) Advanced settings section
- [#6](https://github.com/slavins-co/stay-in-touch-ios/issues/6) Contact search & A-Z alphabet index

### ✅ V1.1.1 (Released February 16, 2026)
5 new features + 4 quality-of-life fixes:
- [#7](https://github.com/slavins-co/stay-in-touch-ios/issues/7) Forward-looking "Next Time" notes per contact
- [#13](https://github.com/slavins-co/stay-in-touch-ios/issues/13) Time-of-day picker (Morning/Afternoon/Evening) on touch logging
- [#22](https://github.com/slavins-co/stay-in-touch-ios/issues/22) Randomized notification copy variations
- [#23](https://github.com/slavins-co/stay-in-touch-ios/issues/23) Snooze/defer due date per contact
- [#8](https://github.com/slavins-co/stay-in-touch-ios/issues/8) Group assignment step when importing contacts
- [#18](https://github.com/slavins-co/stay-in-touch-ios/issues/18) Dynamic app version in Settings
- [#19](https://github.com/slavins-co/stay-in-touch-ios/issues/19) Due date shown in cadence section
- [#20](https://github.com/slavins-co/stay-in-touch-ios/issues/20) Cleaner notification copy
- [#21](https://github.com/slavins-co/stay-in-touch-ios/issues/21) Friendlier notification titles

### 🧭 Open Issues (3 remaining)
- [#24](https://github.com/slavins-co/stay-in-touch-ios/issues/24) Redesign visual language (HIGH priority)
- [#9](https://github.com/slavins-co/stay-in-touch-ios/issues/9) Custom due dates per contact (MEDIUM priority)
- [#10](https://github.com/slavins-co/stay-in-touch-ios/issues/10) Self-guided tutorial (LOW priority, deferred to V2)

### 🔮 V2.0 (Future)
- Visual redesign and streamlined UI
- CloudKit sync for multi-device support
- Home/Lock screen widgets
- Shortcuts/Siri integration
- Self-guided tutorial system

---

## Features

### 📱 Core Functionality
- ✅ Manual touch logging (Text, Call, IRL, Email, Other)
- ✅ Time-of-day tracking (Morning, Afternoon, Evening)
- ✅ SLA-based contact groups with configurable cadences
- ✅ Snooze/defer due dates per contact (preset + custom)
- ✅ Forward-looking "Next Time" notes per contact
- ✅ Tag system (Work, Family, Friend, Mentor + custom)
- ✅ Local notifications with randomized copy variations
- ✅ Full touch history with edit/delete capability
- ✅ Contact search with A-Z alphabet sidebar
- ✅ Group assignment when importing contacts
- ✅ Pause/resume tracking per contact
- ✅ Dark/light/system theme support
- ✅ Animated group expand/collapse transitions
- ✅ Demo mode for testing

### 🔒 Privacy First
- ✅ All data stored locally on device (Core Data)
- ✅ No cloud sync (V1)
- ✅ No analytics or tracking
- ✅ No network requests
- ✅ Read-only access to Contacts (fetch on-demand)
- ✅ Export your data as JSON anytime

---

## Tech Stack

**Platform:** iOS 17.0+
**Language:** Swift 5.0
**UI Framework:** SwiftUI
**Architecture:** Clean Architecture + Repository Pattern
**Persistence:** Core Data
**Testing:** XCTest (30+ unit tests)

### Built-in Frameworks Only
- SwiftUI - User interface
- Core Data - Local persistence
- Contacts - CNContactStore integration
- UserNotifications - Local reminders
- BackgroundTasks - Daily SLA calculations

**No external dependencies** - lightweight, reviewable, and private.

---

## Project Structure

```
StayInTouch/
├── App/
│   └── StayInTouchApp.swift
├── Domain/                      # Pure Swift business logic
│   ├── Entities/                # Person, Group, Tag, TouchEvent
│   ├── ValueObjects/            # SLAStatus, Theme, LocalTime, TimeOfDay
│   └── Protocols/               # Repository interfaces
├── Data/                        # Persistence layer
│   ├── CoreData/                # Core Data stack + repositories
│   └── Contacts/                # CNContactStore integration
├── UseCases/                    # Application logic
│   ├── SLACalculator.swift
│   ├── NotificationScheduler.swift
│   └── ContactsSyncUseCase.swift
├── UI/                          # SwiftUI views
│   ├── Views/
│   │   ├── Onboarding/          # 5-screen onboarding flow
│   │   ├── Home/                # Main contact list
│   │   ├── PersonDetail/        # Contact detail + touch logging
│   │   └── Settings/            # App configuration
│   └── ViewModels/              # @ObservableObject view models
└── Utilities/
    ├── Extensions/              # Date, String, Color helpers
    └── Helpers/                 # AppLogger, NotificationHelper
```

---

## Documentation

### For Users
- **[User Guide]** - Coming soon (TestFlight launch)

### For Developers
- **[CLAUDE.md](CLAUDE.md)** - Claude Code context and workflow
- **[FINAL-PRD.md](FINAL-PRD.md)** - Complete product requirements
- **[CODEX.md](CODEX.md)** - Original Codex instructions (archived)
- **[ASSETS.md](ASSETS.md)** - Design system and UI patterns
- **[AUDIT-FIXES-SUMMARY.md](AUDIT-FIXES-SUMMARY.md)** - Security audit report
- **[FEEDBACK-TRACKING.md](FEEDBACK-TRACKING.md)** - Issue organization workflow

### Planning & Backlog
- **[tasks/todo.md](tasks/todo.md)** - Current milestone tasks
- **[tasks/lessons.md](tasks/lessons.md)** - Development learnings
- **[REMAINING-ISSUES.md](REMAINING-ISSUES.md)** - Low-priority backlog items

---

## Getting Started

### Prerequisites
- macOS 14.0+ (Sonoma or later)
- Xcode 15.0+
- iOS 17.0+ device or simulator

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/slavins-co/stay-in-touch-ios.git
   cd stay-in-touch-ios
   ```

2. **Open in Xcode**
   ```bash
   open "StayInTouch/StayInTouch.xcodeproj"
   ```

3. **Build and run**
   - Select a simulator or device
   - Press Cmd+R to build and run
   - Grant Contacts and Notifications permissions when prompted

4. **Enable Demo Mode** (optional)
   - Go to Settings → Demo Mode → Toggle On
   - Generates sample contacts for testing

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme StayInTouch -destination 'platform=iOS Simulator,name=iPhone 16'

# Or use Xcode: Cmd+U
```

---

## Development Workflow

### Working on Issues

1. **Pick an open issue**
   ```bash
   gh issue list --state open
   ```

2. **Create feature branch**
   ```bash
   git checkout -b feature/issue-N-short-description
   ```

3. **Make changes and test**
   - Follow acceptance criteria in issue
   - Run tests: `Cmd+U`
   - Test on device manually

4. **Commit with conventional format**
   ```bash
   git commit -m "feat: description of change

   - Detail 1
   - Detail 2

   Resolves #N"
   ```

5. **Push and create PR**
   ```bash
   git push origin feature/issue-N-short-description
   gh pr create --title "Title" --body "Closes #N"
   ```

### Coding Standards
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use Clean Architecture layers (Domain → Data → UseCases → UI)
- Write unit tests for business logic
- Document learnings in `tasks/lessons.md`
- See [CLAUDE.md](CLAUDE.md) for detailed conventions

---

## Issue Tracking

### 🐛 Found a Bug?
[Report an issue](https://github.com/slavins-co/stay-in-touch-ios/issues/new?labels=bug-fix&template=bug_report.md)

### 💡 Feature Request?
[Suggest a feature](https://github.com/slavins-co/stay-in-touch-ios/issues/new?labels=feature-request&template=feature_request.md)

### 📊 View Roadmap
- [Open Issues](https://github.com/slavins-co/stay-in-touch-ios/issues) - Current backlog
- [Releases](https://github.com/slavins-co/stay-in-touch-ios/releases) - Version history

### 🏷️ Label System
- **Type:** `ux-improvement`, `feature-request`, `bug-fix`, `feature-simplification`
- **Priority:** `priority-high`, `priority-medium`, `priority-low`
- **Complexity:** `complexity-simple`, `complexity-medium`, `complexity-complex`
- **Area:** `area-home`, `area-detail-view`, `area-settings`, `area-onboarding`, `area-notifications`

---

## Architecture Highlights

### Clean Architecture
```
UI Layer (SwiftUI Views)
    ↓
View Models (@ObservableObject)
    ↓
Use Cases (Business Logic)
    ↓
Repositories (Protocol Interfaces)
    ↓
Data Layer (Core Data Implementation)
```

**Benefits:**
- ✅ Testable (can mock repositories)
- ✅ Swappable persistence (V2: CloudKit)
- ✅ Clear separation of concerns
- ✅ Independent of frameworks

### Repository Pattern
All data access goes through protocol interfaces:

```swift
protocol PersonRepository {
    func fetch(id: UUID) -> Person?
    func fetchAll() -> [Person]
    func fetchTracked() -> [Person]
    func save(_ person: Person) throws
    func delete(id: UUID) throws
}
```

Implemented by `CoreDataPersonRepository` (can swap for CloudKit later).

### SLA Calculation
Business logic lives in `SLACalculator` use case:

```swift
func status(for person: Person, in groups: [Group]) -> SLAStatus {
    // Returns: .inSLA, .dueSoon, .outOfSLA, .unknown
}

func daysOverdue(for person: Person, in groups: [Group]) -> Int {
    // Returns: 0+ days past SLA breach
}
```

---

## Testing

### Current Coverage
- ✅ 30+ unit tests
- ✅ Repository CRUD operations
- ✅ SLA calculation logic
- ✅ ViewModel state management
- ✅ Core Data entity mapping

### Test Structure
```
StayInTouchTests/
├── Domain/
│   └── UseCases/
│       └── SLACalculatorTests.swift
├── Data/
│   └── CoreData/
│       ├── CoreDataPersonRepositoryTests.swift
│       └── PersonEntityMappingTests.swift
└── UI/
    └── ViewModels/
        └── HomeViewModelTests.swift
```

### Running Specific Tests
```bash
# Run single test class
xcodebuild test -scheme StayInTouch -only-testing:StayInTouchTests/SLACalculatorTests

# Run on device
xcodebuild test -scheme StayInTouch -destination 'platform=iOS,name=iPhone'
```

---

## Contributing

### How to Contribute

1. **Check existing issues**
   - Look for `good-first-issue` labels
   - Comment on issue to claim it

2. **Fork the repository**
   ```bash
   gh repo fork slavins-co/stay-in-touch-ios --clone
   ```

3. **Create feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Make changes**
   - Follow coding standards in [CLAUDE.md](CLAUDE.md)
   - Write tests for new features
   - Update documentation

5. **Submit pull request**
   ```bash
   gh pr create --title "Title" --body "Description"
   ```

### Code Review Process
- All PRs require review
- Tests must pass
- No new warnings
- Acceptance criteria verified

---

## Deployment

### TestFlight
V1.1.1 is the TestFlight candidate.

**Pre-TestFlight Checklist:**
- [x] All V1.1.x issues closed (15/15)
- [ ] No crashes in testing
- [ ] Memory leaks checked (Instruments)
- [ ] Privacy policy finalized
- [ ] App Store screenshots prepared

See [TESTFLIGHT-PLAN.md](TESTFLIGHT-PLAN.md) for complete guide.

---

## Security & Privacy

### Data Storage
- ✅ All data in Core Data (encrypted at rest by iOS)
- ✅ No network transmission
- ✅ No analytics or crash reporting
- ✅ Read-only Contacts access (fetch on-demand only)

### Permissions
- **Contacts:** Used to fetch contact info (name, phone, email) on-demand
- **Notifications:** Used to send local reminders about relationship SLAs

### User Control
- ✅ Export all data as JSON
- ✅ Demo mode isolates fake data
- ✅ Pause tracking per contact
- ✅ Delete touch history

**Privacy Policy:** Coming with TestFlight release

---

## Troubleshooting

### Build Issues

**Error: "Could not find module SwiftUI"**
- Ensure Xcode 15.0+ is installed
- Check iOS deployment target is 17.0+

**Error: "Core Data model not found"**
- Clean build folder: `Cmd+Shift+K`
- Rebuild: `Cmd+B`

### Runtime Issues

**Contacts not loading**
- Grant Contacts permission in Settings → Privacy
- Check `ContactsFetcher` logs in Console.app

**Notifications not appearing**
- Grant Notifications permission in Settings
- Check notification center is not in Do Not Disturb
- View scheduled notifications: Settings → Send Test Notification

### Getting Help
- [Open an issue](https://github.com/slavins-co/stay-in-touch-ios/issues/new)
- Check [REMAINING-ISSUES.md](REMAINING-ISSUES.md) for known issues
- Review [tasks/lessons.md](tasks/lessons.md) for common patterns

---

## Changelog

### V1.0 (February 2026)
**Initial release - Feature complete**
- ✅ Complete iOS app with Clean Architecture
- ✅ 30+ unit tests, all passing
- ✅ Security audit completed
- ✅ Device testing with user feedback

### V1.1.0 (February 4, 2026)
**UX improvements based on device testing**
- ✅ Updated onboarding copy
- ✅ Simplified touch time display (date only)
- ✅ System theme auto-detection
- ✅ Animated group expand/collapse
- ✅ Advanced settings section
- ✅ Contact search and A-Z alphabet index

### V1.1.1 (February 16, 2026)
**Snooze, Notes & Quality of Life**
- ✅ Forward-looking "Next Time" notes per contact (#7)
- ✅ Time-of-day picker in touch logging (#13)
- ✅ Randomized notification copy (#22)
- ✅ Snooze/defer due date per contact (#23)
- ✅ Group assignment on Settings import (#8)
- ✅ Dynamic app version in Settings (#18)
- ✅ Due date in cadence section (#19)
- ✅ Cleaner notification copy (#20, #21)

### V2.0 (Future)
**Major features**
- 🔮 Visual redesign (#24)
- 🔮 CloudKit sync (multi-device)
- 🔮 Home/Lock screen widgets
- 🔮 Shortcuts/Siri integration
- 🔮 Self-guided tutorial (#10)

---

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- **Built with:** [Claude Code](https://claude.com/claude-code) by Anthropic
- **Design Inspiration:** Personal CRM apps (Monica, Folk)
- **Architecture:** Clean Architecture by Robert C. Martin

---

## Contact

**Repository:** https://github.com/slavins-co/stay-in-touch-ios
**Issues:** https://github.com/slavins-co/stay-in-touch-ios/issues
**Milestones:** https://github.com/slavins-co/stay-in-touch-ios/milestones

---

**Built with care to help you stay in touch with the people who matter.** ❤️
