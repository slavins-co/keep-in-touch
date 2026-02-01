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

---

## Historical Lessons

*This section will be populated as development progresses*

---

**Maintenance Notes:**
- Review this file at the start of each development session
- Add new lessons immediately after corrections from user
- Archive old lessons quarterly if no longer relevant
- Keep active lessons at top for quick reference
