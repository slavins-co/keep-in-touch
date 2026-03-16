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

    init(person: Person) {
        _viewModel = StateObject(wrappedValue: PersonDetailViewModel(person: person))
    }

    var body: some View {
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

                PersonQuickActionsBar(
                    viewModel: viewModel,
                    onQuickAction: { open($0) }
                )
                .opacity(viewModel.person.contactUnavailable ? 0.4 : 1.0)
                .disabled(viewModel.person.contactUnavailable)

                SubtleDivider()

                // TIER 2: Context Zone
                PersonConversationContextCard(viewModel: viewModel)

                SubtleDivider()

                PersonTouchHistorySection(
                    viewModel: viewModel,
                    showFullHistory: $showFullHistory,
                    onEditTouch: { activeSheet = .editTouch($0) },
                    onDeleteTouch: { activeAlert = .deleteConfirm($0) }
                )

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
            CadencePickerSheet(groups: viewModel.cadences, selectedId: viewModel.person.cadenceId,
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
        if let settings = CoreDataAppSettingsRepository(context: CoreDataStack.shared.viewContext).fetch() {
            return settings.breachTimeOfDay.toDate()
        }
        return Date()
    }
}
