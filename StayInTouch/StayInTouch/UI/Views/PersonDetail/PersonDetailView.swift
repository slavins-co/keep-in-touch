//
//  PersonDetailView.swift
//  KeepInTouch
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
    @State private var showCustomDueDatePicker = false
    @State private var pickedCustomDueDate = Date()
    @State private var nextTouchNotesText: String = ""
    @State private var settingsExpanded = false
    @State private var pendingQuickActionMethod: TouchMethod?
    @State private var pendingQuickActionTouch: TouchEvent?
    @State private var showQuickActionUndo = false
    @State private var showRemoveUndo = false
    @State private var pendingRemoveTask: Task<Void, Never>?
    @State private var showBirthdayEditor = false
    @FocusState private var isNextTouchNotesFocused: Bool
    @AppStorage("hasUsedTimelineLongPress") private var hasUsedTimelineLongPress = false

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
        .safeAreaInset(edge: .bottom) {
            fixedBottomCTA
        }
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
            Text("This will remove them from Keep In Touch.")
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
        .sheet(isPresented: $showCustomDueDatePicker) {
            NavigationStack {
                DatePicker("Due by", selection: $pickedCustomDueDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { showCustomDueDatePicker = false }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                viewModel.setCustomDueDate(pickedCustomDueDate)
                                showCustomDueDatePicker = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showBirthdayEditor) {
            BirthdayEditorSheet(
                birthday: viewModel.displayBirthday,
                onSave: { birthday in
                    viewModel.setBirthday(birthday)
                    showBirthdayEditor = false
                },
                onClear: {
                    viewModel.setBirthday(nil)
                    showBirthdayEditor = false
                }
            )
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
        VStack(alignment: .center, spacing: DS.Spacing.sm) {
            ContactPhotoView(
                cnIdentifier: viewModel.person.cnIdentifier,
                displayName: viewModel.person.displayName,
                size: 96
            )
            .overlay(Circle().stroke(DS.Colors.heroAvatarRing, lineWidth: 4))
            .shadow(color: .black.opacity(0.10), radius: 8, y: 6)

            Text(viewModel.person.displayName)
                .font(DS.Typography.sheetHeroName)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(statusLabel())
                .font(DS.Typography.detailStatusLine)
                .foregroundStyle(statusLineColor)
                .multilineTextAlignment(.center)

            if let birthday = viewModel.displayBirthday {
                Button {
                    showBirthdayEditor = true
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "gift.fill")
                            .font(.caption)
                        Text(birthday.formatted)
                            .font(DS.Typography.contactCardMeta)
                    }
                    .foregroundStyle(Color(.secondaryLabel))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Birthday \(birthday.formatted), tap to edit")
            }

            if !personTags.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(personTags.prefix(3), id: \.id) { tag in
                        TagPill(tag: tag)
                    }
                    if personTags.count > 3 {
                        Text("+\(personTags.count - 3)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.secondaryText)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
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

    private var hasPhone: Bool {
        viewModel.phone != nil || !viewModel.phoneNumbers.isEmpty
    }

    private var hasEmail: Bool {
        viewModel.email != nil || !viewModel.emailAddresses.isEmpty
    }

    private var reachOutButtons: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                actionCard(icon: "message.fill", label: "Message", enabled: hasPhone) { open(.message) }
                actionCard(icon: "phone.fill", label: "Call", enabled: hasPhone) { open(.call) }
                actionCard(icon: "envelope.fill", label: "Email", enabled: hasEmail) { open(.email) }
            }

            if let message = viewModel.quickActionMessage {
                Text(message)
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    private func actionCard(icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.actionButtonIconCircleOpacity)
                    .clipShape(Circle())
                Text(label)
                    .font(DS.Typography.contactCardMeta)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 80)
            .background(DS.Colors.actionButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(DS.Colors.actionButtonBorder, lineWidth: 1)
            )
            .shadow(color: DS.Colors.actionButtonShadow, radius: 6, y: 2)
        }
        .buttonStyle(ActionCardButtonStyle())
        .disabled(!enabled)
        .opacity(!enabled && !viewModel.person.contactUnavailable ? 0.5 : 1.0)
    }

    private var fixedBottomCTA: some View {
        VStack(spacing: 0) {
            DS.Colors.borderMedium.frame(height: 1)
            Button {
                showLogTouch = true
            } label: {
                Text("Log Connection")
                    .font(DS.Typography.ctaButton)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DS.Colors.heroAccentGreen)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .shadow(color: DS.Colors.ctaShadow, radius: 8, y: 2)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
        .background(DS.Colors.ctaContainerBg)
    }

    // MARK: - Tier 2: Context Zone

    private var conversationContextCard: some View {
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

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("History")
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
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        TimelineEntryView(
                            event: event,
                            isLatest: index == 0,
                            isLast: index == events.count - 1
                        )
                        .contextMenu {
                            Button {
                                hasUsedTimelineLongPress = true
                                showEditTouch = event
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                hasUsedTimelineLongPress = true
                                showDeleteConfirm = event
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    if !hasUsedTimelineLongPress {
                        Text("Tap and hold to edit")
                            .font(DS.Typography.timelineHint)
                            .foregroundStyle(DS.Colors.tertiaryText)
                            .padding(.leading, 40)
                    }
                }
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Tier 3: Settings Zone

    private var detailsAndSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
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
                        .animation(.easeInOut(duration: 0.25), value: settingsExpanded)
                }
                .padding(.vertical, DS.Spacing.md)
            }
            .buttonStyle(.plain)

            if settingsExpanded {
                settingsContent
                    .transition(.opacity.combined(with: .slide))
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // No heading — Frequency & Reminder Date
            settingsCard {
                settingsRowFrequency
                settingsDivider
                settingsRowCustomDueDate
            }

            // DETAILS
            settingsSectionHeader("DETAILS")
            settingsCard {
                settingsRowBirthday
                settingsDivider
                settingsRowGroupsTags
            }

            // TRACKING & NOTIFICATIONS
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

            // Remove Contact (standalone)
            settingsRowRemoveContact
        }
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(DS.Colors.settingsSeparator)
            .frame(height: 0.5)
    }

    private func settingsSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DS.Typography.settingsSectionLabel)
            .foregroundStyle(DS.Colors.settingsItemLabel)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .background(DS.Colors.settingsCardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func settingsIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14))
            .foregroundStyle(DS.Colors.settingsChevron)
            .frame(width: 32, height: 32)
            .background(DS.Colors.settingsIconCircle)
            .clipShape(Circle())
    }

    private func snoozePill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.caption)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .overlay(
                    Capsule()
                        .stroke(DS.Colors.settingsSnoozePillBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Settings Row 1 — Frequency

    private var settingsRowFrequency: some View {
        Button { showChangeGroup = true } label: {
            HStack {
                Text("Frequency")
                    .font(DS.Typography.settingsRowLabel)
                    .foregroundStyle(DS.Colors.settingsItemLabel)
                Spacer()
                Text(viewModel.group?.name ?? "Not set")
                    .font(DS.Typography.settingsRowLabel)
                    .foregroundStyle(DS.Colors.settingsItemValue)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.settingsChevron)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Settings Row 2 — Set A Reminder Date

    private var settingsRowCustomDueDate: some View {
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
                    pickedCustomDueDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
                    showCustomDueDatePicker = true
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
        .frame(minHeight: 48)
    }

    // MARK: Settings Row 3 — Snooze

    private var settingsRowSnooze: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Snooze")
                    .font(DS.Typography.settingsRowLabel)
                    .foregroundStyle(DS.Colors.settingsItemLabel)
                Spacer()
                if let snoozedUntil = viewModel.person.snoozedUntil, snoozedUntil > Date() {
                    Text("Until \(snoozedUntil.formatted(date: .abbreviated, time: .omitted))")
                        .font(DS.Typography.settingsRowLabel)
                        .foregroundStyle(.purple)
                    Button("Remove") { viewModel.clearSnooze() }
                        .font(DS.Typography.caption)
                } else {
                    Text("Not snoozed")
                        .font(DS.Typography.settingsRowLabel)
                        .foregroundStyle(DS.Colors.settingsItemValue)
                }
            }

            if !(viewModel.person.snoozedUntil.map { $0 > Date() } ?? false) {
                HStack(spacing: DS.Spacing.sm) {
                    snoozePill("3d") { snooze(days: 3) }
                    snoozePill("7d") { snooze(days: 7) }
                    snoozePill("14d") { snooze(days: 14) }
                    snoozePill("Pick date") {
                        pickedSnoozeDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
                        showSnoozeDatePicker = true
                    }
                }
            }
        }
        .frame(minHeight: 48)
        .padding(.vertical, DS.Spacing.xs)
    }

    // MARK: Settings Row 4 — Groups

    private var settingsRowGroupsTags: some View {
        HStack(spacing: DS.Spacing.md) {
            settingsIcon("tag")
            Text("Groups")
                .font(DS.Typography.settingsRowLabel)
                .foregroundStyle(DS.Colors.settingsItemLabel)
            Spacer()
            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                if !personTags.isEmpty {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(personTags.prefix(2), id: \.id) { tag in
                            TagPill(tag: tag)
                        }
                        if personTags.count > 2 {
                            Text("+\(personTags.count - 2)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                    }
                }
                Button {
                    showManageTags = true
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Manage")
                            .font(DS.Typography.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(DS.Colors.settingsChevron)
                    }
                }
            }
        }
        .frame(minHeight: 48)
    }

    // MARK: Settings Row 5 — Birthday

    private var settingsRowBirthday: some View {
        Button { showBirthdayEditor = true } label: {
            HStack(spacing: DS.Spacing.md) {
                settingsIcon("birthday.cake")
                Text("Birthday")
                    .font(DS.Typography.settingsRowLabel)
                    .foregroundStyle(DS.Colors.settingsItemLabel)
                Spacer()
                Text(viewModel.displayBirthday?.formatted ?? "Add")
                    .font(DS.Typography.settingsRowLabel)
                    .foregroundStyle(DS.Colors.settingsItemValue)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.settingsChevron)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Settings Row 6 — Notification Time

    private var settingsRowNotificationTime: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Button {
                showReminderTimePicker = true
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
                .frame(minHeight: 48)
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

    // MARK: Settings Row 7 — Mute Notifications

    private var settingsRowMuteNotifications: some View {
        Toggle(isOn: Binding(
            get: { viewModel.person.notificationsMuted },
            set: { viewModel.setNotificationsMuted($0) }
        )) {
            Text("Mute Notifications")
                .font(DS.Typography.settingsRowLabel)
                .foregroundStyle(DS.Colors.settingsItemLabel)
        }
        .frame(minHeight: 48)
    }

    // MARK: Settings Row 8 — Pause Tracking

    private var settingsRowPauseTracking: some View {
        Toggle(isOn: Binding(
            get: { viewModel.person.isPaused },
            set: { newValue in
                if newValue {
                    viewModel.togglePause()
                } else {
                    showResumePrompt = true
                }
            }
        )) {
            Text("Pause Tracking")
                .font(DS.Typography.settingsRowLabel)
                .foregroundStyle(DS.Colors.settingsItemLabel)
        }
        .frame(minHeight: 48)
    }

    // MARK: Settings Row 10 — Remove Contact

    private var settingsRowRemoveContact: some View {
        Button { showRemoveConfirm = true } label: {
            Text("Remove Contact")
                .font(DS.Typography.settingsRowLabel)
                .foregroundStyle(DS.Colors.settingsRemoveText)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        guard let dueDate = calculator.effectiveDueDate(for: viewModel.person, in: [group]) else { return 0 }
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: dueDate)).day ?? 0)
    }

    // MARK: - Helper Functions

    private func statusLabel() -> String {
        let groupName = viewModel.group?.name ?? "Frequency"

        // Check paused state first
        if viewModel.person.isPaused {
            return "\(groupName) \u{00B7} Paused"
        }

        // Check snoozed state
        if let snoozedUntil = viewModel.person.snoozedUntil, snoozedUntil > Date() {
            let formatted = Self.dueDateFormatter.string(from: snoozedUntil)
            return "\(groupName) \u{00B7} Snoozed until \(formatted)"
        }

        switch currentStatus {
        case .onTrack:
            return "\(groupName) \u{00B7} All good"
        case .dueSoon:
            let days = daysUntilDue
            return days > 0 ? "\(groupName) \u{00B7} Due in \(days)d" : "\(groupName) \u{00B7} Check in soon"
        case .overdue:
            let days = daysOverdue
            if days >= 14 {
                let weeks = days / 7
                return "\(groupName) \u{00B7} Overdue by \(weeks) week\(weeks == 1 ? "" : "s")"
            }
            return "\(groupName) \u{00B7} Overdue by \(days) day\(days == 1 ? "" : "s")"
        case .unknown:
            return "\(groupName) \u{00B7} No connections yet"
        }
    }

    private var statusLineColor: Color {
        if viewModel.person.isPaused {
            return DS.Colors.textMuted
        }
        if let snoozedUntil = viewModel.person.snoozedUntil, snoozedUntil > Date() {
            return DS.Colors.textMuted
        }
        return DS.Colors.statusColor(for: currentStatus)
    }

    private static let dueDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private func frequencySubtext() -> String {
        guard let group = viewModel.group else { return "" }
        let calculator = FrequencyCalculator()

        if let dueDate = calculator.effectiveDueDate(for: viewModel.person, in: [group]) {
            let cal = Calendar.current
            let remaining = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: dueDate)).day ?? 0
            let formatted = Self.dueDateFormatter.string(from: dueDate)
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

// MARK: - Action Card Button Style

private struct ActionCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

