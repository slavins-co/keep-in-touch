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

    func startObserving() {
        // Remove existing observers first to prevent duplicates
        stopObserving()

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
            return
        }

        await clearAll()

        let now = Date()
        let groups = groupRepository.fetchAll()
        let people = personRepository.fetchTracked(includePaused: false)
        let classified = NotificationClassifier.classify(people: people, groups: groups, referenceDate: now)

        let badgeCount = classified.allOverdue.count

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

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
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
        content.title = "Daily Reminders"
        content.body = notificationBody(for: people)
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = ["type": "home", "category": "daily"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
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
            content.body = "Reach out to \(person.displayName)."
            content.sound = .default
            content.badge = NSNumber(value: badgeCount)
            content.userInfo = ["type": "person", "personId": person.id.uuidString, "category": type.userInfoType]

            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
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
        content.title = "Weekly Digest"
        content.body = notificationBody(for: all)
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = notificationUserInfo(for: all, type: "digest")

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: NotificationIdentifier.weeklyDigest, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLogger.logError(error, category: AppLogger.notifications, context: "NotificationScheduler.scheduleWeeklyDigest")
        }
    }

    private func notificationBody(for people: [Person]) -> String {
        if people.count == 1 {
            return "Reach out to \(people[0].displayName)."
        }

        let preview = people.prefix(3).map { firstName(from: $0.displayName) }.joined(separator: ", ")
        return "\(people.count) people, including \(preview)…"
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
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = time.hour
        components.minute = time.minute
        let candidate = calendar.date(from: components) ?? Date()
        let next = candidate > Date() ? candidate : calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next)
    }

    private func nextWeeklyDate(day: DayOfWeek, time: LocalTime) -> DateComponents {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = time.hour
        components.minute = time.minute

        let currentWeekday = calendar.component(.weekday, from: now)
        var daysAhead = day.calendarWeekday - currentWeekday
        if daysAhead < 0 { daysAhead += 7 }

        let candidate = calendar.date(byAdding: .day, value: daysAhead, to: calendar.startOfDay(for: now)) ?? now
        let candidateWithTime = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: candidate) ?? candidate
        let next = candidateWithTime > now ? candidateWithTime : calendar.date(byAdding: .day, value: 7, to: candidateWithTime) ?? candidateWithTime
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next)
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
        content.body = "Reach out to \(person.displayName)."
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = ["type": "person", "personId": person.id.uuidString, "category": type.userInfoType]

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
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
        case .dueToday: return "Due Today"
        case .overdue: return "Overdue"
        case .dueSoon: return "Due Soon"
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
