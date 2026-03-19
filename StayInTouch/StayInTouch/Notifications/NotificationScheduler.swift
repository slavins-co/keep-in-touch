//
//  NotificationScheduler.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    // MARK: - Notification Templates

    static let singlePersonTemplates: [String] = [
        "Reach out to %@",
        "Time to catch up with %@",
        "Drop %@ a message today",
        "It's been a while — say hi to %@",
        "%@ would love to hear from you",
        "Don't forget about %@ — check in today",
    ]

    static let multiPersonTemplates: [String] = [
        "%d people need your attention, including %@",
        "Catch up with %d people today, including %@",
        "%d connections are waiting, including %@",
    ]

    static let privateSinglePersonTemplates: [String] = [
        "Time to reconnect with someone",
        "You have an overdue connection",
        "Check in with a contact today",
        "Someone could use a check-in",
        "A connection is waiting for you",
        "Don't let a friendship slip away",
    ]

    static let privateMultiPersonTemplates: [String] = [
        "You have %d connections to catch up on",
        "%d people need your attention",
        "%d connections are waiting for you",
    ]

    static let birthdayTemplates: [String] = [
        "It's %@'s birthday today!",
        "Wish %@ a happy birthday!",
        "Don't forget — it's %@'s birthday!",
        "%@ is celebrating a birthday today!",
    ]

    static let privateBirthdayTemplates: [String] = [
        "A contact has a birthday today!",
        "Someone is celebrating a birthday!",
        "Time to send birthday wishes!",
    ]

    private let settingsRepository: AppSettingsRepository
    private let personRepository: PersonRepository
    private let cadenceRepository: CadenceRepository
    private let notificationCenter: UserNotificationCenterProtocol
    private var settingsObserver: NSObjectProtocol?
    private var personObserver: NSObjectProtocol?

    init(
        settingsRepository: AppSettingsRepository = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext),
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        cadenceRepository: CadenceRepository = CoreDataCadenceRepository(context: CoreDataStack.shared.viewContext),
        notificationCenter: UserNotificationCenterProtocol = UNUserNotificationCenter.current()
    ) {
        self.settingsRepository = settingsRepository
        self.personRepository = personRepository
        self.cadenceRepository = cadenceRepository
        self.notificationCenter = notificationCenter
    }

    func registerCategories() {
        let logAction = UNNotificationAction(
            identifier: NotificationIdentifier.actionLogConnection,
            title: "Log Connection",
            options: []
        )
        let personCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.categoryPerson,
            actions: [logAction],
            intentIdentifiers: [],
            options: []
        )
        let birthdayCategory = UNNotificationCategory(
            identifier: NotificationIdentifier.categoryBirthday,
            actions: [logAction],
            intentIdentifiers: [],
            options: []
        )
        notificationCenter.setNotificationCategories([personCategory, birthdayCategory])
    }

    func startObserving() {
        // Remove existing observers first to prevent duplicates
        stopObserving()
        registerCategories()

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.scheduleAll() }
        }
        personObserver = NotificationCenter.default.addObserver(
            forName: .personDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.scheduleAll() }
        }
    }

    func stopObserving() {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
            settingsObserver = nil
        }
        if let observer = personObserver {
            NotificationCenter.default.removeObserver(observer)
            personObserver = nil
        }
    }

    deinit {
        stopObserving()
    }

    func scheduleAll() async {
        guard let settings = settingsRepository.fetch() else { return }

        await clearAll()

        // Birthday notifications are independent of daily reminders
        await scheduleBirthdays(settings: settings)

        if !settings.notificationsEnabled {
            try? await notificationCenter.setBadgeCount(0)
            return
        }

        let now = Date()
        let cadences = cadenceRepository.fetchAll()
        let people = personRepository.fetchTracked(includePaused: false)
        let classified = NotificationClassifier.classify(people: people, cadences: cadences, referenceDate: now)

        let badgeCount: Int
        if settings.badgeCountShowDueSoon {
            badgeCount = classified.allOverdue.count + classified.allDueSoon.count
        } else {
            badgeCount = classified.allOverdue.count
        }

        try? await notificationCenter.setBadgeCount(badgeCount)

        let hideNames = settings.hideContactNamesInNotifications

        for custom in classified.customOverrides {
            await scheduleCustomTime(person: custom.person, type: custom.type, time: custom.time, badgeCount: badgeCount, hideNames: hideNames)
        }

        switch settings.notificationGrouping {
        case .perType:
            await scheduleDaily(type: .dueToday, people: classified.dueToday, settings: settings, badgeCount: badgeCount)
            await scheduleDaily(type: .overdue, people: classified.overdue, settings: settings, badgeCount: badgeCount)
            await scheduleDaily(type: .dueSoon, people: classified.dueSoon, settings: settings, badgeCount: badgeCount)
        case .perDay:
            await scheduleDailyCombined(people: classified.allNonCustom, settings: settings, badgeCount: badgeCount)
        case .perPerson:
            await schedulePerPerson(type: .dueToday, people: classified.dueToday, settings: settings, badgeCount: badgeCount)
            await schedulePerPerson(type: .overdue, people: classified.overdue, settings: settings, badgeCount: badgeCount)
            await schedulePerPerson(type: .dueSoon, people: classified.dueSoon, settings: settings, badgeCount: badgeCount)
        }

        if settings.digestEnabled {
            // Dedup: if the digest would only mention one person, that person is already
            // covered by the daily breach alert. Suppress to avoid two notifications
            // about the same contact. Digest adds value only when summarising 2+ people.
            // Note: we've already returned above if notificationsEnabled is false, so
            // daily alerts are always active at this point.
            let digestPeople = classified.allForDigest
            if digestPeople.count > 1 {
                await scheduleWeeklyDigest(
                    overdue: digestPeople,
                    dueSoon: [],
                    settings: settings,
                    badgeCount: badgeCount
                )
            }
        }
    }

    private func scheduleDaily(type: DailyNotificationType, people: [Person], settings: AppSettings, badgeCount: Int) async {
        guard !people.isEmpty else { return }
        let triggerDate = nextDailyDate(for: settings.breachTimeOfDay)

        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = notificationBody(for: people, hideNames: settings.hideContactNamesInNotifications)
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = notificationUserInfo(for: people, type: type.userInfoType)
        if people.count == 1 {
            content.categoryIdentifier = NotificationIdentifier.categoryPerson
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let request = UNNotificationRequest(identifier: type.identifier, content: content, trigger: trigger)
        do {
            try await notificationCenter.add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications, context: "NotificationScheduler.scheduleDaily(\(type.identifier))")
        }
    }

    private func scheduleDailyCombined(people: [Person], settings: AppSettings, badgeCount: Int) async {
        guard !people.isEmpty else { return }
        let triggerDate = nextDailyDate(for: settings.breachTimeOfDay)

        let content = UNMutableNotificationContent()
        content.title = "Your connections today"
        content.body = notificationBody(for: people, hideNames: settings.hideContactNamesInNotifications)
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = ["type": "home", "category": "daily"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let request = UNNotificationRequest(identifier: NotificationIdentifier.dailyCombined, content: content, trigger: trigger)
        do {
            try await notificationCenter.add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications, context: "NotificationScheduler.scheduleDailyCombined")
        }
    }

    private func schedulePerPerson(type: DailyNotificationType, people: [Person], settings: AppSettings, badgeCount: Int) async {
        guard !people.isEmpty else { return }
        let triggerDate = nextDailyDate(for: settings.breachTimeOfDay)

        let hideNames = settings.hideContactNamesInNotifications

        for person in people {
            let content = UNMutableNotificationContent()
            content.title = type.title
            if hideNames {
                content.body = Self.privateSinglePersonTemplates.randomElement() ?? "Time to reconnect with someone"
            } else {
                content.body = String(format: Self.singlePersonTemplates.randomElement() ?? "Reach out to %@", person.displayName)
            }
            content.sound = .default
            content.badge = NSNumber(value: badgeCount)
            content.userInfo = ["type": "person", "personId": person.id.uuidString, "category": type.userInfoType]
            content.categoryIdentifier = NotificationIdentifier.categoryPerson

            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
            let request = UNNotificationRequest(identifier: "\(type.identifier)_\(person.id.uuidString)", content: content, trigger: trigger)
            do {
                try await notificationCenter.add(request)
            } catch {
                AppLogger.logError(error, category: AppLogger.notifications, context: "NotificationScheduler.schedulePerPerson(\(type.identifier), \(person.id))")
            }
        }
    }

    private func scheduleWeeklyDigest(overdue: [Person], dueSoon: [Person], settings: AppSettings, badgeCount: Int) async {
        let all = overdue + dueSoon
        guard !all.isEmpty else { return }

        let triggerDate = nextWeeklyDate(day: settings.digestDay, time: settings.digestTime)

        let content = UNMutableNotificationContent()
        content.title = "Your week in touch"
        content.body = notificationBody(for: all, hideNames: settings.hideContactNamesInNotifications)
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = notificationUserInfo(for: all, type: "digest")

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let request = UNNotificationRequest(identifier: NotificationIdentifier.weeklyDigest, content: content, trigger: trigger)
        do {
            try await notificationCenter.add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications, context: "NotificationScheduler.scheduleWeeklyDigest")
        }
    }

    private func notificationBody(for people: [Person], hideNames: Bool) -> String {
        if hideNames {
            if people.count == 1 {
                return Self.privateSinglePersonTemplates.randomElement() ?? "Time to reconnect with someone"
            }
            let template = Self.privateMultiPersonTemplates.randomElement() ?? "You have %d connections to catch up on"
            return String(format: template, people.count)
        }

        if people.count == 1, let person = people.first {
            let template = Self.singlePersonTemplates.randomElement() ?? "Reach out to %@"
            return String(format: template, person.displayName)
        }

        let preview = people.prefix(3).map { firstName(from: $0.displayName) }.joined(separator: ", ")
        let template = Self.multiPersonTemplates.randomElement() ?? "%d people need your attention, including %@"
        return String(format: template, people.count, preview)
    }

    private func notificationUserInfo(for people: [Person], type: String) -> [AnyHashable: Any] {
        if people.count == 1, let person = people.first {
            return ["type": "person", "personId": person.id.uuidString, "category": type]
        }
        return ["type": "home", "category": type]
    }

    private func firstName(from displayName: String) -> String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }

    private func nextDailyDate(for time: LocalTime) -> DateComponents {
        // Return only hour/minute so UNCalendarNotificationTrigger with
        // repeats:true fires daily at this time.
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        return components
    }

    private func nextWeeklyDate(day: DayOfWeek, time: LocalTime) -> DateComponents {
        // Return only weekday/hour/minute so UNCalendarNotificationTrigger
        // with repeats:true fires weekly on this day and time.
        var components = DateComponents()
        components.weekday = day.calendarWeekday
        components.hour = time.hour
        components.minute = time.minute
        return components
    }

    private func clearAll() async {
        notificationCenter.removeAllPendingNotificationRequests()
    }
}

