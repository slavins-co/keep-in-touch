# Apple Framework Gotchas (Keep In Touch)

Confirmed-in-codebase lifecycle traps. The pattern is the same in every case: the
fix has to land at the right lifecycle point. Iterating at the wrong point can
never work, no matter how many attempts. When a framework behavior won't respond
to a plausible fix after one attempt, check the lifecycle point before writing
attempt two.

- **App Intents** - validate in `EntityQuery.entities(for:)`, which runs BEFORE
  `perform()`. A `throw` in `perform()` for an invalid entity is effectively dead
  code, because the framework has already resolved (or mis-resolved) the
  parameter by then. See [PersonAppEntity.swift:65](../StayInTouch/StayInTouch/AppIntents/PersonAppEntity.swift) -
  stale ids get a tombstone entity in `entities(for:)` so each intent's
  fetch-guard in `perform()` can surface a clear "no longer in Keep In Touch"
  error instead of the framework silently showing a bare contact picker.

- **TipKit** - `Tips.resetDatastore()` only works BEFORE `Tips.configure()`;
  calling it afterward is a silent no-op, so a runtime user-initiated "reset
  tips" can't take effect in the current session. Workaround in
  [TipsDatastore.swift:1](../StayInTouch/StayInTouch/UI/Views/Tutorial/Tips/TipsDatastore.swift) -
  configure a versioned datastore path keyed on a `tipsDatastoreEpoch` counter
  and bump the epoch on reset, so the next launch reads a fresh empty store.

- **SwiftUI** - `.contextMenu` on a Button with a custom `ButtonStyle` has
  unreliable long-press recognition. Use `Menu(content:label:primaryAction:)` for
  "tap = primary action, long-press = menu" instead. See
  [PersonQuickActionsBar.swift:59](../StayInTouch/StayInTouch/UI/Views/PersonDetail/PersonQuickActionsBar.swift).

- **WidgetKit** - `.containerBackground(_:for:)` captures its ShapeStyle OUTSIDE
  the view's environment, so `.fill.tertiary` and friends won't flip in response
  to `.environment(\.colorScheme)`. Pass a resolved `Color(uiColor:)` instead.
  See [KeepInTouchWidget.swift:129](../StayInTouch/KeepInTouchWidget/KeepInTouchWidget.swift).
