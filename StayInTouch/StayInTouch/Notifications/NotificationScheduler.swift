//
//  NotificationScheduler.swift
//  StayInTouch
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

    private let settingsRepository: AppSettingsRepository
    private let personRepository: PersonRepository
    private let groupRepository: GroupRepository
    private var settingsObserver: NSObjectProtocol?
    private var personObserver: NSObjectProtocol?

    private init(
        settingsRepository: AppSettingsRepository = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext),
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext)
    ) {
        self.settingsRepository = settingsRepository
        self.personRepository = personRepository
        self.groupRepository = groupRepository
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
        UNUserNotificationCenter.current().setNotificationCategories([personCategory])
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
        if !settings.notificationsEnabled {
            await clearAll()
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
            return
        }

        await clearAll()

        let now = Date()
        let groups = groupRepository.fetchAll()
        let people = personRepository.fetchTracked(includePaused: false)
        let classified = NotificationClassifier.classify(people: people, groups: groups, referenceDate: now)

        let badgeCount: Int
        switch settings.badgeCountOption {
        case .overdueOnly:
            badgeCount = classified.allOverdue.count
        case .overdueAndDueSoon:
            badgeCount = classified.allOverdue.count + classified.allDueSoon.count
        }

        try? await UNUserNotificationCenter.current().setBadgeCount(badgeCount)

        for custom in classified.customOverrides {
            await scheduleCustomTime(person: custom.person, type: custom.type, time: custom.time, badgeCount: badgeCount)
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
            await scheduleWeeklyDigest(
                overdue: classified.allForDigest,
                dueSoon: [],
                settings: settings,
                badgeCount: badgeCount
            )
        }
    }

    private func scheduleDaily(type: DailyNotificationType, people: [Person], settings: AppSettings, badgeCount: Int) async {
        guard !people.isEmpty else { return }
        let triggerDate = nextDailyDate(for: settings.breachTimeOfDay)

        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = notificationBody(for: people)
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = notificationUserInfo(for: people, type: type.userInfoType)
        if people.count == 1 {
            content.categoryIdentifier = NotificationIdentifier.categoryPerson
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let request = UNNotificationRequest(identifier: type.identifier, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications, context: "NotificationScheduler.scheduleDaily(\(type.identifier))")
        }
    }

    private func scheduleDailyCombined(people: [Person], settings: AppSettings, badgeCount: Int) async {
        guard !people.isEmpty else { return }
        let triggerDate = nextDailyDate(for: settings.breachTimeOfDay)

        let content = UNMutableNotificationContent()
        content.title = "Your connections today"
        content.body = notificationBody(for: people)
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = ["type": "home", "category": "daily"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let request = UNNotificationRequest(identifier: NotificationIdentifier.dailyCombined, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications, context: "NotificationScheduler.scheduleDailyCombined")
        }
    }

    private func schedulePerPerson(type: DailyNotificationType, people: [Person], settings: AppSettings, badgeCount: Int) async {
        guard !people.isEmpty else { return }
        let triggerDate = nextDailyDate(for: settings.breachTimeOfDay)

        for person in people {
            let content = UNMutableNotificationContent()
            content.title = type.title
            content.body = String(format: Self.singlePersonTemplates.randomElement()!, person.displayName)
            content.sound = .default
            content.badge = NSNumber(value: badgeCount)
            content.userInfo = ["type": "person", "personId": person.id.uuidString, "category": type.userInfoType]
            content.categoryIdentifier = NotificationIdentifier.categoryPerson

            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
            let request = UNNotificationRequest(identifier: "\(type.identifier)_\(person.id.uuidString)", content: content, trigger: trigger)
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                AppLogger.logError(error, category: AppLogger.notifications, context: "NotificationScheduler.schedulePerPerson(\(type.identifier), \(person.displayName))")
            }
        }
    }

    private func scheduleWeeklyDigest(overdue: [Person], dueSoon: [Person], settings: AppSettings, badgeCount: Int) async {
        let all = overdue + dueSoon
        guard !all.isEmpty else { return }

        let triggerDate = nextWeeklyDate(day: settings.digestDay, time: settings.digestTime)

        let content = UNMutableNotificationContent()
        content.title = "Your week in touch"
        content.body = notificationBody(for: all)
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = notificationUserInfo(for: all, type: "digest")

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let request = UNNotificationRequest(identifier: NotificationIdentifier.weeklyDigest, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications, context: "NotificationScheduler.scheduleWeeklyDigest")
        }
    }

    private func notificationBody(for people: [Person]) -> String {
        if people.count == 1 {
            let template = Self.singlePersonTemplates.randomElement()!
            return String(format: template, people[0].displayName)
        }

        let preview = people.prefix(3).map { firstName(from: $0.displayName) }.joined(separator: ", ")
        let template = Self.multiPersonTemplates.randomElement()!
        return String(format: template, people.count, preview)
    }

    private func notificationUserInfo(for people: [Person], type: String) -> [AnyHashable: Any] {
        if people.count == 1 {
            return ["type": "person", "personId": people[0].id.uuidString, "category": type]
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
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

private extension NotificationScheduler {
    func scheduleCustomTime(person: Person, type: DailyNotificationType, time: LocalTime, badgeCount: Int) async {
        let triggerDate = nextDailyDate(for: time)
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = String(format: Self.singlePersonTemplates.randomElement()!, person.displayName)
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = ["type": "person", "personId": person.id.uuidString, "category": type.userInfoType]
        content.categoryIdentifier = NotificationIdentifier.categoryPerson

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let request = UNNotificationRequest(identifier: "\(type.identifier)_custom_\(person.id.uuidString)", content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications, context: "NotificationScheduler.scheduleCustomTime(\(type.identifier), \(person.displayName))")
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
