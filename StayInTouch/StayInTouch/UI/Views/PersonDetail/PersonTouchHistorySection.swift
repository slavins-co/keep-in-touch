//
//  PersonTouchHistorySection.swift
//  KeepInTouch
//

import SwiftUI

struct PersonTouchHistorySection: View {
    @ObservedObject var viewModel: PersonDetailViewModel
    @Binding var showFullHistory: Bool
    var onEditTouch: (TouchEvent) -> Void
    var onDeleteTouch: (TouchEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("History")
                    .font(DS.Typography.settingsHeaderTitle)
                    .foregroundStyle(DS.Colors.settingsTitle)
                Spacer()
                if viewModel.touchEvents.count > 3 {
                    Button(showFullHistory ? "Hide" : "See All") {
                        showFullHistory.toggle()
                    }
                    .font(DS.Typography.caption)
                    .accessibilityLabel(showFullHistory ? "Hide full history" : "See all \(viewModel.touchEvents.count) connections")
                }
            }

            if viewModel.touchEvents.isEmpty {
                Text("No connections yet")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.tertiaryText)
            } else {
                let events = showFullHistory ? viewModel.touchEvents : Array(viewModel.touchEvents.prefix(3))
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        TimelineEntryView(
                            event: event,
                            isLatest: index == 0,
                            isLast: index == events.count - 1
                        )
                        .onTapGesture {
                            onEditTouch(event)
                        }
                        .contextMenu {
                            Button {
                                onEditTouch(event)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                onDeleteTouch(event)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }
}
