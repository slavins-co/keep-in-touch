//
//  SettingsViewModel.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation
import UserNotifications
import Contacts

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var allCadences: [Cadence] = []
    @Published private(set) var cadencesCount: Int = 0
    @Published private(set) var groupsCount: Int = 0
    @Published private(set) var pausedCount: Int = 0
    @Published var showNotificationsSettingsAlert = false
    @Published var pendingNewContacts: [ContactSummary] = []
    @Published var contactAccessDenied = false
    @Published var contactAccessLimited = false
    @Published private(set) var isSyncing = false
    @Published private(set) var isImporting = false

    private let settingsRepository: AppSettingsRepository
    private let cadenceRepository: CadenceRepository
    private let groupRepository: GroupRepository
    private let personRepository: PersonRepository
    private let touchEventRepository: TouchEventRepository

    private let exportService: DataExportService
    private let importService: DataImportService
    private let contactImportService: ContactImportService

    init(
        coreDataStack: CoreDataStack = .shared,
        settingsRepository: AppSettingsRepository = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext),
        cadenceRepository: CadenceRepository = CoreDataCadenceRepository(context: CoreDataStack.shared.viewContext),
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext),
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        touchEventRepository: TouchEventRepository = CoreDataTouchEventRepository(context: CoreDataStack.shared.viewContext)
    ) {
        self.settingsRepository = settingsRepository
        self.cadenceRepository = cadenceRepository
        self.groupRepository = groupRepository
        self.personRepository = personRepository
        self.touchEventRepository = touchEventRepository

        self.exportService = DataExportService(
            personRepository: personRepository,
            cadenceRepository: cadenceRepository,
            groupRepository: groupRepository,
            touchEventRepository: touchEventRepository
        )
        self.importService = DataImportService(
            personRepository: personRepository,
            cadenceRepository: cadenceRepository,
            groupRepository: groupRepository,
            touchEventRepository: touchEventRepository
        )
        self.contactImportService = ContactImportService(
            personRepository: personRepository,
            touchEventRepository: touchEventRepository,
            coreDataStack: coreDataStack
        )

        self.settings = settingsRepository.fetch() ?? AppSettingsDefaults.defaultSettings()
        load()
    }

    convenience init(dependencies: AppDependencies) {
        self.init(
            settingsRepository: dependencies.settingsRepository,
            cadenceRepository: dependencies.cadenceRepository,
            groupRepository: dependencies.groupRepository,
            personRepository: dependencies.personRepository,
            touchEventRepository: dependencies.touchEventRepository
        )
    }

    // MARK: - Settings Management

    func load() {
        settings = settingsRepository.fetch() ?? AppSettingsDefaults.defaultSettings()
        allCadences = cadenceRepository.fetchAll()
        cadencesCount = allCadences.count
        groupsCount = groupRepository.fetchAll().count
        pausedCount = personRepository.fetchTracked(includePaused: true).filter { $0.isPaused }.count
    }

    func setTheme(_ theme: Theme) {
        AnalyticsService.track("settings.theme.changed", parameters: ["theme": theme.rawValue])
        settings.theme = theme
        save()
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        AnalyticsService.track("settings.notifications.toggled", parameters: ["enabled": String(enabled)])
        if enabled {
            let granted = await requestNotificationsPermission()
            if granted {
                settings.notificationsEnabled = true
                save()
            } else {
                settings.notificationsEnabled = false
                save()
                showNotificationsSettingsAlert = true
            }
        } else {
            settings.notificationsEnabled = false
            save()
        }
    }

    func setBreachTime(_ time: LocalTime) {
        settings.breachTimeOfDay = time
        save()
    }

    func setDigestEnabled(_ enabled: Bool) {
        settings.digestEnabled = enabled
        save()
    }

    func setDigestDay(_ day: DayOfWeek) {
        settings.digestDay = day
        save()
    }

    func setDigestTime(_ time: LocalTime) {
        settings.digestTime = time
        save()
    }

    func setNotificationGrouping(_ grouping: NotificationGrouping) {
        settings.notificationGrouping = grouping
        save()
    }

    func setBadgeCountShowDueSoon(_ enabled: Bool) {
        settings.badgeCountShowDueSoon = enabled
        save()
    }

    func setHideContactNamesInNotifications(_ hideNames: Bool) {
        settings.hideContactNamesInNotifications = hideNames
        save()
    }

    func setBirthdayNotificationsEnabled(_ enabled: Bool) {
        AnalyticsService.track("settings.birthdayNotifications.toggled", parameters: ["enabled": String(enabled)])
        settings.birthdayNotificationsEnabled = enabled
        save()
    }

    func setBirthdayNotificationTime(_ time: LocalTime) {
        settings.birthdayNotificationTime = time
        save()
    }

    func setBirthdayIgnoreSnoozePause(_ enabled: Bool) {
        AnalyticsService.track("settings.birthdayIgnoreSnoozePause.toggled", parameters: ["enabled": String(enabled)])
        settings.birthdayIgnoreSnoozePause = enabled
        save()
    }

    func setAnalyticsEnabled(_ enabled: Bool) {
        settings.analyticsEnabled = enabled
        save()
        AnalyticsService.updateEnabled(enabled)
        AnalyticsService.track("settings.analytics.toggled", parameters: ["enabled": String(enabled)])
    }

    func setDemoModeEnabled(_ enabled: Bool) {
        settings.demoModeEnabled = enabled
        save()
        Task { await updateDemoData(enabled) }
    }

    // MARK: - Demo Data

    private func updateDemoData(_ enabled: Bool) async {
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        await backgroundContext.perform {
            if enabled {
                let seeder = DemoDataSeeder(context: backgroundContext)
                seeder.seedIfNeeded()
            } else {
                let repo = CoreDataPersonRepository(context: backgroundContext)
                let touchRepo = CoreDataTouchEventRepository(context: backgroundContext)
                let demoPeople = repo.fetchAll().filter { $0.isDemoData }
                for person in demoPeople {
                    do {
                        // Cascade: delete TouchEvents before Person
                        let events = touchRepo.fetchAll(for: person.id)
                        for event in events {
                            try touchRepo.delete(id: event.id)
                        }
                        try repo.delete(id: person.id)
                    } catch let error as RepositoryError {
                        AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.updateDemoData")
                    } catch {
                        AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.updateDemoData (unexpected)")
                    }
                }
            }
        }
        NotificationCenter.default.post(name: .personDidChange, object: nil)
    }

    // MARK: - Utilities

    func sendTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Keep In Touch test notification."
        content.sound = .default
        content.userInfo = ["type": "home", "category": "test"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.sendTestNotification")
        }
    }

    func resetAllFrequencies() async {
        AnalyticsService.track("freshStart.confirmed")
        let now = Date()
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        await backgroundContext.perform {
            let repo = CoreDataPersonRepository(context: backgroundContext)
            let people = repo.fetchTracked(includePaused: true)
            var updated: [Person] = []
            for var person in people {
                person.lastTouchAt = now
                person.modifiedAt = now
                updated.append(person)
            }
            do {
                try repo.batchSave(updated)
            } catch let error as RepositoryError {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.resetAllFrequencies")
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.resetAllFrequencies (unexpected)")
            }
        }
        await MainActor.run {
            load()
            NotificationCenter.default.post(name: .personDidChange, object: nil)
        }
    }

    // MARK: - Data Export (delegates to DataExportService)

    func exportContacts(format: ExportFormat = .json) -> URL? {
        let url: URL?
        switch format {
        case .json:
            url = exportService.exportJSON()
        case .csv:
            url = exportService.exportCSV()
        }
        if url != nil {
            AnalyticsService.track("data.exported", parameters: ["format": format.rawValue])
        }
        return url
    }

    // MARK: - Data Import (delegates to DataImportService)

    func parseImportFile(url: URL) async -> ImportPreview? {
        await importService.parseImportFile(url: url)
    }

    func executeImport(_ preview: ImportPreview) async -> ImportResult {
        let result = await importService.executeImport(preview)
        AnalyticsService.track("data.imported", parameters: ["count": "\(result.importedPeople.count)"])
        load()
        NotificationCenter.default.post(name: .personDidChange, object: nil)
        return result
    }

    func matchImportedContacts(people: [(id: UUID, displayName: String)]) async -> ContactMatchSummary {
        let results = await importService.fetchContactMatches(people: people)

        guard !results.isEmpty else {
            return ContactMatchSummary(matched: 0, unmatchedPeople: people, total: people.count, matchedNames: [])
        }

        // Persist matches on @MainActor (viewContext must be accessed from main thread)
        var matchedCount = 0
        var matchedNames: [String] = []
        var unmatchedPeople: [(id: UUID, displayName: String)] = []

        for result in results {
            switch result {
            case .matched(let personId, let displayName, let cnIdentifier):
                if var person = personRepository.fetch(id: personId) {
                    person.cnIdentifier = cnIdentifier
                    person.contactUnavailable = false
                    person.modifiedAt = Date()
                    do {
                        try personRepository.save(person)
                        matchedCount += 1
                        matchedNames.append(displayName)
                    } catch {
                        AppLogger.logError(error, category: AppLogger.viewModel, context: "matchImportedContacts.save")
                        unmatchedPeople.append((id: personId, displayName: displayName))
                    }
                } else {
                    unmatchedPeople.append((id: personId, displayName: displayName))
                }
            case .multipleMatches(let personId, let displayName, _):
                unmatchedPeople.append((id: personId, displayName: displayName))
            case .noMatch(let personId, let displayName):
                unmatchedPeople.append((id: personId, displayName: displayName))
            }
        }

        if matchedCount > 0 {
            load()
            NotificationCenter.default.post(name: .personDidChange, object: nil)
        }

        return ContactMatchSummary(
            matched: matchedCount,
            unmatchedPeople: unmatchedPeople,
            total: people.count,
            matchedNames: matchedNames
        )
    }

    func linkContactManually(personId: UUID, cnIdentifier: String) {
        guard var person = personRepository.fetch(id: personId) else { return }
        person.cnIdentifier = cnIdentifier
        person.contactUnavailable = false
        person.modifiedAt = Date()
        do {
            try personRepository.save(person)
            NotificationCenter.default.post(name: .personDidChange, object: nil)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "linkContactManually")
        }
    }

    func performFileImport(_ preview: ImportPreview) async -> (result: ImportResult, matchSummary: ContactMatchSummary?) {
        isImporting = true
        defer { isImporting = false }
        let result = await executeImport(preview)
        var matchSummary: ContactMatchSummary?
        if !result.importedPeople.isEmpty {
            matchSummary = await matchImportedContacts(people: result.importedPeople)
        }
        return (result, matchSummary)
    }

    // MARK: - Contact Import (delegates to ContactImportService)

    func findNewContacts() async -> Int {
        isSyncing = true
        let started = Date()
        contactAccessDenied = false
        contactAccessLimited = false

        let fetchResult = await contactImportService.fetchNewContacts()
        contactAccessDenied = fetchResult.accessDenied
        contactAccessLimited = fetchResult.accessLimited
        pendingNewContacts = fetchResult.contacts

        // Ensure minimum visible loading duration for UX
        let elapsed = Date().timeIntervalSince(started)
        if elapsed < 0.6 {
            try? await Task.sleep(nanoseconds: UInt64((0.6 - elapsed) * 1_000_000_000))
        }
        isSyncing = false
        return fetchResult.contacts.count
    }

    func importSelectedContacts(_ summaries: [ContactSummary]) async {
        await importSelectedContacts(summaries, groupAssignments: [:])
    }

    func importSelectedContacts(_ summaries: [ContactSummary], groupAssignments: [String: UUID], lastTouchSelections: [String: LastTouchOption] = [:]) async {
        guard !summaries.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }

        await contactImportService.importSelectedContacts(summaries, groupAssignments: groupAssignments, lastTouchSelections: lastTouchSelections)

        pendingNewContacts = pendingNewContacts.filter { existing in
            !summaries.contains(where: { $0.identifier == existing.identifier })
        }

        settings.lastContactsSyncAt = Date()
        save()
        load()
        NotificationCenter.default.post(name: .contactsDidSync, object: nil)
    }

    // MARK: - Private

    private func save() {
        do {
            try settingsRepository.save(settings)
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.save")
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.save (unexpected)")
            ErrorToastManager.shared.show(.saveFailed("Settings"))
        }
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    private func requestNotificationsPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }
}

struct AppSettingsDefaults {
    static func defaultSettings() -> AppSettings {
        AppSettings(
            id: AppSettings.singletonId,
            theme: .system,
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
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        )
    }
}
