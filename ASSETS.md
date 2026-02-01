# Asset Reference - Stay in Touch

## Color Palette

### System Colors (Apple Standard)
```swift
// Primary Actions
.blue: Color(hex: "0A84FF")

// Status Colors
.red: Color(hex: "FF3B30")      // Overdue / Destructive
.orange: Color(hex: "FF9500")   // Due Soon / Warning
.green: Color(hex: "34C759")    // All Good / Success

// Text
.primary: .primary              // System adaptive
.secondary: Color(hex: "8E8E93") // Dark mode
.secondary: Color(hex: "6B6B6B") // Light mode
```

### Avatar Color Palette (Random Assignment)
```swift
let avatarColors: [String] = [
    "#FF6B6B", // Coral Red
    "#4ECDC4", // Turquoise
    "#95E1D3", // Mint Green
    "#F38181", // Light Coral
    "#AA96DA", // Lavender
    "#FCBAD3", // Pink
    "#FFD93D", // Yellow
    "#6BCB77", // Green
]

// Usage:
person.avatarColor = avatarColors.randomElement()!
```

### Background Colors

**Dark Mode:**
```swift
.background: Color(hex: "000000")       // Primary BG
.secondaryBG: Color(hex: "1C1C1E")      // Cards, modals
.tertiaryBG: Color(hex: "2C2C2E")       // Input fields
```

**Light Mode:**
```swift
.background: Color(hex: "FFFFFF")       // Primary BG
.secondaryBG: Color(hex: "F2F2F7")      // Cards, modals
.tertiaryBG: Color(hex: "E5E5EA")       // Input fields
```

### Border & Divider Colors

**Dark Mode:**
```swift
.border: Color(hex: "1C1C1E")
.divider: Color(hex: "2C2C2E")
```

**Light Mode:**
```swift
.border: Color(hex: "E5E5EA")
.divider: Color(hex: "E5E5EA")
```

---

## Typography

### Font Sizes (System Dynamic Type)

```swift
.largeTitle: 34pt     // Screen titles
.title: 28pt          // Large headers
.headline: 17pt       // Section headers
.body: 17pt           // Primary content
.callout: 15pt        // Metadata
.footnote: 13pt       // Secondary text, labels
.caption: 11pt        // Tags
```

### Usage Map

| Element | Font Style | Weight | Color |
|---------|-----------|--------|-------|
| Screen title | .largeTitle (34pt) | Regular | Primary |
| Contact name | .headline (17pt) | Semibold | Primary |
| Contact metadata | .callout (15pt) | Regular | Secondary |
| Section headers | .callout (15pt) | Medium | Primary |
| Button text | .headline (17pt) | Medium | Blue |
| Tag labels | .caption (11pt) | Regular | White |
| Field labels | .footnote (13pt) | Regular | Secondary |
| Overdue badge | .callout (15pt) | Medium | Red |

### Font Weights
- **Regular** - Body text, descriptions
- **Medium** - Section headers, buttons
- **Semibold** - Contact names, emphasized text
- **Bold** - Modal action buttons ("Done", "Save")

---

## SF Symbols Reference

### Navigation & Actions

| Symbol | Name | Usage | Size |
|--------|------|-------|------|
| ⚙️ | `gearshape.fill` | Settings button | 24pt |
| 🔍 | `magnifyingglass` | Search icon | 20pt |
| ✕ | `xmark.circle.fill` | Close/dismiss | 22pt |
| ＋ | `plus.circle.fill` | Add new | 24pt |
| ✏️ | `pencil` | Edit | 16pt |
| 🗑️ | `trash.fill` | Delete | 16pt |
| ← | `chevron.left` | Back button | 20pt |
| → | `chevron.right` | Disclosure | 20pt |
| ⌄ | `chevron.down` | Expand | 16pt |
| ⌃ | `chevron.up` | Collapse | 16pt |

### Communication

| Symbol | Name | Usage | Color | Size |
|--------|------|-------|-------|------|
| 💬 | `message.circle.fill` | Text message | Blue | 20pt |
| 📞 | `phone.circle.fill` | Phone call | Green | 20pt |
| ✉️ | `envelope.circle.fill` | Email | Blue | 20pt |

### Status & Info

| Symbol | Name | Usage | Color | Size |
|--------|------|-------|-------|------|
| 📅 | `calendar` | Date/history | Blue | 20pt |
| 🔔 | `bell.fill` | Notifications | Orange | 20pt |
| 🌙 | `moon.fill` | Dark mode | Blue | 20pt |
| ☀️ | `sun.max.fill` | Light mode | Orange | 20pt |
| ⏸️ | `pause.circle.fill` | Pause tracking | Orange | 20pt |
| ▶️ | `play.circle.fill` | Resume tracking | Green | 20pt |

### Data & Management

| Symbol | Name | Usage | Color | Size |
|--------|------|-------|-------|------|
| 👥 | `person.2.fill` | Groups | Blue | 20pt |
| 🏷️ | `tag.fill` | Tags | Blue | 20pt |
| 💾 | `arrow.down.circle.fill` | Export/download | Blue | 20pt |
| 🔄 | `arrow.triangle.2.circlepath` | Sync | Blue | 20pt |
| 🧪 | `flask.fill` | Demo mode | Purple | 20pt |

### Onboarding

| Symbol | Name | Usage | Size |
|--------|------|-------|------|
| 👤 | `person.crop.circle.badge.questionmark` | Contacts permission | 48pt |
| 🔔 | `bell.badge.fill` | Notifications permission | 48pt |
| 👥 | `person.2.circle.fill` | App icon / welcome | 80pt |

