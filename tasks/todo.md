# TODO - Stay in Touch iOS App

**Project Status:** v0.4.0 (Build 13) — Pre-release Beta
**Last Updated:** June 24, 2026

> **TestFlight Status:** Code blockers resolved. Manual submission steps remain — see `tasks/testflight-guide.md`.
> When creating PRs, confirm TestFlight readiness is not regressed (deployment target 17.0, PrivacyInfo.xcprivacy present, UIBackgroundModes declared, build number incremented).

---

## v0.3.3 Triage — TestFlight Launch Scope

> **PRESERVE THIS SECTION.** Future sessions: mark items `[x]` as they ship. Do NOT remove, reorder, or overwrite the priority tiers until v0.3.3 is tagged and released. This is the authoritative scope for v0.3.3.

**Implementation order:** ~~#229~~ → ~~#237~~ → ~~#40~~ → ~~#236~~ → ~~#235~~ → #105 → ~~#106~~ → ~~#228~~

### Tier 1 — Must Ship (bugs + analytics)

- [x] **#229** Fix incorrect app version displayed in Settings *(XS — PR #238)*
- [x] **#237** Fix concurrency & redundant modifier warnings *(S — PR #238)*
- [x] **#228** Audit and update TelemetryDeck events after refactors *(M — PR #240)*

### Tier 2 — Should Ship (privacy + UX polish)

- [x] **#105** Add screenshot blur protection on app background *(M — PR #298, same-window UIVisualEffectView)*
- [x] **#106** Add notification privacy setting to hide contact names *(S-M — PR #244)*
- [x] **#236** Display multiple groups on contact cards in list views *(S — PR #242)*
- [x] **#235** Add "Link to Contact" option when contact is unavailable *(S — PR #243)*
- [x] **#40** Reorder PersonDetailView CTAs — Log Connection as primary *(XS — already closed 2026-02-25)*

### Tier 3 — Nice to Have (stretch goals, if time allows)

- [ ] **#34** Swipe-to-log on home screen *(M-L — highest UX priority but gesture complexity)*
- [x] **#230** Deduplicate breach + digest notifications for single person *(S — PR #259)*
- [ ] **#231** Birthday push notifications with toggle and per-person settings *(M — extends #141)*
- [x] **#134** Add CSV export option for spreadsheet use *(S — PR #265)*
- [ ] **#37** Separate overdue tiers (Recently Due vs Long Overdue) *(S-M — UX improvement)*
- [x] **#283** Add 'all caught up' empty state to Home screen when no one is overdue or due soon *(S)*
- [x] **#232** Pull-to-refresh re-sync contact info from iOS Contacts *(S — PR #255)*

### Tier 4 — Deferred to v0.4+

