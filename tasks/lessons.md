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
- **`maxWidth: .infinity` in filter chip rows truncates the longest content**: When mixing variable-content chips (`Frequency: Weekly`) with short-content chips (`Select`) in an HStack, drop `maxWidth: .infinity` on the short one. Pair with `.fixedSize(horizontal: true, vertical: false)` so the short chip stays content-sized and the variable ones flex
- **Toast/banner action chips need `lineLimit(1)` + `fixedSize`**: Without both, multi-word action titles ("Forgot someone?") can wrap to two lines mid-toast. `.fixedSize(horizontal: true, vertical: false)` on the Text forces single-line, content-sized
- **NavigationLink consumers when changing nav bar**: When modifying a shared view's nav bar behavior, grep for ALL `NavigationLink` references. Test each navigation path
- **`.overlay()` does NOT cover fullScreenCover/sheet**: These create separate UIKit presentation contexts. For app-wide overlays, add a subview to the foreground-active scene's existing key window — SwiftUI modals present into the same window via `UIPresentationController`. A separate UIWindow at `.alert + 1` covers system alerts too but cannot host a `UIVisualEffectView` blur (Apple docs: blur only renders content from its host window). Pick same-window for real blur, separate-window only if you need an opaque overlay above system alerts
- **LazyVStack caches views by ForEach identity across sections**: When items move between sections (same UUID, different section), use `refreshToken` UUID + `.id()` on LazyVStack to force recreation. Clue: "force quit fixes it"
- **Text + Text concat supports `.foregroundStyle` on iOS 17+**: `Text.foregroundStyle(_:)` returns `Text` (not `some View`), so mixed-color single-line labels via `Text(...) + Text(...)` work with the modern API. Don't fall back to deprecated `.foregroundColor` — it's not needed.
- **`widgetAccentable(true)` is the iOS 16+ accent API**: Not `widgetAccentedRenderingMode(_:)` (that's iOS 18+ and a different API for controlling subtree rendering). For zones that should pick up the system accent treatment on Lock Screen / StandBy, use `.widgetAccentable(true)` — no availability check needed
- **Accessory widget body can't host bare `switch` / `let`**: `@ViewBuilder` rejects standalone non-view statements. Extract symbol/copy decisions into separate non-ViewBuilder helpers that return the value, then use the value inside the body. Symptom: "type '()' cannot conform to 'View'"
- **Lock Screen accessory widgets force monochrome — encode severity in fill, weight, or iconography**: Color is stripped on Lock Screen and StandBy night. A ring that always fills 100% becomes a frame, not a signal. Make fill proportional (e.g., `atRisk / trackedCount`) so the widget conveys "how bad" without color
- **`.widgetURL(_:)` on a child inside `Group` propagates up**: Per-branch widget URLs in conditional content work — SwiftUI modifiers propagate upward. Don't refactor away conditional `.widgetURL` placement on the assumption it must be at the root; the existing small/medium widgets already use this pattern
- **`@MainActor` init can't be a default arg in a non-MainActor struct init**: SwiftUI `View` structs are not implicitly `@MainActor` for default-arg evaluation under Swift 6 strict concurrency. Symptom: "call to main actor-isolated initializer in a synchronous nonisolated context." Fix: drop the default and require callers to pass the VM explicitly (`SomeView(viewModel: SomeViewModel())`). Marking the init `@MainActor` and `@autoclosure` both fail to fix this
- **Apple Charts first-time pattern**: `import Charts` only (built-in on iOS 17+). Horizontal bars: `BarMark(xStart:, xEnd:, y:)` + `.chartXScale(domain: 0...1)` for normalized ranges. Donut: `SectorMark(angle:innerRadius:)` with `.ratio(0.6)` inner radius reads lighter when paired with an adjacent legend. Skip `accessibilityChartDescriptor` for simple charts — per-mark `.accessibilityLabel` is sufficient
- **Reuse existing `EmptyStateView`**: When a new view needs an empty/null-state placeholder, grep for `EmptyStateView` before building a fresh `VStack { Image; Text; Text }`. Caught by simplify pass on #138
- **Time-dependent VM filters need a fresh clock per `load()`, not an init-captured `Date()`**: A `referenceDate` captured in `init` goes stale — a row that expires while the screen is open survives the next `.onAppear` reload, and diverges from sibling counts that read `Date()` fresh. Inject `now: () -> Date = { Date() }` and call `now()` inside `load()`. Only matters for time-dependent predicates (snooze, due dates), not boolean state (isPaused). From #334 review

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

- **Wipe-and-rewrite for batch-edit with grace-period undo, not additive**: When a UI flow offers true edit semantics within a toast/banner undo window, model the second commit as delete-priors + write-fresh, not append-only. Stash created event IDs in the carry-forward context (`BatchEditContext.priorEvents: [UUID: TouchEvent]`); on next save, reconcile against them. Avoids the "X-can't-undo-prior-write" paradox where chip removal looks like it should rollback but can't
- **Multi-step writes need snapshot rollback**: If step 2 (batchSave) can throw after step 1 (delete) succeeded, snapshot what step 1 deleted via `fetch(id:)` before deleting, then re-save on step-2 failure. Log loudly with "DATA LOSS" marker if the rollback itself fails. See `BulkLogTouchUseCase.reconcile` for the pattern
- **Pure static helpers > duplicated layer-specific recompute**: When use case + view model both compute the same "headline from events" rule, extract a pure static helper on the use case (sister to existing `applyTouch`). Sort internally; preserve adjacent state (snooze, customDueDate) deliberately. See `BulkLogTouchUseCase.recomputeLastTouch`
- **Centralize ancillary-state invalidation in `.onChange` at the parent**: Multiple call sites that call `coordinator.exit()` should not each remember to clear carry-forward state. One `.onChange(of: isSelectMode) { _, isOn in if !isOn { context = nil } }` at the parent covers all exit paths (action-bar Cancel, chip toggle, header button, post-commit). One source of truth, every exit honest
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
- **Lock-screen widgets need custom `.accessibilityLabel()`**: VoiceOver reads literal widget text including the interpunct (`·`) as "dot." Compose explicit labels that lead with the app name and read in plain English ("Keep In Touch. 3 people overdue.") instead of falling back to default text inference

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
- **Fix sub-70 review findings when they're real bugs**: The 70+ threshold is for "is this a blocker?" not "is this worth fixing?" Data-integrity issues (silent data loss, stale state leaks) scored 60-69 should still get fixed in the same iteration. Pattern: file a comment explaining the call, then do it
- **Edit modes need pre-selection + visible mode signal**: When re-opening a picker for "edit" semantics (vs "add" semantics), pre-select the prior set so users see what they're editing. Pair with a subtitle ("Editing last batch") and commit-label flip ("Save changes" vs "Log Connection") so the mode is unambiguous. Empty selection in edit context = users second-guess ("did I miss them already?")
- **`GeneratedVersion.swift` blocks branch ops**: The Xcode "Set Version from Git" build phase bumps `static let build = "N"` on every build, so the file is always dirty. Before `git checkout`, `gh pr merge`, or any operation requiring a clean tree, run `git checkout -- StayInTouch/StayInTouch/Utilities/GeneratedVersion.swift` to discard. It regenerates on next build

## App Intents

- **AppShortcut phrases support exactly ONE `@Parameter` slot**: The AppIntents metadata processor fails the build with "Multiple parameters detected in phrase" when a phrase references two `\(\.$param)` slots. Multi-parameter invocations come from the Shortcuts editor, not curated phrases. Pick the single best slot per phrase (e.g. person for Log Touch)
- **Widget refresh is at the repository layer, not the use-case layer**: `CoreDataPersonRepository.save/batchSave/delete` (and TouchEvent/Group/AppSettings equivalents) already call `WidgetRefresher.reloadAllTimelines()`. Single-touch UI paths and intent paths both inherit this for free. Don't sprinkle `WidgetRefresher.reloadAllTimelines()` at the view-model or use-case layer — it'll just thrash
- **App Intents live in the main app target, NOT the widget extension**: Widget extension is a separate process with its own NotificationCenter and no NotificationScheduler. Intents that need to trigger `.personDidChange` (which NotificationScheduler observes) must run in the main app process. Set `openAppWhenRun: false` for headless intents — they still run in the main app's process
- **Wrap `/security-review` in an Agent sub-agent for autonomous loops**: The skill has a known failure mode where it exits without posting a PR comment. Sub-agent isolation guarantees a structured text report is returned; the parent posts the comment from the result. Pattern: launch with subagent_type=Explore, instruct it to return findings as text and NOT to post itself
- **AppEntity `entities(matching:)` accepts external string from Siri**: Pass through `searchByName` (which uses `NSPredicate(format: "displayName CONTAINS[cd] %@", query)` — parameterized, safe). Never interpolate the string into a predicate format
- **AppEntity `suggestedEntities()` should cap result count**: Apple's Siri picker only renders a small inline list. Sorting all tracked people (potentially hundreds) just to discard most is wasted work on the cold-launch path. Cap at ~12 and rely on Apple's ranking beyond that
- **Core Data entity names lag the domain rename**: `PersonEntity.cadenceId` is named `groupId` in the .xcdatamodel; `GroupEntity` (Core Data) maps to domain `Cadence`; `TagEntity` (Core Data) maps to domain `Group`. Read `Data/CoreData/Mappings/` before writing predicates against Core Data entity names — the domain → Core Data name mapping is non-obvious
- **Test seam for static services**: For `AnalyticsService.track` (sealed enum, static methods), don't hack the service itself. Take a `trackAnalytics: (String, [String: String]) -> Void` closure param on the caller with `AnalyticsService.track` as default. Tests inject a recorder closure; production wiring is unchanged

## Multi-PR Refactor Orchestration (Issue #302 sweep)

- **Sub-agents can't dispatch their own sub-agents**: When a general-purpose sub-agent invokes a skill that fans out to parallel sub-agents (e.g. `/code-review`'s 5 Sonnet reviewers), the nested dispatch silently fails and the skill degrades to single-agent mode. For the full skill machinery, invoke the skill **directly in the main session**, not wrapped in a sub-agent. Accept the context cost for high-stakes reviews
- **Review sub-agents stall on the test-wait step**: Recurring failure mode — the review sub-agent kicks off `xcodebuild test`, then stalls (stream watchdog / API overload) before posting its comment or cleaning its worktree. Don't assume a stalled-looking review is dead; check the worktree + PR comments first (one "stalled" agent actually completed 20 min later). When genuinely dead, finish the review — but a real skill run beats a hand-written substitute
- **Don't claim test results you didn't run**: `/code-review` explicitly says NOT to build/test. A reviewer writing "tests continue to pass" without running them is overclaiming even when true. Reviews assert code-reading findings; test status comes from a separate run. Keep provenance honest in the posted comment
- **Worktree-isolated executor edits can leak to the main checkout**: An executor in an isolated worktree whose Edit calls use absolute paths pointing at the *main* repo working tree will modify main's files (uncommitted). Verify with `git reflog` (HEAD never moved = nothing committed to main) + `git status` after any worktree session. Add a "verify pwd is inside the worktree before editing" guard to executor prompts
- **Tech-debt refactors add net lines, and that's fine**: The #302 sweep was +2728/−1473 (net +1255) despite "removing duplication" — it introduced 10 named abstraction files + ~900 lines of regression tests. The win is maintainability (one place to change) and coverage, not net deletion
- **Squash-merge then rebase-the-next-branch for overlapping refactor PRs**: When PRs touch the same file (e.g. PersonStatusService in #322 and #321), merge the foundational one, then `git rebase main` + `--force-with-lease` the dependent branch before merging. GitHub `mergeStateStatus: CLEAN` = green light; `UNKNOWN` = still computing, re-poll
- **Person init field-mapping is the make-or-break review check**: Refactoring the Person init or `PersonEntity+Mapping.toDomain()` — the highest-value review is field-by-field fidelity; a transposed pair (`lastTouchNotes`/`nextTouchNotes`, `createdAt`/`modifiedAt`) silently corrupts data. Lock with a regression test using distinct sentinel values per field. Person is NOT Codable, so no JSON wire-format risk
