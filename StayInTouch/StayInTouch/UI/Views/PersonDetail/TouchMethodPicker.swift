//
//  TouchMethodPicker.swift
//  KeepInTouch
//
//  Created by Codex on 5/17/26.
//

import SwiftUI

/// Picker for the touch method. Used by both `LogTouchModal` (new touches)
/// and `EditTouchModal` (existing touches).
///
/// Layout: 4-tile primary row (Text / Call / IRL / More…). The 4th tile
/// opens a sheet with secondary methods (FaceTime / Email / Other). When a
/// secondary method is currently selected, the 4th tile renders as that
/// method with a checkmark so the current selection stays visible without
/// reopening the sheet.
///
/// Replaces the pre-#299 `ForEach(TouchMethod.allCases)` layout which
/// became cramped after PR #296 added routing-only cases to the enum.
struct TouchMethodPicker: View {
    @Binding var selection: TouchMethod

    @State private var showingMoreSheet = false

    private static let primary: [TouchMethod] = [.text, .call, .irl]
    private static let secondary: [TouchMethod] = [.facetime, .email, .other]

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(Self.primary, id: \.self) { method in
                tile(for: method)
            }
            moreTile
        }
        .sheet(isPresented: $showingMoreSheet) {
            moreSheetContent
        }
    }

    @ViewBuilder
    private func tile(for method: TouchMethod) -> some View {
        Button {
            selection = method
        } label: {
            tileLabel(
                icon: DS.touchMethodIcon(method),
                text: method.rawValue,
                isSelected: selection == method
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(method.rawValue)\(selection == method ? ", selected" : "")")
        .accessibilityHint("Sets connection type to \(method.rawValue)")
    }

    @ViewBuilder
    private var moreTile: some View {
        let selectedSecondary = Self.secondary.contains(selection) ? selection : nil
        Button {
            showingMoreSheet = true
        } label: {
            if let method = selectedSecondary {
                tileLabel(
                    icon: DS.touchMethodIcon(method),
                    text: method.rawValue,
                    isSelected: true
                )
            } else {
                tileLabel(
                    icon: "ellipsis.circle.fill",
                    text: "More",
                    isSelected: false
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            selectedSecondary.map { "More, currently \($0.rawValue)" } ?? "More connection types"
        )
        .accessibilityHint("Opens picker with FaceTime, Email, and Other")
    }

    private func tileLabel(icon: String, text: String, isSelected: Bool) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
            Text(text)
                .font(DS.Typography.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            isSelected ? DS.Colors.accent.opacity(0.12) : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .foregroundColor(isSelected ? DS.Colors.accent : DS.Colors.secondaryText)
    }

    @ViewBuilder
    private var moreSheetContent: some View {
        NavigationStack {
            List {
                ForEach(Self.secondary, id: \.self) { method in
                    Button {
                        selection = method
                        showingMoreSheet = false
                    } label: {
                        HStack {
                            Image(systemName: DS.touchMethodIcon(method))
                                .font(.body)
                                .frame(width: 24)
                                .foregroundColor(DS.Colors.secondaryText)
                            Text(method.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if selection == method {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DS.Colors.accent)
                            }
                        }
                    }
                    .accessibilityLabel("\(method.rawValue)\(selection == method ? ", selected" : "")")
                    .accessibilityHint("Sets connection type to \(method.rawValue)")
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { showingMoreSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
