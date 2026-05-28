//
//  BirthdayCache.swift
//  KeepInTouch (Shared — compiled into main app + widget extension)
//
//  App Group-backed cache of contact-sourced birthdays, keyed by Person id.
//  The main app (which holds Contacts access) resolves birthdays for tracked
//  people that have no stored `Person.birthday` and writes them here; the
//  widget extension reads this cache so it never touches `CNContactStore`
//  from a timeline provider. Apple discourages Contacts access inside a
//  widget's tight execution budget, and `ContactsFetcher.fetchBirthdays`
//  is expensive (a fresh store per call). Contact data therefore stays out
//  of the `Person` entity — this cache is the only place it's persisted.
//

import Foundation

enum BirthdayCache {
    static let filename = "birthdayCache.json"

    static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(filename)
    }

    /// Reads the cache. Returns an empty map on any failure (missing file,
    /// missing container, corrupt JSON) — callers degrade to stored-only.
    static func read(from url: URL? = fileURL) -> [UUID: Birthday] {
        guard
            let url,
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String: Birthday].self, from: data)
        else { return [:] }

        return Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
            UUID(uuidString: key).map { ($0, value) }
        })
    }

    /// Writes the cache atomically. Returns false if the container is
    /// unavailable or encoding/writing fails (non-fatal — the widget keeps
    /// showing stored birthdays until the next successful refresh).
    @discardableResult
    static func write(_ birthdays: [UUID: Birthday], to url: URL? = fileURL) -> Bool {
        guard let url else { return false }
        let stringKeyed = Dictionary(uniqueKeysWithValues: birthdays.map { ($0.key.uuidString, $0.value) })
        guard let data = try? JSONEncoder().encode(stringKeyed) else { return false }
        do {
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }
}
