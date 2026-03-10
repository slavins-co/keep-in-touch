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
    @Published var selectedGroupId: UUID?
    @Published var selectedTagId: UUID?

    @Published private(set) var allPeople: [Person] = []
    @Published private(set) var groups: [Group] = []
    @Published private(set) var tags: [Tag] = []
    @Published private(set) var settings: AppSettings?

    @Published private(set) var overduePeople: [Person] = []
    @Published private(set) var dueSoonPeople: [Person] = []
    @Published private(set) var allGoodPeople: [Person] = []

    @Published private(set) var isRefreshing = false
    @Published var freshStartReason: FreshStartDetector.Reason?
    @Published private(set) var refreshToken = UUID()

    private let personRepository: PersonRepository
    private let groupRepository: GroupRepository
    private let tagRepository: TagRepository
    private let settingsRepository: AppSettingsRepository
    private var promptStore: FreshStartPromptStore
    private var searchTask: Task<Void, Never>?

    init(
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext),
        tagRepository: TagRepository = CoreDataTagRepository(context: CoreDataStack.shared.viewContext),
        settingsRepository: AppSettingsRepository = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext),
        promptStore: FreshStartPromptStore = FreshStartPromptStore()
    ) {
        self.personRepository = personRepository
        self.groupRepository = groupRepository
        self.tagRepository = tagRepository
        self.settingsRepository = settingsRepository
        self.promptStore = promptStore
        load()
    }

    convenience init(dependencies: AppDependencies) {
        self.init(
            personRepository: dependencies.personRepository,
            groupRepository: dependencies.groupRepository,
            tagRepository: dependencies.tagRepository,
            settingsRepository: dependencies.settingsRepository
        )
    }

    func load() {
        settings = settingsRepository.fetch()
        groups = groupRepository.fetchAll()
        tags = tagRepository.fetchAll()
        allPeople = personRepository.fetchTracked(includePaused: true)

        applyFilters()
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
            groups: groups,
            tags: tags,
            selectedGroupId: selectedGroupId,
            selectedTagId: selectedTagId,
            searchText: searchText
        )

        let service = PersonStatusService(referenceDate: Date())
        let currentSettings = settings ?? AppSettings(
            id: AppSettings.singletonId,
            theme: .light,
            notificationsEnabled: false,
            breachTimeOfDay: LocalTime(hour: 18, minute: 0),
            digestEnabled: false,
            digestDay: .friday,
            digestTime: LocalTime(hour: 18, minute: 0),
            notificationGrouping: .perType,
            badgeCountShowDueSoon: false,
            dueSoonWindowDays: 3,
            demoModeEnabled: false,
            analyticsEnabled: true,
            hideContactNamesInNotifications: false,
            birthdayNotificationsEnabled: false,
            birthdayNotificationTime: LocalTime(hour: 9, minute: 0),
            birthdayIgnoreSnoozePause: true,
            lastContactsSyncAt: nil,
            onboardingCompleted: false,
            appVersion: ""
        )

        let overdue = service.overduePeople(filtered, groups: groups)
        let dueSoon = service.dueSoonPeople(filtered, groups: groups, settings: currentSettings)
        let allGood = filtered.filter { person in
            guard !person.isPaused else { return false }
            let status = FrequencyCalculator().status(for: person, in: groups)
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
        groups: [Group],
        tags: [Tag],
        selectedGroupId: UUID?,
        selectedTagId: UUID?,
        searchText: String
    ) -> [Person] {
        let searchLower = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tagNameById = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name.lowercased()) })

        return people.filter { person in
            if let groupId = selectedGroupId, person.groupId != groupId { return false }
            if let tagId = selectedTagId, !person.tagIds.contains(tagId) { return false }

            if searchLower.isEmpty { return true }

            let nameMatch = person.displayName.lowercased().contains(searchLower)
            let tagMatch = person.tagIds
                .compactMap { tagNameById[$0] }
                .contains { $0.contains(searchLower) }

            return nameMatch || tagMatch
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
        refreshToken = UUID()
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
