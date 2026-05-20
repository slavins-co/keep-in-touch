//
//  PersonAppEntity.swift
//  KeepInTouch
//
//  AppEntity + EntityQuery that bridges Person from the domain layer
//  into App Intents / Shortcuts / Siri.
//
//  Surface area is intentionally minimal — only fields users can act on
//  inside a Shortcut. Phone/email are deliberately omitted to keep them
//  out of any donation graph.
//

import AppIntents
import Foundation

struct PersonAppEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Contact")
    }

    static var defaultQuery = PersonAppEntityQuery()

    let id: UUID
    let displayName: String
    let nickname: String?
    let lastTouchAt: Date?

    var displayRepresentation: DisplayRepresentation {
        let subtitle: LocalizedStringResource?
        if let lastTouchAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relative = formatter.localizedString(for: lastTouchAt, relativeTo: Date())
            subtitle = "Last touch \(relative)"
        } else {
            subtitle = "No touches yet"
        }
        return DisplayRepresentation(
            title: "\(displayName)",
            subtitle: subtitle
        )
    }

    init(id: UUID, displayName: String, nickname: String?, lastTouchAt: Date?) {
        self.id = id
        self.displayName = displayName
        self.nickname = nickname
        self.lastTouchAt = lastTouchAt
    }

    init(person: Person) {
        self.init(
            id: person.id,
            displayName: person.displayName,
            nickname: person.displayNickname,
            lastTouchAt: person.lastTouchAt
        )
    }
}

struct PersonAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [PersonAppEntity.ID]) async throws -> [PersonAppEntity] {
        let repository = IntentContainer.current.dependencies.personRepository
        let set = Set(identifiers)
        return identifiers.compactMap { id -> PersonAppEntity? in
            guard set.contains(id), let person = repository.fetch(id: id) else { return nil }
            return PersonAppEntity(person: person)
        }
    }

    func entities(matching string: String) async throws -> [PersonAppEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let repository = IntentContainer.current.dependencies.personRepository
        let matches = repository.searchByName(trimmed, includePaused: true)
        return matches.map(PersonAppEntity.init(person:))
    }

    func suggestedEntities() async throws -> [PersonAppEntity] {
        let repository = IntentContainer.current.dependencies.personRepository
        let tracked = repository.fetchTracked(includePaused: true)
        return tracked
            .sorted { ($0.lastTouchAt ?? .distantPast) > ($1.lastTouchAt ?? .distantPast) }
            .map(PersonAppEntity.init(person:))
    }
}
