# Stay in Touch - iOS Personal CRM App

**Version:** 1.0  
**Status:** 📋 Ready for Implementation  
**Updated:** February 1, 2026

---

## Quick Start for Claude Code

1. **Read these files in order:**
   - 📖 **This README** (you are here)
   - 🛠️ **[CLAUDE.md](./CLAUDE.md)** - Workflow, architecture, conventions
   - 📋 **[FINAL-PRD.md](./FINAL-PRD.md)** - Complete requirements
   - 🎨 **[ASSETS.md](./ASSETS.md)** - Design system

2. **Review the task plan:**
   - 📝 **[tasks/todo.md](./tasks/todo.md)** - 8 milestones, 4 weeks

3. **Start first task:**
   - Set up Xcode project scaffold (see CLAUDE.md)

---

## Project Overview

**What:** Privacy-first iOS app to help users maintain friendships  
**How:** Track "last touch" dates, organize contacts into SLA groups, receive gentle reminders  
**Why:** "Out of sight, out of mind" - friendships get neglected without visibility

### Core Features (V1)
✅ Manual touch logging (Text, Call, IRL, Email, Other)  
✅ SLA-based contact groups (Weekly, Bi-Weekly, Monthly, Quarterly)  
✅ Tag system (Work, Family, Friend, Mentor + custom)  
✅ Local notifications (breach alerts + weekly digest)  
✅ Full touch history with edit/delete  
✅ Pause/resume tracking per contact  
✅ Dark/light theme  
✅ Privacy-first (on-device only, no servers)

### Out of Scope (V2)
❌ CloudKit sync  
❌ Shortcuts/Siri integration  
❌ Automatic detection (iMessage/call logs)  
❌ macOS companion  
❌ Widgets

---

## Documentation Structure
```
iOS Personal CRM App/
├── README.md                    ← You are here (start here!)
├── CLAUDE.md                    ← Workflow + architecture (read second!)
├── FINAL-PRD.md                 ← Complete requirements (read third!)
├── ASSETS.md                    ← Design system (reference as needed)
├── SUMMARY.md                   ← Executive summary (optional)
│
├── tasks/
│   ├── todo.md                  ← Implementation roadmap (8 milestones)
│   └── lessons.md               ← Patterns & corrections (update as you go)
│
└── Figma Mockup/                ← Reference implementation (React)
    └── src/
        ├── components/          ← UI patterns to translate to SwiftUI
        ├── types/               ← Data model reference
        └── utils/               ← Logic reference
```

---

## Key Decisions Made

| Topic | Decision | Rationale |
|-------|----------|-----------|
| **Contact Storage** | Fetch phone/email on-demand from Contacts | Prevents sync drift |
| **Tags** | Included in V1 | Better categorization than groups alone |
| **Touch History** | Full edit/delete capability | Users make mistakes |
| **Pause/Resume** | Soft exclusion from tracking | Less destructive than delete |
| **Onboarding** | 5-screen flow | Critical for first-run UX |
| **Notifications** | Local only (no push) | Privacy + simplicity |

---

## Tech Stack

**Platform:** iOS 17.0+  
**Language:** Swift  
**UI:** SwiftUI (no UIKit)  
**Data:** Core Data → NSPersistentCloudKitContainer (V2)  
**Architecture:** Clean Architecture + Repository Pattern  
**Dependencies:** None (built-in frameworks only)

### Frameworks Used
- SwiftUI (UI)
- Core Data (Persistence)
- Contacts (CNContactStore - read-only)
- UserNotifications (Local notifications)
- BackgroundTasks (Daily SLA calculations)

---

## Data Model (5 Entities)

1. **Person** - Tracked contacts (15 attributes)
2. **Group** - SLA cadence definitions (8 attributes)
3. **Tag** - Categorization labels (4 attributes)
4. **TouchEvent** - Interaction history (6 attributes)
5. **AppSettings** - Configuration singleton (11 attributes)

See FINAL-PRD.md Section 1 for complete schema.

---

## Implementation Timeline

| Milestone | Focus | Duration |
|-----------|-------|----------|
| M1 | Core Data + Domain | Week 1 |
| M2 | Onboarding | Week 1 |
| M3 | Home Screen | Week 2 |
| M4 | Person Detail | Week 2 |
| M5 | Touch Logging | Week 3 |
| M6 | Settings & Management | Week 3 |
| M7 | Notifications | Week 4 |
| M8 | Polish & Testing | Week 4 |

**Total:** 4 weeks to TestFlight

---

## Acceptance Criteria

70+ testable requirements documented in FINAL-PRD.md Section 7.

**Example:**
- AC-101: Given 3 overdue contacts, when Home loads, then Overdue section shows count (3) and all 3 contacts sorted by days overdue DESC
- AC-301: Given Log Touch modal, when user selects "Call" and types "Caught up on life", then Done creates TouchEvent with method=Call and notes

