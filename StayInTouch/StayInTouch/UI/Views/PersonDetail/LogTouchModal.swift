//
//  LogTouchModal.swift
//  KeepInTouch
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
                TouchMethodPicker(selection: $selectedMethod)

                DatePicker("Date", selection: $touchDate, in: ...Date(), displayedComponents: .date)

                TouchTimeAndNotesFields(
                    selectedTimeOfDay: $selectedTimeOfDay,
                    notes: $notes
                )
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
