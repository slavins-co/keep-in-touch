# iOS 27 SDK + iPhone Duo readiness plan

- Created: 2026-10-18
- Status: **approved** (2026-10-18: Brad approved all 13 decisions as recommended; every issue is open, #366-#391; implementation not started)
- Milestone: GitHub milestone 4 "iOS 27 + iPhone Duo readiness" (due 2027-03-31 as the working deadline for Apple's "April 2027" rules)
- Epic: #377
- Research (local, gitignored): `tasks/research/ios27-duo/` - `research-iphone-duo.md`, `research-ios27-sdk.md`, `research-ios27-adoption.md`, `audit-codebase.md`. Every claim there carries an Apple URL or is marked UNVERIFIED.
- This file is gitignored (`tasks/`); `git add -f` it in the first implementation PR.

## Summary

- iPhone Duo ships 2026-10-23 on iOS 27.1. The SDK an app is built with decides how it appears: iOS 26 SDK = letterboxed compatibility box (what v0.5.0 does today), 27.0 SDK = fills the display with horizontal bars, **27.1 SDK = full screen with vertical side bars**. Xcode 27.1 (27A9275) went GA 2026-10-15 and runs on this Mac (macOS 26.7.1); only Xcode 26.4 is installed.
- Apple deadlines: from **April 2027** every App Store upload must use the iOS 27 SDK or later and every submission must include iPhone Duo screenshots (outer 1398x2034, inner 2007x2853).
- Hard-requirement audit: **no blockers**. Launch-screen key present (generated `UILaunchScreen`), scene lifecycle already adopted, `UIDesignRequiresCompatibility` never set, no Face ID or LocalAuthentication code, no `UIScreen.main`/idiom/orientation logic.
- Known breakage on the 27 SDK: `@State` is a macro; `PersonDetailView.swift:25/45` hits the documented "inline default + init assignment is discarded" case (TN3211). TabView can crash if selection points at an unavailable tab.
- Duo-specific findings: zero adaptive layout (0 size-class reads, 0 `NavigationSplitView`); the inner display reports regular/regular and **ignores the portrait-only lock (#194)**; 38 text-only toolbar buttons never move into the vertical rail; the app already allows multiple windows (generated `UIApplicationSupportsMultipleScenes = true`) while the privacy blur, contact picker and `DeepLinkRouter` assume one window.
- CI runs Xcode 26.6 on `macos-26` and cannot see Xcode 27 at all; Xcode 27.1 lives on GitHub's `xcode-27` preview runner.
- Best-in-class scan: no competitor states Duo optimization; only Contacts Journal shipped iOS 27 Siri/Spotlight (Oct 7). No App Intents schema domain covers "log a touch", so Siri logging stays an App Shortcut; `.system.open` and `.system.searchInApp` fit. Foundation Models fit on-device only (no Private Cloud Compute).

## Decisions (approved 2026-10-18, all as recommended)

Brad approved every recommendation below on 2026-10-18. The text is kept as the rationale record; the **Recommend** clause in each item is the decision.

1. **Inner-display (and iPad) layout architecture.** A: list + detail split (`NavigationSplitView` for Home and Contacts, Person detail in the detail column instead of a `fullScreenCover`, Settings/Onboarding/Stats capped to a readable width). B: single column capped at ~600pt, centered. C: leave stretched. **Recommend A, staged: ship B's readable-width cap in the first Duo-ready release, then A.** Pros A: Apple's pattern (HIG: one extra hierarchy level on the inner display), collapses to one stack on the outer display for free, also fixes iPad (#78). Cons: L-size, touches Home/Contacts/PersonDetail navigation. Supersedes #78.
2. **Orientation on iPhone.** A: add landscape (reverses #194; Apple says multitasking apps should support all orientations; enables the tent pose). B: keep the portrait lock on the outer display, fix only the forced inner-display landscape (#369). **Recommend B now**; flip to A if a TestFlight upload of a 27.1-SDK build is rejected for portrait-only (unverified risk).
3. **Multi-window.** A: disable (`UIApplicationSupportsMultipleScenes = NO`, also disables iPad multi-window nobody asked for). B: embrace (per-scene privacy blur, per-scene contact-picker presentation, per-scene `DeepLinkRouter`/toasts/one-shot flows: 3 issues). **Recommend A**; Split View next to other apps still works with one scene, and the current single-scene code is then correct.
4. **Search and custom chrome (Liquid Glass).** A: adopt system `.searchable` (bottom placement on iOS 26+, participates in Duo vertical rails), restyle `SelectionActionBar` as glass or `tabViewBottomAccessory`, drop `.toolbarBackground(.visible, for: .tabBar)`, keep custom headers under the scroll-edge effect. B: keep the floating search pill, restyle only. **Recommend A** (the custom pill is the biggest "never goes vertical" liability). Visible UX change: search moves from the floating pill to the system placement.
5. **Minimum iOS.** Keep 17 / raise to 18 / raise to 26. **Recommend 18 now** [ASSUMPTION: iOS 18 runs on every iOS 17 device, so no device is lost; verify against TelemetryDeck's OS split before deciding]. 18 unlocks the `Tab` API (`.tabItem` is deprecated at 27.2), `IndexedEntity`, `ControlWidget`, view annotations. Revisit 26 in 2027.
6. **On-device AI (Foundation Models).** Principle only: none / on-device only, opt-in / also Private Cloud Compute. **Recommend on-device only, opt-in, never PCC**, scoped as its own epic after the Duo milestone (catch-up brief of recent notes; next-touch suggestion; natural-language quick log).

Small ones (approved as a batch):

7. Tab bar on the inner display: keep the tab bar (vertical rail); no sidebar for 3 tabs.
8. Siri from the Lock Screen: `authenticationPolicy = .requiresAuthentication` on every intent that reads names or writes; Log Touch needs no confirmation step (the dialog says what was logged; `UndoableIntent` when the minimum reaches 26).
9. Spotlight indexing scope: names, nicknames, group and cadence names only; never notes; demo rows excluded; controlled by one "hide names outside the app" setting generalized from `hideContactNamesInNotifications`.
10. Widget names on shared surfaces (Apple HomeView Modular face, StandBy): honor the same setting plus `.privacySensitive()`.
11. Swipe-to-log on Home via `swipeActionsContainer` (iOS 27-only gesture; older OS keeps the tap flow): fold into #34.
12. App icon: author an Icon Composer `.icon` so the Liquid Glass/dark/tinted variants are designed, not auto-generated. Brad reviews the look.
13. App Intents Testing bundle: run locally first; add to the non-required Xcode 27.1 CI job later.

## Detailed plan

### Phase 0 - toolchain and compliance (no decisions needed) - OPEN
- [ ] #366 Xcode 27.1 / iOS 27.1 SDK first clean build, `@State` fix, TabView guard, docs
- [ ] #367 CI: pin Xcode; add Xcode 27.1 job on `xcode-27`
- [ ] #370 Bug: dead `applicationWillEnterForeground` hook
- [ ] #371 Privacy manifest CA92.1
- [ ] #376 App Store Connect checklist (age rating, DPLA, review notes for the sandbox Pro grant, Duo screenshot sizes)

### Phase 1 - first Duo-ready release (27.1 SDK, full screen, vertical bars) - OPEN
Minimum to ship a 27.1-SDK build: #366 + #368 + #369, then #372.
- [ ] #368 Vertical bars: icons + semantic placements on 38 toolbar buttons
- [ ] #369 Compact layout survives ~469pt Split View halves and forced inner-display landscape
- [ ] #372 Duo QA pass (poses, both displays, Split View, fold/unfold)
- [ ] #373 Layout previews/tests by size class
- [ ] #375 Accessibility hygiene
- [ ] #380 Orientation decision record: keep the portrait lock; verify a 27.1-SDK TestFlight upload
- [ ] #381 Disable multiple windows
- [ ] #383 Deployment target 18 + `Tab` API
- [ ] #389 Icon Composer icon
- [ ] #378 Readable-width cap on regular width (stage one of the split)

### Phase 2 - Duo-optimized release (before April 2027)
- [ ] #379 Regular-width split layout: Home/Contacts list + Person detail column; Settings/Onboarding/Stats readable width (supersedes #78)
- [ ] #382 System search + glass chrome
- [ ] #387 Widget privacy and rendering pass (hide-names setting, `privacySensitive`, tinted/clear/StandBy); #388 Control Center "Log a connection" control (COULD)
- [ ] #391 Duo screenshots at 1398x2034 and 2007x2853 (ties #65); upload for the "optimized for iPhone Duo" badge
- [ ] #374 Deprecation cleanup

### Phase 3 - best-in-class platform adoption
- [ ] #384 App Intents hardening (`authenticationPolicy`, Snooze + Pause/Resume, voice `IntentDialog`, donations, no upsell copy)
- [ ] #385 Spotlight `IndexedEntity` + `IndexedEntityQuery`, `.system.open` on OpenPerson, `.system.searchInApp`, view annotations (names only, never notes)
- [ ] #386 App Intents Testing bundle (local first, then the non-required 27.1 CI job)
- [ ] #34 Swipe-to-log via `swipeActionsContainer` (iOS 27 gate; approach posted as a comment 2026-10-18)
- [ ] #390 Apple Intelligence epic (on-device only, opt-in, never PCC; sequenced after this milestone, not in milestone 4)

### Not doing (checked)
Private Cloud Compute (network egress), Live Activities, `systemExtraLargePortrait` (HIG: not on iPhone), Visual Intelligence, Reminders/Notes/Messages schemas (domain mismatch), `.xcproj` project-format conversion (release procedure edits `project.pbxproj`).

### Follow-ups to file in the Claude reminders list
- April 2027: iOS 27 SDK upload rule + Duo screenshots become mandatory (check milestone 4 state by 2027-02-01).
- 2026-10-23+: verify widgets, StandBy and Lock Screen on Duo hardware (simulator cannot run extensions).