---

## Component Sizes

### Interactive Elements

```swift
// Minimum tap targets (Apple HIG)
.minTapTarget: 44pt x 44pt

// Avatars
.avatar_small: 44pt circle
.avatar_large: 72pt circle

// Buttons
.primaryButton: Full width, 44pt height, 12pt corner radius
.iconButton: 44pt circle
.pillButton: Auto width, 32pt height, 16pt corner radius

// Cards
.contactCard: Full width, Auto height, 12pt corner radius, 12pt padding
.sectionCard: Full width, Auto height, 12pt corner radius, 16pt padding

// Modals
.bottomSheet: Full width, 80% max height, 20pt top corner radius
.alert: 270pt width, Auto height, 14pt corner radius

// Status Indicator
.statusDot: 10pt circle
```

### Spacing Scale

```swift
// Padding
.xxs: 4pt
.xs: 8pt
.sm: 12pt
.md: 16pt
.lg: 20pt
.xl: 24pt
.xxl: 32pt

// Gaps
.cardGap: 8pt       // Between cards in list
.sectionGap: 16pt   // Between sections
.contentGap: 12pt   // Between content elements
```

---

## Animations

### Standard Durations
```swift
.instant: 0.1s       // Highlighting, active states
.quick: 0.2s         // Button presses
.standard: 0.3s      // Modals, navigation, section collapse
.slow: 0.5s          // Onboarding transitions
```

### Curves
```swift
.easeInOut: default           // Most animations
.spring: response=0.3, damping=0.7  // Interactive gestures
.linear: loading indicators
```

### Usage Examples
```swift
// Button tap
.scaleEffect(isPressed ? 0.95 : 1.0)
.animation(.quick, value: isPressed)

// Modal presentation
.transition(.move(edge: .bottom).combined(with: .opacity))
.animation(.standard)

// Section collapse
.animation(.standard, value: isCollapsed)
```

---

## Shadow & Elevation

### Card Shadows
```swift
// Light mode
.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)

// Dark mode
.shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
```

### Modal Shadows
```swift
.shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 4)
```

---

## Status Indicators

### SLA Status Colors
```swift
enum SLAStatus {
    case inSLA      // Green: #34C759
    case dueSoon    // Orange: #FF9500
    case outOfSLA   // Red: #FF3B30
    case unknown    // Gray: #8E8E93
}
```

### Status Labels
```swift
// With dots
"🟢 All good"
"🟠 Check in soon"
"🔴 Overdue catch-up"

// Minimal (Person Detail)
"All good"
"Check in soon"
"Overdue catch-up"
```

### Overdue Badge
```swift
Text("+\(daysOverdue)d")
    .font(.callout)
    .fontWeight(.medium)
    .foregroundColor(.red)
```

---

## Tag Styles

### Tag Pills
```swift
HStack(spacing: 6) {
    Text(tag.name)
        .font(.caption)
        .foregroundColor(.white)
}
.padding(.horizontal, 8)
.padding(.vertical, 4)
.background(Color(hex: tag.colorHex))
.cornerRadius(12)
```

### Removable Tags (in management)
```swift
HStack(spacing: 4) {
    Text(tag.name)
    Image(systemName: "xmark")
        .font(.caption2)
}
.padding(.horizontal, 10)
.padding(.vertical, 6)
.background(Color(hex: tag.colorHex))
.cornerRadius(16)
```

---

## Loading States

### Skeleton Cards
```swift
VStack(alignment: .leading, spacing: 8) {
    HStack {
        Circle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 44, height: 44)
        
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 150, height: 17)
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 200, height: 13)
        }
    }
}
.redacted(reason: .placeholder)
.shimmering() // Custom modifier
```

### Spinner
```swift
ProgressView()
    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
    .scaleEffect(1.2)
```

---

## Accessibility

### Dynamic Type Scaling
```swift
// All text must scale
Text("Contact Name")
    .font(.headline) // Uses system dynamic type

// Fixed sizes only for icons
Image(systemName: "star.fill")
    .font(.system(size: 20)) // OK - decorative
```

### VoiceOver Labels
```swift
// Good
Button("Delete") { }
    .accessibilityLabel("Delete touch entry from January 29th")

// Bad
Button("Delete") { }
    .accessibilityLabel("Delete") // Not descriptive enough
```

### Color Independence
```swift
// Don't rely solely on color
HStack {
    Image(systemName: "exclamationmark.circle.fill") // Icon
        .foregroundColor(.red)
    Text("Overdue") // Text label
        .foregroundColor(.red)
    Text("+5d") // Metric
        .foregroundColor(.red)
}
```

---

## Platform Differences

### iOS-Specific Patterns

**Safe Area Insets:**
```swift
.padding(.bottom, 34) // Home indicator space
.edgesIgnoringSafeArea(.bottom) // For modals
```

**Status Bar:**
```swift
.preferredColorScheme(settings.theme == .dark ? .dark : .light)
```

**Navigation:**
```swift
// No NavigationView in V1 (single-page design)
// Use sheet() for modals
// Use custom back buttons
```

---

## Export This Reference

Save this file to Xcode project as:
`Resources/DesignSystem.swift` (code constants)
`Resources/ASSETS.md` (documentation)

---

**Version:** 1.0  
**Last Updated:** February 1, 2026  
**Maintained by:** Brad (Design System Owner)
