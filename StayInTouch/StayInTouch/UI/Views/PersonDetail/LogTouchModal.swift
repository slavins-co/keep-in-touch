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
                Picker("Method", selection: $selectedMethod) {
                    ForEach(TouchMethod.allCases, id: \.self) { method in
                        Label(method.rawValue, systemImage: DS.touchMethodIcon(method)).tag(method)
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
                        onSave(selectedMethod, notes.isEmpty ? nil : notes, touchDate, selectedTimeOfDay)
                        dismiss()
                    }
                }
            }
        }
    }
}
