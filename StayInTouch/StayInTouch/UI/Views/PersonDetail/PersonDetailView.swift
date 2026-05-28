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
    @Environment(\.dependencies) private var dependencies

    @StateObject private var viewModel: PersonDetailViewModel

    // Modal state (replaces 12 individual booleans/optionals)
    @State private var activeSheet: PersonDetailSheet?
    @State private var activeAlert: PersonDetailAlert?

    // Inline toggles
    @State private var showFullHistory = false
    @State private var settingsExpanded = false

    // Date picker working values
    @State private var pickedResumeDate = Date()
    @State private var workingReminderTime = Date()
    @State private var pickedSnoozeDate = Date()
    @State private var pickedCustomDueDate = Date()

    // Quick action undo state
    @State private var pendingQuickActionMethod: TouchMethod?
    @State private var pendingQuickActionTouch: TouchEvent?
    @State private var showQuickActionUndo = false

    // Remove undo state
    @State private var showRemoveUndo = false
    @State private var pendingRemoveTask: Task<Void, Never>?

    init(person: Person, mode: PersonDetailViewModel.Mode = .normal) {
        _viewModel = StateObject(wrappedValue: PersonDetailViewModel(person: person, mode: mode))
        if case .preview = mode {
            _settingsExpanded = State(initialValue: true)
        }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // TIER 1: Hero Zone
                    PersonHeroSection(
                        viewModel: viewModel,
                        onBirthdayEdit: { activeSheet = .birthdayEditor },
                        onResumePrompt: { activeAlert = .resumePrompt },
                        onRemoveConfirm: { activeAlert = .removeConfirm },
                        onLinkContact: {
                            ContactPickerPresenter.present { cnIdentifier in
                                viewModel.relinkContact(cnIdentifier: cnIdentifier)
                            }
                        }
                    )
                    .tutorialAnchor(TutorialAnchor.personHero)
                    .tutorialScrollID(TutorialAnchor.personHero, isPreview: viewModel.isPreview)

                    PersonQuickActionsBar(
                        viewModel: viewModel,
                        onQuickAction: { open($0) },
                        onMessageWith: { openMessage(with: $0) },
                        onFaceTime: { faceTime() }
                    )
                    .opacity(viewModel.person.contactUnavailable ? 0.4 : 1.0)
                    .disabled(viewModel.person.contactUnavailable)
                    .tutorialAnchor(TutorialAnchor.personQuickActions)
                    .tutorialScrollID(TutorialAnchor.personQuickActions, isPreview: viewModel.isPreview)

                    SubtleDivider()

                    // TIER 2: Context Zone
                    PersonConversationContextCard(viewModel: viewModel)
                        .tutorialAnchor(TutorialAnchor.personNextTouchNotes)
                        .tutorialScrollID(TutorialAnchor.personNextTouchNotes, isPreview: viewModel.isPreview)

                    SubtleDivider()

                    PersonTouchHistorySection(
                        viewModel: viewModel,
                        showFullHistory: $showFullHistory,
                        onEditTouch: { activeSheet = .editTouch($0) },
                        onDeleteTouch: { activeAlert = .deleteConfirm($0) }
                    )
                    .tutorialAnchor(TutorialAnchor.personTimeline)
                    .tutorialScrollID(TutorialAnchor.personTimeline, isPreview: viewModel.isPreview)

                    SubtleDivider()

                    // TIER 3: Settings Zone
                    PersonSettingsSection(
                        viewModel: viewModel,
                        settingsExpanded: $settingsExpanded,
                        onAction: { handleSettingsAction($0) }
                    )
                }
                .padding(.horizontal, DS.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onReceive(NotificationCenter.default.publisher(for: .tutorialScrollToAnchor)) { note in
                guard viewModel.isPreview, let anchor = note.object as? String else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    scrollProxy.scrollTo(anchor, anchor: .center)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            fixedBottomCTA
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .alert(
            alertTitle,
            isPresented: Binding(
                get: { activeAlert != nil },
                set: { if !$0 { activeAlert = nil } }
            ),
            presenting: activeAlert
        ) { alert in
            alertActions(for: alert)
        } message: { alert in
            alertMessage(for: alert)
        }
        .confirmationDialog("Choose a number", isPresented: $viewModel.showPhonePicker) {
            ForEach(viewModel.phoneNumbers) { phone in
                Button("\(phone.label): \(phone.value)") {
                    guard let routing = viewModel.pendingPhoneRouting,
                          let url = viewModel.routeActionWithValue(routing, value: phone.value) else {
                        viewModel.cancelPendingPhonePicker()
                        return
                    }
                    executeQuickAction(url: url, routing: routing)
                    viewModel.cancelPendingPhonePicker()
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelPendingPhonePicker()
            }
        }
        .confirmationDialog("Choose an email", isPresented: $viewModel.showEmailPicker) {
            ForEach(viewModel.emailAddresses) { email in
                Button("\(email.label): \(email.value)") {
                    guard let url = viewModel.openEmailActionWithValue(email.value) else { return }
                    executeQuickAction(url: url, method: .email, onFailure: nil)
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
        .onAppear {
            viewModel.load()
        }
        .task {
            await viewModel.refreshContactInfo()
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

    // MARK: - Fixed Bottom CTA

    private var fixedBottomCTA: some View {
        VStack(spacing: 0) {
            DS.Colors.borderMedium.frame(height: 1)
            Button {
                activeSheet = .logTouch
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
            .accessibilityLabel("Log connection with \(viewModel.person.displayName)")
            .shadow(color: DS.Colors.ctaShadow, radius: 8, y: 2)
            .tutorialAnchor(TutorialAnchor.personLogTouch)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
        .background(DS.Colors.ctaContainerBg)
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: PersonDetailSheet) -> some View {
        switch sheet {
        case .logTouch:
            LogTouchModal { method, notes, date, timeOfDay in
                viewModel.logTouch(method: method, notes: notes, date: date, timeOfDay: timeOfDay); activeSheet = nil
            }
        case .editTouch(let touch):
            EditTouchModal(touch: touch, onSave: { method, notes, timeOfDay in
                viewModel.updateTouch(touch, method: method, notes: notes, timeOfDay: timeOfDay); activeSheet = nil
            }, onDelete: { viewModel.deleteTouch(touch); activeSheet = nil })
        case .changeCadence:
            CadencePickerSheet(cadences: viewModel.cadences, selectedId: viewModel.person.cadenceId,
                             onSelect: { viewModel.changeCadence(to: $0) }).presentationDetents([.medium])
        case .manageGroups:
            GroupManagerSheet(groups: viewModel.groups, selectedIds: Set(viewModel.person.groupIds),
                            onAdd: { viewModel.addGroup($0) }, onRemove: { viewModel.removeGroup($0) }).presentationDetents([.medium])
        case .resumeDatePicker:
            datePickerSheet("Last Connection", selection: $pickedResumeDate) { viewModel.resumeAndUpdateLastTouch(date: pickedResumeDate) }
        case .reminderTimePicker:
            datePickerSheet("Reminder Time", selection: $workingReminderTime, components: .hourAndMinute, useWheel: true) {
                viewModel.setCustomBreachTime(LocalTime.from(date: workingReminderTime))
            }.onAppear { workingReminderTime = reminderTimeDate() }
        case .snoozeDatePicker:
            datePickerSheet("Snooze Until", selection: $pickedSnoozeDate, minDate: Date()) { viewModel.snooze(until: pickedSnoozeDate) }
        case .customDueDatePicker:
            datePickerSheet("Due Date", selection: $pickedCustomDueDate, minDate: Date()) { viewModel.setCustomDueDate(pickedCustomDueDate) }
        case .birthdayEditor:
            BirthdayEditorSheet(birthday: viewModel.displayBirthday,
                                onSave: { viewModel.setBirthday($0); activeSheet = nil },
                                onClear: { viewModel.setBirthday(nil); activeSheet = nil })
        }
    }

    // MARK: - Alert Content

    private var alertTitle: String {
        switch activeAlert {
        case .resumePrompt: return "Resume tracking?"
        case .deleteConfirm: return "Delete connection?"
        case .removeConfirm: return "Remove contact?"
        case .none: return ""
        }
    }

    @ViewBuilder
    private func alertActions(for alert: PersonDetailAlert) -> some View {
        switch alert {
        case .resumePrompt:
            Button("Today") { viewModel.resumeAndUpdateLastTouch(date: Date()) }
            Button("Pick Date") { pickedResumeDate = Date(); activeSheet = .resumeDatePicker }
            Button("Skip") { viewModel.resumeAndUpdateLastTouch(date: nil) }
            Button("Cancel", role: .cancel) {}
        case .deleteConfirm(let touch):
            Button("Delete", role: .destructive) { Haptics.medium(); viewModel.deleteTouch(touch) }
            Button("Cancel", role: .cancel) {}
        case .removeConfirm:
            Button("Remove", role: .destructive) { startPendingRemove() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func alertMessage(for alert: PersonDetailAlert) -> Text {
        switch alert {
        case .resumePrompt: return Text("When did you last connect?")
        case .deleteConfirm: return Text("This can't be undone.")
        case .removeConfirm: return Text("This will remove them from Keep In Touch.")
        }
    }

    // MARK: - Settings Action Handler

    private func handleSettingsAction(_ action: PersonSettingsAction) {
        switch action {
        case .changeCadence: activeSheet = .changeCadence
        case .manageGroups: activeSheet = .manageGroups
        case .resumePrompt: activeAlert = .resumePrompt
        case .removeConfirm: activeAlert = .removeConfirm
        case .reminderTimePicker: activeSheet = .reminderTimePicker
        case .snoozeDatePicker(let d): pickedSnoozeDate = d; activeSheet = .snoozeDatePicker
        case .customDueDatePicker(let d): pickedCustomDueDate = d; activeSheet = .customDueDatePicker
        case .birthdayEditor: activeSheet = .birthdayEditor
        }
    }

    // MARK: - Date Picker Sheet Helper

    private func datePickerSheet(
        _ title: String,
        selection: Binding<Date>,
        components: DatePickerComponents = .date,
        useWheel: Bool = false,
        minDate: Date? = nil,
        onSave: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            SwiftUI.Group {
                if useWheel {
                    DatePicker(title, selection: selection, displayedComponents: components)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                } else if let minDate {
                    DatePicker(title, selection: selection, in: minDate..., displayedComponents: components)
                        .datePickerStyle(.graphical)
                        .padding()
                } else {
                    DatePicker(title, selection: selection, displayedComponents: components)
                        .datePickerStyle(.graphical)
                        .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { activeSheet = nil }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        activeSheet = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Quick Actions

    private func open(_ action: QuickActionType) {
        switch action {
        case .message:
            let routing = PersonDetailViewModel.PhoneRouting.message(explicit: nil)
            guard let url = viewModel.routeAction(routing) else { return }
            executeQuickAction(url: url, routing: routing)
        case .call:
            guard let url = viewModel.routeAction(.call) else { return }
            executeQuickAction(url: url, routing: .call)
        case .email:
            guard let url = viewModel.openEmailAction() else { return }
            executeQuickAction(url: url, method: .email, onFailure: nil)
        }
    }

    /// Long-press → FaceTime from the Call card. No persistent preference.
    private func faceTime() {
        guard let url = viewModel.routeAction(.faceTime) else { return }
        executeQuickAction(
            url: url,
            method: .facetime,
            onFailure: { viewModel.quickActionMessage = "Whoops — couldn't open FaceTime on this device." }
        )
    }

    /// Explicit messenger pick from the long-press menu. The preference is
    /// persisted AFTER `openURL` succeeds — saving earlier would strand a
    /// sticky preference if the user cancels a downstream phone picker for
    /// a multi-phone contact. The multi-phone case is handled by the
    /// `routeActionWithValue` branch in the phone-picker dialog, which
    /// likewise persists only on accepted-true.
    private func openMessage(with messenger: PreferredMessenger) {
        let routing = PersonDetailViewModel.PhoneRouting.message(explicit: messenger)
        guard let url = viewModel.routeAction(routing) else { return }
        executeQuickAction(url: url, routing: routing)
    }

    /// Centralised "open URL, log touch on success, surface error on failure"
    /// flow shared by every quick-action entry point and the phone-picker
    /// dialog. The `routing` overload encapsulates messenger preference
    /// persistence + handleFailedMessengerOpen self-heal so callers don't
    /// have to reproduce that dance. The plain `method:` overload is for
    /// codepaths that don't need messenger preference handling (email + FaceTime).
    private func executeQuickAction(url: URL, routing: PersonDetailViewModel.PhoneRouting) {
        // Resolve the messenger ONCE — used for the self-heal target on failure.
        // The auto-logged TouchMethod is always `.text` for text-medium messengers
        // (#299 collapsed TouchMethod to medium-only); the which-app signal lives
        // on `Person.preferredMessenger`.
        let resolvedMessenger: PreferredMessenger? = {
            if case .message(let explicit) = routing { return explicit ?? viewModel.resolvedMessenger }
            return nil
        }()
        let method = routing.resolvedTouchMethod(defaultMessenger: viewModel.resolvedMessenger)
        let explicitMessenger: PreferredMessenger? = {
            if case .message(let explicit) = routing { return explicit }
            return nil
        }()
        openURL(url) { accepted in
            if accepted {
                if let explicitMessenger {
                    viewModel.setPreferredMessenger(explicitMessenger)
                }
                logTouchAndArmUndo(method: method)
            } else if let resolvedMessenger {
                viewModel.handleFailedMessengerOpen(messenger: resolvedMessenger)
            } else {
                viewModel.quickActionMessage = "Whoops — couldn't open that on this device."
            }
        }
    }

    private func executeQuickAction(url: URL, method: TouchMethod, onFailure: (() -> Void)?) {
        openURL(url) { accepted in
            if accepted {
                logTouchAndArmUndo(method: method)
            } else {
                onFailure?()
            }
        }
    }

    private func logTouchAndArmUndo(method: TouchMethod) {
        Haptics.light()
        viewModel.logTouch(method: method, notes: nil, date: Date())
        pendingQuickActionTouch = viewModel.touchEvents.first
        pendingQuickActionMethod = method
    }

    private func quickActionUndoBanner(method: TouchMethod) -> some View {
        undoBanner(
            icon: "checkmark.circle.fill",
            text: "Logged \(method.rawValue.lowercased()). Didn't connect?",
            color: DS.Colors.statusAllGood
        ) {
            if let touch = pendingQuickActionTouch { viewModel.deleteTouch(touch) }
            dismissQuickActionUndo()
        }
    }

    private func dismissQuickActionUndo() {
        showQuickActionUndo = false
        pendingQuickActionMethod = nil
        pendingQuickActionTouch = nil
    }

    // MARK: - Remove Undo

    private var removeUndoBanner: some View {
        undoBanner(icon: "trash.fill", text: "Contact removed", color: DS.Colors.destructive) {
            cancelPendingRemove()
        }
    }

    private func undoBanner(icon: String, text: String, color: Color, onUndo: @escaping () -> Void) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon).foregroundStyle(.white)
            Text(text).font(DS.Typography.metadata).foregroundStyle(.white)
            Spacer()
            Button("Undo") { Haptics.light(); onUndo() }
                .font(DS.Typography.metadata.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(DS.Spacing.md)
        .background(color)
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

    // MARK: - Helpers

    private func reminderTimeDate() -> Date {
        if let custom = viewModel.person.customBreachTime {
            return custom.toDate()
        }
        if let settings = dependencies.settingsRepository.fetch() {
            return settings.breachTimeOfDay.toDate()
        }
        return Date()
    }
}
