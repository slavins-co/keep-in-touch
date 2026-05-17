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
                    onCancel: { selectionCoordinator.exit() },
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

    private func commitBulkLog() {
        guard selectionCoordinator.hasSelection else { return }
        let ids = Array(selectionCoordinator.selection)
        let people = ids.compactMap { dependencies.personRepository.fetch(id: $0) }
        bulkLogState = BulkLogPresentation(people: people)
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

            // Refresh the home view so the new touch dates surface.
            viewModel.load()
            NotificationCenter.default.post(name: .personDidChange, object: nil)

            // Build the toast message + "Forgot?" hook.
            let written = result.touchEventsWritten
            let skipped = result.skippedPersonIds.count
            var message = "Logged \(written) \(written == 1 ? "connection" : "connections")"
            if skipped > 0 {
                message += " (skipped \(skipped))"
            }

            let allLoggedIds = combined
            SuccessToastManager.shared.show(
                message,
                actionTitle: "Forgot someone?"
            ) {
                AnalyticsService.track("forgot_someone.tapped")
                // Carry the same date/method/notes forward and re-enter
                // selection with the previous group pre-filled.
                selectionCoordinator.enter(origin: selectionCoordinator.origin)
                selectionCoordinator.setSelection(Array(allLoggedIds))
                bulkLogState = nil
                // Schedule reopen on next loop so the dismissed sheet
                // fully tears down before we present a new one.
                DispatchQueue.main.async {
                    let people = allLoggedIds.compactMap {
                        dependencies.personRepository.fetch(id: $0)
                    }
                    bulkLogState = BulkLogPresentation(
                        people: people,
                        method: method,
                        notes: notes ?? "",
                        date: date,
                        timeOfDay: timeOfDay,
                        alreadyLoggedIds: allLoggedIds
                    )
                }
            }

            bulkLogState = nil
            selectionCoordinator.exit()
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "MainTabView.handleBulkSave")
            ErrorToastManager.shared.show(AppError(message: "Couldn't log touches. Please try again."))
            // Keep the sheet open so the user can retry without losing
            // their typed notes or selection.
        }
    }
}
