//
//  ManageTagsView.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct ManageTagsView: View {
    @StateObject private var viewModel = ManageTagsViewModel()

    @State private var showNewTag = false
    @State private var editingTag: Tag?
    @State private var deleteTarget: Tag?
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            ForEach(viewModel.tags, id: \.id) { tag in
                NavigationLink {
                    TagContactsView(tag: tag)
                } label: {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        TagPill(tag: tag)

                        Text("\(viewModel.countsByTag[tag.id, default: 0]) contacts")
                            .font(DS.Typography.metadata)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteTarget = tag
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        editingTag = tag
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(DS.Colors.accent)
                }
            }
        }
        .navigationTitle("Manage Groups")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewTag = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(item: $editingTag) { tag in
            TagEditorSheet(
                tag: tag,
                existingNames: viewModel.tags.map { $0.name },
                defaultSortOrder: viewModel.tags.count,
                onSave: { tag in
                    viewModel.save(tag)
                },
                onCancel: {}
            )
        }
        .sheet(isPresented: $showNewTag) {
            TagEditorSheet(
                tag: nil,
                existingNames: viewModel.tags.map { $0.name },
                defaultSortOrder: viewModel.tags.count,
                onSave: { tag in
                    viewModel.save(tag)
                    showNewTag = false
                },
                onCancel: { showNewTag = false }
            )
        }
        .alert("Delete Group?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    Haptics.medium()
                    viewModel.delete(tag: target)
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            if let target = deleteTarget, viewModel.countsByTag[target.id, default: 0] > 0 {
                Text("\(viewModel.countsByTag[target.id, default: 0]) contacts will lose this group.")
            } else {
                Text("This action cannot be undone.")
            }
        }
        .onAppear { viewModel.load() }
    }
}
