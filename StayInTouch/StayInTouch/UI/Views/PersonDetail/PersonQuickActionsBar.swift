//
//  PersonQuickActionsBar.swift
//  KeepInTouch
//

import SwiftUI

struct PersonQuickActionsBar: View {
    @ObservedObject var viewModel: PersonDetailViewModel
    var onQuickAction: (QuickActionType) -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                actionCard(icon: "message.fill", label: "Message", enabled: hasPhone) { onQuickAction(.message) }
                actionCard(icon: "phone.fill", label: "Call", enabled: hasPhone) { onQuickAction(.call) }
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
        .accessibilityLabel(enabled ? label : "\(label), unavailable")
        .accessibilityHint(enabled ? "\(label)s this contact" : "No \(label == "Email" ? "email address" : "phone number") on file")
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
