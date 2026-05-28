//
//  BirthdayCacheRefresher.swift
//  KeepInTouch (app target only — uses Contacts + Core Data)
//
//  Resolves contact-sourced birthdays for tracked, opted-in people who have
//  no stored `Person.birthday`, and writes them to the App Group
//  `BirthdayCache` so the widget extension can surface them without touching
//  CNContactStore (Apple discourages Contacts access inside a widget's
//  timeline budget). This mirrors, for the widget, what NotificationScheduler
//  already does live for birthday notifications.
//
//  Runs on app launch and foreground. ContactsSyncService persists contact
//  birthdays onto Person.birthday during its own sync, so this fills the gap
//  between syncs rather than duplicating that work.
//

import Foundation

struct BirthdayCacheRefresher {
    private let fetchPeople: () -> [Person]
    private let fetchContactBirthdays: ([String]) -> [String: Birthday]
    private let writeCache: ([UUID: Birthday]) -> Void
    private let reloadWidgets: () -> Void

    init(
        fetchPeople: @escaping () -> [Person] = BirthdayCacheRefresher.defaultFetchPeople,
        fetchContactBirthdays: @escaping ([String]) -> [String: Birthday] = ContactsFetcher.fetchBirthdays,
        writeCache: @escaping ([UUID: Birthday]) -> Void = { BirthdayCache.write($0) },
        reloadWidgets: @escaping () -> Void = WidgetRefresher.reloadAllTimelines
    ) {
        self.fetchPeople = fetchPeople
        self.fetchContactBirthdays = fetchContactBirthdays
        self.writeCache = writeCache
        self.reloadWidgets = reloadWidgets
    }

    /// Rebuilds the cache from scratch (a full overwrite, so resolved-then-
    /// removed contacts don't linger) and reloads widget timelines. Safe to
    /// call off the main thread; `defaultFetchPeople` uses its own background
    /// context, and the Contacts fetch is the expensive part.
    func refresh() {
        let candidates = fetchPeople().filter { person in
            person.birthdayNotificationsEnabled
                && person.birthday == nil
                && !(person.cnIdentifier ?? "").isEmpty
        }

        let cache: [UUID: Birthday]
        if candidates.isEmpty {
            cache = [:]
        } else {
            let identifiers = candidates.compactMap(\.cnIdentifier)
            let contactBirthdays = fetchContactBirthdays(identifiers)
            cache = Self.resolveCache(people: candidates, contactBirthdays: contactBirthdays)
        }

        writeCache(cache)
        reloadWidgets()
    }

    /// Pure mapping from people + a (cnIdentifier → Birthday) lookup to the
    /// person-id-keyed cache. People without a resolved contact birthday are
    /// dropped.
    static func resolveCache(people: [Person], contactBirthdays: [String: Birthday]) -> [UUID: Birthday] {
        var result: [UUID: Birthday] = [:]
        for person in people {
            guard let cnId = person.cnIdentifier, let birthday = contactBirthdays[cnId] else { continue }
            result[person.id] = birthday
        }
        return result
    }

    /// Fetches tracked people on a private background context (the Contacts +
    /// cache work that follows must not run on the main view context).
    static func defaultFetchPeople() -> [Person] {
        let context = CoreDataStack.shared.newBackgroundContext()
        var people: [Person] = []
        context.performAndWait {
            people = CoreDataPersonRepository(context: context).fetchTracked(includePaused: true)
        }
        return people
    }

    /// Fire-and-forget refresh on a utility-priority background task.
    static func refreshInBackground() {
        Task.detached(priority: .utility) {
            BirthdayCacheRefresher().refresh()
        }
    }
}
