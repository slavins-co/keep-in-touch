//
//  PersonQuickActionsBar.swift
//  KeepInTouch
//

import SwiftUI

struct PersonQuickActionsBar: View {
    @ObservedObject var viewModel: PersonDetailViewModel
    var onQuickAction: (QuickActionType) -> Void
    var onMessageWith: (PreferredMessenger) -> Void
    var onFaceTime: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                messageActionCard
                callActionCard
                emailActionCard
            }

            if let message = viewModel.quickActionMessage {
                Text(message)
                    .font(DS.Typography.metadata)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Private

    private var hasPhone: Bool {
        viewModel.phone != nil || !viewModel.phoneNumbers.isEmpty
    }

    private var hasEmail: Bool {
        viewModel.email != nil || !viewModel.emailAddresses.isEmpty
    }

    private var messengerOptions: [PreferredMessenger] {
        viewModel.availableMessengers
    }

    // MARK: - Email card (plain button, no menu)

    private var emailActionCard: some View {
        actionCardButton(
            icon: "envelope.fill",
            label: "Email",
            enabled: hasEmail,
            hint: "Emails this contact",
            disabledHint: "No email address on file"
        ) {
            onQuickAction(.email)
        }
    }

    // MARK: - Call card — tap dials, long-press shows FaceTime
    //
    // Uses `Menu(content:label:primaryAction:)` — Apple's documented pattern
    // for "tap performs primary action, long-press shows menu." This bypasses
    // the SwiftUI quirk where `.contextMenu` on a Button with a custom
    // ButtonStyle has unreliable long-press recognition.

    @ViewBuilder
    private var callActionCard: some View {
        Menu {
            if hasPhone && !viewModel.isPreview {
                Button {
                    onQuickAction(.call)
                } label: {
                    Label("Phone", systemImage: "phone.fill")
                }
                Button {
                    onFaceTime()
                } label: {
                    Label("FaceTime", systemImage: "video.fill")
                }
            }
        } label: {
            actionCardLabel(icon: "phone.fill", label: "Call", badgeVisible: false)
        } primaryAction: {
            onQuickAction(.call)
        }
        .disabled(!hasPhone)
        .opacity(!hasPhone && !viewModel.person.contactUnavailable ? 0.5 : 1.0)
        .accessibilityLabel(hasPhone ? "Call" : "Call, unavailable")
        .accessibilityHint(hasPhone ? "Calls this contact" : "No phone number on file")
    }

    // MARK: - Message card — tap routes via resolved messenger, long-press picks one
    //
    // Same Menu(primaryAction:) pattern. Badge indicates a sticky preference.
    // Accessibility hint is messenger-specific (avoids "WhatsApps this contact").

    @ViewBuilder
    private var messageActionCard: some View {
        let resolved = viewModel.resolvedMessenger
        let label = resolved == .iMessage ? "Message" : resolved.displayName
        let badgeVisible = viewModel.person.preferredMessenger != nil

        Menu {
            if !viewModel.isPreview {
                ForEach(messengerOptions, id: \.self) { messenger in
                    Button {
                        onMessageWith(messenger)
                    } label: {
                        Label(messenger.displayName, systemImage: messenger.iconName)
                    }
                }
            }
        } label: {
            actionCardLabel(icon: "message.fill", label: label, badgeVisible: badgeVisible)
        } primaryAction: {
            onQuickAction(.message)
        }
        .disabled(!hasPhone)
        .opacity(!hasPhone && !viewModel.person.contactUnavailable ? 0.5 : 1.0)
        .accessibilityLabel(hasPhone ? label : "\(label), unavailable")
        .accessibilityHint(hasPhone ? resolved.actionHint : "No phone number on file")
    }

    // MARK: - Action card primitives

    /// Plain Button-based action card (used by Email which has no menu).
    private func actionCardButton(
        icon: String,
        label: String,
        enabled: Bool,
        hint: String,
        disabledHint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionCardLabel(icon: icon, label: label, badgeVisible: false)
        }
        .buttonStyle(ActionCardButtonStyle())
        .accessibilityLabel(enabled ? label : "\(label), unavailable")
        .accessibilityHint(enabled ? hint : disabledHint)
        .disabled(!enabled)
        .opacity(!enabled && !viewModel.person.contactUnavailable ? 0.5 : 1.0)
    }

    /// Visual presentation of the card (icon + optional badge + label).
    /// Used as either a Button's content (Email) or a Menu's label (Call, Message).
    private func actionCardLabel(
        icon: String,
        label: String,
        badgeVisible: Bool
    ) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.actionButtonIconCircleOpacity)
                    .clipShape(Circle())
                if badgeVisible {
                    Circle()
                        .fill(DS.Colors.accent)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(DS.Colors.actionButtonBackground, lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                        .accessibilityHidden(true)
                }
            }
            Text(label)
                .font(DS.Typography.contactCardMeta)
                .foregroundStyle(.white)
                .lineLimit(1)
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
}

// MARK: - Action Card Button Style

struct ActionCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
