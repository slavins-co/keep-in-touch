//
//  SelectionCoordinator.swift
//  KeepInTouch
//

import Foundation
import SwiftUI

/// Shared multi-select state that powers bulk-log touch and any future
/// bulk action (pause, tag, delete). Lives at MainTabView so the same
/// instance is observed by both Home and Contacts tabs — entering select
/// mode on one tab carries selection across to the other.
@MainActor
final class SelectionCoordinator: ObservableObject {
    enum Origin: String {
        case home
        case people
    }

    @Published var isSelectMode: Bool = false
    @Published var selection: Set<UUID> = []
    @Published private(set) var origin: Origin = .home

    /// True when commit ("Log touch (N)") should be enabled.
    var hasSelection: Bool { !selection.isEmpty }
    var count: Int { selection.count }

    func enter(origin: Origin, preselect: UUID? = nil) {
        let wasIdle = !isSelectMode
        self.origin = origin
        isSelectMode = true
        if let preselect {
            selection = [preselect]
            Haptics.medium()
        } else if wasIdle {
            selection = []
        }
    }

    func exit() {
        isSelectMode = false
        selection = []
    }

    func toggle(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    func contains(_ id: UUID) -> Bool { selection.contains(id) }

    func setSelection(_ ids: [UUID]) {
        selection = Set(ids)
    }

    func remove(_ id: UUID) {
        selection.remove(id)
    }
}
