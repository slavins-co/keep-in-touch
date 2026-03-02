//
//  ErrorToast.swift
//  KeepInTouch
//
//  Created by Claude on 2/24/26.
//

import SwiftUI

@MainActor
final class ErrorToastManager: ObservableObject {
    static let shared = ErrorToastManager()

    @Published var currentError: AppError?

    func show(_ error: AppError) {
        currentError = error
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if currentError?.id == error.id {
                currentError = nil
            }
        }
    }

    func dismiss() {
        currentError = nil
    }
}

struct AppError: Identifiable {
    let id = UUID()
    let message: String

    static func saveFailed(_ context: String) -> AppError {
        AppError(message: "Couldn't save changes. Please try again.")
    }

    static func deleteFailed(_ context: String) -> AppError {
        AppError(message: "Couldn't delete. Please try again.")
    }

    static func loadFailed(_ context: String) -> AppError {
        AppError(message: "Couldn't load data.")
    }
}

struct ErrorToastModifier: ViewModifier {
    @ObservedObject var manager = ErrorToastManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let error = manager.currentError {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        Text(error.message)
                            .font(DS.Typography.metadata)
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            manager.dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.destructive)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: manager.currentError?.id)
                }
            }
    }
}

extension View {
    func errorToast() -> some View {
        modifier(ErrorToastModifier())
    }
}
