# Remaining Issues - Post-TestFlight Backlog

**App:** Stay in Touch (iOS Personal CRM)
**Version:** V1 TestFlight → V1.1 Planning
**Priority:** Low to Medium (Non-blocking for TestFlight)

---

## Phase 2: TestFlight Launch (Should Fix Based on Feedback)

### 1. CNContactStore Singleton Pattern
**Priority:** MEDIUM
**Effort:** 15 minutes
**Impact:** Memory optimization

**Current:** ContactsFetcher creates new CNContactStore instance on every call
**Fix:** Implement singleton or cached instance

```swift
enum ContactsFetcher {
    private static let store = CNContactStore()  // Reuse instance

    static func requestAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            ContactsFetcher.store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}
```

---

### 2. Notification Retry Logic
**Priority:** MEDIUM
**Effort:** 30 minutes
**Impact:** Reliability

**Current:** Silent failure if notification scheduling fails
**Fix:** Implement exponential backoff retry

```swift
private func scheduleWithRetry(_ request: UNNotificationRequest, retries: Int = 3) async {
    for attempt in 0..<retries {
        do {
            try await UNUserNotificationCenter.current().add(request)
            return
        } catch {
            if attempt == retries - 1 {
                AppLogger.logError(error, category: AppLogger.notifications, context: "Failed after \(retries) attempts")
            } else {
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
            }
        }
    }
}
```

---

### 3. UI Test Coverage
**Priority:** MEDIUM
**Effort:** 2-3 hours
**Impact:** Regression prevention

**Current:** Only 2 basic UI tests
**Needed:**
- Onboarding flow test
- Touch logging flow test
- Notification tap handling test
- Contact sync test
- Group/tag management test

---

### 4. Notification Scheduling Unit Tests
**Priority:** MEDIUM
**Effort:** 1 hour
**Impact:** Confidence in notifications

**Needed:**
```swift
func testScheduleDaily_CreatesCorrectTrigger()
func testSchedulePerPerson_CreatesMultipleRequests()
func testScheduleWeeklyDigest_CalculatesCorrectDate()
func testClearAll_RemovesAllNotifications()
func testCustomBreachTime_OverridesDefaultTime()
```

---

## Phase 3: Post-TestFlight (Nice to Have)

### 5. Search Performance Optimization
**Priority:** LOW
**Effort:** 10 minutes
**Impact:** Speed improvement for 100+ contacts

**Current:** No index on displayName
**Fix:** Add Core Data index

In `StayInTouch.xcdatamodeld` → PersonEntity:
- Select `displayName` attribute
- Check "Indexed" in data model inspector

---

### 6. Demo Data Race Condition
**Priority:** LOW
**Effort:** 15 minutes
**Impact:** Edge case fix

**Current:**
```swift
await backgroundContext.perform { /* mutations */ }
DispatchQueue.main.async {
    NotificationCenter.default.post(name: .personDidChange, object: nil)
}
```

**Fix:**
```swift
await backgroundContext.perform { /* mutations */ }
await MainActor.run {
    NotificationCenter.default.post(name: .personDidChange, object: nil)
}
```

---

### 7. Weak Self Consistency Audit
**Priority:** LOW
**Effort:** 30 minutes
**Impact:** Memory best practices

**Audit all closures for:**
- Task {} blocks
- backgroundContext.perform blocks
- NotificationCenter observers

**Add `[weak self]` where appropriate**

---

### 8. Force Unwraps in Tests Cleanup
**Priority:** LOW
**Effort:** 10 minutes
**Impact:** Test robustness

**Location:** `PersonEntityMappingTests.swift`

```swift
// BEFORE
XCTAssertTrue(domain.tagIds.contains(UUID(uuidString: uuid.uuidString)!))

// AFTER
if let parsedUUID = UUID(uuidString: uuid.uuidString) {
    XCTAssertTrue(domain.tagIds.contains(parsedUUID))
} else {
    XCTFail("Failed to parse UUID: \(uuid.uuidString)")
}
```

---

### 9. Contacts Permission State Distinction
**Priority:** LOW
**Effort:** 5 minutes
**Impact:** Better UX

**Current:** Conflates `.denied`, `.restricted`, `.notDetermined`

```swift
let status = CNContactStore.authorizationStatus(for: .contacts)
contactAccessDenied = (status == .denied || status == .restricted)
```

**Fix:**
```swift
enum ContactPermissionState {
    case authorized
    case denied
    case restricted
    case notDetermined
}

var contactPermissionState: ContactPermissionState {
    switch CNContactStore.authorizationStatus(for: .contacts) {
    case .authorized: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    case .notDetermined: return .notDetermined
    @unknown default: return .notDetermined
    }
}
```

---

### 10. DateComponents Builder Helper
**Priority:** LOW
**Effort:** 5 minutes
**Impact:** Code cleanliness

**Current:** Verbose date component construction
```swift
var components = calendar.dateComponents([.year, .month, .day], from: Date())
components.hour = time.hour
components.minute = time.minute
```

