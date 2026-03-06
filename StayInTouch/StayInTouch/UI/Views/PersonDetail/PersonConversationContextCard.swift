//
//  PersonConversationContextCard.swift
//  KeepInTouch
//

import SwiftUI

struct PersonConversationContextCard: View {
    @ObservedObject var viewModel: PersonDetailViewModel

    @State private var nextTouchNotesText: String = ""
    @FocusState private var isNextTouchNotesFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("NOTES FOR NEXT TIME")
                .font(DS.Typography.notesLabel)
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(Color(.secondaryLabel))

            TextField("What to talk about...",
                      text: $nextTouchNotesText,
                      prompt: Text("What to talk about...").foregroundColor(DS.Colors.notesPlaceholder),
                      axis: .vertical)
                .font(DS.Typography.notesBody)
                .foregroundStyle(DS.Colors.notesText)
                .lineSpacing(4)
                .lineLimit(3...6)
                .focused($isNextTouchNotesFocused)
                .onChange(of: nextTouchNotesText) { _, newValue in
                    if newValue.count > 500 { nextTouchNotesText = String(newValue.prefix(500)) }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isNextTouchNotesFocused = false
                        }
                    }
                }
                .onChange(of: isNextTouchNotesFocused) { _, focused in
                    if !focused {
                        viewModel.saveNextTouchNotes(nextTouchNotesText)
                    }
                }
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.notesBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(
                    isNextTouchNotesFocused ? DS.Colors.notesFocusRing : DS.Colors.notesBorder,
                    lineWidth: isNextTouchNotesFocused ? 2 : 1
                )
        )
        .padding(.vertical, DS.Spacing.md)
        .onAppear {
            nextTouchNotesText = viewModel.person.nextTouchNotes ?? ""
        }
    }
}
