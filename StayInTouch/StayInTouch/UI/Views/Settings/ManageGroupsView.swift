//
//  ManageGroupsView.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct ManageGroupsView: View {
    @StateObject private var viewModel = ManageGroupsViewModel()

    @State private var showNewGroup = false
    @State private var editingGroup: Group?
    @State private var deleteTarget: Group?
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            ForEach(viewModel.groups, id: \.id) { group in
                NavigationLink {
                    GroupContactsView(group: group)
                } label: {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        GroupPill(group: group)

                        Text("\(viewModel.countsByGroup[group.id, default: 0]) contacts")
                            .font(DS.Typography.metadata)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteTarget = group
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        editingGroup = group
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(DS.Colors.accent)
                }
            }
        }
        .tint(DS.Colors.accent)
        .navigationTitle("Manage Groups")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewGroup = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(item: $editingGroup) { group in
            GroupEditorSheet(
                group: group,
                existingNames: viewModel.groups.map { $0.name },
                defaultSortOrder: viewModel.groups.count,
                onSave: { group in
                    viewModel.save(group)
                },
                onCancel: {}
            )
        }
        .sheet(isPresented: $showNewGroup) {
            GroupEditorSheet(
                group: nil,
                existingNames: viewModel.groups.map { $0.name },
                defaultSortOrder: viewModel.groups.count,
                onSave: { group in
                    viewModel.save(group)
                    showNewGroup = false
                },
                onCancel: { showNewGroup = false }
            )
        }
        .alert("Delete Group?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    Haptics.medium()
                    viewModel.delete(group: target)
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            if let target = deleteTarget, viewModel.countsByGroup[target.id, default: 0] > 0 {
                Text("\(viewModel.countsByGroup[target.id, default: 0]) contacts will lose this group.")
            } else {
                Text("This action cannot be undone.")
            }
        }
        .onAppear { viewModel.load() }
    }
}
