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

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var displayRepresentation: DisplayRepresentation {
        let subtitle: LocalizedStringResource?
        if let lastTouchAt {
            let relative = Self.relativeFormatter.localizedString(for: lastTouchAt, relativeTo: Date())
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
    // Stale ids (saved-shortcut snapshots that no longer resolve) get a
    // **tombstone** entity — same id, displayName flagging the contact
    // is gone. We can't return [] (Apple's documented "omit") because
    // the framework reacts to a missing required-parameter value by
    // showing the standard contact picker with no explanation of why.
    // QA on PR #305 confirmed that picker behavior is confusing.
    //
    // With a tombstone present, the framework proceeds to `perform()`,
    // where each intent's `repository.fetch(id: person.id) == nil`
    // guard fires and surfaces a clear "no longer in Keep In Touch"
    // error dialog. Bonus: the Shortcut editor row also shows the
    // tombstone label, so users can spot the staleness without running.
    static let staleDisplayName = "(no longer in Keep In Touch)"

    func entities(for identifiers: [PersonAppEntity.ID]) async throws -> [PersonAppEntity] {
        let repository = IntentContainer.current.dependencies.personRepository
        return identifiers.map { id -> PersonAppEntity in
            if let person = repository.fetch(id: id) {
                return PersonAppEntity(person: person)
            }
            return PersonAppEntity(
                id: id,
                displayName: Self.staleDisplayName,
                nickname: nil,
                lastTouchAt: nil
            )
        }
    }

    func entities(matching string: String) async throws -> [PersonAppEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let repository = IntentContainer.current.dependencies.personRepository
        let matches = repository.searchByName(trimmed, includePaused: true)
        return matches.map(PersonAppEntity.init(person:))
    }

    /// Siri renders the top suggestions inline in its parameter picker, so
    /// cap the response at a small number of most-recently-touched contacts.
    /// Sorting all tracked people (potentially hundreds) just to discard most
    /// of them is wasted work on a Siri-cold-launch path.
    private static let suggestedEntitiesLimit = 12

    func suggestedEntities() async throws -> [PersonAppEntity] {
        let repository = IntentContainer.current.dependencies.personRepository
        let tracked = repository.fetchTracked(includePaused: true)
        let topRecent = tracked
            .sorted { ($0.lastTouchAt ?? .distantPast) > ($1.lastTouchAt ?? .distantPast) }
            .prefix(Self.suggestedEntitiesLimit)
        return topRecent.map(PersonAppEntity.init(person:))
    }
}
