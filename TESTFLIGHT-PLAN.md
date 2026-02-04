Testflight Plan

## Action Items Required ⚠️

Before TestFlight submission:
1. Adjust iOS deployment target from 18.5 to 17.0
2. Set up App Store Connect app record
3. Configure distribution provisioning profile
4. Add app icon (1024x1024 PNG)
5. Prepare app screenshots (using demo mode)
6. Create privacy policy URL
7. Archive and upload to App Store Connect

---

## Phase 1: Apple Developer Account Setup

### 1.1 Verify Apple Developer Program Enrollment

**Status Check:**
- Team ID `AFG8NJ774P` is already configured in Xcode
- Verify enrollment at: https://developer.apple.com/account

**Required:**
- Active Apple Developer Program membership ($99/year)
- Account owner or admin role for app submission

**Action:**
```
1. Log in to https://developer.apple.com/account
2. Verify "Membership" status shows "Active"
3. Confirm you have "Account Holder" or "Admin" role
4. Note: Team ID AFG8NJ774P should appear in your account
```

---

### 1.2 Create App Identifier (Bundle ID)

**Location:** Apple Developer Portal → Certificates, Identifiers & Profiles → Identifiers

**App ID to Register:**
- **Bundle ID:** `slavins.co.StayInTouch` (already used in Xcode)
- **Description:** Stay in Touch - Personal CRM
- **Platform:** iOS

**Required Capabilities:**
- ✅ Associated Domains (optional for future deep linking)
- ✅ Push Notifications (optional for future remote notifications)
- ✅ Background Modes → Background fetch (already configured in app)

**Steps:**
```
1. Go to https://developer.apple.com/account/resources/identifiers/list
2. Click "+" to create new App ID
3. Select "App IDs" → "App"
4. Description: "Stay in Touch"
5. Bundle ID: Explicit → "slavins.co.StayInTouch"
6. Capabilities: Enable "Background Modes"
7. Click "Continue" → "Register"
```

---

### 1.3 Create Distribution Certificate

**Purpose:** Sign the app archive for TestFlight/App Store distribution

**Location:** Apple Developer Portal → Certificates, Identifiers & Profiles → Certificates

**Certificate Type:** Apple Distribution (formerly iOS Distribution)

**Steps:**

**Option A: Xcode Automatic (Recommended)**
```
1. Open Xcode → Preferences → Accounts
2. Select your Apple ID
3. Click "Manage Certificates..."
4. Click "+" → "Apple Distribution"
5. Xcode will automatically request and install certificate
```

**Option B: Manual (Advanced Users)**
```
1. Open Keychain Access on Mac
2. Keychain Access → Certificate Assistant → Request Certificate from CA
3. Enter email, name, save to disk
4. Go to developer.apple.com → Certificates → "+"
5. Select "Apple Distribution" → Continue
6. Upload CSR file
7. Download certificate, double-click to install in Keychain
```

**Verification:**
- Open Keychain Access → "My Certificates"
- Should see "Apple Distribution: [Your Name] (AFG8NJ774P)"
- Ensure private key is present (expand certificate arrow)

---

### 1.4 Create Provisioning Profile

**Profile Type:** App Store (Distribution)

**Location:** Apple Developer Portal → Certificates, Identifiers & Profiles → Profiles

**Steps:**
```
1. Go to https://developer.apple.com/account/resources/profiles/list
2. Click "+" to create new profile
3. Select "App Store" under Distribution
4. Select App ID: "slavins.co.StayInTouch"
5. Select Distribution Certificate (created in 1.3)
6. Profile Name: "Stay in Touch App Store"
7. Click "Generate"
8. Download profile (e.g., "Stay_in_Touch_App_Store.mobileprovision")
9. Double-click to install in Xcode
Verification:
bash# In Terminal, list installed profiles:
ls ~/Library/MobileDevice/Provisioning\ Profiles/

# Should see a .mobileprovision file with recent date
```

---

## Phase 2: Xcode Project Configuration

### 2.1 Adjust Deployment Target

**Current:** iOS 18.5 (too restrictive)
**Target:** iOS 17.0 (per PRD specification)

**File to modify:** `StayInTouch.xcodeproj/project.pbxproj`

