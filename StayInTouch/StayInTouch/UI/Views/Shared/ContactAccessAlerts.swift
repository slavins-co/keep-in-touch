//
//  ContactAccessAlerts.swift
//  KeepInTouch
//
//  Shared view modifier for the three contacts-access alerts that were
//  duplicated verbatim across `HomeView` and `SettingsView` (audit
//  finding Q8, issue #313):
//
//    - "No New Contacts"          — info, dismiss only
//    - "Limited Contact Access"   — info + "Open Settings" deep link
//    - "Contacts Access Required" — gate + "Open Settings" deep link
//
//  Behavior preserved exactly: same titles, messages, button order,
//  button labels, and `UIApplication.openSettingsURLString` deep-link.
//

import SwiftUI
import UIKit

struct ContactAccessAlerts: ViewModifier {
    @Binding var showNoNewContacts: Bool
    @Binding var showLimitedAccess: Bool
    @Binding var showContactsSettings: Bool

    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content
            .alert("No New Contacts", isPresented: $showNoNewContacts) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You're already up to date.")
            }
            .alert("Limited Contact Access", isPresented: $showLimitedAccess) {
                Button("Open Settings") { openSettings() }
                Button("OK", role: .cancel) {}
            } message: {
                Text("You've imported all the contacts you gave access to. To add more, open Settings \u{2192} Keep In Touch \u{2192} Contacts and select additional contacts or grant full access.")
            }
            .alert("Contacts Access Required", isPresented: $showContactsSettings) {
                Button("Open Settings") { openSettings() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable Contacts access in Settings to import contacts.")
            }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

extension View {
    /// Attaches the three contacts-access alerts (No New / Limited /
    /// Required) used by Home and Settings. Each is driven by a separate
    /// `Bool` binding so callers can flip whichever is appropriate after
    /// a contacts-sync call.
    func contactAccessAlerts(
        showNoNewContacts: Binding<Bool>,
        showLimitedAccess: Binding<Bool>,
        showContactsSettings: Binding<Bool>
    ) -> some View {
        modifier(ContactAccessAlerts(
            showNoNewContacts: showNoNewContacts,
            showLimitedAccess: showLimitedAccess,
            showContactsSettings: showContactsSettings
        ))
    }
}
