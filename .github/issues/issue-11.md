## Description
Allow users to specify general time-of-day when logging touches, providing more context than date-only without the precision confusion of exact times.

## Current Behavior
- LogTouchModal: DatePicker with `.date` only (no time component)
- PersonDetailView: Displays touch history with date only

## Proposed Enhancement
Add optional time-of-day selection in LogTouchModal with three options:
- Morning
- Afternoon
- Evening

## UI Design

### Log Touch Modal
Add time-of-day picker below date picker:

```swift
Picker("Time of Day", selection: $timeOfDay) {
    Text("Morning").tag(TimeOfDay.morning)
    Text("Afternoon").tag(TimeOfDay.afternoon)
    Text("Evening").tag(TimeOfDay.evening)
}
.pickerStyle(.segmented)
```

### Touch History Display
Update PersonDetailView to show time-of-day:

```swift
// Example output: "Text · Feb 3 · Morning"
Text("\(event.method.rawValue) · \(event.at.formatted(date: .abbreviated, time: .omitted)) · \(event.timeOfDay?.displayName ?? "")")
```

## Data Model Changes

**TouchEvent Entity**:
```swift
struct TouchEvent {
    // ... existing fields
    var timeOfDay: TimeOfDay? // Optional for backward compatibility
}
```

**New ValueObject**:
```swift
enum TimeOfDay: String, CaseIterable, Codable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }
}
```

## Files to Change
- `StayInTouch/Domain/Entities/TouchEvent.swift` (add `timeOfDay: TimeOfDay?`)
- `StayInTouch/Domain/ValueObjects/TimeOfDay.swift` (new file)
- `StayInTouch/Data/CoreData/StayInTouch.xcdatamodeld` (add `timeOfDay` attribute)
- `StayInTouch/UI/Views/PersonDetail/LogTouchModal.swift` (add picker)
- `StayInTouch/UI/Views/PersonDetail/PersonDetailView.swift` (update display)
- `StayInTouch/UI/ViewModels/PersonDetailViewModel.swift` (CRUD updates)
- All repository implementations (mapping logic)

## Schema Migration
Requires lightweight migration - ensure `shouldMigrateStoreAutomatically` is enabled.

## Complexity
- **Effort**: 2-3 hours
- **Risk**: Medium (schema change, backward compatibility)
- **ROI**: High (addresses user confusion while adding useful context)

## Acceptance Criteria
- [ ] User can select morning/afternoon/evening in Log Touch modal
- [ ] Time-of-day displays in touch history (if set)
- [ ] Existing touches without timeOfDay display correctly (backward compatible)
- [ ] Schema migration succeeds without data loss
- [ ] Unit tests for repository save/fetch
- [ ] Manual testing with existing data
