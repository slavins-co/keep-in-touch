//
//  PersonSettingsSection.swift
//  KeepInTouch
//

import SwiftUI

struct PersonSettingsSection: View {
    @ObservedObject var viewModel: PersonDetailViewModel
    @Binding var settingsExpanded: Bool
    var onAction: (PersonSettingsAction) -> Void
    @Environment(\.dependencies) private var dependencies
    @EnvironmentObject private var purchaseManager: PurchaseManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: DS.Motion.standard)) {
                    settingsExpanded.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(DS.Colors.settingsGearIcon)
                    Text("Contact Settings")
                        .font(DS.Typography.settingsHeaderTitle)
                        .foregroundStyle(DS.Colors.settingsTitle)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.Colors.settingsChevron)
                        .rotationEffect(.degrees(settingsExpanded ? 0 : -90))
                        .animation(.easeInOut(duration: DS.Motion.standard), value: settingsExpanded)
                }
                .padding(.vertical, DS.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Contact Settings")
            .accessibilityHint(settingsExpanded ? "Collapses settings" : "Expands settings")
            .tutorialAnchor(TutorialAnchor.personMenuButton)
            .tutorialScrollID(TutorialAnchor.personMenuButton, isPreview: viewModel.isPreview)

            if settingsExpanded {
                settingsContent
                    .transition(.opacity.combined(with: .slide))
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            settingsCard {
                settingsRowFrequency
                settingsDivider
                settingsRowCustomDueDate
            }
            .tutorialAnchor(TutorialAnchor.personCadenceRow)
            .tutorialScrollID(TutorialAnchor.personCadenceRow, isPreview: viewModel.isPreview)

            settingsSectionHeader("DETAILS")
            settingsCard {
                settingsRowBirthday
                if viewModel.displayBirthday != nil {
                    settingsDivider
                    settingsRowBirthdayNotifications
                }
                settingsDivider
                settingsRowCadencesGroups
            }

            settingsSectionHeader("TRACKING & NOTIFICATIONS")
            settingsCard {
                settingsRowNotificationTime
                settingsDivider
                settingsRowSnooze
                settingsDivider
                settingsRowMuteNotifications
                settingsDivider
                settingsRowPauseTracking
            }

            settingsRowRemoveContact
        }
    }

    // MARK: - Settings Rows

    // Pro-gated rows: free users see a lock and tapping opens the paywall.
    // Unpause / clear-due-date stay free (they live on the active variants and
    // on the resume-prompt path), so a refunded user is never trapped.

    @ViewBuilder
    private var settingsRowCustomDueDate: some View {
        if purchaseManager.isPro {
            settingsRowCustomDueDateActive
        } else {
            proLockedRow("Set A Reminder Date", source: "custom_due_date")
        }
    }

    @ViewBuilder
    private var settingsRowNotificationTime: some View {
        if purchaseManager.isPro {
            settingsRowNotificationTimeActive
        } else {
            proLockedRow("Custom Notification Time", source: "custom_notification_time")
        }
    }

    @ViewBuilder
    private var settingsRowSnooze: some View {
        if purchaseManager.isPro {
            settingsRowSnoozeActive
        } else {
            proLockedRow("Snooze", source: "snooze")
        }
    }

    @ViewBuilder
    private var settingsRowPauseTracking: some View {
        if purchaseManager.isPro {
            settingsRowPauseTrackingActive
        } else {
            proLockedRow("Pause Tracking", source: "pause")
        }
    }

    private var settingsRowFrequency: some View {
        Button { onAction(.changeCadence) } label: {
            HStack {
                Text("Frequency")
                    .font(DS.Typography.settingsRowLabel)
                    .foregroundStyle(DS.Colors.settingsItemLabel)
                Spacer()
                Text(viewModel.cadence?.name ?? "Not set")
                    .font(DS.Typography.settingsRowLabel)
                    .foregroundStyle(DS.Colors.settingsItemValue)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.settingsChevron)
            }
            .frame(minHeight: DS.Spacing.menuRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var settingsRowCustomDueDateActive: some View {
        HStack {
            Text("Set A Reminder Date")
                .font(DS.Typography.settingsRowLabel)
                .foregroundStyle(DS.Colors.settingsItemLabel)
            Spacer()
            if let customDue = viewModel.person.customDueDate {
                Text(customDue.formatted(date: .abbreviated, time: .omitted))
                    .font(DS.Typography.settingsRowLabel)
                    .foregroundStyle(DS.Colors.settingsItemValue)
                Button("Clear") { viewModel.clearCustomDueDate() }
                    .font(DS.Typography.caption)
            } else {
                Button {
                    onAction(.customDueDatePicker(initialDate: .defaultSnoozeStartDate))
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Not set")
                            .font(DS.Typography.settingsRowLabel)
                            .foregroundStyle(DS.Colors.settingsItemValue)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DS.Colors.settingsChevron)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: DS.Spacing.menuRowHeight)
    }

    private var settingsRowSnoozeActive: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Snooze")
                    .font(DS.Typography.settingsRowLabel)
                    .foregroundStyle(DS.Colors.settingsItemLabel)
                Spacer()
                if viewModel.person.isSnoozed(), let snoozedUntil = viewModel.person.snoozedUntil {
                    Text("Until \(snoozedUntil.formatted(date: .abbreviated, time: .omitted))")
                        .font(DS.Typography.settingsRowLabel)
                        .foregroundStyle(DS.Colors.settingsSnoozeActive)
                    Button("Remove") { viewModel.clearSnooze() }
                        .font(DS.Typography.caption)
                } else {
                    Text("Not snoozed")
                        .font(DS.Typography.settingsRowLabel)
                        .foregroundStyle(DS.Colors.settingsItemValue)
                }
            }

            if !viewModel.person.isSnoozed() {
                HStack(spacing: DS.Spacing.sm) {
                    snoozePill("3d") { snooze(days: 3) }
                    snoozePill("7d") { snooze(days: 7) }
                    snoozePill("14d") { snooze(days: 14) }
                    snoozePill("Pick date") {
                        onAction(.snoozeDatePicker(initialDate: .defaultSnoozeStartDate))
                    }
                }
            }
        }
        .frame(minHeight: DS.Spacing.menuRowHeight)
        .padding(.vertical, DS.Spacing.xs)
    }

    private var settingsRowBirthday: some View {
        Button { onAction(.birthdayEditor) } label: {
            HStack(spacing: DS.Spacing.md) {
                settingsIcon("birthday.cake")
                Text("Birthday")
                    .font(DS.Typography.settingsRowLabel)
                    .foregroundStyle(DS.Colors.settingsItemLabel)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.displayBirthday?.formatted ?? "Add")
                        .font(DS.Typography.settingsRowLabel)
                        .foregroundStyle(DS.Colors.settingsItemValue)
                    if viewModel.person.birthday == nil && viewModel.contactBirthday != nil {
                        Text("from Contacts")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.settingsChevron)
            }
            .frame(minHeight: DS.Spacing.menuRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var settingsRowBirthdayNotifications: some View {
        Toggle(isOn: Binding(
            get: { viewModel.person.birthdayNotificationsEnabled },
            set: { viewModel.setBirthdayNotificationsEnabled($0) }
        )) {
            Text("Birthday Notifications")
                .font(DS.Typography.settingsRowLabel)
                .foregroundStyle(DS.Colors.settingsItemLabel)
        }
        .accessibilityLabel("Birthday Notifications for \(viewModel.person.displayName)")
        .accessibilityHint("Sends a reminder on this contact's birthday")
        .frame(minHeight: DS.Spacing.menuRowHeight)
    }

    private var settingsRowCadencesGroups: some View {
        HStack(spacing: DS.Spacing.md) {
            settingsIcon("person.2")
            Text("Groups")
                .font(DS.Typography.settingsRowLabel)
                .foregroundStyle(DS.Colors.settingsItemLabel)
            Spacer()
            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                if !personGroups.isEmpty {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(personGroups.prefix(2), id: \.id) { group in
                            GroupPill(group: group)
                        }
                        if personGroups.count > 2 {
                            Text("+\(personGroups.count - 2)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                    }
                }
                Button {
                    onAction(.manageGroups)
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Manage")
                            .font(DS.Typography.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(DS.Colors.settingsChevron)
                    }
                }
                .accessibilityLabel("Manage groups")
                .accessibilityHint("Opens group manager")
            }
        }
        .frame(minHeight: DS.Spacing.menuRowHeight)
    }

    private var settingsRowNotificationTimeActive: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Button {
                onAction(.reminderTimePicker)
            } label: {
                HStack {
                    Text("Custom Notification Time")
                        .font(DS.Typography.settingsRowLabel)
                        .foregroundStyle(DS.Colors.settingsItemLabel)
                    Spacer()
                    Text(reminderTimeLabel())
                        .font(DS.Typography.settingsRowLabel)
                        .foregroundStyle(DS.Colors.settingsItemValue)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DS.Colors.settingsChevron)
                }
                .frame(minHeight: DS.Spacing.menuRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if viewModel.person.customBreachTime != nil {
                Button("Restore defaults") {
                    viewModel.restoreNotificationDefaults()
                }
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
                .padding(.bottom, DS.Spacing.xs)
            }
        }
    }

    private var settingsRowMuteNotifications: some View {
        Toggle(isOn: Binding(
            get: { viewModel.person.notificationsMuted },
            set: { viewModel.setNotificationsMuted($0) }
        )) {
            Text("Mute Notifications")
                .font(DS.Typography.settingsRowLabel)
                .foregroundStyle(DS.Colors.settingsItemLabel)
        }
        .frame(minHeight: DS.Spacing.menuRowHeight)
    }

    private var settingsRowPauseTrackingActive: some View {
        Toggle(isOn: Binding(
            get: { viewModel.person.isPaused },
            set: { newValue in
                if newValue {
                    onAction(.requestPause)
                } else {
                    onAction(.resumePrompt)
                }
            }
        )) {
            Text("Pause Tracking")
                .font(DS.Typography.settingsRowLabel)
                .foregroundStyle(DS.Colors.settingsItemLabel)
        }
        .frame(minHeight: DS.Spacing.menuRowHeight)
    }

    private var settingsRowRemoveContact: some View {
        Button { onAction(.removeConfirm) } label: {
            Text("Remove Contact")
                .font(DS.Typography.settingsRowLabel)
                .foregroundStyle(DS.Colors.settingsRemoveText)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: DS.Spacing.menuRowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(viewModel.person.displayName)")
        .accessibilityHint("Confirms removal")
    }

    // MARK: - Helpers

    private var personGroups: [Group] {
        viewModel.groups.filter { viewModel.person.groupIds.contains($0.id) }
    }

    private func snooze(days: Int) {
        let date = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        viewModel.snooze(until: date)
    }

    /// A Pro-locked settings row: shows the title with a trailing lock and routes
    /// taps to the paywall. Mirrors the lock affordance used in Settings.
    private func proLockedRow(_ title: String, source: String) -> some View {
        Button {
            onAction(.requestPaywall(source: source))
        } label: {
            HStack {
                Text(title)
                    .font(DS.Typography.settingsRowLabel)
                    .foregroundStyle(DS.Colors.settingsItemLabel)
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.settingsChevron)
            }
            .frame(minHeight: DS.Spacing.menuRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Unlocks with Pro")
    }

    private func reminderTimeLabel() -> String {
        if let custom = viewModel.person.customBreachTime {
            return custom.formatted
        }
        if let settings = dependencies.settingsRepository.fetch() {
            return settings.breachTimeOfDay.formatted
        }
        return "Default"
    }

    private var settingsDivider: some View {
        Rectangle().fill(DS.Colors.settingsSeparator).frame(height: 0.5)
    }

    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title).font(DS.Typography.settingsSectionLabel).foregroundStyle(DS.Colors.settingsItemLabel)
            .textCase(.uppercase).tracking(0.5)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, DS.Spacing.lg).background(DS.Colors.settingsCardBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func settingsIcon(_ systemName: String) -> some View {
        Image(systemName: systemName).font(.footnote).foregroundStyle(DS.Colors.settingsChevron)
            .frame(width: 32, height: 32).background(DS.Colors.settingsIconCircle).clipShape(Circle())
    }

    private func snoozePill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(DS.Typography.caption)
                .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.xs)
                .overlay(Capsule().stroke(DS.Colors.settingsSnoozePillBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
