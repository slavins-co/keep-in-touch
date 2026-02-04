//
//  ManageGroupsViewModel.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import Foundation

@MainActor
final class ManageGroupsViewModel: ObservableObject {
    @Published private(set) var groups: [Group] = []
    @Published private(set) var countsByGroup: [UUID: Int] = [:]

    private let groupRepository: GroupRepository
    private let personRepository: PersonRepository

    init(
        groupRepository: GroupRepository = CoreDataGroupRepository(context: CoreDataStack.shared.viewContext),
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext)
    ) {
        self.groupRepository = groupRepository
        self.personRepository = personRepository
        load()
    }

    func load() {
        groups = groupRepository.fetchAll().sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let people = personRepository.fetchTracked(includePaused: true)
        var counts: [UUID: Int] = [:]
        for person in people {
            let groupId = person.groupId
            counts[groupId, default: 0] += 1
        }
        countsByGroup = counts
    }

    func save(_ group: Group, makeDefault: Bool) {
        var updated = group
        updated.modifiedAt = Date()

        if makeDefault {
            let all = groupRepository.fetchAll()
            for existing in all where existing.id != updated.id && existing.isDefault {
                var cleared = existing
                cleared.isDefault = false
                cleared.modifiedAt = Date()
                try? groupRepository.save(cleared)
            }
            updated.isDefault = true
        }

        try? groupRepository.save(updated)
        load()
    }

    func delete(group: Group) {
        try? groupRepository.delete(id: group.id)
        load()
    }

    func movePeople(from group: Group, to defaultGroup: Group) {
        let people = personRepository.fetchByGroup(id: group.id, includePaused: true)
        for person in people {
            var updated = person
            updated.groupId = defaultGroup.id
            updated.groupAddedAt = Date()
            updated.modifiedAt = Date()
            try? personRepository.save(updated)
        }
    }

    func defaultGroup() -> Group? {
        groups.first(where: { $0.isDefault })
    }
}