**Steps in Xcode:**
```
1. Open StayInTouch.xcodeproj in Xcode
2. Select project in navigator (blue icon)
3. Select "StayInTouch" target
4. General tab → Deployment Info
5. Change "iOS Deployment Target" from 18.5 to 17.0
6. Repeat for StayInTouchTests and StayInTouchUITests targets
7. Build project to verify no errors (Cmd+B)
Verification:
bash# Search project file for deployment target
grep -r "IPHONEOS_DEPLOYMENT_TARGET" StayInTouch.xcodeproj/project.pbxproj

# Should show: IPHONEOS_DEPLOYMENT_TARGET = 17.0;
```

---

### 2.2 Configure Code Signing for Distribution

**Current:** Automatic signing (development)
**Needed:** Manual signing (distribution) OR keep automatic with distribution profile

**Recommended Approach:** Keep automatic, Xcode will use App Store profile when archiving

**Steps in Xcode:**
```
1. Select StayInTouch target
2. Signing & Capabilities tab
3. Verify "Automatically manage signing" is CHECKED
4. Verify "Team" is set to your Apple Developer account (AFG8NJ774P)
5. For "Release" configuration:
   - Xcode will automatically select App Store provisioning profile
   - No manual changes needed
```

**Alternative (Manual Signing):**
```
1. UNCHECK "Automatically manage signing"
2. Set "Provisioning Profile" to "Stay in Touch App Store" (downloaded in 1.4)
3. Ensure certificate appears as "Apple Distribution: ..."
```

---

### 2.3 Set Version and Build Number

**Current:**
- Version: 1.0
- Build: 1

**Recommendation:** Keep as-is for first TestFlight release

**Future Increments:**
- Version: User-facing (1.0, 1.1, 2.0, etc.)
- Build: Must increment for each upload (1, 2, 3, ...)

**Steps in Xcode:**
```
1. Select StayInTouch target
2. General tab → Identity
3. Version: 1.0
4. Build: 1
Alternative (via command line):
bashcd StayInTouch
agvtool new-version -all 2  # Increment build to 2 for next upload
agvtool new-marketing-version 1.0.1  # Change version to 1.0.1
```

---

### 2.4 Add App Icon

**Required:** 1024x1024 PNG (no transparency, no alpha channel)

**Location:** `StayInTouch/StayInTouch/Assets.xcassets/AppIcon.appiconset`

**Steps:**
```
1. Open Assets.xcassets in Xcode
2. Select "AppIcon"
3. Drag 1024x1024 PNG image into "App Store iOS 1024pt" slot
4. Xcode will automatically generate all required sizes
```

**If you don't have an icon yet:**
```
Option 1: Use SF Symbols placeholder
  - Create temporary icon with SF Symbol "person.2.fill"
  - Use design tool (Sketch, Figma, Canva) to export 1024x1024

Option 2: Hire designer
  - Fiverr, 99designs, Upwork (~$50-200)

Option 3: AI-generated
  - DALL-E, Midjourney with prompt: "minimalist app icon for personal CRM,
    people staying connected, clean iOS design, gradient background"
```

**Icon Guidelines:**
- No transparency
- No rounded corners (iOS adds automatically)
- High contrast for visibility
- Avoid text (hard to read at small sizes)
- Test in dark mode

---

### 2.5 Configure App Capabilities (Already Done ✅)

**Current capabilities in Xcode:**
- ✅ Background Modes → Background fetch
- ✅ Push Notifications (entitlement ready)

**Verify in Xcode:**
```
1. Select StayInTouch target
2. Signing & Capabilities tab
3. Ensure "Background Modes" capability shows:
   - Background fetch (checked)
```

**No additional configuration needed** - already matches App ID capabilities.

---

## Phase 3: App Store Connect Setup

### 3.1 Create App Record

**Location:** https://appstoreconnect.apple.com

**Prerequisites:**
- Apple Developer account with admin/account holder role
- Bundle ID registered (from Phase 1.2)

**Steps:**
```
1. Log in to https://appstoreconnect.apple.com
2. Click "My Apps" → "+" → "New App"
3. Platform: iOS
4. Name: "Stay in Touch"
5. Primary Language: English (U.S.)
6. Bundle ID: Select "slavins.co.StayInTouch" from dropdown
7. SKU: "stayintouch-ios-v1" (unique identifier for your records)
8. User Access: Full Access
9. Click "Create"
```

