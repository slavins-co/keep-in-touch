//
//  NewContactsPickerView.swift
//  KeepInTouch
//
//  Created by Codex on 2/3/26.
//

import SwiftUI

struct NewContactsPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager

    let contacts: [ContactSummary]
    /// Live count of currently-tracked people, evaluated at Import time (not a
    /// snapshot) so the cap can't be bypassed by adds made after presentation.
    let currentTrackedCount: () -> Int
    /// Analytics source for the cap/paywall, e.g. "settings" or "home".
    let capSource: String
    let onImport: ([ContactSummary]) -> Void
    let onCancel: () -> Void

    @State private var selection: Set<String> = []
    @State private var searchText = ""
    @State private var paywallTrigger: PaywallTrigger?

    private var groupedContacts: [(String, [ContactSummary])] {
        let filtered = searchText.isEmpty ? contacts : contacts.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(searchText)
        }

        let grouped = Dictionary(grouping: filtered) { contact -> String in
            let firstChar = contact.displayName.prefix(1).uppercased()
            return firstChar.rangeOfCharacter(from: CharacterSet.letters) != nil ? firstChar : "#"
        }

        return grouped.sorted { lhs, rhs in
            if lhs.key == "#" { return false }
            if rhs.key == "#" { return true }
            return lhs.key < rhs.key
        }.map { (key, contacts) in
            (key, contacts.sorted { $0.displayName < $1.displayName })
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Search contacts...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.vertical, DS.Spacing.sm)

                ScrollViewReader { proxy in
                    HStack(spacing: 0) {
                        List(selection: $selection) {
                            ForEach(groupedContacts, id: \.0) { section in
                                Section(header: Text(section.0).id(section.0)) {
                                    ForEach(section.1, id: \.identifier) { contact in
                                        HStack {
                                            Text(contact.displayName)
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)

                        SectionIndexView(sections: groupedContacts.map { $0.0 }) { section in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(section, anchor: .top)
                            }
                        }
                        .padding(.trailing, 4)
                    }
                }
            }
            .navigationTitle("Add Contacts")
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        let selected = contacts.filter { selection.contains($0.identifier) }
                        if ContactCapGate.wouldExceedFreeLimit(
                            currentTrackedCount: currentTrackedCount(),
                            adding: selected.count,
                            isPro: purchaseManager.isPro
                        ) {
                            AnalyticsService.track(
                                "pro.cap_blocked",
                                parameters: ["source": capSource, "attempted": String(selected.count)]
                            )
                            paywallTrigger = PaywallTrigger(source: "cap_\(capSource)")
                        } else {
                            onImport(selected)
                            dismiss()
                        }
                    }
                    .disabled(selection.isEmpty)
                }
            }
            .sheet(item: $paywallTrigger) { trigger in
                PaywallView(source: trigger.source)
                    .environmentObject(purchaseManager)
            }
        }
    }
}
