//
//  TouchEditorForm.swift
//  KeepInTouch
//
//  Shared form rows used by `LogTouchModal` (creating a touch) and
//  `EditTouchModal` (editing an existing touch). Covers the contiguous
//  "Time of Day" + "Notes" pair plus the 500-char notes clamp that was
//  duplicated across both modals (audit finding Q7, issue #313).
//
//  Why not also include the `TouchMethodPicker`? Both modals already
//  call it as a single line; LogTouchModal interleaves a `DatePicker`
//  between the method picker and the time picker, so the time+notes
//  pair is the only contiguous shared block.
//

import SwiftUI

struct TouchTimeAndNotesFields: View {
    @Binding var selectedTimeOfDay: TimeOfDay?
    @Binding var notes: String

    /// Notes field clamps to this many characters. Both call sites used
    /// 500 pre-extraction — exposed as a parameter so the constant lives
    /// in exactly one place.
    var notesCharacterLimit: Int = 500

    var body: some View {
        Picker("Time of Day", selection: $selectedTimeOfDay) {
            Text("None").tag(TimeOfDay?.none)
            ForEach(TimeOfDay.allCases, id: \.self) { time in
                Text(time.rawValue).tag(TimeOfDay?.some(time))
            }
        }

        TextField("Notes", text: $notes, axis: .vertical)
            .onChange(of: notes) { _, newValue in
                if newValue.count > notesCharacterLimit {
                    notes = String(newValue.prefix(notesCharacterLimit))
                }
            }
    }
}
