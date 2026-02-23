//
//  TagManagerSheet.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct TagManagerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let tags: [Tag]
    let selectedIds: Set<UUID>
    let onAdd: (Tag) -> Void
    let onRemove: (Tag) -> Void

    var body: some View {
        NavigationStack {
            List(tags, id: \.id) { tag in
                Button {
                    if selectedIds.contains(tag.id) {
                        onRemove(tag)
                    } else {
                        onAdd(tag)
                    }
                } label: {
                    HStack {
                        TagPill(tag: tag)
                        Spacer()
                        if selectedIds.contains(tag.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DS.Colors.accent)
                        }
                    }
                }
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
