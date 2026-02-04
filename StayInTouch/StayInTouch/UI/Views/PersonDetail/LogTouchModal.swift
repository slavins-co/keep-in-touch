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

    let onSave: (TouchMethod, String?, Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Method", selection: $selectedMethod) {
                    ForEach(TouchMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }

                DatePicker("Date", selection: $touchDate, in: ...Date(), displayedComponents: .date)

                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle("Log Touch")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSave(selectedMethod, notes.isEmpty ? nil : notes, touchDate)
                        dismiss()
                    }
                }
            }
        }
    }
}
