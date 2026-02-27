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
    private let touchEventRepository: TouchEventRepository

    init(
        settingsRepository: AppSettingsRepository = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext),
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext),
        tagRepository: TagRepository = CoreDataTagRepository(context: CoreDataStack.shared.viewContext),
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        touchEventRepository: TouchEventRepository = CoreDataTouchEventRepository(context: CoreDataStack.shared.viewContext)
    ) {
        self.settingsRepository = settingsRepository
        self.groupRepository = groupRepository
        self.tagRepository = tagRepository
        self.personRepository = personRepository
        self.touchEventRepository = touchEventRepository
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

    func setBadgeCountOption(_ option: BadgeCountOption) {
        settings.badgeCountOption = option
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
                let demoPeople = repo.fetchAll().filter { $0.isDemoData }
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

    func resetAllFrequencies() async {
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
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.resetAllFrequencies")
            }
        }
        await MainActor.run {
            load()
            NotificationCenter.default.post(name: .personDidChange, object: nil)
        }
    }

    func exportContacts() -> URL? {
        let people = personRepository.fetchAll()
        let groups = groupRepository.fetchAll()
        let tags = tagRepository.fetchAll()

        let groupNameById = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })
        let tagNameById = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })

        let payload = people.map { person in
            ExportPerson.from(
                person,
                groupName: groupNameById[person.groupId],
                tagNames: person.tagIds.compactMap { tagNameById[$0] },
                touchEvents: touchEventRepository.fetchAll(for: person.id)
            )
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return nil }

        let filename = "contacts-export-\(ISO8601DateFormatter().string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func parseImportFile(url: URL) -> ImportPreview? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let imported = try? decoder.decode([ExportPerson].self, from: data) else { return nil }

        let existingById = Dictionary(uniqueKeysWithValues: personRepository.fetchAll().map { ($0.id, $0) })
        let existingByCN = Dictionary(
            personRepository.fetchAll().compactMap { p -> (String, Person)? in
                guard let cn = p.cnIdentifier else { return nil }
                return (cn, p)
            },
            uniquingKeysWith: { first, _ in first }
        )

        var newPeople: [ExportPerson] = []
        var updatedPeople: [ExportPerson] = []
        var skipped = 0
        var touchEventCount = 0

        for person in imported {
            guard !person.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                skipped += 1
                continue
            }

            let matchById = existingById[person.id] != nil
            let matchByCN = person.cnIdentifier.flatMap { existingByCN[$0] } != nil

            if matchById || matchByCN {
                updatedPeople.append(person)
            } else {
                newPeople.append(person)
            }
            touchEventCount += person.touchEvents?.count ?? 0
        }

        return ImportPreview(
            newPeople: newPeople,
            updatedPeople: updatedPeople,
            skippedCount: skipped,
            touchEventCount: touchEventCount
        )
    }

    func executeImport(_ preview: ImportPreview) async {
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()
        await backgroundContext.perform {
            let peopleRepo = CoreDataPersonRepository(context: backgroundContext)
            let touchRepo = CoreDataTouchEventRepository(context: backgroundContext)
            let groupRepo = CoreDataGroupRepository(context: backgroundContext)

            let groups = groupRepo.fetchAll()
            let defaultGroupId = groups.first(where: { $0.isDefault })?.id ?? groups.first?.id ?? UUID()
            let validGroupIds = Set(groups.map { $0.id })

            let existingById = Dictionary(uniqueKeysWithValues: peopleRepo.fetchAll().map { ($0.id, $0) })
            let existingByCN = Dictionary(
                peopleRepo.fetchAll().compactMap { p -> (String, Person)? in
                    guard let cn = p.cnIdentifier else { return nil }
                    return (cn, p)
                },
                uniquingKeysWith: { first, _ in first }
            )
            let existingCount = peopleRepo.fetchTracked(includePaused: true).count
            var sortOrder = existingCount
            let now = Date()
            let assignGroup = AssignGroupUseCase(referenceDate: now)

            var personsToSave: [Person] = []

            for exportPerson in preview.newPeople {
                let groupId = exportPerson.groupId.flatMap { validGroupIds.contains($0) ? $0 : nil } ?? defaultGroupId
                var person = Person(
                    id: exportPerson.id,
                    cnIdentifier: exportPerson.cnIdentifier,
                    displayName: exportPerson.displayName,
                    initials: InitialsBuilder.initials(for: exportPerson.displayName),
                    avatarColor: AvatarColors.randomHex(),
                    groupId: groupId,
                    tagIds: exportPerson.tagIds,
                    lastTouchAt: exportPerson.lastTouchAt,
                    lastTouchMethod: nil,
                    lastTouchNotes: nil,
                    nextTouchNotes: nil,
                    isPaused: exportPerson.isPaused,
                    isTracked: true,
                    notificationsMuted: false,
                    customBreachTime: nil,
                    snoozedUntil: nil,
                    contactUnavailable: false,
                    isDemoData: false,
                    groupAddedAt: nil,
                    createdAt: exportPerson.createdAt,
                    modifiedAt: now,
                    sortOrder: sortOrder
                )
                person = assignGroup.assign(person: person, to: groupId)
                personsToSave.append(person)
                sortOrder += 1
            }

            for exportPerson in preview.updatedPeople {
                let existing = existingById[exportPerson.id]
                    ?? exportPerson.cnIdentifier.flatMap { existingByCN[$0] }
                guard var person = existing else { continue }

                person.displayName = exportPerson.displayName
                person.initials = InitialsBuilder.initials(for: exportPerson.displayName)
                person.tagIds = exportPerson.tagIds
                person.lastTouchAt = exportPerson.lastTouchAt
                person.isPaused = exportPerson.isPaused
                person.modifiedAt = now

                if let newGroupId = exportPerson.groupId, validGroupIds.contains(newGroupId), newGroupId != person.groupId {
                    person = assignGroup.assign(person: person, to: newGroupId)
                }
                personsToSave.append(person)
            }

            do {
                try peopleRepo.batchSave(personsToSave)
            } catch {
                AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.executeImport.people")
            }

            let allExported = preview.newPeople + preview.updatedPeople
            for exportPerson in allExported {
                guard let events = exportPerson.touchEvents else { continue }
                for event in events {
                    let method = TouchMethod(rawValue: event.method) ?? .other
                    let touchEvent = TouchEvent(
                        id: event.id,
                        personId: exportPerson.id,
                        at: event.at,
                        method: method,
                        notes: event.notes,
                        timeOfDay: nil,
                        createdAt: now,
                        modifiedAt: now
                    )
                    do {
                        try touchRepo.save(touchEvent)
                    } catch {
                        AppLogger.logError(error, category: AppLogger.viewModel, context: "SettingsViewModel.executeImport.touchEvents")
                    }
                }
            }
        }

        load()
        NotificationCenter.default.post(name: .personDidChange, object: nil)
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
                    isDemoData: false,
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

struct ExportTouchEvent: Codable {
    let id: UUID
    let at: Date
    let method: String
    let notes: String?

    static func from(_ event: TouchEvent) -> ExportTouchEvent {
        ExportTouchEvent(
            id: event.id,
            at: event.at,
            method: event.method.rawValue,
            notes: event.notes
        )
    }
}

struct ExportPerson: Codable {
    let id: UUID
    let displayName: String
    let cnIdentifier: String?
    let groupId: UUID?
    let groupName: String?
    let tagIds: [UUID]
    let tagNames: [String]
    let lastTouchAt: Date?
    let isPaused: Bool
    let createdAt: Date
    let modifiedAt: Date
    let touchEvents: [ExportTouchEvent]?

    static func from(_ person: Person, groupName: String?, tagNames: [String], touchEvents: [TouchEvent]) -> ExportPerson {
        let exportEvents: [ExportTouchEvent]? = touchEvents.isEmpty ? nil : touchEvents.map { ExportTouchEvent.from($0) }
        return ExportPerson(
            id: person.id,
            displayName: person.displayName,
            cnIdentifier: person.cnIdentifier,
            groupId: person.groupId,
            groupName: groupName,
            tagIds: person.tagIds,
            tagNames: tagNames,
            lastTouchAt: person.lastTouchAt,
            isPaused: person.isPaused,
            createdAt: person.createdAt,
            modifiedAt: person.modifiedAt,
            touchEvents: exportEvents
        )
    }
}

struct ImportPreview {
    let newPeople: [ExportPerson]
    let updatedPeople: [ExportPerson]
    let skippedCount: Int
    let touchEventCount: Int

    var totalPeople: Int { newPeople.count + updatedPeople.count }
    var isEmpty: Bool { newPeople.isEmpty && updatedPeople.isEmpty }
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
            badgeCountOption: .overdueOnly,
            dueSoonWindowDays: 3,
            demoModeEnabled: false,
            lastContactsSyncAt: nil,
            onboardingCompleted: false,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        )
    }
}
