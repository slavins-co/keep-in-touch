//
//  GroupContactsView.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct GroupContactsView: View {
    let group: Group

    @StateObject private var viewModel: GroupContactsViewModel
    @State private var showAddContacts = false

    init(group: Group) {
        self.group = group
        _viewModel = StateObject(wrappedValue: GroupContactsViewModel(group: group))
    }

    var body: some View {
        List {
            if viewModel.people.isEmpty {
                Text("No contacts yet")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
            } else {
                ForEach(viewModel.people, id: \.id) { person in
                    Text(person.displayName)
                        .font(DS.Typography.contactName)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.removeGroup(from: person)
                            } label: {
                                Label("Remove", systemImage: "tag.slash")
                            }
                        }
                }
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") { showAddContacts = true }
            }
        }
        .sheet(isPresented: $showAddContacts) {
            AddContactsToGroupView(
                available: viewModel.available,
                onSave: { ids in
                    viewModel.addGroup(to: ids)
                    showAddContacts = false
                },
                onCancel: { showAddContacts = false }
            )
        }
        .onAppear { viewModel.load() }
    }
}
