# User Feedback Tracking

## How We Organize Feedback

### From Device Testing to GitHub Issues

1. **Capture Feedback:** Test app on device, document issues in running notes
2. **Categorize:** Analyze by type, scope, complexity, priority
3. **Create Issues:** File on GitHub with appropriate labels and milestones
4. **Assign Milestones:** V1.1 (quick wins), V1.2 (enhancements), V2 (major features)
5. **Track Progress:** Use project boards and milestone views

### Label System

**Type:**
- `ux-improvement` - User experience improvements
- `feature-simplification` - Simplify existing features
- `bug-fix` - Bug fixes
- `feature-request` - New feature requests

**Priority:**
- `priority-high` - Significant UX impact, should fix soon
- `priority-medium` - Nice to have, improves experience
- `priority-low` - Minor polish, low impact

**Complexity:**
- `complexity-simple` - < 1 hour effort
- `complexity-medium` - 1-4 hours effort
- `complexity-complex` - 1+ days effort

**Area:**
- `area-onboarding` - Onboarding flow
- `area-detail-view` - Person detail view
- `area-settings` - Settings and configuration
- `area-home` - Home screen
- `area-notifications` - Notification system

### Milestone Strategy

**V1.1 Quick Wins (1-2 weeks)**
- Focus: High-impact, low-effort improvements
- Goal: Address most common UX issues
- Target: ~6 hours total effort

**V1.2 Enhancements (2-4 weeks)**
- Focus: Feature parity and power user functionality
- Goal: Add requested features with schema changes
- Target: 2-3 days total effort

**V2.0 Major Features (3-4 months)**
- Focus: Advanced functionality and architectural changes
- Goal: CloudKit sync, tutorial, statistics dashboard
- Target: 2+ weeks effort

### Current Issues (Feb 2026)

**V1.1 Quick Wins:**
- [#1](https://github.com/slavins-co/stay-in-touch-ios/issues/1): Update onboarding copy
- [#2](https://github.com/slavins-co/stay-in-touch-ios/issues/2): Remove time from touch history
- [#3](https://github.com/slavins-co/stay-in-touch-ios/issues/3): Add system theme option
- [#4](https://github.com/slavins-co/stay-in-touch-ios/issues/4): Animated group expand/collapse
- [#5](https://github.com/slavins-co/stay-in-touch-ios/issues/5): Advanced settings section
- [#6](https://github.com/slavins-co/stay-in-touch-ios/issues/6): Contact search and alphabet index

**V1.2 Enhancements:**
- [#7](https://github.com/slavins-co/stay-in-touch-ios/issues/7): Next touch notes field
- [#8](https://github.com/slavins-co/stay-in-touch-ios/issues/8): Group assignment in settings flow
- [#9](https://github.com/slavins-co/stay-in-touch-ios/issues/9): Custom due date per contact

**V2.0 Major Features:**
- [#10](https://github.com/slavins-co/stay-in-touch-ios/issues/10): Self-guided tutorial system
- (More to come: CloudKit sync, statistics, batch import)

### Existing Backlog

See [REMAINING-ISSUES.md](REMAINING-ISSUES.md) for 10 additional low-priority items identified during code audit.

---

## Implementation Workflow

### For Each Issue:

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/issue-N-short-description
   ```

2. **Make Changes**
   - Follow acceptance criteria
   - Update related tests
   - Manual testing on device

3. **Commit with Convention**
   ```bash
   git commit -m "feat: description of change

   - Detail 1
   - Detail 2

   Resolves #N"
   ```

4. **Push and Create PR**
   ```bash
   git push origin feature/issue-N-short-description
   gh pr create --title "Title" --body "Closes #N"
   ```

5. **Merge and Close**
   - Verify all acceptance criteria met
   - Take screenshots for UI changes
   - Document learnings in tasks/lessons.md

---

## Milestone Release Process

### V1.1 Release Checklist

- [ ] All 6 issues closed and tested
- [ ] No regressions introduced
- [ ] Update version in Xcode (1.1.0, Build 2)
- [ ] Create git tag: `v1.1.0`
- [ ] Deploy new TestFlight build
- [ ] Update changelog
- [ ] Close V1.1 milestone on GitHub
- [ ] Collect feedback from beta testers

---

**Last Updated:** February 4, 2026
**Repository:** https://github.com/slavins-co/stay-in-touch-ios
