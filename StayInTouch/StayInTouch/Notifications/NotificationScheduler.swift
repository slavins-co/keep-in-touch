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

    /// Coalescing window for `.personDidChange` / `.settingsDidChange` bursts.
    /// A single Person Detail tap (toggle pause, set custom breach time, etc.)
    /// historically triggered scheduleAll(); rapid succession of edits would
    /// re-run the entire classification + scheduling pipeline N times. This
    /// debouncer collapses bursts within `debounceInterval` into one run.
    /// Set to 1.0s — long enough to absorb typical UI tap bursts, short enough
    /// that the user-visible reschedule still feels immediate. Direct
    /// `scheduleAll()` callers (AppDelegate didFinishLaunching, scenePhase
    /// transitions, background refresh) bypass the debouncer.
    private let debounceInterval: TimeInterval
    private var pendingScheduleTask: Task<Void, Never>?

    init(
        settingsRepository: AppSettingsRepository = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext),
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        cadenceRepository: CadenceRepository = CoreDataCadenceRepository(context: CoreDataStack.shared.viewContext),
        notificationCenter: UserNotificationCenterProtocol = UNUserNotificationCenter.current(),
        debounceInterval: TimeInterval = 1.0
    ) {
        self.settingsRepository = settingsRepository
        self.personRepository = personRepository
        self.cadenceRepository = cadenceRepository
        self.notificationCenter = notificationCenter
        self.debounceInterval = debounceInterval
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

        // Deliver on .main so scheduleAllDebounced()'s access to the
        // shared pendingScheduleTask is serialized — observer posts can
        // originate from any thread, and the debouncer mutates shared state.
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleAllDebounced()
        }
        personObserver = NotificationCenter.default.addObserver(
            forName: .personDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleAllDebounced()
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
        pendingScheduleTask?.cancel()
        pendingScheduleTask = nil
    }

    /// Coalesces a burst of `.personDidChange` / `.settingsDidChange` posts into
    /// a single `scheduleAll()` run. Each call cancels the previous pending
    /// task (if it has not started its work yet) and queues a fresh sleep +
    /// scheduleAll. If the sleep is cancelled the task exits without calling
    /// scheduleAll — the *next* post will schedule again. If the sleep has
    /// already elapsed and `scheduleAll()` is in flight, we let it complete
    /// and the new post enqueues a fresh task — no reschedule is ever lost.
    ///
    /// This intentionally does NOT change the content, timing, identifier, or
    /// trigger of the resulting UNNotificationRequests — only *how often*
    /// scheduleAll runs in response to upstream change posts.
    func scheduleAllDebounced() {
        pendingScheduleTask?.cancel()
        let interval = debounceInterval
        pendingScheduleTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                return  // cancelled before sleep elapsed — newer post will reschedule
            }
            await self?.scheduleAll()
        }
    }

    deinit {
        stopObserving()
    }

    func scheduleAll() async {
        guard let settings = settingsRepository.fetch() else { return }

        await clearAll()

        // E6: build the entire batch of UNNotificationRequests synchronously
        // (cheap — random template selection + content/trigger construction),
        // then issue all `notificationCenter.add(_:)` calls in a single
        // TaskGroup. Previously each `add` was awaited sequentially even
        // though every request is independent. The synchronous build phase
        // preserves the existing relative-order semantics of
        // `randomElement()` template picks across notification kinds, so the
        // *set* of scheduled requests is identical to the pre-E6 behavior —
        // only the I/O issuance overlaps.

        var requests: [UNNotificationRequest] = []

        // Birthday notifications are independent of daily reminders and fire
        // even when notificationsEnabled is false.
        requests.append(contentsOf: birthdayRequests(settings: settings))

        if !settings.notificationsEnabled {
            // Still issue any birthday requests built above before resetting
            // the badge — birthdays are gated on their own setting.
            await addAll(requests)
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
            if let request = customTimeRequest(
                person: custom.person,
                type: custom.type,
                time: custom.time,
                badgeCount: badgeCount,
                hideNames: hideNames
            ) {
                requests.append(request)
            }
        }

        switch settings.notificationGrouping {
        case .perType:
            if let r = dailyRequest(type: .dueToday, people: classified.dueToday, settings: settings, badgeCount: badgeCount) { requests.append(r) }
            if let r = dailyRequest(type: .overdue, people: classified.overdue, settings: settings, badgeCount: badgeCount) { requests.append(r) }
            if let r = dailyRequest(type: .dueSoon, people: classified.dueSoon, settings: settings, badgeCount: badgeCount) { requests.append(r) }
        case .perDay:
            if let r = dailyCombinedRequest(people: classified.allNonCustom, settings: settings, badgeCount: badgeCount) {
                requests.append(r)
            }
        case .perPerson:
            requests.append(contentsOf: perPersonRequests(type: .dueToday, people: classified.dueToday, settings: settings, badgeCount: badgeCount))
            requests.append(contentsOf: perPersonRequests(type: .overdue, people: classified.overdue, settings: settings, badgeCount: badgeCount))
            requests.append(contentsOf: perPersonRequests(type: .dueSoon, people: classified.dueSoon, settings: settings, badgeCount: badgeCount))
        }

        if settings.digestEnabled {
            // Dedup: if the digest would only mention one person, that person is already
            // covered by the daily breach alert. Suppress to avoid two notifications
            // about the same contact. Digest adds value only when summarising 2+ people.
            // Note: we've already returned above if notificationsEnabled is false, so
            // daily alerts are always active at this point.
            let digestPeople = classified.allForDigest
            if digestPeople.count > 1 {
                if let r = weeklyDigestRequest(
                    overdue: digestPeople,
                    dueSoon: [],
                    settings: settings,
                    badgeCount: badgeCount
                ) {
                    requests.append(r)
                }
            }
        }

        await addAll(requests)
    }

    /// Submits a batch of UNNotificationRequests concurrently. The real
    /// `UNUserNotificationCenter` is thread-safe and each add is independent
    /// (different identifier per request), so a TaskGroup is the natural
    /// fit. Errors are logged per-request and do not abort siblings —
    /// matches the prior per-call `try? await` semantics.
    private func addAll(_ requests: [UNNotificationRequest]) async {
        guard !requests.isEmpty else { return }
        let center = notificationCenter
        await withTaskGroup(of: Void.self) { group in
            for request in requests {
                let identifier = request.identifier
                group.addTask {
                    do {
                        try await center.add(request)
                    } catch {
                        AppLogger.logError(
                            error,
                            category: AppLogger.notifications,
                            context: "NotificationScheduler.addAll(\(identifier))"
                        )
                    }
                }
            }
        }
    }

    // E6: each `*Request(...)` builder constructs the UNNotificationRequest
    // synchronously and returns it. `scheduleAll()` collects all requests
    // and submits them concurrently via `addAll`. Content/trigger
    // construction is unchanged — only the I/O issuance is parallelized.
    private func dailyRequest(type: DailyNotificationType, people: [Person], settings: AppSettings, badgeCount: Int) -> UNNotificationRequest? {
        guard !people.isEmpty else { return nil }
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
        return UNNotificationRequest(identifier: type.identifier, content: content, trigger: trigger)
    }

    private func dailyCombinedRequest(people: [Person], settings: AppSettings, badgeCount: Int) -> UNNotificationRequest? {
        guard !people.isEmpty else { return nil }
        let triggerDate = nextDailyDate(for: settings.breachTimeOfDay)

        let content = UNMutableNotificationContent()
        content.title = "Your connections today"
        content.body = notificationBody(for: people, hideNames: settings.hideContactNamesInNotifications)
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = [
            NotificationIdentifier.UserInfoKey.type.rawValue: NotificationIdentifier.UserInfoValue.home.rawValue,
            NotificationIdentifier.UserInfoKey.category.rawValue: NotificationIdentifier.UserInfoValue.daily.rawValue
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        return UNNotificationRequest(identifier: NotificationIdentifier.dailyCombined, content: content, trigger: trigger)
    }

    private func perPersonRequests(type: DailyNotificationType, people: [Person], settings: AppSettings, badgeCount: Int) -> [UNNotificationRequest] {
        guard !people.isEmpty else { return [] }
        let triggerDate = nextDailyDate(for: settings.breachTimeOfDay)
        let hideNames = settings.hideContactNamesInNotifications

        return people.map { person in
            let content = UNMutableNotificationContent()
            content.title = type.title
            if hideNames {
                content.body = Self.privateSinglePersonTemplates.randomElement() ?? "Time to reconnect with someone"
            } else {
                content.body = String(format: Self.singlePersonTemplates.randomElement() ?? "Reach out to %@", person.displayName)
            }
            content.sound = .default
            content.badge = NSNumber(value: badgeCount)
            content.userInfo = [
                NotificationIdentifier.UserInfoKey.type.rawValue: NotificationIdentifier.UserInfoValue.person.rawValue,
                NotificationIdentifier.UserInfoKey.personId.rawValue: person.id.uuidString,
                NotificationIdentifier.UserInfoKey.category.rawValue: type.userInfoType
            ]
            content.categoryIdentifier = NotificationIdentifier.categoryPerson

            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
            return UNNotificationRequest(identifier: "\(type.identifier)_\(person.id.uuidString)", content: content, trigger: trigger)
        }
    }

    private func weeklyDigestRequest(overdue: [Person], dueSoon: [Person], settings: AppSettings, badgeCount: Int) -> UNNotificationRequest? {
        let all = overdue + dueSoon
        guard !all.isEmpty else { return nil }

        let triggerDate = nextWeeklyDate(day: settings.digestDay, time: settings.digestTime)

        let content = UNMutableNotificationContent()
        content.title = "Your week in touch"
        content.body = notificationBody(for: all, hideNames: settings.hideContactNamesInNotifications)
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        content.userInfo = notificationUserInfo(for: all, type: NotificationIdentifier.UserInfoValue.digest.rawValue)

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        return UNNotificationRequest(identifier: NotificationIdentifier.weeklyDigest, content: content, trigger: trigger)
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
            return [
                NotificationIdentifier.UserInfoKey.type.rawValue: NotificationIdentifier.UserInfoValue.person.rawValue,
                NotificationIdentifier.UserInfoKey.personId.rawValue: person.id.uuidString,
                NotificationIdentifier.UserInfoKey.category.rawValue: type
            ]
        }
        return [
            NotificationIdentifier.UserInfoKey.type.rawValue: NotificationIdentifier.UserInfoValue.home.rawValue,
            NotificationIdentifier.UserInfoKey.category.rawValue: type
        ]
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
    func customTimeRequest(person: Person, type: DailyNotificationType, time: LocalTime, badgeCount: Int, hideNames: Bool) -> UNNotificationRequest? {
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
        content.userInfo = [
            NotificationIdentifier.UserInfoKey.type.rawValue: NotificationIdentifier.UserInfoValue.person.rawValue,
            NotificationIdentifier.UserInfoKey.personId.rawValue: person.id.uuidString,
            NotificationIdentifier.UserInfoKey.category.rawValue: type.userInfoType
        ]
        content.categoryIdentifier = NotificationIdentifier.categoryPerson

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        return UNNotificationRequest(identifier: "\(type.identifier)_custom_\(person.id.uuidString)", content: content, trigger: trigger)
    }

    func birthdayRequests(settings: AppSettings) -> [UNNotificationRequest] {
        guard settings.birthdayNotificationsEnabled else { return [] }

        let ignoreSnoozePause = settings.birthdayIgnoreSnoozePause
        let people = personRepository.fetchTracked(includePaused: ignoreSnoozePause)
        let hideNames = settings.hideContactNamesInNotifications
        let time = settings.birthdayNotificationTime

        // First pass: filter eligibility (cheap, in-memory) and collect the
        // set of `cnIdentifier`s we need to resolve from the Contacts store.
        // Previously each eligible person without a stored birthday opened a
        // fresh CNContactStore — N people = N XPC round-trips. Batch them.
        var eligible: [Person] = []
        var idsNeedingContactBirthday: [String] = []
        for person in people {
            guard person.birthdayNotificationsEnabled else { continue }
            guard !person.notificationsMuted else { continue }
            if !ignoreSnoozePause, person.isSnoozed() { continue }
            eligible.append(person)
            if person.birthday == nil, let cnId = person.cnIdentifier {
                idsNeedingContactBirthday.append(cnId)
            }
        }

        let contactBirthdaysById = ContactsFetcher.fetchBirthdays(identifiers: idsNeedingContactBirthday)

        // Second pass: assemble (person, birthday) pairs grouped by calendar date.
        struct BirthdayKey: Hashable { let month: Int; let day: Int }
        var groups: [BirthdayKey: [(Person, Birthday)]] = [:]

        for person in eligible {
            let birthday: Birthday?
            if let stored = person.birthday {
                birthday = stored
            } else if let cnId = person.cnIdentifier {
                birthday = contactBirthdaysById[cnId]
            } else {
                birthday = nil
            }

            guard let birthday else { continue }
            let key = BirthdayKey(month: birthday.month, day: birthday.day)
            groups[key, default: []].append((person, birthday))
        }

        var requests: [UNNotificationRequest] = []
        for (key, pairs) in groups {
            if pairs.count == 1, let (person, birthday) = pairs.first {
                requests.append(singleBirthdayRequest(person: person, birthday: birthday, time: time, hideNames: hideNames))
            } else {
                requests.append(groupedBirthdayRequest(people: pairs.map(\.0), month: key.month, day: key.day, time: time, hideNames: hideNames))
            }
        }
        return requests
    }

    private func singleBirthdayRequest(person: Person, birthday: Birthday, time: LocalTime, hideNames: Bool) -> UNNotificationRequest {
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
            NotificationIdentifier.UserInfoKey.type.rawValue: NotificationIdentifier.UserInfoValue.person.rawValue,
            NotificationIdentifier.UserInfoKey.personId.rawValue: person.id.uuidString,
            NotificationIdentifier.UserInfoKey.category.rawValue: NotificationIdentifier.UserInfoValue.birthday.rawValue
        ]

        var dateComponents = DateComponents()
        dateComponents.month = birthday.month
        dateComponents.day = birthday.day
        dateComponents.hour = time.hour
        dateComponents.minute = time.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        return UNNotificationRequest(
            identifier: "\(NotificationIdentifier.birthdayPrefix)\(person.id.uuidString)",
            content: content,
            trigger: trigger
        )
    }

    private func groupedBirthdayRequest(people: [Person], month: Int, day: Int, time: LocalTime, hideNames: Bool) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Birthdays Today 🎂"
        content.body = groupedBirthdayBody(for: people, hideNames: hideNames)
        content.sound = .default
        content.threadIdentifier = "birthday"
        // No categoryIdentifier: grouped notifications have no single personId, so
        // attaching the BIRTHDAY_REMINDER category (which includes a "Log Connection"
        // action) would silently do nothing when tapped. Leave unset so no action
        // button appears.
        content.userInfo = [
            NotificationIdentifier.UserInfoKey.type.rawValue: NotificationIdentifier.UserInfoValue.home.rawValue,
            NotificationIdentifier.UserInfoKey.category.rawValue: NotificationIdentifier.UserInfoValue.birthday.rawValue
        ]

        var dateComponents = DateComponents()
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = time.hour
        dateComponents.minute = time.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        return UNNotificationRequest(
            identifier: "\(NotificationIdentifier.birthdayGroupedPrefix)\(month)_\(day)",
            content: content,
            trigger: trigger
        )
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

    /// Typed keys for `UNNotificationContent.userInfo`. Raw values are the
    /// stringly-typed keys preserved byte-identical from prior call sites so
    /// in-flight notifications and DeepLinkRouter parsing keep working.
    enum UserInfoKey: String {
        case type
        case personId
        case category
    }

    /// Typed values used under `UserInfoKey.type` (the "kind" of notification)
    /// and `UserInfoKey.category` (the bucket it belongs to). Raw values match
    /// the prior string literals byte-identical.
    enum UserInfoValue: String {
        // type values
        case home
        case person
        // category values
        case daily
        case digest
        case birthday
        // SettingsViewModel.sendTestNotification uses this category
        case test
    }
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
