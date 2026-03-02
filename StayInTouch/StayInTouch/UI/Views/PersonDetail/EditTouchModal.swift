//
//  EditTouchModal.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct EditTouchModal: View {
    @Environment(\.dismiss) private var dismiss

    let touch: TouchEvent
    let onSave: (TouchMethod, String?, TimeOfDay?) -> Void

    @State private var selectedMethod: TouchMethod
    @State private var notes: String
    @State private var selectedTimeOfDay: TimeOfDay?

    init(touch: TouchEvent, onSave: @escaping (TouchMethod, String?, TimeOfDay?) -> Void) {
        self.touch = touch
        self.onSave = onSave
        _selectedMethod = State(initialValue: touch.method)
        _notes = State(initialValue: touch.notes ?? "")
        _selectedTimeOfDay = State(initialValue: touch.timeOfDay)
    }

    var body: some View {
        NavigationStack {
            Form {
                Text("Date: \(touch.at.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: DS.Spacing.md) {
                    ForEach(TouchMethod.allCases, id: \.self) { touchMethod in
                        Button {
                            selectedMethod = touchMethod
                        } label: {
                            VStack(spacing: DS.Spacing.xs) {
                                Image(systemName: DS.touchMethodIcon(touchMethod))
                                    .font(.title2)
                                Text(touchMethod.rawValue)
                                    .font(DS.Typography.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(
                                selectedMethod == touchMethod
                                    ? DS.Colors.accent.opacity(0.12)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(selectedMethod == touchMethod ? DS.Colors.accent : DS.Colors.secondaryText)
                    }
                }

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
            .navigationTitle("Edit Connection")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedMethod, notes.isEmpty ? nil : notes, selectedTimeOfDay)
                        dismiss()
                    }
                }
            }
        }
    }
}
