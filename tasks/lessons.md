# Lessons Learned

Compact prevention rules. Full narratives archived in `tasks/lessons-archive.md`.

## SwiftUI

- **Sheet stacking timing**: Never dismiss one sheet and present another in the same render cycle. Use `.onChange(of:)` to defer second presentation until first fully dismisses
- **clipShape nullifies ignoresSafeArea**: Safe area modifiers go AFTER clip shapes. Order: `.background()` -> `.clipShape()` -> `.ignoresSafeArea()`
- **No `if` inside `.swipeActions {}`**: Conditional content in the ViewBuilder kills swipe gesture for ALL rows. Move conditionals into Button's action closure
- **`.background()` stacks bottom-up**: `.background(.ultraThinMaterial).background(Color)` puts material on top (visible); reverse order hides it
- **`.opacity()` compounds multiplicatively**: Container 0.4 + child 0.5 = 0.20 visible. Use mutually exclusive conditions or single-layer opacity
- **`.sheet(item:)` over boolean flags for edits**: Using a shared boolean to present edit sheets causes stale state when multiple actions fire quickly. Let the selected model drive presentation
- **Multi-select lists need edit mode**: SwiftUI list `selection` requires edit mode for multi-select. Force edit mode on multi-select screens
- **Sort options that change grouping must visually change grouping**: "Sort by Name" should flatten across sections, not just reorder within them
- **`onChange` misses init() values**: When a `@StateObject`'s `@Published` property is set during `init()`, `.onChange` never fires. Also check the value in `.onAppear`
- **`fullScreenCover(item:)` over `isPresented`**: When presenting based on an optional, use `item:` binding to avoid blank screen flash
- **NavigationLink consumers when changing nav bar**: When modifying a shared view's nav bar behavior, grep for ALL `NavigationLink` references. Test each navigation path
- **`.overlay()` does NOT cover fullScreenCover/sheet**: These create separate UIKit presentation contexts. For app-wide overlays (privacy screen), use a UIWindow at `.alert + 1` level
- **LazyVStack caches views by ForEach identity across sections**: When items move between sections (same UUID, different section), use `refreshToken` UUID + `.id()` on LazyVStack to force recreation. Clue: "force quit fixes it"
- **Text + Text concat supports `.foregroundStyle` on iOS 17+**: `Text.foregroundStyle(_:)` returns `Text` (not `some View`), so mixed-color single-line labels via `Text(...) + Text(...)` work with the modern API. Don't fall back to deprecated `.foregroundColor` — it's not needed.

## Multi-Target Sharing

- **Protocol seam beats moving the domain layer**: When a widget/extension needs main-app logic, prefer narrow `FrequencyCalculator*` protocols over moving `Person` / `Cadence` / related value objects into `Shared/`. Existing domain types conform via empty extensions; the extension target defines tiny adapter structs populated from its own Core Data entities. Zero-diff for existing tests (generics over protocols, not `any P`)
- **`PBXFileSystemSynchronizedRootGroup` subdirs inherit membership**: Files placed in `StayInTouch/StayInTouch/Shared/` are automatically members of the main app target because the main app's synced group (`path = StayInTouch`) is the parent directory. The widget target declares `Shared` explicitly via a second `PBXFileSystemSynchronizedRootGroup` (`Shared (widget membership)`). Moving a file into `Shared/` requires zero pbxproj edits
- **Widget-only code that tests need access to**: Move it to `Shared/` so the main app module also compiles it — `@testable import StayInTouch` then sees it. Keep widget-only dependencies (e.g. `WidgetCoreData.shared`) in a thin extension file that stays in the widget target

## Core Data

- **Tag Transformable safety**: `tagIds` can persist as mixed types (UUID/NSUUID/String). Always decode defensively, never assume a single concrete type
- **Detail view reload**: Detail views must refresh their model from persistence on appear, not rely on navigation-passed snapshots
- **fetchBatchSize on all list requests**: Every `NSFetchRequest` returning a list should set `fetchBatchSize = 50`. Zero-risk optimization for memory
- **Push filtering into predicates**: Before filtering Core Data results in Swift, ask: "Can this be a compound predicate?" Pre-fetch the small lookup table (groups) and build per-key predicates
- **CoreData renamingIdentifier for attribute renames**: Add `renamingIdentifier="oldName"` to renamed attributes in versioned models. Without it, CoreData treats rename as delete+add, losing data
- **Never auto-delete persistent store on failure**: Surface migration failures to the user with explicit confirmation before destructive recovery. Never silently delete the SQLite store
- **Demo mode must apply immediately**: Settings toggles that affect data must trigger the data operation (seed/remove) immediately, not just update the settings flag

## Contacts Framework

