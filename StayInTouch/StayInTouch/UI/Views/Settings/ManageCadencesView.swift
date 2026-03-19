//
//  ManageCadencesView.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct ManageCadencesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ManageCadencesViewModel()

    @State private var showNewCadence = false
    @State private var editingCadence: Cadence?
    @State private var deleteTarget: Cadence?
    @State private var showDeleteConfirm = false
    @State private var showCannotDeleteAlert = false

    var body: some View {
        List {
            ForEach(viewModel.cadences, id: \.id) { cadence in
                NavigationLink {
                    CadenceContactsView(cadence: cadence)
                } label: {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text(cadence.name)
                                .font(DS.Typography.contactName)
                            if cadence.isDefault {
                                Text("Default")
                                    .font(DS.Typography.captionBold)
                                    .foregroundStyle(DS.Colors.secondaryText)
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, DS.Spacing.xxs)
                                    .background(DS.Colors.secondaryBackground)
                                    .clipShape(Capsule())
                            }
                        }

                        Text("Every \(cadence.frequencyDays) days \u{2022} \(viewModel.countsByCadence[cadence.id, default: 0]) contacts")
                            .font(DS.Typography.metadata)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                    .padding(.vertical, DS.Spacing.xs)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        guard !cadence.isDefault else { return }
                        deleteTarget = cadence
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(cadence.isDefault)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        editingCadence = cadence
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(DS.Colors.accent)
                }
            }
        }
        .tint(DS.Colors.accent)
        .navigationTitle("Manage Frequencies")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewCadence = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(item: $editingCadence) { cadence in
            CadenceEditorSheet(
                cadence: cadence,
                existingNames: viewModel.cadences.map { $0.name },
                defaultSortOrder: viewModel.cadences.count,
                onSave: { cadence, makeDefault in
                    viewModel.save(cadence, makeDefault: makeDefault)
                },
                onCancel: {}
            )
        }
        .sheet(isPresented: $showNewCadence) {
            CadenceEditorSheet(
                cadence: nil,
                existingNames: viewModel.cadences.map { $0.name },
                defaultSortOrder: viewModel.cadences.count,
                onSave: { cadence, makeDefault in
                    viewModel.save(cadence, makeDefault: makeDefault)
                    showNewCadence = false
                },
                onCancel: { showNewCadence = false }
            )
        }
        .alert("Cannot Delete", isPresented: $showCannotDeleteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Default frequencies cannot be deleted.")
        }
        .alert("Delete Frequency?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                guard let target = deleteTarget else { return }
                Haptics.medium()
                let defaultCadence = viewModel.defaultCadence()
                if let defaultCadence, viewModel.countsByCadence[target.id, default: 0] > 0 {
                    viewModel.movePeople(from: target, to: defaultCadence)
                }
                viewModel.delete(cadence: target)
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            if let target = deleteTarget, viewModel.countsByCadence[target.id, default: 0] > 0 {
                Text("\(viewModel.countsByCadence[target.id, default: 0]) contacts will be moved to the default frequency.")
            } else {
                Text("This action cannot be undone.")
            }
        }
        .onAppear { viewModel.load() }
    }
}