**Fix:** Extension method
```swift
extension DateComponents {
    static func from(date: Date, time: LocalTime, calendar: Calendar = .current) -> DateComponents {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        return components
    }
}

// Usage
let components = DateComponents.from(date: Date(), time: time)
```

---

## Monitoring & Observability

### Production Logging Checklist
Once in TestFlight, monitor Console.app for:

1. **Core Data Errors**
   - Filter: `subsystem:com.stayintouch.app category:CoreData`
   - Watch for: Migration failures, seeding errors

2. **Notification Failures**
   - Filter: `subsystem:com.stayintouch.app category:Notifications`
   - Watch for: Scheduling errors, permission issues

3. **Contacts Sync Errors**
   - Filter: `subsystem:com.stayintouch.app category:Contacts`
   - Watch for: Permission denied, fetch failures

4. **ViewModel Errors**
   - Filter: `subsystem:com.stayintouch.app category:ViewModel`
   - Watch for: Save failures, delete errors

---

## Known Edge Cases to Test Manually

### High Priority Manual Tests
1. **Contact Deleted from Phone App**
   - Add person from contacts
   - Delete contact in Phone app
   - Open person detail in Stay in Touch
   - Expected: Graceful handling (no crash, shows cached data)

2. **Group Deletion with Contacts**
   - Create group with 5 people
   - Delete group
   - Expected: People reassigned to default group

3. **Last Touch Event Deletion**
   - Person with 1 touch event
   - Delete that touch event
   - Expected: `lastTouchAt` becomes nil, status updates to "Unknown"

4. **Timezone Change During Active Session**
   - Schedule notifications
   - Change device timezone
   - Expected: Notification times adjust correctly

5. **DST Transition**
   - Test notifications scheduled around DST boundary
   - Expected: Correct time after DST change

6. **Notification Permission Denial**
   - Deny notifications during onboarding
   - Enable in Settings → Notifications later
   - Expected: App detects permission change, reschedules

---

## Device Testing Feedback (February 2026)

User tested V1.0 build on device and provided feedback. All items filed as GitHub issues.

### Quick Wins (V1.1 Milestone)
- [Issue #1](https://github.com/slavins-co/stay-in-touch-ios/issues/1): Update onboarding copy → "stay in touch with"
- [Issue #2](https://github.com/slavins-co/stay-in-touch-ios/issues/2): Remove time display from touch history
- [Issue #3](https://github.com/slavins-co/stay-in-touch-ios/issues/3): Add system theme option (auto dark mode)
- [Issue #4](https://github.com/slavins-co/stay-in-touch-ios/issues/4): Animated group expand/collapse
- [Issue #5](https://github.com/slavins-co/stay-in-touch-ios/issues/5): Move debug features to Advanced Settings
- [Issue #6](https://github.com/slavins-co/stay-in-touch-ios/issues/6): Contact search and alphabet section index

### Enhancements (V1.2 Milestone)
- [Issue #7](https://github.com/slavins-co/stay-in-touch-ios/issues/7): Add next touch notes field
- [Issue #8](https://github.com/slavins-co/stay-in-touch-ios/issues/8): Group assignment in settings import flow
- [Issue #9](https://github.com/slavins-co/stay-in-touch-ios/issues/9): Custom due date per contact

### Major Features (V2.0 Milestone)
- [Issue #10](https://github.com/slavins-co/stay-in-touch-ios/issues/10): Self-guided tutorial system

**Status:** All issues created and tracked in GitHub
**Next Steps:** Implement V1.1 Quick Wins (~6 hours total effort)
**Documentation:** See [FEEDBACK-TRACKING.md](FEEDBACK-TRACKING.md) for full workflow

---

## V1.1 Feature Ideas (Based on Audit Insights)

### Potential Enhancements
1. **Notification Delivery Report**
   - Show which notifications were delivered vs dismissed
   - Track engagement metrics

2. **Batch Import from CSV**
   - Import contacts from other CRMs
   - Useful for power users

3. **Export Enhancement**
   - Include touch events in export
   - Support multiple formats (JSON, CSV)

4. **Advanced Search**
   - Search by last touch date range
   - Search by SLA status
   - Search by group + tag combination

5. **Statistics Dashboard**
   - Total touches this month
   - Streak tracking
   - Contact frequency heatmap

---

## Decision Log

### Why These Were Deferred

**CNContactStore Singleton:** Minor optimization, no user impact
**Notification Retry:** System already handles most transient failures
**UI Tests:** Manual testing sufficient for V1, automate in V1.1
**Search Index:** Only impacts users with 100+ contacts (rare in V1)
**Demo Data Race:** Extremely rare edge case, never seen in testing

### When to Revisit

- **After 100 TestFlight users:** If no issues reported, defer to V1.2
- **If memory issues reported:** Prioritize CNContactStore singleton
- **If notification issues reported:** Add retry logic and tests
- **If search feels slow:** Add displayName index
- **Before V2 CloudKit sync:** Add comprehensive test suite

---

**Last Updated:** February 3, 2026
**Owner:** Development Team
**Review Cycle:** After TestFlight feedback (2 weeks)
