//
//  GroupContactsView.swift
//  KeepInTouch
//
//  Created by Codex on 3/3/26.
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
                Text("No contacts in this frequency")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
            } else {
                ForEach(viewModel.people, id: \.id) { person in
                    Text(person.displayName)
                        .font(DS.Typography.contactName)
                        .swipeActions(edge: .trailing) {
                            if !group.isDefault {
                                Button(role: .destructive) {
                                    viewModel.removePerson(person)
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
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
                    viewModel.addPeople(ids)
                    showAddContacts = false
                },
                onCancel: { showAddContacts = false }
            )
        }
        .onAppear { viewModel.load() }
    }
}