private extension NotificationScheduler {
    func scheduleCustomTime(person: Person, type: DailyNotificationType, time: LocalTime, badgeCount: Int, hideNames: Bool) async {
        let triggerDate = nextDailyDate(for: time)
        let content = UNMutableNotificationContent()
        content.title = type.title
        if hideNames {
            content.body = Self.privateSinglePersonTemplates.randomElement() ?? "Time to reconnect with someone"
        } else {
            content.body = String(format: Self.singlePersonTemplates.randomElement() ?? "Reach out to %@", person.displayName)
        }
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = ["type": "person", "personId": person.id.uuidString, "category": type.userInfoType]
        content.categoryIdentifier = NotificationIdentifier.categoryPerson

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let request = UNNotificationRequest(identifier: "\(type.identifier)_custom_\(person.id.uuidString)", content: content, trigger: trigger)
        do {
            try await notificationCenter.add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications, context: "NotificationScheduler.scheduleCustomTime(\(type.identifier), \(person.id))")
        }
    }

    func scheduleBirthdays(settings: AppSettings) async {
        guard settings.birthdayNotificationsEnabled else { return }

        let ignoreSnoozePause = settings.birthdayIgnoreSnoozePause
        let people = personRepository.fetchTracked(includePaused: ignoreSnoozePause)
        let hideNames = settings.hideContactNamesInNotifications
        let time = settings.birthdayNotificationTime

        // Collect eligible (person, birthday) pairs grouped by calendar date
        struct BirthdayKey: Hashable { let month: Int; let day: Int }
        var groups: [BirthdayKey: [(Person, Birthday)]] = [:]

        for person in people {
            guard person.birthdayNotificationsEnabled else { continue }
            guard !person.notificationsMuted else { continue }
            if !ignoreSnoozePause, let snoozedUntil = person.snoozedUntil, snoozedUntil > Date() { continue }

            // Resolve birthday: stored first, then contact-sourced
            let birthday: Birthday?
            if let stored = person.birthday {
                birthday = stored
            } else if let cnId = person.cnIdentifier {
                birthday = ContactsFetcher.fetchBirthday(identifier: cnId)
            } else {
                birthday = nil
            }

            guard let birthday else { continue }
            let key = BirthdayKey(month: birthday.month, day: birthday.day)
            groups[key, default: []].append((person, birthday))
        }

        for (key, pairs) in groups {
            if pairs.count == 1, let (person, birthday) = pairs.first {
                await scheduleSingleBirthday(person: person, birthday: birthday, time: time, hideNames: hideNames)
            } else {
                await scheduleGroupedBirthday(people: pairs.map(\.0), month: key.month, day: key.day, time: time, hideNames: hideNames)
            }
        }
    }

    private func scheduleSingleBirthday(person: Person, birthday: Birthday, time: LocalTime, hideNames: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = "Birthday Today 🎂"
        if hideNames {
            content.body = Self.privateBirthdayTemplates.randomElement()
                ?? "A contact has a birthday today!"
        } else {
            content.body = String(
                format: Self.birthdayTemplates.randomElement()
                    ?? "It's %@'s birthday today!",
                person.displayName
            )
        }
        content.sound = .default
        content.threadIdentifier = "birthday"
        content.categoryIdentifier = NotificationIdentifier.categoryBirthday
        content.userInfo = [
            "type": "person",
            "personId": person.id.uuidString,
            "category": "birthday"
        ]

        var dateComponents = DateComponents()
        dateComponents.month = birthday.month
        dateComponents.day = birthday.day
        dateComponents.hour = time.hour
        dateComponents.minute = time.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(NotificationIdentifier.birthdayPrefix)\(person.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications,
                context: "NotificationScheduler.scheduleSingleBirthday(\(person.id))")
        }
    }

    private func scheduleGroupedBirthday(people: [Person], month: Int, day: Int, time: LocalTime, hideNames: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = "Birthdays Today 🎂"
        content.body = groupedBirthdayBody(for: people, hideNames: hideNames)
        content.sound = .default
        content.threadIdentifier = "birthday"
        // No categoryIdentifier: grouped notifications have no single personId, so
        // attaching the BIRTHDAY_REMINDER category (which includes a "Log Connection"
        // action) would silently do nothing when tapped. Leave unset so no action
        // button appears.
        content.userInfo = ["type": "home", "category": "birthday"]

        var dateComponents = DateComponents()
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = time.hour
        dateComponents.minute = time.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(NotificationIdentifier.birthdayGroupedPrefix)\(month)_\(day)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications,
                context: "NotificationScheduler.scheduleGroupedBirthday(\(month)/\(day))")
        }
    }

    private func groupedBirthdayBody(for people: [Person], hideNames: Bool) -> String {
        guard !hideNames else {
            return "Multiple contacts have birthdays today!"
        }
        let firstNames = people.map { firstName(from: $0.displayName) }
        switch firstNames.count {
        case 2:
            return "\(firstNames[0]) and \(firstNames[1]) have birthdays today!"
        default:
            let othersCount = firstNames.count - 2
            return "\(firstNames[0]), \(firstNames[1]), and \(othersCount) \(othersCount == 1 ? "other" : "others") have birthdays today!"
        }
    }
}

