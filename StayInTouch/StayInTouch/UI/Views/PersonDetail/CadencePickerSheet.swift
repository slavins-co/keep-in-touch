//
//  CadencePickerSheet.swift
//  KeepInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct CadencePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let groups: [Cadence]
    let selectedId: UUID
    let onSelect: (UUID) -> Void

    var body: some View {
        NavigationStack {
            List(groups, id: \.id) { group in
                Button {
                    onSelect(group.id)
                    dismiss()
                } label: {
                    HStack {
                        Text(group.name)
                            .font(DS.Typography.contactName)
                        Spacer()
                        if group.id == selectedId {
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