**Result:** App record created, now in "Prepare for Submission" state

---

### 3.2 Fill Out App Information

**Required Fields:**

**Category:**
- Primary: Productivity
- Secondary: Social Networking (optional)

**Content Rights:**
- Select "No, it does not contain third-party content"

**Age Rating:**
```
1. Click "Edit" next to Age Rating
2. Answer questionnaire:
   - Unrestricted Web Access: No
   - Gambling: No
   - Contests: No
   - Made for Kids: No
   - Mature/Suggestive Themes: None
   - Violence: None
   - Horror/Fear Themes: None
   Result: Rated 4+ (Everyone)

3.3 Prepare App Privacy Details
Privacy Policy URL:

Required for App Store submission
Can use simple hosted page (GitHub Pages, Notion, etc.)

Sample Privacy Policy Template:
markdown# Privacy Policy for Stay in Touch

Last updated: February 3, 2026

## Data Collection
Stay in Touch does not collect, transmit, or share any personal data. All
information stays on your device.

## Contacts Access
The app requests access to your Contacts to help you select people to track.
Contact information is:
- Stored locally on your device only
- Never transmitted to external servers
- Never shared with third parties

## Notifications
Local notifications are generated on your device and are not sent through
external servers.

## Data Storage
All data is stored using iOS Core Data on your device. No cloud sync in version 1.0.

## Contact
For questions: your-email@example.com
```

**Hosting Options:**
- GitHub Gist (free, simple)
- Notion public page (free)
- Your personal website
- GitHub Pages

**Steps:**
```
1. Create privacy policy document
2. Host at public URL (e.g., https://yourdomain.com/privacy)
3. Add URL to App Store Connect:
   - App Information → Privacy Policy URL
   - Paste URL → Save
```

---

### 3.4 Configure Data Use in App Privacy

**Location:** App Store Connect → App Privacy

**Required Disclosures:**

**Data Types Used:**
1. **Contact Info**
   - Data Type: Name, Email Address (optional), Phone Number (optional)
   - Linked to User: No
   - Used for Tracking: No
   - Purpose: App Functionality (managing contacts)
   - Data stored on device only, not collected by developer

**Steps:**
```
1. App Store Connect → Your App → App Privacy
2. Click "Get Started"
3. "Do you collect data from this app?" → YES
4. Click "Contact Info" → Select:
   - Name
   - Email Address (if app accesses from Contacts)
   - Phone Number (if app accesses from Contacts)
5. For each:
   - Linked to user: NO
   - Used for tracking: NO
   - Purpose: App Functionality
   - "Is this data collected from the app?" → NO (only accessed, not collected)
6. Save and publish
```

---

### 3.5 Prepare App Screenshots