enum DailyNotificationType {
    case dueToday
    case overdue
    case dueSoon

    var identifier: String {
        switch self {
        case .dueToday: return NotificationIdentifier.dailyDueToday
        case .overdue: return NotificationIdentifier.dailyOverdue
        case .dueSoon: return NotificationIdentifier.dailyDueSoon
        }
    }

    var title: String {
        switch self {
        case .dueToday: return "Time to reconnect"
        case .overdue: return "Don't lose touch"
        case .dueSoon: return "Coming up soon"
        }
    }

    var userInfoType: String {
        switch self {
        case .dueToday: return "due_today"
        case .overdue: return "overdue"
        case .dueSoon: return "due_soon"
        }
    }
}

enum NotificationIdentifier {
    static let dailyDueToday = "daily_due_today"
    static let dailyOverdue = "daily_overdue"
    static let dailyDueSoon = "daily_due_soon"
    static let dailyCombined = "daily_combined"
    static let weeklyDigest = "weekly_digest"

    static let categoryPerson = "PERSON_REMINDER"
    static let actionLogConnection = "LOG_CONNECTION"

    static let birthdayPrefix = "birthday_"
    static let birthdayGroupedPrefix = "birthday_grouped_"
    static let categoryBirthday = "BIRTHDAY_REMINDER"
}

private extension DayOfWeek {
    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}
