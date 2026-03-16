//
//  GroupManagerSheet.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct GroupManagerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let groups: [Group]
    let selectedIds: Set<UUID>
    let onAdd: (Group) -> Void
    let onRemove: (Group) -> Void

    var body: some View {
        NavigationStack {
            List(groups, id: \.id) { group in
                Button {
                    if selectedIds.contains(group.id) {
                        onRemove(group)
                    } else {
                        onAdd(group)
                    }
                } label: {
                    HStack {
                        GroupPill(group: group)
                        Spacer()
                        if selectedIds.contains(group.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DS.Colors.accent)
                        }
                    }
                }
                .accessibilityLabel("\(tag.name)\(selectedIds.contains(tag.id) ? ", selected" : "")")
                .accessibilityHint(selectedIds.contains(tag.id) ? "Removes from \(tag.name)" : "Adds to \(tag.name)")
            }
            .navigationTitle("Manage Groups")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
