//
//  ContactsSyncService.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation

enum ContactsSyncService {
    static func syncExistingContacts() async {
        let summaries = await Task.detached {
            do {
                return try ContactsFetcher.fetchAll()
            } catch {
                AppLogger.logError(error, category: AppLogger.coreData, context: "ContactsSyncService.syncExistingContacts")
                return []
            }
        }.value

        let byId = Dictionary(uniqueKeysWithValues: summaries.map { ($0.identifier, $0) })
        let backgroundContext = CoreDataStack.shared.newBackgroundContext()

        await backgroundContext.perform {
            let repo = CoreDataPersonRepository(context: backgroundContext)
            let people = repo.fetchTracked(includePaused: true)
            let now = Date()

            for person in people {
                guard let cnId = person.cnIdentifier else { continue }
                var updated = person

                if let summary = byId[cnId] {
                    // Contact still exists — sync name and clear unavailable flag
                    updated.displayName = summary.displayName
                    updated.initials = summary.initials
                    if updated.contactUnavailable {
                        updated.contactUnavailable = false
                    }
                    // Sync birthday from CNContacts when not manually set
                    if updated.birthday == nil, let contactBirthday = summary.birthday {
                        updated.birthday = contactBirthday
                    }
                } else {
                    // Contact no longer found — mark unavailable
                    if !updated.contactUnavailable {
                        updated.contactUnavailable = true
                    } else {
                        continue // already marked, skip save
                    }
                }

                updated.modifiedAt = now
                do {
                    try repo.save(updated)
                } catch {
                    AppLogger.logError(error, category: AppLogger.coreData, context: "ContactsSyncService.syncExistingContacts")
                }
            }
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .contactsDidSync, object: nil)
        }
    }
}
