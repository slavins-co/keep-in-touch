//
//  NotificationSettingsView.swift
//  KeepInTouch
//
//  Created by Codex on 3/10/26.
//

import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.openURL) private var openURL

    @State private var showBreachTimePicker = false
    @State private var showBirthdayTimePicker = false
    @State private var showDigestTimePicker = false
    @State private var showDigestDayPicker = false
    @State private var workingTime = Date()

    var body: some View {
        List {
            connectionRemindersSection
            weeklyDigestSection
            birthdayRemindersSection
            privacySection
        }
        .listStyle(.insetGrouped)
        .tint(DS.Colors.accent)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBreachTimePicker) {
            timePickerSheet(
                title: "Reminder Time",
                time: viewModel.settings.breachTimeOfDay,
                onSave: { viewModel.setBreachTime($0) }
            )
        }
        .sheet(isPresented: $showBirthdayTimePicker) {
            timePickerSheet(
                title: "Birthday Alert Time",
                time: viewModel.settings.birthdayNotificationTime,
                onSave: { viewModel.setBirthdayNotificationTime($0) }
            )
        }
        .sheet(isPresented: $showDigestTimePicker) {
            timePickerSheet(
                title: "Digest Time",
                time: viewModel.settings.digestTime,
                onSave: { viewModel.setDigestTime($0) }
            )
        }
        .sheet(isPresented: $showDigestDayPicker) {
            dayPickerSheet
        }
        .alert("Notifications Disabled", isPresented: $viewModel.showNotificationsSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable notifications in iOS Settings to receive alerts.")
        }
    }

    // MARK: - Sections

    private var connectionRemindersSection: some View {
        Section("Connection Reminders") {
            Toggle(isOn: Binding(
                get: { viewModel.settings.notificationsEnabled },
                set: { newValue in
                    Task { await viewModel.setNotificationsEnabled(newValue) }
                }
            )) {
                Label("Daily Reminders", systemImage: "bell.fill")
                    .foregroundStyle(DS.Colors.statusDueSoon)
            }

            if viewModel.settings.notificationsEnabled {
                Button {
                    showBreachTimePicker = true
                } label: {
                    HStack {
                        Text("Reminder Time")
                        Spacer()
                        Text(viewModel.settings.breachTimeOfDay.formatted)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                .padding(.leading, DS.Spacing.lg)
            }

            Picker("Reminder Grouping", selection: Binding(
                get: { viewModel.settings.notificationGrouping },
                set: { viewModel.setNotificationGrouping($0) }
            )) {
                ForEach(NotificationGrouping.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }

            Toggle(isOn: Binding(
                get: { viewModel.settings.badgeCountShowDueSoon },
                set: { viewModel.setBadgeCountShowDueSoon($0) }
            )) {
                Text("Include Due Soon in Badge")
            }
        }
    }

    private var weeklyDigestSection: some View {
        Section("Weekly Digest") {
            Toggle(isOn: Binding(
                get: { viewModel.settings.digestEnabled },
                set: { newValue in viewModel.setDigestEnabled(newValue) }
            )) {
                Label("Weekly Digest", systemImage: "bell.badge.fill")
                    .foregroundStyle(DS.Colors.statusDueSoon)
            }

            if viewModel.settings.digestEnabled {
                Button {
                    showDigestDayPicker = true
                } label: {
                    HStack {
                        Text("Digest Day")
                        Spacer()
                        Text(viewModel.settings.digestDay.displayName)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                .padding(.leading, DS.Spacing.lg)

                Button {
                    showDigestTimePicker = true
                } label: {
                    HStack {
                        Text("Digest Time")
                        Spacer()
                        Text(viewModel.settings.digestTime.formatted)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                .padding(.leading, DS.Spacing.lg)
            }
        }
    }

    private var birthdayRemindersSection: some View {
        Section("Birthday Reminders") {
            Toggle(isOn: Binding(
                get: { viewModel.settings.birthdayNotificationsEnabled },
                set: { viewModel.setBirthdayNotificationsEnabled($0) }
            )) {
                Label("Birthday Reminders", systemImage: "birthday.cake")
                    .foregroundStyle(DS.Colors.statusDueSoon)
            }

            if viewModel.settings.birthdayNotificationsEnabled {
                Button {
                    showBirthdayTimePicker = true
                } label: {
                    HStack {
                        Text("Birthday Alert Time")
                        Spacer()
                        Text(viewModel.settings.birthdayNotificationTime.formatted)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                .accessibilityLabel("Birthday Alert Time")
                .accessibilityValue(viewModel.settings.birthdayNotificationTime.formatted)
                .accessibilityHint("Opens time picker")
                .padding(.leading, DS.Spacing.lg)

                Toggle(isOn: Binding(
                    get: { viewModel.settings.birthdayIgnoreSnoozePause },
                    set: { viewModel.setBirthdayIgnoreSnoozePause($0) }
                )) {
                    Text("Include Snoozed & Paused")
                }
                .accessibilityLabel("Include Snoozed and Paused contacts")
                .accessibilityHint("Sends birthday reminders even for snoozed or paused contacts")
                .padding(.leading, DS.Spacing.lg)
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Toggle(isOn: Binding(
                get: { viewModel.settings.hideContactNamesInNotifications },
                set: { viewModel.setHideContactNamesInNotifications($0) }
            )) {
                Label("Hide Names in Notifications", systemImage: "eye.slash")
            }
        }
    }

    // MARK: - Picker Sheets

    private func timePickerSheet(title: String, time: LocalTime, onSave: @escaping (LocalTime) -> Void) -> some View {
        NavigationStack {
            DatePicker(
                title,
                selection: $workingTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismissSheets() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(LocalTime.from(date: workingTime))
                        dismissSheets()
                    }
                }
            }
            .onAppear { workingTime = time.toDate() }
        }
        .presentationDetents([.medium])
    }

    private var dayPickerSheet: some View {
        NavigationStack {
            List(DayOfWeek.allCases, id: \.self) { day in
                Button {
                    viewModel.setDigestDay(day)
                    showDigestDayPicker = false
                } label: {
                    HStack {
                        Text(day.displayName)
                        Spacer()
                        if viewModel.settings.digestDay == day {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DS.Colors.accent)
                        }
                    }
                }
            }
            .navigationTitle("Digest Day")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showDigestDayPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func dismissSheets() {
        showBreachTimePicker = false
        showBirthdayTimePicker = false
        showDigestTimePicker = false
    }
}