---

## File Inventory

### Core Documentation (Read These!)
- ✅ **README.md** - This file (overview)
- ✅ **CLAUDE.md** - Workflow, architecture, conventions (5,000+ words)
- ✅ **FINAL-PRD.md** - Complete requirements (12,000+ words)
- ✅ **ASSETS.md** - Design system reference (2,000+ words)
- ✅ **SUMMARY.md** - Executive summary (2,000+ words)

### Task Management
- ✅ **tasks/todo.md** - Implementation roadmap
- ✅ **tasks/lessons.md** - Patterns learned (update during dev)

### Reference Implementation
- ✅ **Figma Mockup/** - React prototype (translate to SwiftUI)

---

## Getting Started Checklist

Before writing code, verify you understand:

- [ ] Data model schema (5 entities, relationships)
- [ ] Repository pattern usage (why UUIDs for foreign keys)
- [ ] Contact fetching strategy (on-demand vs stored)
- [ ] SLA calculation algorithm (days overdue logic)
- [ ] Notification scheduling rules (breach + digest)
- [ ] Onboarding flow (5 screens, permission handling)
- [ ] Screen specifications (12 screens documented)
- [ ] Edge cases (9 scenarios with solutions)
- [ ] Workflow principles (plan mode, verification, lessons)

**Questions?** Review CLAUDE.md Section "Common Gotchas"

---

## First Task

**Set up Xcode project scaffold:**

1. Create new iOS App project
   - Target: iOS 17.0
   - Interface: SwiftUI
   - Language: Swift
   - Enable Core Data: ✅

2. Configure Info.plist
   - Add NSContactsUsageDescription
   - Add NSUserNotificationsUsageDescription

3. Create folder structure (see CLAUDE.md)

4. Define Core Data model (.xcdatamodeld)
   - Person entity (15 attributes)
   - Group entity (8 attributes)
   - Tag entity (4 attributes)
   - TouchEvent entity (6 attributes)
   - AppSettings entity (11 attributes)

5. Implement CoreDataStack.swift

6. Verify build succeeds

See CLAUDE.md final section for detailed instructions.

---

## Success Metrics

**V1 Complete When:**
- ✅ All 70+ acceptance criteria pass
- ✅ No crashes in Xcode testing
- ✅ Memory leaks checked (Instruments)
- ✅ TestFlight build submitted
- ✅ 5+ beta testers give feedback

---

## Support Resources

**Documentation:**
- Apple HIG: https://developer.apple.com/design/human-interface-guidelines/
- SwiftUI Docs: https://developer.apple.com/documentation/swiftui/
- Core Data Guide: https://developer.apple.com/documentation/coredata/

**Within This Project:**
- Questions about requirements → FINAL-PRD.md
- Questions about architecture → CLAUDE.md
- Questions about design → ASSETS.md
- Questions about tasks → tasks/todo.md

---

## Development Workflow

### Daily Routine
1. Review lessons.md for relevant patterns
2. Check todo.md for current milestone tasks
3. Enter plan mode for non-trivial work
4. Implement with verification at each step
5. Update todo.md progress
6. Document any corrections in lessons.md

### Weekly Routine
1. Review milestone completion
2. Update SUMMARY.md if major changes
3. Adjust timeline if needed
4. Document blockers and decisions

### Quality Gates
- ✅ Code builds without warnings
- ✅ Tests pass (unit + UI where applicable)
- ✅ No memory leaks
- ✅ Acceptance criteria verified
- ✅ Staff engineer would approve

---

## Known Risks & Mitigations

🟡 **Notification Scheduling** (Medium Risk)  
→ Test on real device early (Week 3)

🟡 **Contacts Framework** (Medium Risk)  
→ Handle all CNContactStore errors gracefully

🟡 **Theme Switching** (Medium Risk)  
→ Test in both modes throughout development

🟢 **Data Model** (Low Risk)  
→ Straightforward Core Data implementation

---

## V2 Roadmap (Post-Launch)

**Top Priorities:**
1. CloudKit sync (multi-device)
2. Shortcuts integration (quick log)
3. Widgets (Home/Lock screen)
4. Manual contact creation
5. macOS companion app

**Timeline:** 8-12 weeks after V1 ships

---

## Contact & Feedback

**During Development:**
- Update tasks/todo.md with progress
- Document issues and blockers
- Capture corrections in tasks/lessons.md

**Questions About Requirements:**
- Review FINAL-PRD.md first
- Check CLAUDE.md "Common Gotchas"
- Ask user if truly blocked

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Feb 1, 2026 | Initial complete specification |

---

## License & Privacy

**App Privacy:** All data on-device only, no servers, no analytics  
**Code Privacy:** Private repository, not open source in V1  
**User Data:** Export available as JSON, full user control

---

**Ready to build? Start with CLAUDE.md, then dive into M1!** 🚀