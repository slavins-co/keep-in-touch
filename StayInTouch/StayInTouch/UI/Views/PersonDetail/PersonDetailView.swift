//
//  PersonDetailView.swift
//  StayInTouch
//
//  Created by Codex on 2/2/26.
//

import SwiftUI

struct PersonDetailView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: PersonDetailViewModel

    @State private var showLogTouch = false
    @State private var showEditTouch: TouchEvent?
    @State private var showChangeGroup = false
    @State private var showManageTags = false
    @State private var showFullHistory = false
    @State private var showResumePrompt = false
    @State private var showDatePicker = false
    @State private var pickedResumeDate = Date()
    @State private var showDeleteConfirm: TouchEvent?
    @State private var showRemoveConfirm = false
    @State private var showReminderTimePicker = false
    @State private var workingReminderTime = Date()

    init(person: Person) {
        _viewModel = StateObject(wrappedValue: PersonDetailViewModel(person: person))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if viewModel.person.isPaused {
                    pausedBanner
                }
                cadenceCard
                historyCard
                reachOutCard
                tagsCard
                notificationsCard
                actionButtons
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(viewModel.person.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogTouch) {
            LogTouchModal { method, notes, date in
                viewModel.logTouch(method: method, notes: notes, date: date)
                showLogTouch = false
            }
        }
        .sheet(item: $showEditTouch) { touch in
            EditTouchModal(touch: touch) { method, notes in
                viewModel.updateTouch(touch, method: method, notes: notes)
                showEditTouch = nil
            }
        }
        .sheet(isPresented: $showChangeGroup) {
            GroupPickerSheet(
                groups: viewModel.groups,
                selectedId: viewModel.person.groupId,
                onSelect: { viewModel.changeGroup(to: $0) }
            )
        }
        .sheet(isPresented: $showManageTags) {
            TagManagerSheet(
                tags: viewModel.tags,
                selectedIds: Set(viewModel.person.tagIds),
                onAdd: { viewModel.addTag($0) },
                onRemove: { viewModel.removeTag($0) }
            )
        }
        .alert("Resume tracking?", isPresented: $showResumePrompt) {
            Button("Today") {
                viewModel.resumeAndUpdateLastTouch(date: Date())
            }
            Button("Pick Date") {
                pickedResumeDate = Date()
                showDatePicker = true
            }
            Button("Skip") {
                viewModel.resumeAndUpdateLastTouch(date: nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("When did you last connect?")
        }
        .alert("Delete touch?", isPresented: Binding(
            get: { showDeleteConfirm != nil },
            set: { if !$0 { showDeleteConfirm = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let touch = showDeleteConfirm {
                    viewModel.deleteTouch(touch)
                }
                showDeleteConfirm = nil
            }
            Button("Cancel", role: .cancel) { showDeleteConfirm = nil }
        } message: {
            Text("This can't be undone.")
        }
        .alert("Remove contact?", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) {
                viewModel.deletePerson()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove them from Stay in Touch.")
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker("Last touch", selection: $pickedResumeDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                viewModel.resumeAndUpdateLastTouch(date: pickedResumeDate)
                                showDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { showDatePicker = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showReminderTimePicker) {
            NavigationStack {
                DatePicker("Reminder Time", selection: $workingReminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { showReminderTimePicker = false }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                viewModel.setCustomBreachTime(LocalTime.from(date: workingReminderTime))
                                showReminderTimePicker = false
                            }
                        }
                    }
                    .onAppear {
                        workingReminderTime = reminderTimeDate()
                    }
            }
        }
        .task {
            await viewModel.refreshContactInfo()
            viewModel.load()
        }
        .onDisappear {
            NotificationCenter.default.post(name: .personDidChange, object: viewModel.person.id)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: viewModel.person.avatarColor))
                    .frame(width: 72, height: 72)
                Text(viewModel.person.initials)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.person.displayName)
                    .font(.title2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor())
                        .frame(width: 8, height: 8)
                    Text(statusLabel())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if daysOverdue > 0 {
                        Text("+\(daysOverdue)d")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var pausedBanner: some View {
        HStack {
            Text("Tracking paused")
                .font(.footnote)
            Spacer()
            Button("Resume") { showResumePrompt = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cadenceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Cadence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Change") { showChangeGroup = true }
            }
            Text(viewModel.group?.name ?? "Group")
                .font(.title3)
            Text(cadenceSubtext())
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Manage") { showManageTags = true }
            }

            if viewModel.person.tagIds.isEmpty {
                Text("No tags yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                WrapLayout {
                    ForEach(viewModel.tags.filter { viewModel.person.tagIds.contains($0.id) }, id: \.id) { tag in
                        Button {
                            viewModel.removeTag(tag)
                        } label: {
                            Text(tag.name)
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(hex: tag.colorHex))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Contact History")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.touchEvents.count > 1 {
                    Button(showFullHistory ? "Hide" : "See All") {
                        showFullHistory.toggle()
                    }
                }
            }

            if viewModel.touchEvents.isEmpty {
                Text("A house of friendship begins with a single brick.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                let events = showFullHistory ? viewModel.touchEvents : Array(viewModel.touchEvents.prefix(1))
                ForEach(events, id: \.id) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(event.method.rawValue) · \(event.at.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                        if let notes = event.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Button("Edit") { showEditTouch = event }
                            Button("Delete", role: .destructive) { showDeleteConfirm = event }
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 6)
                }
            }

            Button("Log Touch") { showLogTouch = true }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var reachOutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reach Out")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Message") { open(.message) }
                Button("Call") { open(.call) }
                Button("Email") { open(.email) }
            }
            .buttonStyle(.bordered)

            if let message = viewModel.quickActionMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(isOn: Binding(
                get: { viewModel.person.notificationsMuted },
                set: { viewModel.setNotificationsMuted($0) }
            )) {
                Text("Mute reminders")
            }

            HStack {
                Text("Reminder time")
                Spacer()
                Text(reminderTimeLabel())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showReminderTimePicker = true
            }

            if viewModel.person.customBreachTime != nil {
                Button("Restore defaults") {
                    viewModel.restoreNotificationDefaults()
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var actionButtons: some View {
        if !viewModel.person.isPaused {
            Button("Pause") { viewModel.togglePause() }
                .buttonStyle(.bordered)
                .tint(.gray)
                .frame(maxWidth: .infinity)
        }
        Button("Remove from App") { showRemoveConfirm = true }
            .buttonStyle(.bordered)
            .tint(.red)
            .frame(maxWidth: .infinity)
    }

    private var daysOverdue: Int {
        guard let group = viewModel.group else { return 0 }
        return SLACalculator().daysOverdue(for: viewModel.person, in: [group])
    }

    private func statusLabel() -> String {
        guard let group = viewModel.group else { return "All good" }
        switch SLACalculator().status(for: viewModel.person, in: [group]) {
        case .inSLA: return "All good"
        case .dueSoon: return "Check in soon"
        case .outOfSLA: return "Overdue"
        case .unknown: return "Unknown"
        }
    }

    private func statusColor() -> Color {
        guard let group = viewModel.group else { return Color(hex: "34C759") }
        switch SLACalculator().status(for: viewModel.person, in: [group]) {
        case .inSLA: return Color(hex: "34C759")
        case .dueSoon: return Color(hex: "FF9500")
        case .outOfSLA: return Color(hex: "FF3B30")
        case .unknown: return Color(hex: "8E8E93")
        }
    }

    private func cadenceSubtext() -> String {
        guard let group = viewModel.group else { return "" }
        let remaining = group.slaDays - (SLACalculator().daysSinceLastTouch(for: viewModel.person) ?? 0)
        if remaining > 0 {
            return "Connect every \(group.slaDays) days · \(remaining)d remaining"
        }
        return "Connect every \(group.slaDays) days"
    }

    private func open(_ action: QuickActionType) {
        guard let url = viewModel.openAction(type: action) else { return }
        openURL(url) { accepted in
            if !accepted {
                viewModel.quickActionMessage = "Whoops — couldn't open that on this device."
            }
        }
    }

    private func reminderTimeLabel() -> String {
        if let custom = viewModel.person.customBreachTime {
            return custom.formatted
        }
        if let settings = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext).fetch() {
            return settings.breachTimeOfDay.formatted
        }
        return "Default"
    }

    private func reminderTimeDate() -> Date {
        if let custom = viewModel.person.customBreachTime {
            return custom.toDate()
        }
        if let settings = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext).fetch() {
            return settings.breachTimeOfDay.toDate()
        }
        return Date()
    }
}

private struct WrapLayout<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
    }
}
