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

        // E4: collect all per-row updates and issue a single batchSave + one
        // widget refresh. Previously 100 contacts on refresh = 100 Core Data
        // transactions + 100 WidgetRefresher.reloadAllTimelines() calls. We
        // preserve the existing skip-if-already-marked behavior so the set
        // of rows that change is identical to the per-row version.
        let updates: [Person] = await backgroundContext.perform {
            let repo = CoreDataPersonRepository(context: backgroundContext)
            let people = repo.fetchTracked(includePaused: true)
            let now = Date()
            var changed: [Person] = []
            changed.reserveCapacity(people.count)

            for person in people {
                guard let cnId = person.cnIdentifier else { continue }
                var updated = person

                if let summary = byId[cnId] {
                    // Contact still exists — sync name, nickname and clear unavailable flag
                    updated.displayName = summary.displayName
                    updated.nickname = summary.nickname
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
                changed.append(updated)
            }
            return changed
        }

        guard !updates.isEmpty else {
            await MainActor.run {
                NotificationCenter.default.post(name: .contactsDidSync, object: nil)
            }
            return
        }

        do {
            // batchUpsertEntities runs inside its own performAndWait on the
            // background context, executes a single context.save(), and fires
            // one WidgetRefresher.reloadAllTimelines() at the end.
            let repo = CoreDataPersonRepository(context: backgroundContext)
            try repo.batchSave(updates)
        } catch {
            AppLogger.logError(error, category: AppLogger.coreData, context: "ContactsSyncService.syncExistingContacts")
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .contactsDidSync, object: nil)
        }
    }
}
