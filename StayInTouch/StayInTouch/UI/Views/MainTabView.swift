//
//  MainTabView.swift
//  KeepInTouch
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared
    @StateObject private var selectionCoordinator = SelectionCoordinator()
    @State private var selectedPerson: Person?
    @State private var freshStartReason: FreshStartDetector.Reason?
    @State private var bulkLogState: BulkLogPresentation?
    @State private var batchEditContext: BatchEditContext?
    @State private var recentGroups: [RecentGroup] = []
    @State private var paywallTrigger: PaywallTrigger?
    private let recentGroupsStore = RecentGroupsStore()
    @Environment(\.dependencies) private var dependencies
    @EnvironmentObject private var purchaseManager: PurchaseManager

    var body: some View {
        TabView(selection: $deepLinkRouter.selectedTab) {
            HomeView(
                viewModel: viewModel,
                selectionCoordinator: selectionCoordinator,
                recentGroups: recentGroups,
                selectPerson: { selectedPerson = $0 }
            )
                .tabItem {
                    Image(systemName: deepLinkRouter.selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)

            ContactsListView(
                viewModel: viewModel,
                selectionCoordinator: selectionCoordinator,
                recentGroups: recentGroups,
                selectPerson: { selectedPerson = $0 }
            )
                .tabItem {
                    Image(systemName: deepLinkRouter.selectedTab == 1 ? "person.2.fill" : "person.2")
                    Text("Contacts")
                }
                .tag(1)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Image(systemName: deepLinkRouter.selectedTab == 2 ? "gearshape.fill" : "gearshape")
                Text("Settings")
            }
            .tag(2)
        }
        .toolbarBackground(.visible, for: .tabBar)
        .tint(DS.Colors.accent)
        .safeAreaInset(edge: .bottom) {
            if selectionCoordinator.isSelectMode {
                SelectionActionBar(
                    count: selectionCoordinator.count,
                    subtitle: batchEditSubtitle,
                    onCancel: { selectionCoordinator.exit() },
                    onCommit: { commitBulkLog() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectionCoordinator.isSelectMode)
        .onChange(of: selectionCoordinator.isSelectMode) { _, isOn in
            // Any path that exits select mode — action-bar Cancel, the
            // Home "Selecting" chip toggle, the Contacts "Select" header
            // button, or post-commit cleanup — must drop the carry-
            // forward `batchEditContext`. Centralizing the invalidation
            // here keeps every exit site honest without coupling the
            // coordinator to bulk-log state.
            if !isOn { batchEditContext = nil }
        }
        .successToast()
        .overlay {
            // Dimming lives here so it fades in place instead of
            // sliding with the fullScreenCover transition.
            if selectedPerson != nil {
                DS.Colors.sheetOverlay
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedPerson != nil)
        .fullScreenCover(item: $selectedPerson) { person in
            DismissableFullScreenCover {
                PersonDetailView(person: person)
            }
        }
        .sheet(item: $bulkLogState) { state in
            bulkLogSheet(for: state)
        }
        .sheet(item: $paywallTrigger) { trigger in
            PaywallView(source: trigger.source)
                .environmentObject(purchaseManager)
        }
        .onChange(of: deepLinkRouter.pending) { _, newValue in
            if newValue != nil { processPendingDeepLink() }
        }
        .onAppear {
            processPendingDeepLink()
            recentGroups = recentGroupsStore.load()
            // onChange misses the initial value when evaluation
            // completes during HomeViewModel.init() before the
            // modifier is registered, so check it here.
            if let reason = viewModel.freshStartReason, selectedPerson == nil {
                freshStartReason = reason
            }
        }
        .onChange(of: viewModel.freshStartReason) { _, newValue in
            if newValue != nil && selectedPerson == nil {
                freshStartReason = newValue
            }
        }
        .fullScreenCover(item: $freshStartReason, onDismiss: {
            // SwiftUI defers re-rendering of views behind a
            // fullScreenCover, so the Home tab may still show
            // stale status indicators after executeFreshStart()
            // updates data while the cover is up. Re-loading
            // here fires after the cover is fully gone,
            // guaranteeing the visible view re-renders.
            viewModel.load()
        }) { reason in
            FreshStartPromptView(
                reason: reason,
                onFreshStart: {
                    await viewModel.executeFreshStart()
                    freshStartReason = nil
                },
                onDismiss: {
                    viewModel.dismissFreshStartPrompt()
                    freshStartReason = nil
                }
            )
        }
    }

    // MARK: - Deep Link Processing

    private func processPendingDeepLink() {
        guard let destination = deepLinkRouter.pending else { return }
        deepLinkRouter.pending = nil

        switch destination {
        case .person(let id):
            deepLinkRouter.selectedTab = 0
            if let person = dependencies.personRepository.fetch(id: id) {
                selectedPerson = person
            }
        case .home:
            deepLinkRouter.selectedTab = 0
            viewModel.selectedCadenceId = nil
            viewModel.selectedGroupId = nil
            viewModel.applyFilters()
        }
    }

    // MARK: - Bulk Log

    /// Snapshot of the bulk-log sheet's pre-fill state. Created on every
    /// commit (first pass or batch edit). When `batchEditContext` is set,
    /// the values carry forward from the prior pass.
    struct BulkLogPresentation: Identifiable {
        let id = UUID()
        let people: [Person]
        var method: TouchMethod = .irl
        var notes: String = ""
        var date: Date = Date()
        var timeOfDay: TimeOfDay? = nil
    }

    /// State carried between commits in the "Forgot someone?" batch-edit
    /// flow. Tapping the toast chip reopens the picker with the prior
    /// people pre-selected; the user can freely add / remove people, and
    /// the next commit reconciles against `priorEvents` (deleting events
    /// for people who got removed, writing fresh events for everyone in
    /// the new selection).
    struct BatchEditContext {
        /// The events committed in the previous pass, keyed by personId.
        /// On reconcile, every one of these is deleted; new events are
        /// written for whoever's in the final selection.
        let priorEvents: [UUID: TouchEvent]
        let method: TouchMethod
        let notes: String
        let date: Date
        let timeOfDay: TimeOfDay?

        var priorPersonIds: [UUID] { Array(priorEvents.keys) }
        var priorEventIds: [UUID] { priorEvents.values.map(\.id) }
    }

    private func commitBulkLog() {
        guard selectionCoordinator.hasSelection else { return }
        if !purchaseManager.isPro {
            AnalyticsService.track("pro.gate_tapped", parameters: ["source": "bulk_log"])
            paywallTrigger = PaywallTrigger(source: "bulk_log")
            return
        }
        let ids = Array(selectionCoordinator.selection)
        let people = ids.compactMap { dependencies.personRepository.fetch(id: $0) }
        if let ctx = batchEditContext {
            // Editing an existing batch — pre-fill form values from the
            // prior pass so users don't retype.
            bulkLogState = BulkLogPresentation(
                people: people,
                method: ctx.method,
                notes: ctx.notes,
                date: ctx.date,
                timeOfDay: ctx.timeOfDay
            )
        } else {
            bulkLogState = BulkLogPresentation(people: people)
        }
    }

    /// Subtle subtitle on the action bar communicating that this commit
    /// will modify the prior batch rather than create a fresh one.
    private var batchEditSubtitle: String? {
        guard batchEditContext != nil else { return nil }
        return "Editing last batch"
    }

    @ViewBuilder
    private func bulkLogSheet(for state: BulkLogPresentation) -> some View {
        BulkLogTouchModal(
            people: state.people,
            initialMethod: state.method,
            initialNotes: state.notes,
            initialDate: state.date,
            initialTimeOfDay: state.timeOfDay,
            onSave: { method, notes, date, timeOfDay, peopleIds in
                handleBulkSave(
                    method: method,
                    notes: notes,
                    date: date,
                    timeOfDay: timeOfDay,
                    finalPersonIds: peopleIds
                )
            },
            onRemove: { id in
                selectionCoordinator.remove(id)
            }
        )
    }

    /// Routes the modal's Done event to either a fresh `execute` (first
    /// pass) or a `reconcile` (batch edit). Both paths post a success
    /// toast that offers another "Forgot someone?" round — every commit
    /// rolls into the next `BatchEditContext`.
    private func handleBulkSave(
        method: TouchMethod,
        notes: String?,
        date: Date,
        timeOfDay: TimeOfDay?,
        finalPersonIds: [UUID]
    ) {
        let useCase = BulkLogTouchUseCase(
            personRepository: dependencies.personRepository,
            touchEventRepository: dependencies.touchEventRepository
        )
        let editing = batchEditContext

        do {
            let nextContext: BatchEditContext?
            let toastMessage: String
            let skippedCount: Int

            if let editing {
                // BATCH EDIT pass: delete prior events, write fresh events
                // for the final selection, recompute lastTouch* for every
                // person on either side of the delta.
                let result = try useCase.reconcile(
                    priorEventIds: editing.priorEventIds,
                    priorPersonIds: editing.priorPersonIds,
                    finalPersonIds: finalPersonIds,
                    method: method,
                    notes: notes,
                    date: date,
                    timeOfDay: timeOfDay
                )
                AnalyticsService.track("bulk_log.reconciled", parameters: [
                    "added": String(result.added),
                    "removed": String(result.removed),
                    "method": method.rawValue
                ])
                nextContext = Self.makeBatchEditContext(
                    from: result.writtenEvents,
                    method: method,
                    notes: notes,
                    date: date,
                    timeOfDay: timeOfDay
                )
                let n = result.writtenEvents.count
                toastMessage = "Updated batch — \(n) \(n == 1 ? "connection" : "connections")"
                skippedCount = result.skippedPersonIds.count
            } else {
                // FIRST PASS: write fresh events for the selection. The
                // returned `writtenEvents` seed the next BatchEditContext.
                let result = try useCase.execute(
                    personIds: finalPersonIds,
                    method: method,
                    notes: notes,
                    date: date,
                    timeOfDay: timeOfDay
                )
                AnalyticsService.track("bulk_log.committed", parameters: [
                    "count": String(result.touchEventsWritten),
                    "method": method.rawValue
                ])
                nextContext = Self.makeBatchEditContext(
                    from: result.writtenEvents,
                    method: method,
                    notes: notes,
                    date: date,
                    timeOfDay: timeOfDay
                )
                let n = result.touchEventsWritten
                toastMessage = "Logged \(n) \(n == 1 ? "connection" : "connections")"
                skippedCount = result.skippedPersonIds.count
            }

            // RecentGroups always reflects the *final* set of people in
            // the batch (post-edit), not the cumulative union — that way
            // if a user starts with [A,B,C,D] then edits to [A,B] the
            // recent-groups entry is the edited pair, matching their
            // actual mental model of "the dinner I had".
            if let nextContext, !nextContext.priorPersonIds.isEmpty {
                recentGroupsStore.append(personIds: nextContext.priorPersonIds)
                recentGroups = recentGroupsStore.load()
            }

            // HomeView observes `.personDidChange` and reloads.
            NotificationCenter.default.post(name: .personDidChange, object: nil)

            var message = toastMessage
            if skippedCount > 0 {
                message += " (skipped \(skippedCount))"
            }

            // Offer another round of editing only when there's something
            // to edit (at least one event survived the reconcile).
            let canOfferAnotherRound = (nextContext?.priorEvents.isEmpty == false)
            SuccessToastManager.shared.show(
                message,
                actionTitle: canOfferAnotherRound ? "Forgot someone?" : nil
            ) {
                AnalyticsService.track("forgot_someone.tapped")
                guard let nextContext else { return }
                // Re-enter select mode with the FINAL group pre-selected
                // — the user can now add or remove freely, and the next
                // commit will reconcile against this batch.
                batchEditContext = nextContext
                bulkLogState = nil
                selectionCoordinator.enter(origin: selectionCoordinator.origin)
                selectionCoordinator.setSelection(nextContext.priorPersonIds)
            }

            bulkLogState = nil
            // `batchEditContext` is cleared by the centralized onChange
            // handler when isSelectMode flips to false on exit().
            selectionCoordinator.exit()
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "MainTabView.handleBulkSave")
            ErrorToastManager.shared.show(AppError(message: "Couldn't log touches. Please try again."))
            // Keep the sheet open so the user can retry without losing
            // their typed notes or selection.
        }
    }

    /// Pure helper: bundles up the just-written events + the current form
    /// values into a `BatchEditContext` for the next round. Returns nil
    /// when no events were written so the caller can short-circuit the
    /// "Forgot?" affordance.
    private static func makeBatchEditContext(
        from events: [TouchEvent],
        method: TouchMethod,
        notes: String?,
        date: Date,
        timeOfDay: TimeOfDay?
    ) -> BatchEditContext? {
        guard !events.isEmpty else { return nil }
        var priorEvents: [UUID: TouchEvent] = [:]
        for event in events {
            priorEvents[event.personId] = event
        }
        return BatchEditContext(
            priorEvents: priorEvents,
            method: method,
            notes: notes ?? "",
            date: date,
            timeOfDay: timeOfDay
        )
    }
}