Calendar integration (#234), WhatsApp (#233), ~~Dynamic Type (#202)~~, architecture refactors (#203), ~~VoiceOver picker/editor sheets (#197)~~, full VoiceOver audit (#39), widget (#60), ~~Siri Shortcuts (#80)~~ (superseded by #304 — App Intents v1 shipped in PR #305), iCloud sync (#79), iPad layout (#78), localization (#77), ~~stats page (#138)~~ (v1 shipped in PR #306), tutorial (#10), UX direction (#45), design polish (#41, #42, #44).

> **Note:** #34, #37, #231 are CLOSED on GitHub (closed as won't implement in v0.3.x). #214, #215, #216, #168 completed in v0.3.4 work.

### Not Code (human parallel track)

- [ ] **#65** Create App Store screenshots
- [ ] **#66** Write App Store description, subtitle, and keywords
- [ ] **#68** App Store submission checklist
- [ ] **#69** TestFlight beta validation plan
- [ ] **#70** Validate core loop retention during beta

---

## Completed — Session 2026-06-24 (Issue #342/#349: CI pipeline landed)

Fixed the bug that kept PR #349's own CI red, then merged the project's first CI pipeline to `main`. The hang: `ContactsSyncService.syncExistingContacts()` enumerated the real address book without an authorization check, so on a fresh CI runner (`.notDetermined`) the read blocked on the TCC permission prompt forever → 40-min timeout. Guarded the passive sync on `ContactsFetcher.isAuthorized` (mirrors the existing thumbnail/birthday "skip when unauthorized" pattern). Reproduced the hang on a freshly-erased simulator, verified the fix (full suite green on a `.notDetermined` sim). Rebased onto current `main` (freemium had merged in between) and re-added the `<StoreKitConfigurationFileReference>` the committed scheme had dropped, so local IAP testing survives. `/code-review` (xhigh) + `/security-review` both PASS. CI green on the PR and on post-merge `main`. Squash-merged `70adc83`.

- [x] **#349 / #342** CI pipeline live (`.github/workflows/ci.yml` + shared `StayInTouch.xcscheme`); `main` mechanically gated on the `Build & Unit Test` check
- [x] Contacts-sync authorization guard (`ContactsFetcher.isAuthorized` + `ContactsSyncService` early-return)
- [x] StoreKit config reference restored to the now-canonical scheme (no CI impact; preserves local IAP testing)

### Lessons captured from #342/#349
- A real `CNContactStore` read hangs headless CI on a fresh sim (`.notDetermined` → TCC prompt blocks); guard passive syncs on authorization, keep unit tests off the real store
- The PR that adds the CI workflow satisfies its own required check via its `pull_request` run — no `--admin` deadlock once the check is green (corrects the earlier #351 assumption)
- Rebase-and-reverify a stale foundational-CI branch before merge so the green check reflects what actually lands on `main`

## Completed — Session 2026-06-21 → 2026-06-23 (Issue #351: Freemium / Pro unlock)

Shipped the freemium model: 12-contact free tier + one-time non-consumable **Pro** unlock (StoreKit 2). Built across 6 stages, bundled into a single umbrella PR **#359** and squash-merged to `main` (commit `3f26716`). Grandfathered TestFlight users get Pro free via a write-once flag. Device QA passed (pre + post purchase). Both `/code-review high` + `/security-review` ran on the full feature diff vs main → PASS.

- [x] **Stage 1** Entitlement foundation — Core Data v11 (`isGrandfathered`/`proStatusEvaluated`), `GrandfatherEvaluator`, `Entitlements.isPro`, App Group `EntitlementCache`, `EntitlementBootstrap`, `ProConfig`
- [x] **Stage 2** StoreKit 2 — `StoreKitGateway` seam + `LiveStoreKitGateway`, `@MainActor PurchaseManager` (authoritative cache writer), `Configuration.storekit`
- [x] **Stage 3** Paywall + 12-contact cap — `PaywallView`/`PaywallTrigger`, `ContactCapGate`, `PersonRepository.trackedCount()`
- [x] **Stage 4** Feature gates — onboarding cap, stats, file import, bulk logging
- [x] **Stage 5** In-detail gates — pause, custom due dates, custom cadences, snooze, custom notif time (SET gated; clear/unpause/undo stay free — never trap an ex-Pro user)
- [x] **Stage 6 (PR6)** Widget gates — birthday + lock-screen/StandBy widgets are Pro (upsell placeholder + `keepintouch://paywall`); Overdue home widget stays free; `PurchaseManager` reloads widgets on entitlement change

### Lessons captured from #351
- StoreKit entitlement changes need an explicit widget reload (repo-layer `WidgetRefresher` only fires on Core Data saves)
- Gate Pro widgets in the entry view, not the provider (`supportedFamilies` is compile-time static)
- Single-merge umbrella PR pattern for a stacked feature; a required CI check with no producing workflow blocks all merges (needs `--admin`)

### Follow-ups deferred from #351
- [ ] **#360** Fix stale widget-accent API comment in `OverdueLockScreenWidget` (tech debt, comment-only)
- [ ] **#353** Manual $7.99 → $9.99 price cutover (ASC, no app logic)
- [ ] **Manual prereq (pre-release)** Create ASC non-consumable IAP `slavins.co.KeepInTouch.pro` ($7.99, Family Sharing on) + active Paid Apps Agreement
- [x] **#349** Land the CI pipeline — **merged 2026-06-24** (squash `70adc83`). No `--admin` needed: the PR's own `pull_request` run produces the `Build & Unit Test` check, which passed once the test hang was fixed. See Completed section below
- [x] **#362** Beta builds grant Pro to all TestFlight testers — `BuildEnvironment` sandbox-receipt override OR'd into `Entitlements.isPro`, propagated via the App Group cache. **PR #363** (pending simulator + TestFlight manual QA + merge). Side effect: ASC IAP is no longer a *beta* blocker (still an App-Store-submission prereq)

## Completed — Session 2026-05-27 → 2026-05-28 (Issue #302: Tech-debt audit sweep)

Closed the full `/simplify` audit (#302). 13 child issues (#307-#319), 12 substantive PRs + 1 Swift-6 hotfix merged; #319 closed without a PR (findings resolved by prior waves or schema-blocked). North star held: zero observable behavior change, every PR manually QA'd against `main`.

**Execution model:** 5 waves of parallel worktree executor sub-agents (implement → context7 doc check → build/test → review loop → manual QA → squash merge). Reviews ran as sub-agents with a score-70 auto-fix loop.

- [x] **R2, R3, R4, R8** Shared helpers (`Person.isSnoozed`, `FrequencyCalculator.daysUntilDue`, `Color.normalize(hex:)`, `CoreDataMappingHelpers.requiredField`) — PR #322
- [x] **R1** Repository CRUD base (`CoreDataRepositoryHelpers` free helpers) — PR #323
- [x] **E10, E15, HomeView dupe fetch** Formatter caching + cold-launch — PR #320
- [x] **R5** Status drift — `PersonStatusService.partition` unifies Home buckets — PR #321
- [x] **Swift 6 hotfix** `TouchMethod: Sendable` declared in source (retroactive AppEnum conformance was a strict-mode error) — PR #326
- [x] **Q5, Q6, Q7, Q8** View component extraction (`FloatingSearchBar`, `timeAgoText`, `TouchTimeAndNotesFields`, `ContactAccessAlerts`) — PR #324
- [x] **E1, E5, E7** PersonDetailVM in-place updates + NotificationScheduler debounce + batched CNContact fetch — PR #325
- [x] **E4, E8, E12, E6** Batch saves (ContactsSync, deletePerson cascade, addPeople, TaskGroup notification add) — PR #327
- [x] **E2, E3, E9, E13** List-render efficiency (`ContactsListViewModel` derived state, dict-based FrequencyCalculator overloads, `count(for:)`) — PR #328
- [x] **Q13, Q10-12, R7, R9, R12** Stringly + magic numbers (`UserInfoKey`/`UserInfoValue` enums, `DS.Timing`/`DS.Motion` tokens, `PhoneNormalizer.dialableDigits`, `Date.defaultSnoozeStartDate`, unified avatar palette) — PR #330
- [x] **Q14, Q15, N2** DI / layering (`AppDependencies.shared`, `BackgroundWorkScheduler` protocol restores Domain/Data boundary) — PR #331
- [x] **Q9** `ViewModelErrorHandling` helper — 9 VMs migrated, ~115 LOC boilerplate removed — PR #332
- [x] **Q1** Person initializer split — 27 flat params → 4 nested config structs (Identity/TouchState/NotificationConfig/Metadata) — PR #333
- [x] **Q2, Q3, E14** Tier-3 — closed #319 without a PR: Q2 already consolidated by #324/#325, Q3 resolved by #328/E9, E14 schema-blocked (Transformable `tagIds`, zero production callers)

**Net diff (pre `370dd2a` → post `8f84275`):** 88 Swift files, +2728 / −1473. Source +2075/−1077, tests +653/−396. 10 new abstraction files. `CoreDataStack.shared.viewContext` DI-bypass defaults: 27 → 0. `requiredField` definitions: 4 → 1.

### Deferred (Tier 4, not filed)
- **E14 join-entity migration** — denormalize `tagIds` into a queryable join entity so `fetchByGroup` can use an SQLite predicate. Requires Core Data schema migration. No production callers today, so low priority.

---

## Completed — Session 2026-05-20 (Issue #138: Stats & Insights v1)

- [x] **#138** Settings → Insights destination with 30d/90d range toggle — PR #306 (pending manual QA / merge)
  - REDUCE-mode plan-review locked v1 scope to 2 metric families: per-cadence "Performance vs Intent" bars + "How you showed up" method breakdown donut. Streaks, leaderboards, trends-over-time, lifetime totals, per-person momentum, custom date pickers all deferred — file separately if v1 lands
  - `StatsRange` enum with `startDate(now:)` helper — single source of truth for "events at or after this date are in range." Subtitle copy ties each window to the cadences it best surfaces (30d → Weekly + Biweekly; 90d → Monthly + Quarterly)
  - `StatsSnapshot` Codable value type — three states (`.empty`, `.emptyForRange`, `.ready`) with `CadenceRow` (id, name, frequencyDays, trackedCount, expected, actual, ratio: Double?) + `MethodRow` (method, count, percent)
  - `StatsCalculator` — pure use case, no Core Data import. Filters `isTracked && !isPaused` for the expected denominator; returns `ratio = nil` when range < cadence frequency (UI shows "Range too short" instead of fake 0% or 100%). Over-performing ratios (>1.0) preserved in data; only visually capped
  - `TouchEventRepository.fetchAll(since:)` — new range-scoped fetch, predicate `at >= since`, `fetchBatchSize = 200`, sort descending. Boundary inclusive (`>=`), verified with explicit test
  - `StatsViewModel` — @MainActor, repo-injected. `fetchTracked(includePaused: false)` (post-simplify) so the calculator doesn't waste work on archived contacts. Reloads on `.onAppear`, on `.onChange(of: range)`, and on `.personDidChange` notification
  - `StatsView` + `CadencePerformanceChart` (BarMark, range-scaled 0...1, ✓ Ahead pill when over, "Range too short" when nil ratio) + `MethodBreakdownChart` (donut SectorMark with `innerRadius: .ratio(0.6)` + adjacent legend). DS tokens throughout, no `colorScheme` conditionals, no fixed font sizes. Per-row/segment accessibility labels
  - Empty states use the existing `EmptyStateView` component (caught by simplify pass)
  - 21 new unit tests: `StatsCalculatorTests` (12) + `StatsViewModelTests` (4) + `CoreDataTouchEventRepositoryTests.fetchAll(since:)` (5)
- [x] Code review (sub-agent): PASS — 0 blockers. 3 sub-70 informational notes only (unused `LoadState.failed`, unused `convenience init(dependencies:)`, defensive double-filter in calculator). None acted on
- [x] Simplify pass (sub-agent): 3 changes pushed in commit `93b4e4f` — hoisted range-start math into `StatsRange.startDate(now:)` (was inlined in VM + calculator), reused existing `EmptyStateView` for empty/empty-for-range states, switched VM to `fetchTracked(includePaused: false)` instead of `fetchAll()`. All tests still green after
- [x] Security review (sub-agent): PASS — 0 findings. Read-only Core Data fetch with parameterized predicate; no new network surface, no external input, no file I/O. Consistent with the "local-only iOS app = PASS by default" precedent
- [ ] Manual QA — see PR #306 description for the 10-scenario checklist (Brad's morning pass)

### Lessons captured from #138

- **`@MainActor`-isolated init can't be used as a default arg in a non-MainActor struct init** under Swift 6 strict concurrency. SwiftUI `View` structs are NOT implicitly `@MainActor` for default-arg evaluation purposes. Symptom: "call to main actor-isolated initializer in a synchronous nonisolated context" on the View init's signature line. Fix: drop the default value and require callers to pass the VM explicitly — `StatsView(viewModel: StatsViewModel())`. Marking the init `@MainActor` does NOT fix it. `@autoclosure` also doesn't help because the default expression still has to type-check at the call site
- **Apple Charts (`BarMark` / `SectorMark`) first-time integration**: `import Charts` only; deployment target 17.0 has it built-in. For horizontal bars use `BarMark(xStart:, xEnd:, y:)` + `.chartXScale(domain: 0...1)` to constrain a normalized range. For donut: `SectorMark(angle:innerRadius:)` with `.ratio(0.6)` inner radius reads lighter than a solid pie when paired with an adjacent legend. Per-mark `.foregroundStyle(Color)` works on both. Skip `accessibilityChartDescriptor` for simple charts — per-row/segment `.accessibilityLabel` is enough
- **Hoist shared range/window math to the value object, not a private helper**: when a `@MainActor` VM and a pure use case both compute the same "rangeStart from now" math, put it on the range enum itself (e.g. `StatsRange.startDate(now:)`) — the use case stays pure, the VM uses it for the repo query, and the enum is the single source of truth. Caught by the simplify pass: don't let me ship the inlined duplicate next time
- **Empty states have a reusable `EmptyStateView` component** — when a new view needs an empty/null-state placeholder, grep for `EmptyStateView` before building a fresh `VStack { Image; Text; Text }`. Existing component handles centering, padding, and Dynamic Type
- **`.personDidChange` is the canonical "data may have changed" notification** in this app — posted by every touch-logging flow (`PersonDetailViewModel`, `BulkLogTouchUseCase` via repo, App Intents). Any new view that needs to refresh on touch logging should `.onReceive(NotificationCenter.default.publisher(for: .personDidChange))` — don't invent a new notification or subscribe to Core Data `didSave` directly

---

## Completed — Session 2026-05-20 (Issue #304: App Intents v1 for iOS Shortcuts)

- [x] **#304** Expose Keep In Touch's core actions as App Intents — PR #305 (pending manual QA / merge)
  - `LogTouchIntent` — log a touch via Siri / Shortcuts / Action Button / Spotlight. Reuses `BulkLogTouchUseCase.applyTouch` via a thin `IntentActions` facade — same headline-recompute helper as `PersonDetailViewModel.logTouch`, zero logic duplication
  - `GetOverdueContactsIntent` / `GetDueSoonContactsIntent` — return `[PersonAppEntity]` for Shortcut chains. Due-soon uses `PersonStatusService.dueSoonPeople` (same classifier as Home tab)
  - `OpenPersonIntent` — deep-links via existing `DeepLinkRouter.shared.pending`; stale-id fallback routes to Home and throws `IntentError.personNotFound`
  - `KeepInTouchShortcuts: AppShortcutsProvider` — curated phrases for Spotlight / Siri discoverability (one parameter per phrase per Apple's metadata processor)
  - `IntentContainer` — lazy DI singleton with `install` / `reset` / `make` test seam. Memberwise init added to `AppDependencies` for mock injection
  - `PersonAppEntity` + `PersonAppEntityQuery` (`EntityStringQuery`) with capped `suggestedEntities()` (12 most-recent) to keep Siri cold launches snappy
  - `TouchMethod.verb` lives next to the AppEnum case mapping — single source of truth for "Logged a {verb} with X" dialog phrasing across any future intent
  - `PersonListDialog.make(...)` — shared zero/one/many phrasing helper for GetOverdue + GetDueSoon, ready for any future query intent
  - 24 new unit tests: LogTouchIntent (6) + IntentActions (2) + PersonAppEntityQuery (6) + OpenPersonIntent (2) + GetOverdue (3) + GetDueSoon (2) + IntentContainer (3)
- [x] Code review: PASS — 0 blockers (no 70+ findings). 5 sub-70 polish items fixed inline (redundant Set check, RelativeDateTimeFormatter hoisted to static, analytics test seam, divergence comment honesty, phrase-limit doc)
- [x] Simplify pass (reuse + quality + efficiency, 3 parallel agents): PASS — 0 blockers. Moved `methodVerb` to `TouchMethod.verb`, extracted `PersonListDialog`, capped `suggestedEntities`, parallelized GetDueSoon's two fetches via `async let`
- [x] Security review (run via sub-agent wrapper for autonomy resilience): PASS — 0 findings (critical/high/medium/low). All 9 threat-model surfaces cleared
- [ ] Manual QA — see PR #305 description for the 8-scenario checklist (Brad's morning pass)

### Follow-ups deferred from #304 (v2 candidates)

- [ ] **v2 toggles**: SnoozePerson, PausePerson, ResumePerson, MuteNotifications, UnmuteNotifications — file as one consolidated issue
- [ ] `SetCustomDueDateIntent`, `AddPersonToGroupIntent` — admin-grade automation; file individually if requested
- [ ] `MarkContactedTodayIntent` — users can build via `LogTouchIntent` + default method in Shortcuts editor
- [ ] `GetLastTouchIntent` — `PersonAppEntity.lastTouchAt` already exposed; defer unless users ask
- [ ] `OpenGroupIntent` — low value; defer
- [ ] Move `GroupAppEntity` to `Shared/` for both widget + main app — only needed when v2 adds Group-parameter intents
- [ ] Siri intent **donations** (`IntentDonationManager`) for on-device prediction — file when v1 usage is observed
- [ ] Custom result snippet views (e.g. streak SwiftUI view in LogTouch confirmation) — defer until dogfooding shows the plain dialog feels thin
- [ ] Interactive widgets / Control Center controls (issue #24 lives downstream of this)
- [ ] Focus filter integration, Apple Watch shortcuts, localization beyond English

### Lessons captured from #304

- App Intent phrases support exactly ONE `@Parameter` slot. Multi-parameter invocations must be entered via the Shortcuts editor; the metadata processor errors out at build time. Don't waste a phrase slot on `"Log a {method} with {person}"` — pick the single best slot per phrase
- Widget refresh is wired at the **repository layer** (`CoreDataPersonRepository.save/batchSave/delete`), not just in `BulkLogTouchUseCase`. Single-touch paths get widget refresh for free — don't add redundant `WidgetRefresher.reloadAllTimelines()` calls at view-model or use-case layer
- Wrap `/security-review` in a spawned `Agent` sub-agent when running it inside an autonomous loop. The skill has a known failure mode where it exits without posting a PR comment; the parent agent can recover by reading the sub-agent's text result and posting itself
- Core Data attribute names lag the domain rename: `PersonEntity.cadenceId` is named `groupId` in the .xcdatamodel, and `GroupEntity` (Core Data) maps to domain `Cadence`, while `TagEntity` (Core Data) maps to domain `Group`. Read the mapping files (`Data/CoreData/Mappings/`) before writing predicates against entity names

---

## Completed — Session 2026-05-17 → 2026-05-19 (Issue #293: Bulk Log Touch for Group Hangouts)

- [x] **#293** Log one TouchEvent against multiple people in a single flow — PR #303 squash-merged to main as `dc503d9`
  - Multi-select via "Select" filter chip on Home + "Select" header button on Contacts + long-press on rows/cards (Photos/Mail pattern)
  - `SelectionCoordinator` shared between Home + Contacts so selection carries across tabs
  - `BulkLogTouchUseCase.execute()` — fresh-batch path with newest-wins lastTouch* rule + rollback on partial failure
  - `BulkLogTouchUseCase.reconcile()` — batch-edit path (wipe-and-rewrite): deletes prior events, writes fresh ones, recomputes lastTouch* for affected persons via the shared `recomputeLastTouch` helper, with snapshot rollback if step-2 batchSave throws
  - `BulkLogTouchModal` with avatar chips (X-to-remove) above a reused single-touch form
  - `RecentGroupsStore` (UserDefaults) — last 3 distinct selections, one-tap reselection at the top of the picker; stores the *final* batch composition (post-edit), not the cumulative union
  - Success toast with "Forgot someone?" action chip — reopens picker with prior group pre-selected, carries forward method/notes/date, runs reconcile on second commit. Chained Forgot rounds supported (round 2 → round 3 → ...)
  - Subtitle "Editing last batch" + commit-label flip "Save changes" so users know they're editing, not creating
  - Helper `BulkLogTouchUseCase.recomputeLastTouch(for:from:now:)` shared with `PersonDetailViewModel.deleteTouch` — single-event undo and bulk batch-edit now flow through one source of truth
  - 11 new tests (use case happy paths, newest-wins, missing-person handling, reconcile delta + rollback + skip + edge cases, helper contract, snooze preservation)
  - 4 analytics events: `bulk_log.opened`, `bulk_log.committed`, `bulk_log.reconciled`, `forgot_someone.tapped`
- [x] Code review: 4 passes (initial, simplify, QA fixes, reconcile rework, DRY refactor) — all PASS, all sub-70 findings addressed inline
- [x] Security review: PASS — 0 exploitable findings (10 items considered)
- [x] Manual QA: 9-scenario matrix + 6 reconcile/batch-edit scenarios including date/notes change during edit pass — all passing

### Follow-ups deferred from #293

- [ ] Move `recomputeLastTouch` onto `Person` as `func recomputingLastTouch(from:now:) -> Person` (Domain layer) — drops PersonDetailViewModel's incidental dependency on BulkLogTouchUseCase. _(Code-review note, sub-70, architectural polish)_
- [ ] Stable chip ordering in `BulkLogTouchModal` — currently from `Set<UUID>` iteration, unstable between presentations. Fix when next form-field addition forces refactor anyway
- [ ] Extract shared `LogTouchFormBody` view — `BulkLogTouchModal` and `LogTouchModal` Forms duplicate the method/date/notes layout. Defer until the next form field gets added
- [ ] UI integration test for happy-path bulk log — deferred pending onboarding-bypass infrastructure
- [ ] TipKit `BulkSelectTip` for Select-chip discoverability — defer until dogfooding shows the affordance gets missed

---

## Completed — Session 2026-04-22 (Issue #283: Home 'All Caught Up' Banner)

- [x] **#283** Add celebratory banner on Home when tracked contacts exist but none are overdue/due-soon — matches widget's `hand.wave.fill` + "You've reached out to everyone. Way to go!" copy
  - New `AllCaughtUpView` component in `UI/Views/Home/`
  - `HomeViewModel.showsAllCaughtUpBanner` computed property gates visibility: tracked-non-empty + overdue/dueSoon empty + not during search (whitespace-only search allowed)
  - Inserted into `HomeView` content stack in place of overdue/due-soon sections; All Good list remains below
  - 5 new unit tests (fresh install / all on-track / overdue present / search active / whitespace-only search)

---

## Completed — Session 2026-04-22 (Issues #284, #286: Share FrequencyCalculator + Widget Tests)

- [x] **#284** Share FrequencyCalculator between app and widget (single PR with #286)
  - Introduced `FrequencyCalculatorPerson` / `FrequencyCalculatorCadence` protocols in `Shared/`
  - `Person` + `Cadence` conform via empty extensions (passthrough)
  - `FrequencyCalculator` moved to `Shared/`, methods generic over the protocols — 16 existing tests pass unchanged
  - `ContactStatus` moved to `Shared/`
  - `WidgetDataProvider.statusFor` rewritten to build lightweight adapter structs and delegate to `FrequencyCalculator` — widget and app now agree on `customDueDate` + grace-period (`groupAddedAt`) cases
- [x] **#286** Widget unit tests (reduced scope — `statusFor` collapsed into `FrequencyCalculatorTests` via #284)
  - Moved `WidgetDataProvider` testable core to `Shared/`; kept widget-only `loadSnapshot` wrapper in a loader file
  - New `WidgetDataProviderTests` — 12 tests covering `sortPriority` ordering, `snapshot` counts + featured prefix + pause/demo/untracked exclusion, and parity with `FrequencyCalculator` for customDueDate / grace-period / snoozed cases
- [x] Build: main app + widget compile clean
- [x] Full test suite passes (previously 341 + 12 new widget tests)

---

## Completed — Session 2026-04-22 (Issue #278: Nickname Display)

- [x] **#278** Display nickname in contact detail and list views (PR #287)
  - Added `Person.displayNickname` computed property with case-insensitive/trim dedupe against `displayName`
  - `ContactCard` renders inline parenthetical `Name (Nickname)` in secondary color via `Text + Text` concat
  - `PersonHeroSection` renders `\u{2018}Nickname\u{2019}` on secondary line below hero name
  - Accessibility: "also known as" on list, "Nickname" label on detail
  - 7 new unit tests covering nil/empty/whitespace/case-insensitive/trim/different-value
  - Follow-up commit: switched to `.foregroundStyle` on concatenated Text (iOS 17+ API)
- [x] Code review: PASS (one sub-threshold `.foregroundStyle` consistency fix committed in-branch)
- [x] Security review: PASS

---

## Completed — Session 2026-04-08 (Issues #274, #275: Search Improvements)

- [x] **#275** Enable nickname searching from contact info (PR #277)
  - Added `nickname` field to Person entity with Core Data v8 migration
  - Fetch `CNContactNicknameKey` from iOS Contacts during import and pull-to-refresh sync
  - Search on both Home and Contacts tabs now matches nickname in addition to displayName
  - 6 new unit tests, 341 total passing
- [x] **#274** Auto-expand groups with matching results during search (PR #277)
  - Auto-expand all collapsed Home tab status sections when search text is active
  - Restore previous collapse state when search is cleared
- [x] Code review: PASS
- [x] Security review: PASS

---

## Completed — Session 2026-03-30 (Issue #272: Search Bar Empty State Bug)

- [x] **#272** Fix search bar disappearing when search returns no results on Contacts tab (PR #273)
  - Added `contactsSearchBar` to the empty-search-results branch in ContactsListView
  - Users can now clear/edit search text when no results are found
- [x] Code review: PASS
- [x] Security review: PASS

---

## Completed — Session 2026-03-20 (Issue #268: Due Soon Home View Bug)

- [x] **#268** Fix Due Soon contacts missing from Home View when warningDays > dueSoonWindowDays (PR #269)
  - Removed redundant `dueSoonWindowDays` second filter from `PersonStatusService.dueSoonPeople()`
  - `FrequencyCalculator` is now single source of truth for Due Soon status
  - 331 unit tests passing
- [x] Code review: PASS
- [x] Security review: PASS

---

## Completed — Session 2026-03-10c (Issues #250, #230, #168: Tech Debt)

- [x] **#250** Fix Swift 6 actor-isolation warnings in OnboardingViewModel (PR #259)
  - Capture `@MainActor` properties before `@Sendable` closures
  - Create repos/seeder inline inside `backgroundContext.perform` closures
  - Dispatch `ErrorToastManager.shared.show()` via `Task { @MainActor in }`
- [x] **#230** Suppress weekly digest when single person already covered by daily breach (PR #259)
  - `digestPeople.count > 1` guard in `scheduleAll()`; 5 new/updated tests
- [x] **#168** Port `OnboardingViewModel.importSelectedContacts()` to `ContactImportService` (PR #259)
  - Remove ~60 lines of duplicate Person/TouchEvent creation logic
  - Add `touchEventRepository` to init; add `convenience init(dependencies:)`
- [x] 309 unit tests passing (up from 304)
- [x] Code review: PASS (1 informational note re: ContactImportService ignoring injected repos — pre-existing, filed as follow-up)
- [x] Security review: PASS

---

## Completed — Session 2026-03-10b (Issue #246: Foreground Notifications)

- [x] **#246** Notifications silently suppressed when app is in foreground (PR #257)
  - Added `userNotificationCenter(_:willPresent:withCompletionHandler:)` to AppDelegate
  - Calls completion with `[.banner, .sound, .badge]` — applies to all notification types
  - 304 unit tests passing
- [x] Code review: PASS
- [x] Security review: PASS

---

## Completed — Session 2026-03-10 (Issues #248, #249, #232)

- [x] **#232** Pull-to-refresh re-sync contact info from iOS Contacts (PR #255, merged)
- [x] **#249** Fix blank import screen on first file selection (PR #251, merged)
- [x] **#248** Extract notifications section into NotificationSettingsView sub-screen (PR #256)
  - New `NotificationSettingsView` with 4 sections: Connection Reminders, Weekly Digest, Birthday Reminders, Privacy
  - SettingsView simplified to single NavigationLink
  - Post-review fixes: accessibility annotations on Reminder Time/Digest Day/Digest Time buttons, restored "Alert Time" sheet title
- [x] Code review: PASS
- [x] Security review: PASS

---

## Completed — Session 2026-03-09c (Issue #106: Notification Privacy)

- [x] **#106** Hide names in notifications — new `hideContactNamesInNotifications` AppSettings toggle (PR #244)
- [x] Core Data v5 → v6 lightweight migration for new boolean attribute
- [x] 4 new notification privacy tests, 280 total tests passing
- [ ] **#105** Screenshot blur — deferred after 3 failed approaches (SwiftUI overlay, separate UIWindow, key window subview). UIVisualEffectView cannot blur cross-window; key window subview still rendered opaque. Needs deeper investigation.
- [x] Code review: PASS
- [x] Security review: PASS

---

## Completed — Session 2026-03-09b (Issues #235, #236: UX Polish)

- [x] **#235** Fix HIG tap target compliance on unavailable contact banner (PR #243)
- [x] Added `DS.Spacing.tapTarget` (44pt) design system token
- [x] Restructured banner: info row on top, horizontal action row below with 44pt min-height buttons
- [x] **#236** Display multiple groups on contact cards (PR #242)
- [x] Code review: PASS (both PRs)
- [x] Security review: PASS (both PRs)

---

## Completed — Session 2026-03-09a (Issue #137: Fresh Start for Inactive Users)

- [x] **#137** Auto-prompt Fresh Start for inactive or overwhelmed users (PR #227)

---

## Completed — Session 2026-03-09 (Issues #229, #237, #228)

- [x] **#229** Fix app version display — replace PlistBuddy with build-phase-generated Swift file (PR #238)
- [x] **#237** Add `alwaysOutOfDate` to version build phase for incremental builds (PR #238)
- [x] **#228** Audit and update TelemetryDeck events after refactors (PR #240)
- [x] Swapped filter analytics parameters corrected: `selectedGroupId` → "group", `selectedTagId` → "tag"
- [x] Added new signals: `freshStart.confirmed`, `data.exported`, `data.imported`
- [x] Code review: PASS (all 3 PRs)
- [x] Security review: PASS (all 3 PRs)
- [x] **#241** Filed issue for backend terminology rename (Group→Cadence, Tag→Group) — post-beta
- [x] Updated TelemetryDeck dashboard JSON with all 25 signals (31 insights)

---

## Completed — Session 2026-03-06 (Issue #208: Contact Import State Enum)

- [x] **#208** Replace onChange modal chains with ContactImportStep enum (PR #221)
- [x] 7 @State variables → 2, 2 onChange chains → 0, single sheet(item:) with onDismiss
- [x] Code review: PASS
- [x] Security review: PASS
- [x] Defensive fix: clear pendingImportStep on all cancel paths

---

## Completed — Session 2026-03-06 (Issue #207: Extract SettingsViewModel Services)

- [x] **#207** Extract SettingsViewModel import/export into dedicated services (PR #220)
- [x] Created `ExportModels.swift` — shared data structures for import/export
- [x] Created `DataExportService.swift` — JSON export logic
- [x] Created `DataImportService.swift` — JSON import parsing, execution, contact matching
- [x] Created `ContactImportService.swift` — device address book contact import
- [x] SettingsViewModel reduced from 1,084 → ~400 lines (thin orchestrator)
- [x] Code review: PASS (no issues above threshold)
- [x] Security review: PASS
- [x] Post-review fixes: thread safety for viewContext access (score 75), AppSettingsDefaults placement (score 65)
- [x] All 22 SettingsViewModel tests pass unchanged

---

## Completed — Session 2026-03-04 (Issue #173: fullScreenCover Detail Presentation)

- [x] **#173** Change PersonDetailView from NavigationLink push to fullScreenCover with DismissableFullScreenCover wrapper
- [x] New DismissableFullScreenCover component: rounded top corners, drag handle, X button, drag-to-dismiss
- [x] Lifted selectedPerson state to MainTabView — single fullScreenCover serves Home + Contacts tabs
- [x] Deep link processing moved from HomeView to MainTabView
- [x] ContactListSection + ContactsListView: NavigationLink → Button with selectPerson closure
- [x] Code review: caught PausedContactsView nav trap — fixed by removing .navigationBarHidden(true)
- [x] Security review: PASS

---

## Completed — Session 2026-03-02 (Issue #152: Date Calculation Bug)

- [x] **#152** Fix "Today" shown for contacts touched yesterday — normalize to calendar days instead of 24-hour periods
- [x] FrequencyCalculator: `daysSinceLastTouch()`, `status()`, `daysOverdue()` all use `startOfDay` normalization
- [x] 3 new edge-case tests for calendar-day boundary scenarios, all pass

---

## Completed — Session 2026-03-01 (Issues #140 + #141: Birthday Display)

- [x] **#140** Remove "last connected" badge from PersonDetailView header
- [x] **#141** Add birthday display to contact detail page — cake icon + M/DD format, CNContact auto-pull, manual override, edit sheet
- [x] New `Birthday` value object, Core Data v4 model, ContactsFetcher birthday fetch, export/import support
- [x] 8 new Birthday tests + 4 ViewModel birthday tests, all tests pass

---

## Completed — Session 2026-02-27d (Onboarding UX Polish)

- [x] **PR 94 fixes** Fix onboarding progress bar and layout issues — custom capsule progress bar, unique fractions per step, vertical centering Spacers, hide bar on welcome, 8 new/updated progress tests

## Completed — Session 2026-02-27c (Contact Photos + Multi-value Picker + Onboarding Nav)

- [x] **#72** Display contact photos from iOS Contacts — on-demand thumbnail fetch with NSCache, initials fallback (PR #92)
- [x] **#51** Show picker when contact has multiple phone numbers or emails — LabeledValue struct, confirmationDialog pickers (PR #93)
- [x] **#58** Add back navigation and progress indicator to onboarding — history stack, progress bar, back button, 13 new tests (PR #94)

## Completed — Session 2026-02-27b (Notifications + Import)

- [x] **#71** Notification-tapped contact opens as navigation push instead of modal sheet (PR #90)
- [x] **#73** JSON import to complement existing export — file picker, preview screen, conflict resolution (PR #91)

## Completed — Session 2026-02-27 (Performance + Export + UX)

- [x] **#81** Optimize contact fetching — add `fetchBatchSize=50` to all fetch requests, rewrite `fetchOverdue()` with predicate-based filtering (PR #86)
- [x] **#74** Enrich data export — add `groupName`, `tagNames`, and `touchEvents` array to exported JSON (PR #87)
- [x] **#59** Add "Reset All Frequencies" emergency button in Settings with confirmation dialog (PR #88)
- [x] **#43** Add "Last connected Xd ago" timestamp to PersonDetailView hero zone (PR #89)

## Completed — v0.2.2 (Critical + Performance + UX)

- [x] **#62** Optimize FrequencyCalculator — single instance per render (was creating hundreds of instances in ForEach)
- [x] **#54** Auto-log touch after quick action with undo on return (Call/Message/Email now auto-log, undo banner on app return)
- [x] **#53** Handle limited contact access dead end (shows "grant full access" alert instead of "up to date")
- [x] **#61** Improve notification reliability with repeating triggers (daily/weekly notifications now fire reliably + foreground rescheduling)
- [x] **#33** Add DS.Typography.heroTitle token — PersonDetailView name uses design system font
- [x] **#63** Batch CoreData saves during contact import (single save instead of per-contact)
- [x] **#36** Add undo for person deletion with 5-second timed banner
- [x] **#75** Quick-log touch from notification action ("Log Connection" button on person reminders)
- [x] **#38** Replace WrapLayout stub and HStack filter chips with proper FlowLayout (Layout protocol)
- [x] Build number bumped to 8, version 0.2.2

## Completed — v0.2.1 (Critical Issues)

- [x] **#57** Reframe SLA terminology to consumer-friendly language (ContactStatus, FrequencyCalculator)
- [x] **#55** CoreData versioned migration strategy (v2 model, safe migration, no auto-delete)
- [x] **#35** Surface errors with contextual banners (ErrorToast system, ViewModel try? audit)
- [x] **#56** Handle deleted/merged contacts (contactUnavailable flag, sync detection, UI banner)
- [x] Build number bumped to 6, version 0.2.1

## Completed — v0.2.0 (UX Redesign)

- [x] **PR #29** Full UX redesign — centralized design system, modern filter patterns, streamlined info hierarchy
- [x] **#30** Rename all UI "Tags" → "Groups" (8 strings across 5 files)
- [x] **#31** Fix section header color contrast for WCAG AA (primaryText + colored dot)
- [x] **#32** Fix filter chip X button touch targets (minWidth: 44)
- [x] Bug fix: Section header font weight `.semibold` → `.bold` for light mode legibility
- [x] Bug fix: Filter chip height inflation from `minHeight: 44` — removed
- [x] Bug fix: Settings section headers (FREQUENCY/GROUPS/NOTIFICATIONS) `tertiaryText` → `secondaryText`
- [x] Version numbering revised from v1.x.x → v0.x.x (pre-beta)
- [x] GitHub releases recreated: v0.1.0, v0.1.1, v0.2.0 (all pre-release)
- [x] README streamlined from 525 → 81 lines
- [x] License changed from MIT → All Rights Reserved
- [x] `design-review.md` created with full critique

## Completed — v0.1.1

- [x] **#20** Remove trailing period from notification body text
- [x] **#18** Display dynamic app version/build in Settings
- [x] **#21** Replace notification titles with friendlier copy
- [x] **#19** Show due date in cadence section of detail view
- [x] **#7** Add forward-looking notes field to person detail
- [x] **#22** Add randomized notification copy variations
- [x] **#13** Add morning/afternoon/evening time picker to Log Touch
- [x] **#23** Add snooze/defer due date per contact
- [x] **#8** Add group assignment step when importing from Settings
- [x] **#25** Fix empty group assignment list (SwiftUI sheet stacking bug)
- [x] **#24** Redesign visual language (subsumed by PR #29)

---

## Milestone: TestFlight Readiness

### Resolved (Build 6+)
- [x] PrivacyInfo.xcprivacy, deployment target 17.0, UIBackgroundModes
- [x] Clean build, 278+ unit tests passing, app icon, error handling, safe migration, deleted contact handling

### Before App Store (not TestFlight blockers)
- [ ] Full accessibility audit (VoiceOver, Dynamic Type) — #39, #197, ~~#202~~
- [ ] **#49** Create and host privacy policy URL
- [ ] App Store screenshots (use demo mode)
- [ ] **README screenshots** Add 2-3 evergreen shots (Home, widget on home screen, contact detail) to README under `docs/screenshots/`. Reuse App Store marketing shots when produced. *(XS — pairs with App Store screenshot prep)*
- [ ] Edge-case testing (timezone changes, large contact lists)
- [ ] Performance testing (100+ contacts, launch time)

### Manual Steps Remaining
See `tasks/testflight-guide.md`:
- [ ] Verify Apple Developer account enrollment
- [ ] Register App ID in Developer Portal
- [ ] Create App Store Connect record
- [ ] Archive and upload via Xcode
- [ ] Configure TestFlight and add testers

---

## Post-Beta (Future)

- [ ] **#241** Rename backend terminology: Group→Cadence, Tag→Group (tech debt)
- [ ] CloudKit sync
- [ ] Shortcuts integration
- [x] Widgets *(shipped v0.4.0 — PR #282)*
- [ ] Manual contact creation
- [ ] macOS companion app
