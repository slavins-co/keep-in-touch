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
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var showSnoozeDatePicker = false
    @State private var pickedSnoozeDate = Date()
    @State private var nextTouchNotesText: String = ""
    @State private var settingsExpanded = false
    @State private var pendingQuickActionMethod: TouchMethod?
    @State private var pendingQuickActionTouch: TouchEvent?
    @State private var showQuickActionUndo = false
    @State private var showRemoveUndo = false
    @State private var pendingRemoveTask: Task<Void, Never>?
    @FocusState private var isNextTouchNotesFocused: Bool

    init(person: Person) {
        _viewModel = StateObject(wrappedValue: PersonDetailViewModel(person: person))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // TIER 1: Hero Zone
                header
                    .padding(.bottom, DS.Spacing.lg)

                if viewModel.person.contactUnavailable {
                    unavailableContactBanner
                }

                if viewModel.person.isPaused {
                    pausedBanner
                }

                reachOutButtons
                    .opacity(viewModel.person.contactUnavailable ? 0.4 : 1.0)
                    .disabled(viewModel.person.contactUnavailable)

                logTouchButton

                SubtleDivider()

                // TIER 2: Context Zone
                conversationContextCard

                SubtleDivider()

                historyCard

                SubtleDivider()

                // TIER 3: Settings Zone
                detailsAndSettings
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogTouch) {
            LogTouchModal { method, notes, date, timeOfDay in
                viewModel.logTouch(method: method, notes: notes, date: date, timeOfDay: timeOfDay)
                showLogTouch = false
            }
        }
        .sheet(item: $showEditTouch) { touch in
            EditTouchModal(touch: touch) { method, notes, timeOfDay in
                viewModel.updateTouch(touch, method: method, notes: notes, timeOfDay: timeOfDay)
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
        .alert("Delete connection?", isPresented: Binding(
            get: { showDeleteConfirm != nil },
            set: { if !$0 { showDeleteConfirm = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let touch = showDeleteConfirm {
                    Haptics.medium()
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
                startPendingRemove()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove them from Stay in Touch.")
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker("Last connection", selection: $pickedResumeDate, displayedComponents: .date)
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
        .sheet(isPresented: $showSnoozeDatePicker) {
            NavigationStack {
                DatePicker("Snooze until", selection: $pickedSnoozeDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { showSnoozeDatePicker = false }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                viewModel.snooze(until: pickedSnoozeDate)
                                showSnoozeDatePicker = false
                            }
                        }
                    }
            }
        }
        .confirmationDialog("Choose a number", isPresented: $viewModel.showPhonePicker) {
            ForEach(viewModel.phoneNumbers) { phone in
                Button("\(phone.label): \(phone.value)") {
                    guard let action = viewModel.pendingPhoneAction,
                          let url = viewModel.openActionWithValue(type: action, value: phone.value) else {
                        viewModel.pendingPhoneAction = nil
                        return
                    }
                    openURL(url) { accepted in
                        if accepted {
                            Haptics.light()
                            let method = action.touchMethod
                            viewModel.logTouch(method: method, notes: nil, date: Date())
                            pendingQuickActionTouch = viewModel.touchEvents.first
                            pendingQuickActionMethod = method
                        }
                    }
                    viewModel.pendingPhoneAction = nil
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.pendingPhoneAction = nil
            }
        }
        .confirmationDialog("Choose an email", isPresented: $viewModel.showEmailPicker) {
            ForEach(viewModel.emailAddresses) { email in
                Button("\(email.label): \(email.value)") {
                    guard let url = viewModel.openActionWithValue(type: .email, value: email.value) else { return }
                    openURL(url) { accepted in
                        if accepted {
                            Haptics.light()
                            viewModel.logTouch(method: .email, notes: nil, date: Date())
                            pendingQuickActionTouch = viewModel.touchEvents.first
                            pendingQuickActionMethod = .email
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .overlay(alignment: .top) {
            if showQuickActionUndo, let method = pendingQuickActionMethod {
                quickActionUndoBanner(method: method)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if showRemoveUndo {
                removeUndoBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showQuickActionUndo)
        .animation(.easeInOut(duration: 0.3), value: showRemoveUndo)
        .task {
            await viewModel.refreshContactInfo()
            viewModel.load()
        }
        .onDisappear {
            if showRemoveUndo {
                pendingRemoveTask?.cancel()
                viewModel.deletePerson()
            }
            NotificationCenter.default.post(name: .personDidChange, object: viewModel.person.id)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, pendingQuickActionMethod != nil {
                showQuickActionUndo = true
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    dismissQuickActionUndo()
                }
            }
        }
    }

    // MARK: - Tier 1: Hero Zone

    private var personTags: [Tag] {
        viewModel.tags.filter { viewModel.person.tagIds.contains($0.id) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Text(viewModel.person.displayName)
                    .font(DS.Typography.heroTitle)
                    .lineLimit(1)
                    .layoutPriority(1)

                if !personTags.isEmpty {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(personTags.prefix(3), id: \.id) { tag in
                            TagPill(tag: tag)
                        }
                        if personTags.count > 3 {
                            Text("+\(personTags.count - 3)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                    }
                    .lineLimit(1)
                }
            }

            HStack(spacing: DS.Spacing.sm) {
                StatusIndicator(status: currentStatus, daysOverdue: daysOverdue)
                Text(statusLabel())
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
    }

    private var unavailableContactBanner: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Contact unavailable")
                    .font(DS.Typography.metadata.weight(.semibold))
                    .foregroundStyle(.white)
                Text("This contact may have been deleted or merged.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Button("Remove") { showRemoveConfirm = true }
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.statusDueSoon)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.bottom, DS.Spacing.md)
    }

    private var pausedBanner: some View {
        HStack {
            Text("Tracking paused")
                .font(DS.Typography.metadata)
            Spacer()
            Button("Resume") { showResumePrompt = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.statusUnknown.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.bottom, DS.Spacing.md)
    }

    private var reachOutButtons: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: 0) {
                reachOutButton(icon: "message.fill", label: "Message") { open(.message) }
                reachOutButton(icon: "phone.fill", label: "Call") { open(.call) }
                reachOutButton(icon: "envelope.fill", label: "Email") { open(.email) }
            }

            if let message = viewModel.quickActionMessage {
                Text(message)
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    private func reachOutButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 48, height: 48)
                    .background(DS.Colors.accent.opacity(0.12))
                    .clipShape(Circle())
                Text(label)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.accent)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var logTouchButton: some View {
        Button {
            showLogTouch = true
        } label: {
            Label("Log Connection", systemImage: "plus.circle.fill")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.bottom, DS.Spacing.md)
    }

    // MARK: - Tier 2: Context Zone

    private var conversationContextCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Next Time")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.tertiaryText)

            TextField("What to talk about...", text: $nextTouchNotesText, axis: .vertical)
                .font(.body)
                .lineLimit(3...6)
                .focused($isNextTouchNotesFocused)
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
        .background(DS.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.vertical, DS.Spacing.md)
        .onAppear {
            nextTouchNotesText = viewModel.person.nextTouchNotes ?? ""
        }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Contact History")
                    .font(DS.Typography.sectionHeader)
                    .foregroundStyle(DS.Colors.secondaryText)
                Spacer()
                if viewModel.touchEvents.count > 3 {
                    Button(showFullHistory ? "Hide" : "See All") {
                        showFullHistory.toggle()
                    }
                }
            }

            if viewModel.touchEvents.isEmpty {
                Text("No connections yet")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.tertiaryText)
            } else {
                let events = showFullHistory ? viewModel.touchEvents : Array(viewModel.touchEvents.prefix(3))
                List {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        let isLatest = index == 0

                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: DS.touchMethodIcon(event.method))
                                    .foregroundStyle(DS.Colors.secondaryText)
                                    .font(.caption)
                                Text("\(event.method.rawValue) \u{00B7} \(event.at.formatted(date: .abbreviated, time: .omitted))\(event.timeOfDay.map { " \u{00B7} \($0.rawValue)" } ?? "")")
                                    .font(DS.Typography.metadata)
                            }
                            if let notes = event.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(DS.Typography.metadata)
                                    .foregroundStyle(DS.Colors.secondaryText)
                            }
                        }
                        .padding(.leading, DS.Spacing.sm)
                        .overlay(alignment: .leading) {
                            if isLatest {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(DS.Colors.accent)
                                    .frame(width: 3)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: DS.Spacing.sm, leading: 0, bottom: DS.Spacing.sm, trailing: 0))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                showDeleteConfirm = event
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                showEditTouch = event
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(DS.Colors.accent)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(events.count) * 52)
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Tier 3: Settings Zone

    private var detailsAndSettings: some View {
        DisclosureGroup(isExpanded: $settingsExpanded) {
            VStack(alignment: .leading, spacing: 0) {
                frequencySection
                SubtleDivider()
                tagsSection
                SubtleDivider()
                notificationsSection
                SubtleDivider()
                dangerSection
            }
        } label: {
            Text("Details & Settings")
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(DS.Colors.secondaryText)
        }
        .tint(DS.Colors.secondaryText)
        .padding(.vertical, DS.Spacing.md)
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("FREQUENCY")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .tracking(0.5)
                Spacer()
                Button("Change") { showChangeGroup = true }
                    .font(DS.Typography.caption)
            }
            Text(viewModel.group?.name ?? "Frequency")
                .font(.body)
            Text(frequencySubtext())
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.secondaryText)

            if let snoozedUntil = viewModel.person.snoozedUntil, snoozedUntil > Date() {
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(.purple)
                    Text("Snoozed until \(snoozedUntil.formatted(date: .abbreviated, time: .omitted))")
                        .font(DS.Typography.metadata)
                        .foregroundStyle(.purple)
                    Spacer()
                    Button("Clear") { viewModel.clearSnooze() }
                        .font(DS.Typography.metadata)
                }
            } else {
                Menu {
                    Button("3 days") { snooze(days: 3) }
                    Button("1 week") { snooze(days: 7) }
                    Button("2 weeks") { snooze(days: 14) }
                    Button("Pick date...") {
                        pickedSnoozeDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
                        showSnoozeDatePicker = true
                    }
                } label: {
                    Label("Snooze", systemImage: "moon")
                        .font(DS.Typography.metadata)
                }
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("GROUPS")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .tracking(0.5)
                Spacer()
                Button("Manage") { showManageTags = true }
                    .font(DS.Typography.caption)
            }

            if viewModel.person.tagIds.isEmpty {
                Text("No groups yet")
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
            } else {
                FlowLayout(spacing: DS.Spacing.sm) {
                    ForEach(viewModel.tags.filter { viewModel.person.tagIds.contains($0.id) }, id: \.id) { tag in
                        Button {
                            viewModel.removeTag(tag)
                        } label: {
                            TagPill(tag: tag)
                        }
                    }
                }
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("NOTIFICATIONS")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.secondaryText)
                .tracking(0.5)

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
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showReminderTimePicker = true
            }

            if viewModel.person.customBreachTime != nil {
                Button("Restore defaults") {
                    viewModel.restoreNotificationDefaults()
                }
                .foregroundStyle(DS.Colors.secondaryText)
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if !viewModel.person.isPaused {
                Button("Pause Tracking") { viewModel.togglePause() }
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            Button("Remove from App") { showRemoveConfirm = true }
                .font(DS.Typography.metadata)
                .foregroundStyle(DS.Colors.destructive)
        }
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Computed Properties

    private var currentStatus: ContactStatus {
        guard let group = viewModel.group else { return .onTrack }
        return FrequencyCalculator().status(for: viewModel.person, in: [group])
    }

    private var daysOverdue: Int {
        guard let group = viewModel.group else { return 0 }
        return FrequencyCalculator().daysOverdue(for: viewModel.person, in: [group])
    }

    private var daysUntilDue: Int {
        guard let group = viewModel.group else { return 0 }
        let calculator = FrequencyCalculator()
        let daysSince = calculator.daysSinceLastTouch(for: viewModel.person) ?? 0
        return max(0, group.frequencyDays - daysSince)
    }

    // MARK: - Helper Functions

    private func statusLabel() -> String {
        switch currentStatus {
        case .onTrack:
            let days = daysUntilDue
            return days > 0 ? "All good · Due in \(days)d" : "All good"
        case .dueSoon:
            let days = daysUntilDue
            return days > 0 ? "Check in soon · Due in \(days)d" : "Check in soon"
        case .overdue: return "Overdue"
        case .unknown: return "Unknown"
        }
    }

    private func statusColor() -> Color {
        DS.Colors.statusColor(for: currentStatus)
    }

    private static let dueDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private func frequencySubtext() -> String {
        guard let group = viewModel.group else { return "" }
        let calculator = FrequencyCalculator()
        let daysSince = calculator.daysSinceLastTouch(for: viewModel.person) ?? 0
        let remaining = group.frequencyDays - daysSince

        if let effectiveDate = calculator.effectiveLastTouchDate(for: viewModel.person) {
            let dueDate = Calendar.current.date(byAdding: .day, value: Int(group.frequencyDays), to: effectiveDate)
            let formatted = dueDate.map { Self.dueDateFormatter.string(from: $0) } ?? "?"
            if remaining > 0 {
                return "Connect every \(group.frequencyDays) days \u{00B7} Due \(formatted) \u{00B7} \(remaining)d remaining"
            }
            return "Connect every \(group.frequencyDays) days \u{00B7} Was due \(formatted)"
        }
        return "Connect every \(group.frequencyDays) days"
    }

    private func snooze(days: Int) {
        let date = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        viewModel.snooze(until: date)
    }

    private func open(_ action: QuickActionType) {
        guard let url = viewModel.openAction(type: action) else { return }
        openURL(url) { accepted in
            if accepted {
                Haptics.light()
                let method = action.touchMethod
                viewModel.logTouch(method: method, notes: nil, date: Date())
                pendingQuickActionTouch = viewModel.touchEvents.first
                pendingQuickActionMethod = method
            } else {
                viewModel.quickActionMessage = "Whoops — couldn't open that on this device."
            }
        }
    }

    private func quickActionUndoBanner(method: TouchMethod) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text("Logged \(method.rawValue.lowercased()). Didn't connect?")
                .font(DS.Typography.metadata)
                .foregroundStyle(.white)
            Spacer()
            Button("Undo") {
                Haptics.light()
                if let touch = pendingQuickActionTouch {
                    viewModel.deleteTouch(touch)
                }
                dismissQuickActionUndo()
            }
            .font(DS.Typography.metadata.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(.white.opacity(0.2))
            .clipShape(Capsule())
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.statusAllGood)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
    }

    private func dismissQuickActionUndo() {
        showQuickActionUndo = false
        pendingQuickActionMethod = nil
        pendingQuickActionTouch = nil
    }

    private var removeUndoBanner: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "trash.fill")
                .foregroundStyle(.white)
            Text("Contact removed")
                .font(DS.Typography.metadata)
                .foregroundStyle(.white)
            Spacer()
            Button("Undo") {
                Haptics.light()
                cancelPendingRemove()
            }
            .font(DS.Typography.metadata.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(.white.opacity(0.2))
            .clipShape(Capsule())
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.destructive)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
    }

    private func startPendingRemove() {
        Haptics.medium()
        showRemoveUndo = true
        pendingRemoveTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            showRemoveUndo = false
            viewModel.deletePerson()
            dismiss()
        }
    }

    private func cancelPendingRemove() {
        pendingRemoveTask?.cancel()
        pendingRemoveTask = nil
        showRemoveUndo = false
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

