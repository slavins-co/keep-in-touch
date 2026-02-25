//
//  SettingsViewModel.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation
import UserNotifications
import Contacts

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var allGroups: [Group] = []
    @Published private(set) var groupsCount: Int = 0
    @Published private(set) var tagsCount: Int = 0
    @Published private(set) var pausedCount: Int = 0
    @Published var showNotificationsSettingsAlert = false
    @Published var pendingNewContacts: [ContactSummary] = []
    @Published var contactAccessDenied = false
    @Published var contactAccessLimited = false

    private let settingsRepository: AppSettingsRepository
    private let groupRepository: GroupRepository
    private let tagRepository: TagRepository
    private let personRepository: PersonRepository

    init(
        settingsRepository: AppSettingsRepository = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext),
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext),
        tagRepository: TagRepository = CoreDataTagRepository(context: CoreDataStack.shared.viewContext),
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext)
    ) {
        self.settingsRepository = settingsRepository
        self.groupRepository = groupRepository
        self.tagRepository = tagRepository
        self.personRepository = personRepository
        self.settings = settingsRepository.fetch() ?? AppSettingsDefaults.defaultSettings()
        load()
    }

    func load() {
        settings = settingsRepository.fetch() ?? AppSettingsDefaults.defaultSettings()
        allGroups = groupRepository.fetchAll()
        groupsCount = allGroups.count
        tagsCount = tagRepository.fetchAll().count
        pausedCount = personRepository.fetchTracked(includePaused: true).filter { $0.isPaused }.count
    }

    func setTheme(_ theme: Theme) {
        settings.theme = theme
        save()
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
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

    func setDemoModeEnabled(_ enabled: Bool) {
        settings.demoModeEnabled = enabled
        save()
        Task { await updateDemoData(enabled) }
    }

    private func updateDemoData(_ enabled: Bool) async {
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        await backgroundContext.perform {
            if enabled {
                let seeder = DemoDataSeeder(context: backgroundContext)
                seeder.seedIfNeeded()
            } else {
                let repo = CoreDataPersonRepository(context: backgroundContext)
                let demoPeople = repo.fetchAll().filter { $0.cnIdentifier == nil }
                for person in demoPeople {
                    do {
                        try repo.delete(id: person.id)
                    } catch {
                        AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.updateDemoData")
                    }
                }
            }
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .personDidChange, object: nil)
        }
    }

    func sendTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Stay in Touch test notification."
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

    func exportContacts() -> URL? {
        let people = personRepository.fetchAll()
        let payload = people.map { ExportPerson.from($0) }
        guard let data = try? JSONEncoder().encode(payload) else { return nil }

        let filename = "contacts-export-\(ISO8601DateFormatter().string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func findNewContacts() async -> Int {
        contactAccessDenied = false
        contactAccessLimited = false
        let summaries = await Task.detached {
            do {
                return try ContactsFetcher.fetchAll()
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.findNewContacts")
                return []
            }
        }.value
        guard !summaries.isEmpty else {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            contactAccessDenied = (status == .denied || status == .restricted)
            contactAccessLimited = Self.isLimitedAccess(status)
            return 0
        }

        let existing = Set(personRepository.fetchTracked(includePaused: true).compactMap { $0.cnIdentifier })
        let newContacts = summaries.filter { !existing.contains($0.identifier) }
        if newContacts.isEmpty {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            contactAccessLimited = Self.isLimitedAccess(status)
        }
        pendingNewContacts = newContacts
        return newContacts.count
    }

    private static func isLimitedAccess(_ status: CNAuthorizationStatus) -> Bool {
        if #available(iOS 18.0, *) {
            return status == .limited
        }
        return false
    }

    func importSelectedContacts(_ summaries: [ContactSummary]) async {
        await importSelectedContacts(summaries, groupAssignments: [:])
    }

    func importSelectedContacts(_ summaries: [ContactSummary], groupAssignments: [String: UUID]) async {
        guard !summaries.isEmpty else { return }

        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        await backgroundContext.perform {
            let peopleRepo = CoreDataPersonRepository(context: backgroundContext)
            let groupRepo = CoreDataGroupRepository(context: backgroundContext)

            let groups = groupRepo.fetchAll()
            let defaultGroupId = groups.first(where: { $0.isDefault })?.id ?? groups.first?.id
            guard let defaultGroupId else { return }

            let existing = peopleRepo.fetchTracked(includePaused: true)
            var sortOrder = existing.count
            let now = Date()

            var personsToSave: [Person] = []

            for summary in summaries {
                let groupId = groupAssignments[summary.identifier] ?? defaultGroupId
                let person = Person(
                    id: UUID(),
                    cnIdentifier: summary.identifier,
                    displayName: summary.displayName,
                    initials: summary.initials,
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

            do {
                try peopleRepo.batchSave(personsToSave)
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.importSelectedContacts")
            }
        }

        pendingNewContacts = pendingNewContacts.filter { existing in
            !summaries.contains(where: { $0.identifier == existing.identifier })
        }

        settings.lastContactsSyncAt = Date()
        save()
        load()
        NotificationCenter.default.post(name: .contactsDidSync, object: nil)
    }

    private func save() {
        do {
            try settingsRepository.save(settings)
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.save")
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

struct ExportPerson: Codable {
    let id: UUID
    let displayName: String
    let cnIdentifier: String?
    let groupId: UUID?
    let tagIds: [UUID]
    let lastTouchAt: Date?
    let isPaused: Bool
    let createdAt: Date
    let modifiedAt: Date

    static func from(_ person: Person) -> ExportPerson {
        ExportPerson(
            id: person.id,
            displayName: person.displayName,
            cnIdentifier: person.cnIdentifier,
            groupId: person.groupId,
            tagIds: person.tagIds,
            lastTouchAt: person.lastTouchAt,
            isPaused: person.isPaused,
            createdAt: person.createdAt,
            modifiedAt: person.modifiedAt
        )
    }

    // MARK: - Contact Grouping & Filtering

    func filteredAndGroupedContacts(searchText: String, allContacts: [CNContact]) -> [(String, [CNContact])] {
        // Filter by search text
        let filtered = searchText.isEmpty ? allContacts : allContacts.filter { contact in
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            return name.localizedCaseInsensitiveContains(searchText)
        }

        // Group alphabetically
        let grouped = groupContactsAlphabetically(filtered)

        // Sort sections A-Z (with # at end)
        let sorted = grouped.sorted { lhs, rhs in
            if lhs.key == "#" { return false }
            if rhs.key == "#" { return true }
            return lhs.key < rhs.key
        }

        // Sort contacts within each section
        return sorted.map { (key, contacts) in
            (key, contacts.sorted {
                let name1 = CNContactFormatter.string(from: $0, style: .fullName) ?? ""
                let name2 = CNContactFormatter.string(from: $1, style: .fullName) ?? ""
                return name1 < name2
            })
        }
    }

    private func groupContactsAlphabetically(_ contacts: [CNContact]) -> [String: [CNContact]] {
        let grouped = Dictionary(grouping: contacts) { contact -> String in
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            let firstChar = name.prefix(1).uppercased()

            // Handle non-alphabetic characters
            if firstChar.rangeOfCharacter(from: CharacterSet.letters) != nil {
                return firstChar
            } else {
                return "#"
            }
        }
        return grouped
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
            dueSoonWindowDays: 3,
            demoModeEnabled: false,
            lastContactsSyncAt: nil,
            onboardingCompleted: false,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        )
    }
}
