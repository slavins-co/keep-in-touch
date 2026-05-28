//
//  SnoozedContactsView.swift
//  KeepInTouch
//
//  Central list of actively-snoozed contacts with bulk un-snooze (#334).
//  Mirrors PausedContactsView; un-snooze is a one-tap clear (no date prompt).
//

import SwiftUI

struct SnoozedContactsView: View {
    @StateObject private var viewModel = SnoozedContactsViewModel()
    @State private var selection: Set<UUID> = []

    @State private var unsnoozeTargets: [Person] = []
    @State private var showUnsnoozeConfirm = false

    var body: some View {
        List(selection: $selection) {
            ForEach(viewModel.people, id: \.id) { person in
                NavigationLink {
                    PersonDetailView(person: person)
                } label: {
                    HStack {
                        Text(person.displayName)
                            .font(DS.Typography.contactName)
                        Spacer()
                        if let snoozedUntil = person.snoozedUntil {
                            Text("Snoozed until \(snoozedUntil.formatted(date: .abbreviated, time: .omitted))")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                    }
                }
                .tag(person.id)
            }
        }
        .navigationTitle("Snoozed Contacts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Un-snooze All") {
                    unsnoozeTargets = viewModel.people
                    showUnsnoozeConfirm = true
                }
                .disabled(viewModel.people.isEmpty)
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Un-snooze Selected") {
                    unsnoozeTargets = viewModel.people.filter { selection.contains($0.id) }
                    showUnsnoozeConfirm = true
                }
                .disabled(selection.isEmpty)
            }
        }
        .alert("Un-snooze these contacts?", isPresented: $showUnsnoozeConfirm) {
            Button("Un-snooze") {
                viewModel.unsnooze(unsnoozeTargets)
                cleanupAfterUnsnooze()
            }
            Button("Cancel", role: .cancel) {
                unsnoozeTargets = []
            }
        } message: {
            Text("They'll resume their normal reminder schedule.")
        }
        .onAppear { viewModel.load() }
    }

    private func cleanupAfterUnsnooze() {
        showUnsnoozeConfirm = false
        selection.removeAll()
        unsnoozeTargets = []
        viewModel.load()
    }
}
