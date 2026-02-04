//
//  PausedContactsView.swift
//  StayInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct PausedContactsView: View {
    @StateObject private var viewModel = PausedContactsViewModel()
    @State private var selection: Set<UUID> = []

    @State private var resumeTargets: [Person] = []
    @State private var showResumePrompt = false
    @State private var showDatePicker = false
    @State private var pickedDate = Date()

    var body: some View {
        List(selection: $selection) {
            ForEach(viewModel.people, id: \.id) { person in
                NavigationLink {
                    PersonDetailView(person: person)
                } label: {
                    HStack {
                        Text(person.displayName)
                        Spacer()
                        if person.isPaused {
                            Text("Paused")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tag(person.id)
            }
        }
        .navigationTitle("Paused Contacts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Resume All") {
                    resumeTargets = viewModel.people
                    showResumePrompt = true
                }
                .disabled(viewModel.people.isEmpty)
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Resume Selected") {
                    resumeTargets = viewModel.people.filter { selection.contains($0.id) }
                    showResumePrompt = true
                }
                .disabled(selection.isEmpty)
            }
        }
        .alert("When did you last connect?", isPresented: $showResumePrompt) {
            Button("Today") {
                viewModel.resume(resumeTargets, lastTouchAt: Date())
                cleanupAfterResume()
            }
            Button("Pick Date") {
                pickedDate = Date()
                showDatePicker = true
            }
            Button("Skip") {
                viewModel.resume(resumeTargets, lastTouchAt: nil)
                cleanupAfterResume()
            }
            Button("Cancel", role: .cancel) {
                resumeTargets = []
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker("Last touch", selection: $pickedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                viewModel.resume(resumeTargets, lastTouchAt: pickedDate)
                                cleanupAfterResume()
                            }
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { showDatePicker = false }
                        }
                    }
            }
        }
        .onAppear { viewModel.load() }
    }

    private func cleanupAfterResume() {
        showDatePicker = false
        showResumePrompt = false
        selection.removeAll()
        resumeTargets = []
        viewModel.load()
    }
}
