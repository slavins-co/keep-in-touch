//
//  BirthdayEditorSheet.swift
//  KeepInTouch
//
//  Created by Claude on 3/1/26.
//

import SwiftUI

struct BirthdayEditorSheet: View {
    let birthday: Birthday?
    let onSave: (Birthday) -> Void
    let onClear: () -> Void

    @State private var selectedMonth: Int
    @State private var selectedDay: Int
    @Environment(\.dismiss) private var dismiss

    init(birthday: Birthday?, onSave: @escaping (Birthday) -> Void, onClear: @escaping () -> Void) {
        self.birthday = birthday
        self.onSave = onSave
        self.onClear = onClear
        let now = Date()
        let cal = Calendar.current
        _selectedMonth = State(initialValue: birthday?.month ?? cal.component(.month, from: now))
        _selectedDay = State(initialValue: birthday?.day ?? cal.component(.day, from: now))
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Month", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(Self.monthNames[month - 1]).tag(month)
                    }
                }

                Picker("Day", selection: $selectedDay) {
                    ForEach(1...daysInMonth, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .onChange(of: selectedMonth) {
                    let maxDay = daysInMonth
                    if selectedDay > maxDay {
                        selectedDay = maxDay
                    }
                }

                if birthday != nil {
                    Button("Remove Birthday", role: .destructive) {
                        onClear()
                    }
                }
            }
            .navigationTitle("Birthday")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(Birthday(month: selectedMonth, day: selectedDay, year: nil))
                    }
                }
            }
        }
    }

    private var daysInMonth: Int {
        var components = DateComponents()
        components.month = selectedMonth
        components.year = 2024 // leap year so Feb gets 29
        guard let date = Calendar.current.date(from: components),
              let range = Calendar.current.range(of: .day, in: .month, for: date) else {
            return 31
        }
        return range.count
    }

    private static let monthNames: [String] = {
        let formatter = DateFormatter()
        return formatter.monthSymbols
    }()
}
