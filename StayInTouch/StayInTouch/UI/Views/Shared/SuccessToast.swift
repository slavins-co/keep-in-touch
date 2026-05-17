//
//  SuccessToast.swift
//  KeepInTouch
//

import SwiftUI

/// Transient toast shown after a successful action. Optional `actionTitle`
/// surfaces a chip ("Forgot someone?") that fires `onAction` before
/// dismiss. Auto-dismisses after 5 seconds.
@MainActor
final class SuccessToastManager: ObservableObject {
    static let shared = SuccessToastManager()

    struct Payload: Equatable {
        let id: UUID
        let message: String
        let actionTitle: String?

        init(message: String, actionTitle: String? = nil) {
            self.id = UUID()
            self.message = message
            self.actionTitle = actionTitle
        }
    }

    @Published var current: Payload?

    /// `onAction` is stored alongside the payload so the View can fire it
    /// without making the modifier generic. Cleared on dismiss.
    private var actionHandler: (() -> Void)?

    func show(_ message: String, actionTitle: String? = nil, onAction: (() -> Void)? = nil) {
        let payload = Payload(message: message, actionTitle: actionTitle)
        current = payload
        actionHandler = onAction

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self else { return }
            if self.current?.id == payload.id {
                self.current = nil
                self.actionHandler = nil
            }
        }
    }

    func fireAction() {
        let handler = actionHandler
        current = nil
        actionHandler = nil
        handler?()
    }

    func dismiss() {
        current = nil
        actionHandler = nil
    }
}

struct SuccessToastModifier: ViewModifier {
    @ObservedObject var manager = SuccessToastManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let payload = manager.current {
                    toast(payload: payload)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: manager.current?.id)
    }

    private func toast(payload: SuccessToastManager.Payload) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text(payload.message)
                .font(DS.Typography.metadata)
                .foregroundStyle(.white)
            Spacer()
            if let actionTitle = payload.actionTitle {
                Button {
                    manager.fireAction()
                } label: {
                    Text(actionTitle)
                        .font(DS.Typography.metadata.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionTitle)
            }
            Button {
                manager.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.heroAccentGreen)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

extension View {
    func successToast() -> some View {
        modifier(SuccessToastModifier())
    }
}
