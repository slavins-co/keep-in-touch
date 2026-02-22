//
//  ManageGroupsView.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct ManageGroupsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ManageGroupsViewModel()

    @State private var showNewGroup = false
    @State private var editingGroup: Group?
    @State private var deleteTarget: Group?
    @State private var showDeleteConfirm = false
    @State private var showCannotDeleteAlert = false

    var body: some View {
        List {
            ForEach(viewModel.groups, id: \.id) { group in
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack {
                        Text(group.name)
                            .font(DS.Typography.contactName)
                        if group.isDefault {
                            Text("Default")
                                .font(DS.Typography.captionBold)
                                .foregroundStyle(DS.Colors.secondaryText)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(DS.Colors.secondaryBackground)
                                .clipShape(Capsule())
                        }
                    }

                    Text("Every \(group.slaDays) days \u{2022} \(viewModel.countsByGroup[group.id, default: 0]) contacts")
                        .font(DS.Typography.metadata)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
                .padding(.vertical, DS.Spacing.xs)
                .swipeActions(edge: .trailing) {
                    if !group.isDefault {
                        Button(role: .destructive) {
                            deleteTarget = group
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
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
                onSave: { group, makeDefault in
                    viewModel.save(group, makeDefault: makeDefault)
                },
                onCancel: {}
            )
        }
        .sheet(isPresented: $showNewGroup) {
            GroupEditorSheet(
                group: nil,
                existingNames: viewModel.groups.map { $0.name },
                defaultSortOrder: viewModel.groups.count,
                onSave: { group, makeDefault in
                    viewModel.save(group, makeDefault: makeDefault)
                    showNewGroup = false
                },
                onCancel: { showNewGroup = false }
            )
        }
        .alert("Cannot Delete", isPresented: $showCannotDeleteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Default groups cannot be deleted.")
        }
        .alert("Delete Group?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                guard let target = deleteTarget else { return }
                let defaultGroup = viewModel.defaultGroup()
                if let defaultGroup, viewModel.countsByGroup[target.id, default: 0] > 0 {
                    viewModel.movePeople(from: target, to: defaultGroup)
                }
                viewModel.delete(group: target)
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            if let target = deleteTarget, viewModel.countsByGroup[target.id, default: 0] > 0 {
                Text("\(viewModel.countsByGroup[target.id, default: 0]) contacts will be moved to the default group.")
            } else {
                Text("This action cannot be undone.")
            }
        }
        .onAppear { viewModel.load() }
    }
}
