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
                actionCard(icon: "envelope.fill", label: "Email", enabled: hasEmail) { onQuickAction(.email) }
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

    /// Call card: tap = phone (always), long-press = menu with FaceTime when available.
    /// No persistent preference, no badge — single-tap behavior is unchanged.
    /// Menu is suppressed in preview mode to keep the tutorial walkthrough deterministic.
    @ViewBuilder
    private var callActionCard: some View {
        actionCard(icon: "phone.fill", label: "Call", enabled: hasPhone) {
            onQuickAction(.call)
        }
        .contextMenu {
            if hasPhone && viewModel.isFaceTimeAvailable && !viewModel.isPreview {
                Button {
                    onFaceTime()
                } label: {
                    Label("FaceTime", systemImage: "video.fill")
                }
            }
        }
    }

    /// Message card: tap = resolved messenger (sticky or iMessage), long-press = picker.
    /// Shows a small badge when the resolved messenger is not iMessage.
    /// Menu is suppressed in preview mode to keep the tutorial walkthrough deterministic.
    /// Accessibility hint is messenger-specific (avoids the ungrammatical
    /// "WhatsApps this contact" that the generic actionCard formula produces).
    @ViewBuilder
    private var messageActionCard: some View {
        let resolved = viewModel.resolvedMessenger
        let label = resolved == .iMessage ? "Message" : resolved.displayName
        let badgeVisible = viewModel.person.preferredMessenger != nil

        actionCard(
            icon: "message.fill",
            label: label,
            enabled: hasPhone,
            badgeVisible: badgeVisible,
            hintOverride: resolved.actionHint
        ) {
            onQuickAction(.message)
        }
        .contextMenu {
            if messengerOptions.count > 1 && !viewModel.isPreview {
                ForEach(messengerOptions, id: \.self) { messenger in
                    Button {
                        onMessageWith(messenger)
                    } label: {
                        Label(messenger.displayName, systemImage: messenger.iconName)
                    }
                }
            }
        }
    }

    private func actionCard(
        icon: String,
        label: String,
        enabled: Bool,
        badgeVisible: Bool = false,
        hintOverride: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
        .buttonStyle(ActionCardButtonStyle())
        .accessibilityLabel(enabled ? label : "\(label), unavailable")
        .accessibilityHint(enabled
            ? (hintOverride ?? "\(label)s this contact")
            : "No \(label == "Email" ? "email address" : "phone number") on file")
        .disabled(!enabled)
        .opacity(!enabled && !viewModel.person.contactUnavailable ? 0.5 : 1.0)
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
