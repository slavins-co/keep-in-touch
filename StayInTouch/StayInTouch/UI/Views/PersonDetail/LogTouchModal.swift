//
//  LogTouchModal.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct LogTouchModal: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: TouchMethod = .text
    @State private var notes = ""
    @State private var touchDate = Date()
    @State private var selectedTimeOfDay: TimeOfDay?

    let onSave: (TouchMethod, String?, Date, TimeOfDay?) -> Void

    var body: some View {
        NavigationStack {
            Form {
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

                DatePicker("Date", selection: $touchDate, in: ...Date(), displayedComponents: .date)

                Picker("Time of Day", selection: $selectedTimeOfDay) {
                    Text("None").tag(TimeOfDay?.none)
                    ForEach(TimeOfDay.allCases, id: \.self) { time in
                        Text(time.rawValue).tag(TimeOfDay?.some(time))
                    }
                }

                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle("Log Connection")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.success()
                        onSave(selectedMethod, notes.isEmpty ? nil : notes, touchDate, selectedTimeOfDay)
                        dismiss()
                    }
                }
            }
        }
    }
}
