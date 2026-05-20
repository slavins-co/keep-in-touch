//
//  BulkLogTouchModal.swift
//  KeepInTouch
//

import SwiftUI

/// Sheet shown after the user commits a multi-person selection. The
/// SelectedAvatarChips row at the top lets users correct mistakes
/// without bouncing back to the picker; the body mirrors `LogTouchModal`
/// (method / date / time-of-day / notes) so the muscle memory is
/// identical between single- and bulk-log flows.
struct BulkLogTouchModal: View {
    @Environment(\.dismiss) private var dismiss

    let initialPeople: [Person]
    /// Pre-filled state, used when the "Forgot someone?" chip re-opens
    /// the picker — the second commit carries the original date/method
    /// /notes/timeOfDay so adding one more person doesn't force users
    /// to retype.
    var initialMethod: TouchMethod = .irl
    var initialNotes: String = ""
    var initialDate: Date = Date()
    var initialTimeOfDay: TimeOfDay? = nil

    /// Callback fires per Done. `(method, notes, date, timeOfDay, peopleIds)`.
    /// `peopleIds` reflects the current chip set (post any removals).
    let onSave: (TouchMethod, String?, Date, TimeOfDay?, [UUID]) -> Void
    /// Notifies the parent that the user removed someone from the chips,
    /// so the parent's selection state can stay in sync.
    let onRemove: (UUID) -> Void

    @State private var people: [Person]
    @State private var selectedMethod: TouchMethod
    @State private var notes: String
    @State private var touchDate: Date
    @State private var selectedTimeOfDay: TimeOfDay?

    init(
        people: [Person],
        initialMethod: TouchMethod = .irl,
        initialNotes: String = "",
        initialDate: Date = Date(),
        initialTimeOfDay: TimeOfDay? = nil,
        onSave: @escaping (TouchMethod, String?, Date, TimeOfDay?, [UUID]) -> Void,
        onRemove: @escaping (UUID) -> Void
    ) {
        self.initialPeople = people
        self.initialMethod = initialMethod
        self.initialNotes = initialNotes
        self.initialDate = initialDate
        self.initialTimeOfDay = initialTimeOfDay
        self.onSave = onSave
        self.onRemove = onRemove
        _people = State(initialValue: people)
        _selectedMethod = State(initialValue: initialMethod)
        _notes = State(initialValue: initialNotes)
        _touchDate = State(initialValue: initialDate)
        _selectedTimeOfDay = State(initialValue: initialTimeOfDay)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SelectedAvatarChips(people: people) { id in
                    people.removeAll { $0.id == id }
                    onRemove(id)
                }

                Form {
                    TouchMethodPicker(selection: $selectedMethod)

                    DatePicker("Date", selection: $touchDate, in: ...Date(), displayedComponents: .date)

                    Picker("Time of Day", selection: $selectedTimeOfDay) {
                        Text("None").tag(TimeOfDay?.none)
                        ForEach(TimeOfDay.allCases, id: \.self) { time in
                            Text(time.rawValue).tag(TimeOfDay?.some(time))
                        }
                    }

                    TextField("Notes", text: $notes, axis: .vertical)
                        .onChange(of: notes) { _, newValue in
                            if newValue.count > 500 { notes = String(newValue.prefix(500)) }
                        }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.success()
                        onSave(
                            selectedMethod,
                            notes.isEmpty ? nil : notes,
                            touchDate,
                            selectedTimeOfDay,
                            people.map(\.id)
                        )
                    }
                    .disabled(people.isEmpty)
                }
            }
        }
    }

    private var navigationTitle: String {
        people.count == 1 ? "Log Connection" : "Log Connection (\(people.count))"
    }
}
