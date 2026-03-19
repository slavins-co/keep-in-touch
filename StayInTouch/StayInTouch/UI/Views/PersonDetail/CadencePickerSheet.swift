//
//  CadencePickerSheet.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct CadencePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let cadences: [Cadence]
    let selectedId: UUID
    let onSelect: (UUID) -> Void

    var body: some View {
        NavigationStack {
            List(cadences, id: \.id) { cadence in
                Button {
                    onSelect(cadence.id)
                    dismiss()
                } label: {
                    HStack {
                        Text(cadence.name)
                            .font(DS.Typography.contactName)
                        Spacer()
                        if cadence.id == selectedId {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DS.Colors.accent)
                        }
                    }
                }
            }
            .navigationTitle("Change Frequency")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
