//
//  GroupAppEntity.swift
//  KeepInTouchWidget
//
//  AppEntity + EntityQuery bridge so the widget's configuration sheet
//  can offer a picker of the user's Core Data groups, plus a synthetic
//  "All groups" option that acts as the default (no filter).
//

import AppIntents
import CoreData
import Foundation

struct GroupAppEntity: AppEntity, Identifiable {
    /// Sentinel UUID representing "no filter". Real Core Data Group
    /// UUIDs will never collide with this.
    static let allGroupsID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    static let allGroups = GroupAppEntity(id: allGroupsID, name: "All groups")

    var id: UUID
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Group" }
    static var defaultQuery = GroupAppEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct GroupAppEntityQuery: EntityQuery {
    func entities(for identifiers: [GroupAppEntity.ID]) async throws -> [GroupAppEntity] {
        let all = [GroupAppEntity.allGroups] + Self.fetchAllGroups()
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return identifiers.compactMap { byID[$0] }
    }

    func suggestedEntities() async throws -> [GroupAppEntity] {
        [GroupAppEntity.allGroups] + Self.fetchAllGroups()
    }

    func defaultResult() async -> GroupAppEntity? {
        GroupAppEntity.allGroups
    }

    static func fetchAllGroups() -> [GroupAppEntity] {
        guard let context = WidgetCoreData.shared?.viewContext else { return [] }
        var results: [GroupAppEntity] = []
        context.performAndWait {
            let request: NSFetchRequest<GroupEntity> = GroupEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "sortOrder", ascending: true),
                NSSortDescriptor(key: "name", ascending: true),
            ]
            let groups = (try? context.fetch(request)) ?? []
            results = groups.compactMap { group in
                guard let id = group.id, let name = group.name else { return nil }
                return GroupAppEntity(id: id, name: name)
            }
        }
        return results
    }
}