**Required Sizes (6.7" iPhone 16 Pro Max):**
- 1290 x 2796 pixels (portrait)
- Minimum 3 screenshots, maximum 10

**Recommended Screenshots (using Demo Mode):**
1. Home screen showing categorized contacts (Overdue/Due Soon/All Good)
2. Person detail screen with touch history
3. Log touch modal with date picker
4. Settings screen with theme toggle
5. Onboarding screen (contacts permission)

**How to capture in Simulator:**
```
1. Run app in Xcode: Product → Run (Cmd+R)
2. Select "iPhone 16 Pro Max" simulator
3. Enable demo mode in app Settings
4. Navigate to each screen
5. Capture: Cmd+S (saves to Desktop)
6. Files will be named "Simulator Screenshot..."
Tools for Adding Text/Highlights:

Figma (free, browser-based)
Sketch (Mac, paid)
Screenshot Wizard (Mac, free)
Canva (free templates for app screenshots)

Optional: Use Fastlane Snapshot (automated):
bash# Future enhancement - automate screenshot capture
fastlane snapshot
```

---

### 3.6 Write App Description

**App Name:** Stay in Touch

**Subtitle (max 30 chars):** Never lose track of friends

**Promotional Text (optional, max 170 chars):**
```
Track your relationships effortlessly. Stay in Touch reminds you when it's
time to reconnect with the people who matter most.
```

**Description (max 4000 chars):**
```
NEVER LOSE TRACK OF FRIENDSHIPS

Stay in Touch is your personal relationship manager that helps you maintain
meaningful connections. Simply categorize your contacts by how often you want
to stay in touch, and let the app handle the rest.

FEATURES

- Contact Organization
  - Create custom groups (weekly, monthly, quarterly friends)
  - Set SLA (Service Level Agreement) for each group
  - Automatic status tracking (In SLA, Due Soon, Overdue)

- Smart Reminders
  - Gentle notifications when it's time to reconnect
  - Customizable reminder times per contact
  - Weekly digest of who needs attention

- Touch Logging
  - Track every interaction (call, text, coffee, etc.)
  - Full history for each contact
  - Edit or delete past touches

- Privacy First
  - All data stored locally on your device
  - No cloud sync, no account required
  - Your relationships, your data

- Clean Interface
  - Dark and light themes
  - Simple, distraction-free design
  - Built with iOS design guidelines

PERFECT FOR

- Busy professionals maintaining client relationships
- Long-distance friendships
- Family connections across time zones
- Anyone wanting to be more intentional with relationships

YOUR DATA, YOUR DEVICE

Stay in Touch uses Apple's Contacts framework to help you select people to
track, but all data stays on your device. No analytics, no tracking, no
external servers.

VERSION 1.0

This is the first release! We're actively developing and would love your
feedback. Future versions will include CloudKit sync, Shortcuts integration,
and more.

SUPPORT

Questions or feedback? Email us at your-email@example.com
```

**Keywords (max 100 chars, comma-separated):**
```
contacts, CRM, relationships, friends, reminders, productivity, personal

Phase 4: Build and Archive
4.1 Clean Build Environment
Purpose: Ensure fresh build without cached data
bash# In Terminal:
cd "/Users/brad/Library/CloudStorage/SynologyDrive-brad-MBA-home/Documents/2 Hobbies & Interests/Tech/Claude-Code/iOS Personal CRM App/StayInTouch"

# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/StayInTouch-*

# Or in Xcode:
# Product → Clean Build Folder (Shift+Cmd+K)

4.2 Run Final Tests
Before archiving, verify all tests pass:
bash# In Terminal:
xcodebuild test \
  -scheme StayInTouch \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  | grep -E "(Test Suite|passed|failed)"

# Expected output: All tests passed (30+ tests)
```

**Or in Xcode:**
```
1. Product → Test (Cmd+U)
2. Wait for all tests to complete
3. Verify: All 30+ tests show green checkmarks
```

---

### 4.3 Create Archive

**Steps in Xcode:**
```
1. Select "Any iOS Device (arm64)" as destination (not simulator)
   - Click device dropdown in toolbar
   - Select "Any iOS Device" at bottom of list

2. Product → Archive (Cmd+Shift+B won't work, must use Archive)
   - This may take 2-5 minutes
   - Xcode will build in Release configuration
   - Will use App Store provisioning profile automatically

3. Verify archive appears in Organizer:
   - Window → Organizer (Cmd+Opt+Shift+O)
   - Select "Archives" tab
   - Should see "StayInTouch" with today's date
```

**Troubleshooting Common Errors:**

**Error: "No valid signing certificate"**
```
Solution:
1. Xcode → Preferences → Accounts
2. Select Apple ID → "Download Manual Profiles"
3. Retry archive
```

**Error: "Provisioning profile doesn't include signing certificate"**
```
Solution:
1. Go to developer.apple.com → Profiles
2. Delete existing "Stay in Touch App Store" profile
3. Recreate with your current distribution certificate
4. Download and double-click to install
5. Retry archive
```

**Error: "Bundle identifier doesn't match"**
```
Solution:
1. Verify target Bundle Identifier matches App ID exactly
2. Should be: slavins.co.StayInTouch
3. Check for typos or extra spaces
```

---

### 4.4 Validate Archive

**Before uploading, validate for common issues:**
```
1. In Organizer, select your archive
2. Click "Validate App" button
3. Select distribution method: "App Store Connect"
4. Select signing: "Automatically manage signing" (recommended)
5. Click "Validate"
6. Wait for validation (1-2 minutes)
7. Should see "Validation Successful" message
```

**Validation checks:**
- Bundle identifier matches App Store Connect
- Provisioning profile is valid
- Entitlements are correct
- No missing or invalid assets
- No disallowed API usage

---

### 4.5 Upload to App Store Connect

**Steps:**
```
1. In Organizer, with archive selected
2. Click "Distribute App" button
3. Select "App Store Connect" → Next
4. Select "Upload" → Next
5. Distribution options:
   - Include bitcode: NO (deprecated in Xcode 14+)
   - Upload symbols: YES (for crash reports)
   - Manage version/build: Automatically manage
6. Re-sign: "Automatically manage signing" → Next
7. Review summary → Upload
8. Wait for upload (3-10 minutes depending on connection)
9. Should see "Upload Successful" message
```

**Progress tracking:**
- Xcode shows progress bar during upload
- You can close Organizer after seeing success
- Build will process on Apple's servers (10-30 minutes)

---

## Phase 5: TestFlight Configuration

### 5.1 Wait for Build Processing

**After upload:**
```
1. Go to App Store Connect → Your App → TestFlight
2. Build will show "Processing" status
3. Wait 10-30 minutes for processing to complete
4. You'll receive email when build is ready: "Your build has finished processing"
```

**During processing, Apple checks:**
- App binary for malware
- Entitlements validity
- Required frameworks presence
- Symbolication files

---

### 5.2 Provide Export Compliance Information

**When build processing completes:**
```
1. App Store Connect → TestFlight → Build 1.0 (1)
2. Click on build number
3. Provide Export Compliance Information:
   - "Does your app use encryption?" → NO
     (Stay in Touch uses only iOS built-in encryption, no custom crypto)
   - Click "Start Internal Testing" (appears after export compliance)
```

**Why "NO":**
- App doesn't implement custom encryption algorithms
- Uses only standard iOS encryption (Core Data, HTTPS would use system)
- No export restrictions apply

---

### 5.3 Add Test Information

**Required for TestFlight:**

**Test Information:**
```
1. Beta App Description:
   "Personal CRM to track relationships and get reminded when to reconnect."

2. Feedback Email:
   your-email@example.com

3. Marketing URL (optional):
   https://yourdomain.com/stayintouch

4. Privacy Policy URL:
   https://yourdomain.com/privacy

5. Test Notes (what testers should focus on):
   "Test core features: adding contacts, logging touches, receiving
   notifications. Demo mode available in Settings for quick testing."
```

**Save changes**

---

### 5.4 Internal Testing (You + Team)

**Internal testers:**
- Automatically includes all App Store Connect users with Admin/App Manager role
- Up to 100 internal testers
- No App Review required
- Instant access after build processing

**Steps:**
```
1. App Store Connect → TestFlight → Internal Testing
2. Build should be automatically selected
3. "Internal Testers" section shows your Apple ID
4. You'll receive email: "Stay in Touch is ready to test"
5. Download TestFlight app on iPhone:
   - App Store → Search "TestFlight" → Install
6. Open TestFlight email → "View in TestFlight"
7. Install app from TestFlight
8. Test app on your device!
```

---

### 5.5 External Testing (Friends/Beta Testers)

**External testers:**
- Up to 10,000 external testers
- Requires App Review (first time only, ~24-48 hours)
- Testers use invite link or code

**Steps:**

**A. Add External Testers:**
```
1. App Store Connect → TestFlight → External Testing
2. Click "+" to create new group
3. Group Name: "Beta Testers"
4. Select Build: 1.0 (1)
5. Add testers:
   - Click "Add Testers"
   - Enter email addresses (one per line)
   - OR generate public link (anyone with link can join)
6. Click "Add"
```

**B. Submit for Review (first external build only):**
```
1. Click "Submit for Review"
2. Provide test credentials if app requires login (N/A for Stay in Touch)
3. Agree to terms
4. Submit
5. Wait 24-48 hours for Apple review
```

**C. Share with Testers:**

**Option 1: Email Invites**
- Testers receive email: "You've been invited to test Stay in Touch"
- They click link → Install TestFlight → Install app

**Option 2: Public Link**
```
1. TestFlight → External Testing → "Beta Testers" group
2. Click "Public Link" tab
3. Copy link: https://testflight.apple.com/join/XXXXXXXX
4. Share link via email, Slack, message, etc.
5. Anyone with link can join (up to 10,000 testers)
```

**Testers will need:**
- iPhone/iPad running iOS 17.0 or later
- TestFlight app installed from App Store
- Invite email or public link

---

## Phase 6: Post-Upload Tasks

### 6.1 Monitor Crash Reports

**Location:** App Store Connect → Your App → TestFlight → Crashes

**Setup:**
```
1. Ensure "Upload symbols" was enabled during upload (yes in 4.5)
2. Crashes will appear within 24 hours of occurrence
3. Review crash logs for patterns
```

**What to monitor:**
- Number of crashes per build
- Most common crash locations
- Specific devices/iOS versions affected

---

### 6.2 Collect Tester Feedback

**TestFlight Feedback:**
- Testers can send feedback directly from TestFlight app
- Includes screenshots, device info, crash logs
- View at: App Store Connect → TestFlight → Feedback

**Request from testers:**
```
Email template:
"Thanks for testing Stay in Touch!

Please focus on:
1. Onboarding flow (contacts permission, group setup)
2. Adding and tracking contacts
3. Logging touches (past and present)
4. Notification delivery (set a 1-minute SLA group for testing)
5. Demo mode (Settings → Enable Demo Mode)

Send feedback directly through TestFlight or email me at: your-email@example.com"
```

---

### 6.3 Iterate and Upload New Builds

**For each bug fix or feature update:**
```
1. Make code changes in Xcode
2. Increment build number:
   - Target → General → Build: 2 (was 1)
   - OR: agvtool new-version -all 2

3. Run tests: Product → Test (Cmd+U)
4. Create archive: Product → Archive
5. Validate → Distribute → Upload
6. Wait for processing (10-30 min)
7. Add "What to Test" notes in App Store Connect:
   - TestFlight → Build 1.0 (2) → What to Test
   - Describe what changed

8. Testers receive notification: "Stay in Touch (1.0) Build 2 is ready to test"
```

**Build version strategy:**
- Keep version 1.0 during TestFlight beta
- Increment build: 1 → 2 → 3 → ...
- When ready for App Store: Version 1.0, Build 10 (for example)

---

## Phase 7: Prepare for App Store Submission

### 7.1 App Review Preparation

**Required assets (prepare during TestFlight):**

1. **App Preview Video (optional but recommended)**
   - 15-30 seconds showing app in action
   - Recorded in Simulator or on device
   - Size: 6.7" display (iPhone 16 Pro Max)

2. **App Store Screenshots** (from Phase 3.5)
   - Already prepared during TestFlight setup
   - Update if UI changed based on feedback

3. **Support URL**
   - Website or GitHub Issues page for user support
   - Required for App Store submission

4. **Marketing URL (optional)**
   - Landing page for app
   - Can be same as support URL

---

### 7.2 App Review Guidelines Checklist

**Ensure compliance before submission:**

- [ ] App functions as described without crashes
- [ ] All features work as advertised
- [ ] No placeholder content or "Lorem ipsum"
- [ ] Privacy policy accessible and accurate
- [ ] Contact information valid
- [ ] App doesn't request permissions unnecessarily
- [ ] No hidden features or Easter eggs
- [ ] Complies with App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

**Specific to Stay in Touch:**
- [ ] Contacts permission clearly explained in UI (already done)
- [ ] Notifications permission clearly explained (already done)
- [ ] App doesn't mislead about functionality
- [ ] No reference to non-iOS platforms in first version

---

### 7.3 Submit for App Store Review

**When ready (after TestFlight feedback incorporated):**
```
1. App Store Connect → Your App → App Store tab
2. Click "+" to create new version
3. Version: 1.0
4. Select build from dropdown (choose latest TestFlight build)
5. Fill in all required fields (already done in Phase 3)
6. Screenshot sets: Drag screenshots from Phase 3.5
7. Version Information:
   - What's New in This Version: "Initial release"
8. App Review Information:
   - Contact: Your name, phone, email
   - Notes: "Demo mode available in Settings for quick testing. All features work offline."
9. Save
10. Click "Submit for Review"
Review time: Typically 24-48 hours
Possible outcomes:

Accepted → App goes live on App Store
Rejected → Fix issues, resubmit
Metadata Rejected → Fix description/screenshots, resubmit (no new build needed)


Quick Reference: Command Cheat Sheet
Build & Test
bash# Clean build
xcodebuild clean -project StayInTouch.xcodeproj -scheme StayInTouch

# Run tests
xcodebuild test -scheme StayInTouch -destination 'platform=iOS Simulator,name=iPhone 16'

# Increment build number
agvtool new-version -all 2

# Check current version/build
agvtool what-version
agvtool what-marketing-version
```

### Archive & Upload (GUI Required)
- Archive: Xcode → Product → Archive
- Upload: Organizer → Distribute App → Upload

---

## Troubleshooting Common Issues

### "No accounts with App Store Connect access"
```
Solution:
1. Xcode → Preferences → Accounts
2. Add Apple ID if missing
3. Team must have Admin/App Manager/Developer role
4. Contact account holder to grant access
```

### "Failed to create provisioning profile"
```
Solution:
1. Delete existing profiles: developer.apple.com → Profiles
2. Xcode → Preferences → Accounts → Download Manual Profiles
3. Retry archive
```

### "Build processing failed" email
```
Solution:
1. Check email for specific error (e.g., "Missing required icon sizes")
2. Fix issue in Xcode
3. Increment build number
4. Re-archive and upload
```

### "Testflight build not appearing"
```
Wait time:
- Processing: 10-30 minutes
- If >1 hour, check App Store Connect activity log
- Possible issues: Missing entitlements, invalid binary
```

### Testers can't install
```
Common causes:
1. iOS version too old (need 17.0+)
2. TestFlight app not installed
3. Invite email in spam
4. Wrong Apple ID (must use email invited)

Timeline Estimate
PhaseTaskEstimated Time1Apple Developer account setup30 min - 1 hour2Xcode project configuration30 min3App Store Connect setup1-2 hours4Build and archive15-30 min5Upload & processing15-45 minTotal First Time3-5 hoursSubsequent BuildsArchive → Upload → Processing30-60 min

Verification Checklist
Before calling this plan complete, verify:
Pre-Archive

 Deployment target set to iOS 17.0 (all targets)
 Bundle identifier matches App ID: slavins.co.StayInTouch
 Version 1.0, Build 1
 App icon 1024x1024 added to Assets
 All tests passing (30+ tests)
 Build succeeds in Release configuration

App Store Connect

 App record created
 Privacy policy URL added
 App description written
 Screenshots prepared (minimum 3)
 Keywords added
 Age rating completed (4+)
 App Privacy configured (Contact Info disclosed)

TestFlight

 Build uploaded successfully
 Build processing completed (email received)
 Export compliance provided (No encryption)
 Test information filled out
 Internal testing working (app installs via TestFlight)
 External testing group created (if sharing with friends)

App Functionality

 Onboarding flow works
 Can add contacts from Contacts app
 Can log touches
 Notifications appear (test with 1-min SLA group)
 Demo mode works for screenshots/testing
 Dark/light themes work
 No crashes during basic use


Post-Deployment Monitoring
Week 1 After TestFlight Release

Check crash reports daily
Respond to tester feedback within 24 hours
Monitor TestFlight installs/sessions
Track completion rate of onboarding

Metrics to Track

Installs: Number of TestFlight downloads
Crashes: Crash-free rate (target: >99%)
Feedback: Number and themes of feedback items
Retention: How many testers open app multiple times


Next Steps After This Plan

Execute Phase 1: Apple Developer account setup (30-60 min)
Execute Phase 2: Xcode configuration (30 min)
Execute Phase 3: App Store Connect setup (1-2 hours)
Execute Phase 4-5: Build, upload, TestFlight (1-2 hours)
Test internally: Verify app works on your iPhone via TestFlight
Invite external testers: Share public link with friends
Iterate based on feedback: Fix bugs, add minor improvements
Submit to App Store: When ready for public release


Resources
Official Apple Documentation:

TestFlight Overview: https://developer.apple.com/testflight/
App Store Connect Help: https://help.apple.com/app-store-connect/
Code Signing Guide: https://developer.apple.com/support/code-signing/
App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

Tools:

Xcode: https://developer.apple.com/xcode/
TestFlight App: https://apps.apple.com/app/testflight/id899247664
App Store Connect: https://appstoreconnect.apple.com

Community:

Apple Developer Forums: https://developer.apple.com/forums/
Stack Overflow: https://stackoverflow.com/questions/tagged/testflight


Plan Created: February 3, 2026
App Version: 1.0 (Build 1)
Estimated Total Time: 3-5 hours (first time), 30-60 min (subsequent builds)
Prerequisites Met: ✅ Code ready, tests passing, audit complete