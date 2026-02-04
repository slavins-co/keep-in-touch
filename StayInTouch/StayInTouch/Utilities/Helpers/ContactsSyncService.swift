//
//  ContactsSyncService.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation

enum ContactsSyncService {
    static func syncExistingContacts() async {
        let summaries = await Task.detached {
            (try? ContactsFetcher.fetchAll()) ?? []
        }.value

        let byId = Dictionary(uniqueKeysWithValues: summaries.map { ($0.identifier, $0) })
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()

        await backgroundContext.perform {
            let repo = CoreDataPersonRepository(context: backgroundContext)
            let people = repo.fetchTracked(includePaused: true)
            let now = Date()

            for person in people {
                guard let cnId = person.cnIdentifier, let summary = byId[cnId] else { continue }
                var updated = person
                updated.displayName = summary.displayName
                updated.initials = summary.initials
                updated.modifiedAt = now
                try? repo.save(updated)
            }
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .contactsDidSync, object: nil)
        }
    }
}
