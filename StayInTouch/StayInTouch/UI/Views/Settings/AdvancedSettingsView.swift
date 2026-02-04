//
//  AdvancedSettingsView.swift
//  StayInTouch
//
//  Created by Claude Code on 2/4/26.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section(header: Text("Testing & Debug")) {
                Button("Send Test Notification") {
                    Task { await viewModel.sendTestNotification() }
                }

                Toggle("Demo Mode", isOn: Binding(
                    get: { viewModel.settings.demoModeEnabled },
                    set: { newValue in viewModel.setDemoModeEnabled(newValue) }
                ))
            }

            Section(footer: Text("These settings are intended for testing and development purposes.")) {
                EmptyView()
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AdvancedSettingsView(viewModel: SettingsViewModel())
    }
}