- **CNContactFormatter requires its own keys**: Always include `CNContactFormatter.descriptorForRequiredKeys(for: .fullName)` in fetch requests, or get `CNPropertyNotFetchedException`
- **Contact fetches off main thread**: `CNContactStore.enumerateContacts` is synchronous and expensive. Always run on background task, publish results on main actor
- **CNLabeledValue labels are system constants**: Always use `CNLabeledValue.localizedString(forLabel:)` to convert to display strings. Never show raw labels like `_$!<Mobile>!$_`
- **Sync must handle "missing" explicitly**: When syncing contacts, don't skip records not found - set `contactUnavailable = true`. Handle the deleted/merged case
- **Contact photos: on-demand with NSCache**: Fetch via `CNContactThumbnailImageDataKey` (pre-resized ~60x60pt), cache in `NSCache`, never persist in Core Data
- **`CNAuthorizationStatus.limited` requires iOS 18 check**: Wrap in `#available(iOS 18.0, *)` with `false` fallback for iOS 17 deployment target

## Notifications

- **Custom breach time excludes from grouped**: People with `customBreachTime` must be excluded from grouped notification lists. Classify into mutually exclusive buckets
- **Repeating triggers use minimal DateComponents**: Daily = only `hour` + `minute`. Weekly = `weekday` + `hour` + `minute`. Never include year/month/day for repeating triggers
- **`content.badge` only applies on delivery**: Always call `setBadgeCount()` directly for immediate badge updates. Don't rely on notification delivery for badge state
- **Badge count arrays must be symmetric**: If `allOverdue` includes custom breach time people, `allDueSoon` must too. Keep classifier and calculator boundary conditions aligned

## Architecture / Threading

- **Guard `isPaused` before displaying status**: `FrequencyCalculator` returns `.onTrack` for paused (correct for SLA), wrong for display. Check order: isPaused -> snoozedUntil -> currentStatus
- **Don't recompute what sections already encode**: If `applyFilters()` categorizes into Overdue/Due Soon/All Good, use section-based status closures. Don't create a second `FrequencyCalculator`
- **Thread safety when extracting from @MainActor**: When moving methods from `@MainActor` classes to plain structs, audit every repo call. `viewContext` writes must stay in `@MainActor` code or use a background context. Actor isolation doesn't carry through `await`
- **`scenePhase` for detecting app return**: Use `@Environment(\.scenePhase)` with `.onChange` to detect `.active`. Store pending state before `openURL`, show undo banner on return
- **History stack for branching navigation**: For multi-step flows with branches, use a history stack (not step arithmetic). Records actual path taken
- **NavigationPath for deep links**: Use `NavigationPath` + `navigationDestination(for:)` for deep links and programmatic navigation. Sheets are for modal workflows, not content navigation
- **Error toast vs logger**: User taps a button -> show error toast on failure. App does background work -> log error silently. Never use `try?` in user-initiated flows
- **Backward-compatible Codable extensions**: When extending `Codable` types with existing serialized data, always make new fields optional. Swift's `Codable` treats missing optional keys as nil
- **Export should be self-contained**: User-facing data exports need denormalized names alongside foreign keys, plus ISO 8601 dates and pretty-printed JSON
- **Security-scoped URLs from file picker**: Always wrap `fileImporter` URL access with `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`

## Accessibility

- **WCAG AA for section headers**: Never use color alone for section identity in text. Pair colored indicators (dots, icons) with high-contrast `primaryText`
- **Touch target vs layout inflation**: `minHeight: 44` on inline elements inflates parent height. For compact containers (chips, pills), use `minWidth` only + `.contentShape(Rectangle())`
- **Font weight as legibility lever**: For section-level headers at `subheadline` size or smaller, default to `.bold`. Reserve `.semibold` for body-adjacent text
- **Semantic color tiers**: `primaryText` = main content. `secondaryText` = supporting content that must be read (labels, section headers). `tertiaryText` = decorative/hint only (placeholders, disabled). When in doubt, use `secondaryText`

## Testing

- **Domain model changes require test fixture updates**: Any change to a domain entity must be reflected in all test factories/fixtures immediately
- **Test through public API only**: If you can't set up state through public methods, the test scenario may not be reachable in practice. Don't manipulate internal state directly

## Git / Process

- **Duplicate views need consistent fixes**: When fixing a bug in a view, grep for similar/duplicate views. Apply the fix to all instances
- **One commit per issue for clean bisection**: Build + test after each commit. Commit message starts with issue number. Version bump as final separate commit
- **One branch per issue in multi-issue sessions**: Start each from fresh `main`. Create PR, then `git checkout main` before starting next issue
- **Version bumps touch 6 locations**: Both `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` appear 6 times in `project.pbxproj` (Debug/Release x App/Tests/UITests). Always use global replace
- **Discard uncommitted work in two steps**: `git reset HEAD -- .` (unstage) then `git checkout HEAD -- .` (revert). `git checkout -- .` alone misses staged changes
- **Subagents for bulk file edits (5+ files)**: Do core changes yourself. Delegate mechanical updates (constructor sites, renames) to a subagent with explicit file list
- **Apple HIG evolves**: Before critiquing UI placement, verify current convention in latest iOS system apps. Bottom search bar is now the Apple convention
- **Empty state CTA should match core flow**: Every empty state should provide the fastest path to resolve it
- **Settings counts must refresh on return**: When secondary screens change global counters, publish a notification and refresh counts on return
- **Never trust external identifiers in import**: Regenerate UUIDs for imported records. Clear/validate `cnIdentifier`. Treat imported data as untrusted at every field level
