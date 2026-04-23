//
//  HomeViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCadenceId: UUID?
    @Published var selectedGroupId: UUID?

    @Published private(set) var allPeople: [Person] = []
    @Published private(set) var cadences: [Cadence] = []
    @Published private(set) var groups: [Group] = []
    @Published private(set) var settings: AppSettings?

    @Published private(set) var overduePeople: [Person] = []
    @Published private(set) var dueSoonPeople: [Person] = []
    @Published private(set) var allGoodPeople: [Person] = []

    /// True when the user has tracked contacts but none are overdue or
    /// due soon — triggers the celebratory banner (#283). Not shown
    /// during search (empty overdue/dueSoon could just be a filter
    /// artifact) or on a fresh install (use `EmptyStateView` instead).
    var showsAllCaughtUpBanner: Bool {
        overduePeople.isEmpty
            && dueSoonPeople.isEmpty
            && !allGoodPeople.isEmpty
            && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @Published private(set) var isRefreshing = false
    @Published var freshStartReason: FreshStartDetector.Reason?
    @Published private(set) var refreshToken = UUID()

    private let personRepository: PersonRepository
    private let cadenceRepository: CadenceRepository
    private let groupRepository: GroupRepository
    private let settingsRepository: AppSettingsRepository
    private var promptStore: FreshStartPromptStore
    private var searchTask: Task<Void, Never>?

    init(
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        cadenceRepository: CadenceRepository = CoreDataCadenceRepository(context: CoreDataStack.shared.viewContext),
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext),
        settingsRepository: AppSettingsRepository = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext),
        promptStore: FreshStartPromptStore = FreshStartPromptStore()
    ) {
        self.personRepository = personRepository
        self.cadenceRepository = cadenceRepository
        self.groupRepository = groupRepository
        self.settingsRepository = settingsRepository
        self.promptStore = promptStore
        load()
    }

    convenience init(dependencies: AppDependencies) {
        self.init(
            personRepository: dependencies.personRepository,
            cadenceRepository: dependencies.cadenceRepository,
            groupRepository: dependencies.groupRepository,
            settingsRepository: dependencies.settingsRepository
        )
    }

    func load() {
        settings = settingsRepository.fetch()
        cadences = cadenceRepository.fetchAll()
        groups = groupRepository.fetchAll()
        allPeople = personRepository.fetchTracked(includePaused: true)

        applyFilters()
        refreshToken = UUID()
    }

    func updateSearchText(_ text: String) {
        searchText = text
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !Task.isCancelled else { return }
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                AnalyticsService.track("search.used")
            }
            await MainActor.run {
                self.applyFilters()
            }
        }
    }

    func refreshFromContacts() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Delegate to the shared sync service so pull-to-refresh stays in sync
        // with foreground sync: display name, initials, birthday, and
        // contactUnavailable are all handled in one place.
        // syncExistingContacts() posts .contactsDidSync on the MainActor when
        // done; HomeView observes it and calls load() — no explicit reload needed.
        // viewContext.automaticallyMergesChangesFromParent ensures the context
        // is up to date before the notification fires.
        await ContactsSyncService.syncExistingContacts()
    }

    func applyFilters() {
        let filtered = Self.filterPeople(
            people: allPeople,
            cadences: cadences,
            groups: groups,
            selectedCadenceId: selectedCadenceId,
            selectedGroupId: selectedGroupId,
            searchText: searchText
        )

        let service = PersonStatusService(referenceDate: Date())

        let overdue = service.overduePeople(filtered, cadences: cadences)
        let dueSoon = service.dueSoonPeople(filtered, cadences: cadences)
        let allGood = filtered.filter { person in
            guard !person.isPaused else { return false }
            let status = FrequencyCalculator().status(for: person, in: cadences)
            return status == .onTrack
        }
        let allGoodByRecency = allGood.sorted {
            ($0.lastTouchAt ?? .distantPast) > ($1.lastTouchAt ?? .distantPast)
        }

        overduePeople = overdue
        dueSoonPeople = dueSoon
        allGoodPeople = allGoodByRecency

        evaluateFreshStartPrompt()
    }

    static func filterPeople(
        people: [Person],
        cadences: [Cadence],
        groups: [Group],
        selectedCadenceId: UUID?,
        selectedGroupId: UUID?,
        searchText: String
    ) -> [Person] {
        let searchLower = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let groupNameById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name.lowercased()) })

        return people.filter { person in
            if let cadenceId = selectedCadenceId, person.cadenceId != cadenceId { return false }
            if let groupId = selectedGroupId, !person.groupIds.contains(groupId) { return false }

            if searchLower.isEmpty { return true }

            let nameMatch = person.displayName.lowercased().contains(searchLower)
            let nicknameMatch = person.nickname?.lowercased().contains(searchLower) ?? false
            let groupMatch = person.groupIds
                .compactMap { groupNameById[$0] }
                .contains { $0.contains(searchLower) }

            return nameMatch || nicknameMatch || groupMatch
        }
    }

    // MARK: - Fresh Start Prompt

    func recordAppOpen() {
        promptStore.recordAppOpen()
    }

    func dismissFreshStartPrompt() {
        promptStore.recordDismissal()
        freshStartReason = nil
    }

    func executeFreshStart() async {
        let now = Date()
        let people = personRepository.fetchTracked(includePaused: true)
        var updated: [Person] = []
        for var person in people {
            person.lastTouchAt = now
            person.modifiedAt = now
            updated.append(person)
        }
        do {
            try personRepository.batchSave(updated)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "HomeViewModel.executeFreshStart")
        }

        promptStore.recordDismissal()
        freshStartReason = nil
        load()
        NotificationCenter.default.post(name: .personDidChange, object: nil)
    }

    private func evaluateFreshStartPrompt() {
        let tracked = allPeople.filter { !$0.isDemoData }
        let overdueNonDemo = overduePeople.filter { !$0.isDemoData }

        let detector = FreshStartDetector()
        let input = FreshStartDetector.Input(
            trackedCount: tracked.count,
            overdueCount: overdueNonDemo.count,
            lastAppOpenedAt: promptStore.lastAppOpenedAt,
            lastDismissedAt: promptStore.lastDismissedAt,
            referenceDate: Date()
        )

        switch detector.evaluate(input) {
        case .showPrompt(let reason):
            freshStartReason = reason
        case .doNotShow:
            freshStartReason = nil
        }
    }
}
