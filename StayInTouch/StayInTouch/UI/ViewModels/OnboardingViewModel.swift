//
//  OnboardingViewModel.swift
//  KeepInTouch
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
        case lastTouchSeeding
        case notificationsPermission
        case notificationsSkipped
    }

    @Published var isLoading = true
    @Published var isOnboardingCompleted = false
    @Published var isCompleting = false
    @Published var isImporting = false
    @Published var step: Step = .welcome
    private(set) var stepHistory: [Step] = []

    var canGoBack: Bool { !stepHistory.isEmpty }

    var showsProgress: Bool { step != .welcome }

    var progressFraction: Double {
        if isCompleting { return 1.0 }
        switch step {
        case .welcome:                 return 0
        case .contactsPermission:      return 0.15
        case .contactsRequired:        return 0.3
        case .contactPicker:           return 0.3
        case .groupAssignment:         return 0.5
        case .lastTouchSeeding:        return 0.7
        case .notificationsPermission: return 0.85
        case .notificationsSkipped:    return 0.95
        }
    }

    @Published var contacts: [ContactSummary] = []
    @Published var selectedContactIds: Set<String> = []
    @Published var searchText = ""
    @Published var useDemoData = false

    @Published var groups: [Group] = []
    @Published var selectedGroupId: UUID?
    @Published var contactGroupSelections: [String: UUID] = [:]
    @Published var contactLastTouchSelections: [String: LastTouchOption] = [:]

    private let coreDataStack: CoreDataStack
    private let personRepository: PersonRepository
    private let groupRepository: GroupRepository
    private let settingsRepository: AppSettingsRepository
    private let contactImportService: ContactImportService

    private var settings: AppSettings?

    init(
        coreDataStack: CoreDataStack = .shared,
        personRepository: PersonRepository? = nil,
        groupRepository: GroupRepository? = nil,
        touchEventRepository: TouchEventRepository? = nil,
        settingsRepository: AppSettingsRepository? = nil
    ) {
        self.coreDataStack = coreDataStack
        let context = coreDataStack.viewContext
        let personRepo = personRepository ?? CoreDataPersonRepository(context: context)
        let touchRepo = touchEventRepository ?? CoreDataTouchEventRepository(context: context)
        self.personRepository = personRepo
        self.groupRepository = groupRepository ?? CoreDataGroupRepository(context: context)
        self.settingsRepository = settingsRepository ?? CoreDataAppSettingsRepository(context: context)
        self.contactImportService = ContactImportService(
            personRepository: personRepo,
            touchEventRepository: touchRepo
        )

        loadSettingsAndGroups()
    }

    convenience init(dependencies: AppDependencies) {
        self.init(
            personRepository: dependencies.personRepository,
            groupRepository: dependencies.groupRepository,
            touchEventRepository: dependencies.touchEventRepository,
            settingsRepository: dependencies.settingsRepository
        )
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
        AnalyticsService.track("onboarding.started")
        pushAndNavigate(to: .contactsPermission)
    }

    func skipContactsPermission() {
        pushAndNavigate(to: .contactsRequired)
    }

    func requestContactsPermission() async {
        let granted = await ContactsFetcher.requestAccess()
        if granted {
            AnalyticsService.track("onboarding.contacts.granted")
            await loadContacts()
            pushAndNavigate(to: .contactPicker)
        } else {
            AnalyticsService.track("onboarding.contacts.denied")
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
        AnalyticsService.track("onboarding.contacts.selected", parameters: ["count": String(selectedContactIds.count)])
        if selectedContactIds.isEmpty {
            pushAndNavigate(to: .notificationsPermission)
            return
        }

        seedGroupSelectionsIfNeeded()
        pushAndNavigate(to: .groupAssignment)
    }

    func continueFromGroupAssignment() {
        seedLastTouchSelectionsIfNeeded()
        pushAndNavigate(to: .lastTouchSeeding)
    }

    func continueFromLastTouchSeeding() {
        guard !isImporting else { return }
        isImporting = true
        Task {
            defer { isImporting = false }
            await importSelectedContacts()
            pushAndNavigate(to: .notificationsPermission)
        }
    }

    func requestNotificationsPermission() async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
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
        let selected = contacts.filter { selectedContactIds.contains($0.identifier) }
        await contactImportService.importSelectedContacts(
            selected,
            groupAssignments: contactGroupSelections,
            lastTouchSelections: contactLastTouchSelections
        )
    }

    private func seedLastTouchSelectionsIfNeeded() {
        for contactId in selectedContactIds {
            if contactLastTouchSelections[contactId] == nil {
                contactLastTouchSelections[contactId] = .cantRemember
            }
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
        do {
            try settingsRepository.save(settings)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "OnboardingViewModel.updateNotificationsEnabled")
            ErrorToastManager.shared.show(.saveFailed("Onboarding"))
        }
        self.settings = settings
    }

    private func seedDemoData() {
        guard var settings else { return }
        settings.demoModeEnabled = true
        do {
            try settingsRepository.save(settings)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "OnboardingViewModel.seedDemoData")
            ErrorToastManager.shared.show(.saveFailed("Onboarding"))
        }
        self.settings = settings

        let backgroundContext = coreDataStack.newBackgroundContext()
        backgroundContext.perform {
            // Create seeder inside closure to avoid capturing non-Sendable type
            DemoDataSeeder(context: backgroundContext).seedIfNeeded()
        }
    }

    private func completeOnboarding() {
        AnalyticsService.track("onboarding.completed")
        guard var settings else { return }
        settings.onboardingCompleted = true
        do {
            try settingsRepository.save(settings)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "OnboardingViewModel.completeOnboarding")
            ErrorToastManager.shared.show(.saveFailed("Onboarding"))
        }
        self.settings = settings

        // Phase 1: Fill progress bar to 100%
        isCompleting = true

        // Phase 2: Transition to home after animation completes
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            isOnboardingCompleted = true
        }
    }
}
