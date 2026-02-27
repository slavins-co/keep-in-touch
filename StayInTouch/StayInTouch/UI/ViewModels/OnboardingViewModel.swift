//
//  OnboardingViewModel.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import Contacts
import Foundation
import UserNotifications

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step {
        case welcome
        case contactsPermission
        case contactsRequired
        case contactPicker
        case groupAssignment
        case notificationsPermission
        case notificationsSkipped
    }

    @Published var isLoading = true
    @Published var isOnboardingCompleted = false
    @Published var step: Step = .welcome
    private(set) var stepHistory: [Step] = []

    var canGoBack: Bool { !stepHistory.isEmpty }

    var progressFraction: Double {
        let position: Double
        switch step {
        case .welcome: position = 0
        case .contactsPermission, .contactsRequired: position = 1
        case .contactPicker: position = 2
        case .groupAssignment: position = 3
        case .notificationsPermission, .notificationsSkipped: position = 4
        }
        return position / 4.0
    }

    @Published var contacts: [ContactSummary] = []
    @Published var selectedContactIds: Set<String> = []
    @Published var searchText = ""
    @Published var useDemoData = false

    @Published var groups: [Group] = []
    @Published var selectedGroupId: UUID?
    @Published var contactGroupSelections: [String: UUID] = [:]

    private let coreDataStack: CoreDataStack
    private let personRepository: PersonRepository
    private let groupRepository: GroupRepository
    private let settingsRepository: AppSettingsRepository

    private var settings: AppSettings?

    init(
        coreDataStack: CoreDataStack = .shared,
        personRepository: PersonRepository? = nil,
        groupRepository: GroupRepository? = nil,
        settingsRepository: AppSettingsRepository? = nil
    ) {
        self.coreDataStack = coreDataStack
        let context = coreDataStack.viewContext
        self.personRepository = personRepository ?? CoreDataPersonRepository(context: context)
        self.groupRepository = groupRepository ?? CoreDataGroupRepository(context: context)
        self.settingsRepository = settingsRepository ?? CoreDataAppSettingsRepository(context: context)

        loadSettingsAndGroups()
    }

    var filteredContacts: [ContactSummary] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    func start() {
        stepHistory = []
        step = .welcome
    }

    func goBack() {
        guard let previousStep = stepHistory.popLast() else { return }
        step = previousStep
    }

    func goToContactsPermission() {
        pushAndNavigate(to: .contactsPermission)
    }

    func skipContactsPermission() {
        pushAndNavigate(to: .contactsRequired)
    }

    func requestContactsPermission() async {
        let granted = await ContactsFetcher.requestAccess()
        if granted {
            await loadContacts()
            pushAndNavigate(to: .contactPicker)
        } else {
            pushAndNavigate(to: .contactsRequired)
        }
    }

    func requestContactsPermissionFromRequired() async {
        let granted = await ContactsFetcher.requestAccess()
        if granted {
            await loadContacts()
            pushAndNavigate(to: .contactPicker)
        }
    }

    func continueFromContactsRequired() {
        if useDemoData {
            seedDemoData()
        }
        pushAndNavigate(to: .notificationsPermission)
    }

    func toggleSelection(for contactId: String) {
        if selectedContactIds.contains(contactId) {
            selectedContactIds.remove(contactId)
        } else {
            selectedContactIds.insert(contactId)
        }
    }

    func continueFromContactPicker() {
        if selectedContactIds.isEmpty {
            pushAndNavigate(to: .notificationsPermission)
            return
        }

        seedGroupSelectionsIfNeeded()
        pushAndNavigate(to: .groupAssignment)
    }

    func continueFromGroupAssignment() {
        Task {
            await importSelectedContacts()
            pushAndNavigate(to: .notificationsPermission)
        }
    }

    func requestNotificationsPermission() async {
        let center = UNUserNotificationCenter.current()
        let granted = await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { allowed, _ in
                continuation.resume(returning: allowed)
            }
        }

        updateNotificationsEnabled(granted)

        if granted {
            completeOnboarding()
        } else {
            pushAndNavigate(to: .notificationsSkipped)
        }
    }

    func skipNotifications() {
        pushAndNavigate(to: .notificationsSkipped)
    }

    func finishFromNotificationsSkipped() {
        completeOnboarding()
    }

    private func pushAndNavigate(to newStep: Step) {
        stepHistory.append(step)
        step = newStep
    }

    private func loadSettingsAndGroups() {
        settings = settingsRepository.fetch()
        groups = groupRepository.fetchAll()
        selectedGroupId = groups.first(where: { $0.name == "Monthly" })?.id ?? groups.first?.id
        isOnboardingCompleted = settings?.onboardingCompleted ?? false
        isLoading = false
    }

    private func loadContacts() async {
        let result = await Task.detached(priority: .userInitiated) { () -> [ContactSummary] in
            return (try? ContactsFetcher.fetchAll()) ?? []
        }.value

        contacts = result
    }

    private func importSelectedContacts() async {
        guard !selectedContactIds.isEmpty else { return }
        guard let defaultGroupId = selectedGroupId else { return }

        let selected = contacts.filter { selectedContactIds.contains($0.identifier) }
        let now = Date()

        let backgroundContext = coreDataStack.newBackgroundContext()
        let repo = CoreDataPersonRepository(context: backgroundContext)

        await backgroundContext.perform {
            let existingCount = repo.fetchAll().count
            var sortOrder = existingCount

            var personsToSave: [Person] = []

            for contact in selected {
                let groupId = self.contactGroupSelections[contact.identifier] ?? defaultGroupId
                let person = Person(
                    id: UUID(),
                    cnIdentifier: contact.identifier,
                    displayName: contact.displayName,
                    initials: contact.initials,
                    avatarColor: AvatarColors.randomHex(),
                    groupId: groupId,
                    tagIds: [],
                    lastTouchAt: nil,
                    lastTouchMethod: nil,
                    lastTouchNotes: nil,
                    nextTouchNotes: nil,
                    isPaused: false,
                    isTracked: true,
                    notificationsMuted: false,
                    customBreachTime: nil,
                    snoozedUntil: nil,
                    contactUnavailable: false,
                    groupAddedAt: nil,
                    createdAt: now,
                    modifiedAt: now,
                    sortOrder: sortOrder
                )

                personsToSave.append(AssignGroupUseCase(referenceDate: now).assign(person: person, to: groupId))
                sortOrder += 1
            }

            try? repo.batchSave(personsToSave)
        }
    }

    private func seedGroupSelectionsIfNeeded() {
        guard let defaultGroupId = selectedGroupId else { return }
        for contactId in selectedContactIds {
            if contactGroupSelections[contactId] == nil {
                contactGroupSelections[contactId] = defaultGroupId
            }
        }
    }

    private func updateNotificationsEnabled(_ enabled: Bool) {
        guard var settings else { return }
        settings.notificationsEnabled = enabled
        try? settingsRepository.save(settings)
        self.settings = settings
    }

    private func seedDemoData() {
        guard var settings else { return }
        settings.demoModeEnabled = true
        try? settingsRepository.save(settings)
        self.settings = settings

        let backgroundContext = coreDataStack.newBackgroundContext()
        let seeder = DemoDataSeeder(context: backgroundContext)
        backgroundContext.perform {
            seeder.seedIfNeeded()
        }
    }

    private func completeOnboarding() {
        guard var settings else { return }
        settings.onboardingCompleted = true
        try? settingsRepository.save(settings)
        self.settings = settings
        isOnboardingCompleted = true
    }
}
