# TestFlight Submission Guide — StayInTouch

**Version:** v0.2.0 (Build 5)
**Last Updated:** 2026-02-23
**Status:** Code blockers resolved. Ready for manual submission steps.

---

## What Was Already Done (Automated)

The following blockers were identified in the TestFlight Readiness Audit and fixed programmatically:

- [x] **PrivacyInfo.xcprivacy** created at `StayInTouch/StayInTouch/PrivacyInfo.xcprivacy` — declares no tracking, no collected data, no required reason APIs (#46)
- [x] **Deployment target** changed from iOS 18.5 → 17.0 (4 occurrences in project.pbxproj) (#47)
- [x] **UIBackgroundModes** added to Info.plist with `fetch` value (#48)
- [x] **Build number** bumped from 4 to 5 (6 occurrences in project.pbxproj)
- [x] **Clean build** verified — zero errors
- [x] **All tests passing** — 33+ tests across 11 suites

---

## Remaining Manual Steps

Complete these steps in order. Each section notes what tool to use and estimated time.

### Step 1: Clean Git State (5 min)

Synology Drive has introduced file permission artifacts. Clean before committing.

```bash
# From project root:
cd "iOS Personal CRM App"

# Check current state
git status --short | head -20

# Reset permission-only changes (0 insertions, 0 deletions)
git checkout -- "Figma Mockup_Bradleys-MacBook-Air.local_Feb-03-175314-2026_Conflict/"
git checkout -- .github/
git checkout -- .gitignore
git checkout -- FEEDBACK-TRACKING.md

# Stage the intentional changes (blocker fixes + doc archival)
git add StayInTouch/StayInTouch/PrivacyInfo.xcprivacy
git add StayInTouch/StayInTouch/Info.plist
git add StayInTouch/StayInTouch.xcodeproj/project.pbxproj

# If you want to track the doc moves to archive/:
git add archive/
git rm CLAUDE.md CODEX.md FINAL-PRD.md REMAINING-ISSUES.md TESTFLIGHT-PLAN.md AUDIT-FIXES-SUMMARY.md SUMMARY.md

# Commit
git commit -m "Fix TestFlight blockers: privacy manifest, deployment target, background modes

- Add PrivacyInfo.xcprivacy (Apple requirement since Spring 2024)
- Change deployment target from iOS 18.5 to 17.0
- Add UIBackgroundModes with fetch to Info.plist
- Bump build number to 5
- Archive stale documentation files

Closes #46, closes #47, closes #48"

# Push
git push origin main
```

### Step 2: Verify Apple Developer Account (5 min)

**Tool:** Browser → https://developer.apple.com/account

1. Log in and verify "Membership" status shows **Active**
2. Confirm Team ID **AFG8NJ774P** appears
3. Verify you have **Account Holder** or **Admin** role

### Step 3: Register App ID (10 min)

**Tool:** Browser → https://developer.apple.com/account/resources/identifiers/list

> Skip this step if `slavins.co.StayInTouch` already appears in your identifiers list.

1. Click "+" → App IDs → App
2. Description: `Stay in Touch`
3. Bundle ID: Explicit → `slavins.co.StayInTouch`
4. Enable capability: **Background Modes**
5. Register

### Step 4: Create App Store Connect Record (15 min)

**Tool:** Browser → https://appstoreconnect.apple.com

1. My Apps → "+" → New App
2. Platform: **iOS**
3. Name: **Stay in Touch**
4. Primary Language: **English (U.S.)**
5. Bundle ID: `slavins.co.StayInTouch`
6. SKU: `stayintouch-ios` (or any unique string)
7. Full Access: Your access level

### Step 5: Configure Privacy in App Store Connect (10 min)

**Tool:** App Store Connect → Your App → App Privacy

Since the app collects no data and makes no network requests:

1. Click "Get Started" on App Privacy
2. For "Do you or your third-party partners collect data from this app?", select **No**
3. For tracking: Select **No, we do not use data for tracking**
4. Save

### Step 6: Create Privacy Policy (20 min)

**Tool:** GitHub Pages, Notion, or personal website

> Required for App Store review since the app accesses contacts. Not required for TestFlight, but best to create now.

Create a page with this content (customize as needed):

```
Privacy Policy for Stay in Touch

Last updated: [Date]

Stay in Touch is a privacy-first personal CRM app. Your data stays on your device.

Data Collection
- We do NOT collect any personal data
- We do NOT transmit any data off your device
- We do NOT use analytics, tracking, or advertising frameworks
- The app has zero network requests

Contacts Access
- The app accesses your device contacts solely to display names for relationship tracking
- Contact data is read on-demand and never stored separately
- Only names and identifiers are used — no phone numbers or emails are stored in app data

Local Storage
- All app data is stored locally using Apple's Core Data framework
- Data is encrypted at rest by iOS
- No cloud sync in the current version

Notifications
- The app uses local notifications only
- No push notification servers are involved
- Notification content is generated entirely on-device

Contact
[Your contact email]
```

After hosting, note the URL for Step 8.

### Step 7: Archive and Upload (15-30 min)

**Tool:** Xcode

1. Open `StayInTouch.xcodeproj` in Xcode
2. Select **Any iOS Device (arm64)** as the build destination (not a simulator)
3. Menu: **Product → Archive**
4. Wait for archive to complete
5. In the Organizer window, select the archive
6. Click **Validate App** — fix any issues reported
7. Click **Distribute App** → **App Store Connect** → **Upload**
8. Wait for upload to complete

### Step 8: Configure TestFlight (10 min)

**Tool:** App Store Connect → TestFlight

After upload completes and processing finishes (5-30 min):

1. Navigate to your app → TestFlight tab
2. The build should appear under "iOS Builds"
3. If there's a "Missing Compliance" warning:
   - The app uses no encryption beyond Apple's built-in HTTPS (and doesn't even use networking)
   - Select: "No, this app does not use encryption" (or the equivalent option for apps that only use Apple's standard encryption)
4. Add privacy policy URL (from Step 6) if prompted
5. Add test information:
   - Beta App Description: "Personal CRM to maintain friendships through gentle reminders"
   - Contact info for testers

### Step 9: Add Testers (5 min)

**Tool:** App Store Connect → TestFlight → Internal Testing

For internal testing (up to 100 Apple Developer team members):

1. Click "+" next to "Internal Testing"
2. Create a group (e.g., "Beta Testers")
3. Add testers by Apple ID email
4. Testers will receive an email invite to install via TestFlight

For external testing (up to 10,000 people):
- Requires Apple's Beta App Review (usually 24-48 hours)
- Create an "External Testing" group
- Submit for review

### Step 10: Device Verification (15 min)

**Tool:** Physical iPhone with TestFlight installed

After receiving the TestFlight invite:

1. Install the app via TestFlight
2. Verify the full onboarding flow:
   - Welcome screen
   - Contacts permission request (grant access)
   - Contact selection
   - Group assignment
   - Notification permission request
3. Verify home screen shows imported contacts with SLA status
4. Log a connection on a contact
5. Verify the connection appears in history
6. Check Settings → app version shows `0.2.0 (5)`
7. Background the app, wait 10 min, verify notification scheduling works
8. Toggle demo mode on/off in Settings → Advanced

---

## Before App Store Submission (Not Needed for TestFlight)

These items are required for the full App Store review but can be deferred past TestFlight:

| Item | Status | Effort |
|---|---|---|
| Privacy policy URL | Needed | 20 min (see Step 6) |
| App Store screenshots | Not created | 30 min (use demo mode) |
| App Store description | Not written | 15 min |
| Support URL | Not configured | 5 min |
| Accessibility labels (#39) | Open issue | 1-2 hours |
| VoiceOver audit | Not done | 1 hour |

### Screenshot Specifications

Required device sizes for App Store:
- **6.9" display** (iPhone 16 Pro Max): 1320 × 2868 pixels
- **6.7" display** (iPhone 15 Plus): 1290 × 2796 pixels
- **6.5" display** (iPhone 11 Pro Max): 1242 × 2688 pixels

Use demo mode to populate sample data, then capture:
1. Home screen with contacts in different SLA states
2. Person detail view with connection history
3. Log Connection modal
4. Settings screen
5. Onboarding flow (optional)

---

## Troubleshooting

### Archive fails with signing error
- Xcode → Preferences → Accounts → verify Apple ID is logged in
- Signing & Capabilities → verify "Automatically manage signing" is checked
- Team should be set to AFG8NJ774P

### Upload fails with "Invalid Binary"
- Check that deployment target is 17.0 (not 18.5)
- Verify no simulator-only frameworks are linked
- Run `Validate App` before `Distribute App`

### TestFlight build stuck in "Processing"
- Normal — takes 5-30 minutes
- If stuck >1 hour, check App Store Connect for error messages

### "Missing Compliance" warning
- The app uses no encryption (no networking at all)
- Answer "No" to the export compliance question

### Background notifications not firing
- Verify UIBackgroundModes is in Info.plist (confirmed in this build)
- Background fetch is best-effort — iOS throttles based on app usage patterns
- Test by backgrounding, waiting, and checking notification center
