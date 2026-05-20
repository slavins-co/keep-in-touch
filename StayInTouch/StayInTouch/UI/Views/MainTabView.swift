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
    @State private var forgotContext: ForgotContext?
    @State private var recentGroups: [RecentGroup] = []
    private let recentGroupsStore = RecentGroupsStore()
    @Environment(\.dependencies) private var dependencies

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
                    subtitle: forgotContextSubtitle,
                    onCancel: {
                        // Cancelling a "Forgot?" pass discards the carry-
                        // forward context but leaves the first-pass writes
                        // intact (those committed at the prior modal Done).
                        forgotContext = nil
                        selectionCoordinator.exit()
                    },
                    onCommit: { commitBulkLog() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectionCoordinator.isSelectMode)
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

    /// Snapshot of the bulk-log sheet's pre-fill state. Created once on
    /// commit and again, with prior method/notes/date carried forward,
    /// when "Forgot someone?" reopens the picker.
    struct BulkLogPresentation: Identifiable {
        let id = UUID()
        let people: [Person]
        var method: TouchMethod = .irl
        var notes: String = ""
        var date: Date = Date()
        var timeOfDay: TimeOfDay? = nil
        /// Person IDs already logged in this round — used by the
        /// "Forgot someone?" flow so we only write events for newly-added
        /// people on the second commit.
        var alreadyLoggedIds: Set<UUID> = []
    }

    /// State carried between the first commit and the "Forgot someone?"
    /// follow-up. Holds the prior group + the form values to pre-fill,
    /// so the user lands back in the picker (not the modal) and only
    /// needs to add the missing people.
    struct ForgotContext {
        let alreadyLoggedIds: Set<UUID>
        let alreadyLoggedPeople: [Person]
        let method: TouchMethod
        let notes: String
        let date: Date
        let timeOfDay: TimeOfDay?
    }

    private func commitBulkLog() {
        guard selectionCoordinator.hasSelection else { return }
        let ids = Array(selectionCoordinator.selection)
        let people = ids.compactMap { dependencies.personRepository.fetch(id: $0) }
        // In the "Forgot?" pass, carry forward the prior form values and
        // the alreadyLoggedIds so we don't double-write events for the
        // original group.
        if let ctx = forgotContext {
            bulkLogState = BulkLogPresentation(
                people: people,
                method: ctx.method,
                notes: ctx.notes,
                date: ctx.date,
                timeOfDay: ctx.timeOfDay,
                alreadyLoggedIds: ctx.alreadyLoggedIds
            )
        } else {
            bulkLogState = BulkLogPresentation(people: people)
        }
    }

    /// Subtitle shown above the action bar during the "Forgot someone?"
    /// follow-up. Lists up to 3 names; collapses the rest into "+N others".
    private var forgotContextSubtitle: String? {
        guard let ctx = forgotContext else { return nil }
        let names = ctx.alreadyLoggedPeople.map { $0.displayName }
        let head = names.prefix(3).joined(separator: ", ")
        let extra = names.count - 3
        if extra > 0 {
            return "Adding to: \(head), +\(extra) \(extra == 1 ? "other" : "others")"
        }
        return "Adding to: \(head)"
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
                    allPersonIds: peopleIds,
                    alreadyLoggedIds: state.alreadyLoggedIds
                )
            },
            onRemove: { id in
                selectionCoordinator.remove(id)
            }
        )
    }

    private func handleBulkSave(
        method: TouchMethod,
        notes: String?,
        date: Date,
        timeOfDay: TimeOfDay?,
        allPersonIds: [UUID],
        alreadyLoggedIds: Set<UUID>
    ) {
        // Only log new (not-already-logged) people on the "Forgot?" pass.
        let toLog = allPersonIds.filter { !alreadyLoggedIds.contains($0) }

        guard !toLog.isEmpty else {
            bulkLogState = nil
            selectionCoordinator.exit()
            return
        }

        let useCase = BulkLogTouchUseCase(
            personRepository: dependencies.personRepository,
            touchEventRepository: dependencies.touchEventRepository
        )
        do {
            let result = try useCase.execute(
                personIds: toLog,
                method: method,
                notes: notes,
                date: date,
                timeOfDay: timeOfDay
            )
            AnalyticsService.track("bulk_log.committed", parameters: [
                "count": String(result.touchEventsWritten),
                "method": method.rawValue
            ])

            // Persist all logged person IDs (including ones from earlier
            // pass) as one combined RecentGroup entry.
            let combined = alreadyLoggedIds.union(toLog)
            recentGroupsStore.append(personIds: Array(combined))
            recentGroups = recentGroupsStore.load()

            // HomeView observes `.personDidChange` and reloads — one
            // post is enough, no need for an extra viewModel.load() here.
            NotificationCenter.default.post(name: .personDidChange, object: nil)

            // Build the toast message + "Forgot?" hook.
            let written = result.touchEventsWritten
            let skipped = result.skippedPersonIds.count
            var message = "Logged \(written) \(written == 1 ? "connection" : "connections")"
            if skipped > 0 {
                message += " (skipped \(skipped))"
            }

            let allLoggedIds = combined
            let alreadyLoggedPeople = allLoggedIds.compactMap {
                dependencies.personRepository.fetch(id: $0)
            }
            SuccessToastManager.shared.show(
                message,
                actionTitle: "Forgot someone?"
            ) {
                AnalyticsService.track("forgot_someone.tapped")
                // Re-enter selection mode with an EMPTY selection so the
                // user picks NEW people to add. The carry-forward state
                // (method/notes/date + alreadyLoggedIds) lives in
                // `forgotContext`; commitBulkLog uses it to seed the
                // next modal and to skip double-writes for the prior
                // group. The action bar shows an "Adding to: ..."
                // subtitle so the user knows which group they're
                // extending.
                forgotContext = ForgotContext(
                    alreadyLoggedIds: allLoggedIds,
                    alreadyLoggedPeople: alreadyLoggedPeople,
                    method: method,
                    notes: notes ?? "",
                    date: date,
                    timeOfDay: timeOfDay
                )
                bulkLogState = nil
                selectionCoordinator.enter(origin: selectionCoordinator.origin)
            }

            bulkLogState = nil
            // Clear forgotContext on a successful commit so the next
            // fresh selection doesn't inherit stale carry-forward state.
            forgotContext = nil
            selectionCoordinator.exit()
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "MainTabView.handleBulkSave")
            ErrorToastManager.shared.show(AppError(message: "Couldn't log touches. Please try again."))
            // Keep the sheet open so the user can retry without losing
            // their typed notes or selection.
        }
    }
}
