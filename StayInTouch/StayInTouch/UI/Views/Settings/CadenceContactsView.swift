//
//  CadenceContactsView.swift
//  KeepInTouch
//
//  Created by Codex on 3/3/26.
//

import SwiftUI

struct CadenceContactsView: View {
    let cadence: Cadence

    @StateObject private var viewModel: CadenceContactsViewModel
    @State private var showAddContacts = false
    @State private var removeTarget: Person?

    init(cadence: Cadence) {
        self.cadence = cadence
        _viewModel = StateObject(wrappedValue: CadenceContactsViewModel(cadence: cadence))
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
                            Button(role: .destructive) {
                                if cadence.isDefault {
                                    removeTarget = person
                                } else if let defaultId = viewModel.otherCadences.first(where: { $0.isDefault })?.id {
                                    viewModel.movePerson(person, to: defaultId)
                                }
                            } label: {
                                Label("Remove", systemImage: "person.badge.minus")
                            }
                        }
                }
            }
        }
        .navigationTitle(cadence.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") { showAddContacts = true }
            }
        }
        .confirmationDialog(
            "Move to which frequency?",
            isPresented: Binding(
                get: { removeTarget != nil },
                set: { if !$0 { removeTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(viewModel.otherCadences, id: \.id) { destination in
                Button(destination.name) {
                    if let person = removeTarget {
                        viewModel.movePerson(person, to: destination.id)
                    }
                    removeTarget = nil
                }
            }
            Button("Cancel", role: .cancel) { removeTarget = nil }
        }
        .sheet(isPresented: $showAddContacts) {
            AddContactsToCadenceView(
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
