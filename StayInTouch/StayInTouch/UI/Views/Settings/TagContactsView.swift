//
//  TagContactsView.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct TagContactsView: View {
    let tag: Tag

    @StateObject private var viewModel: TagContactsViewModel
    @State private var showAddContacts = false

    init(tag: Tag) {
        self.tag = tag
        _viewModel = StateObject(wrappedValue: TagContactsViewModel(tag: tag))
    }

    var body: some View {
        List {
            if viewModel.people.isEmpty {
                Text("No contacts yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.people, id: \.id) { person in
                    HStack {
                        Text(person.displayName)
                        Spacer()
                        Button("Remove") {
                            viewModel.removeTag(from: person)
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                    }
                }
            }
        }
        .navigationTitle(tag.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") { showAddContacts = true }
            }
        }
        .sheet(isPresented: $showAddContacts) {
            AddContactsToTagView(
                available: viewModel.available,
                onSave: { ids in
                    viewModel.addTag(to: ids)
                    showAddContacts = false
                },
                onCancel: { showAddContacts = false }
            )
        }
        .onAppear { viewModel.load() }
    }
}
