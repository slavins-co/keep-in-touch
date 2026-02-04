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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(tag.name)
                                .font(.headline)
                            Spacer()
                            Button {
                                editingTag = tag
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                deleteTarget = tag
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }

                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: tag.colorHex))
                                .frame(width: 8, height: 8)
                            Text("\(viewModel.countsByTag[tag.id, default: 0]) contacts")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Manage Tags")
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
        .alert("Delete Tag?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    viewModel.delete(tag: target)
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            if let target = deleteTarget, viewModel.countsByTag[target.id, default: 0] > 0 {
                Text("\(viewModel.countsByTag[target.id, default: 0]) contacts will lose this tag.")
            } else {
                Text("This action cannot be undone.")
            }
        }
        .onAppear { viewModel.load() }
    }
}
