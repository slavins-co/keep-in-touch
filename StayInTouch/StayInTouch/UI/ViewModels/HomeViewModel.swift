//
//  HomeViewModel.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    enum SortOption: String, CaseIterable {
        case status = "Status"
        case name = "Name"
    }

    @Published var searchText = ""
    @Published var selectedGroupId: UUID?
    @Published var selectedTagId: UUID?
    @Published var sortOption: SortOption = .status

    @Published private(set) var allPeople: [Person] = []
    @Published private(set) var groups: [Group] = []
    @Published private(set) var tags: [Tag] = []
    @Published private(set) var settings: AppSettings?

    @Published private(set) var overduePeople: [Person] = []
    @Published private(set) var dueSoonPeople: [Person] = []
    @Published private(set) var allGoodPeople: [Person] = []
    @Published private(set) var nameSortedPeople: [Person] = []

    private let personRepository: PersonRepository
    private let groupRepository: GroupRepository
    private let tagRepository: TagRepository
    private let settingsRepository: AppSettingsRepository
    private var searchTask: Task<Void, Never>?

    init(
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext),
        tagRepository: TagRepository = CoreDataTagRepository(context: CoreDataStack.shared.viewContext),
        settingsRepository: AppSettingsRepository = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext)
    ) {
        self.personRepository = personRepository
        self.groupRepository = groupRepository
        self.tagRepository = tagRepository
        self.settingsRepository = settingsRepository
        load()
    }

    func load() {
        settings = settingsRepository.fetch()
        groups = groupRepository.fetchAll()
        tags = tagRepository.fetchAll()
        allPeople = personRepository.fetchTracked(includePaused: false)

        applyFilters()
    }

    func updateSearchText(_ text: String) {
        searchText = text
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.applyFilters()
            }
        }
    }

    func refreshFromContacts() async {
        let summaries = await Task.detached {
            (try? ContactsFetcher.fetchAll()) ?? []
        }.value
        let byId = Dictionary(uniqueKeysWithValues: summaries.map { ($0.identifier, $0) })

        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        let repo = CoreDataPersonRepository(context: backgroundContext)

        await backgroundContext.perform {
            let people = repo.fetchTracked(includePaused: true)
            for person in people {
                guard let cnId = person.cnIdentifier, let summary = byId[cnId] else { continue }
                var updated = person
                updated.displayName = summary.displayName
                updated.initials = summary.initials
                updated.modifiedAt = Date()
                do {
                    try repo.save(updated)
                } catch {
                    AppLogger.logError(error, category: AppLogger.viewModel, context: "HomeViewModel.refreshFromContacts")
                }
            }
        }

        // Ensure UI updates happen on main thread
        await MainActor.run {
            allPeople = personRepository.fetchTracked(includePaused: false)
            applyFilters()
        }
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
            dueSoonWindowDays: 3,
            demoModeEnabled: false,
            lastContactsSyncAt: nil,
            onboardingCompleted: false,
            appVersion: ""
        )

        let overdue = service.overduePeople(filtered, groups: groups)
        let dueSoon = service.dueSoonPeople(filtered, groups: groups, settings: currentSettings)
        let allGood = filtered.filter { person in
            let status = FrequencyCalculator().status(for: person, in: groups)
            return status == .onTrack
        }
        let nameSorted = filtered.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        let allGoodByRecency = allGood.sorted {
            ($0.lastTouchAt ?? .distantPast) > ($1.lastTouchAt ?? .distantPast)
        }

        switch sortOption {
        case .status:
            overduePeople = overdue
            dueSoonPeople = dueSoon
            allGoodPeople = allGoodByRecency
            nameSortedPeople = nameSorted
        case .name:
            overduePeople = overdue
            dueSoonPeople = dueSoon
            allGoodPeople = allGoodByRecency
            nameSortedPeople = nameSorted
        }
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
}
