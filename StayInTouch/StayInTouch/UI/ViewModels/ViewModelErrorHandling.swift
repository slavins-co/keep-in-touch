//
//  ViewModelErrorHandling.swift
//  KeepInTouch
//
//  Created by Claude Code on 5/27/26.
//

import Foundation

/// Marker protocol for view models that route repository write/delete
/// failures through the standard log + error-toast path.
///
/// The two helpers below collapse the ~16 near-identical catch blocks that
/// previously lived inline in each view model. Behavior is preserved exactly:
/// same `AppLogger` category + context strings, same `ErrorToastManager.shared`
/// toasts. Conformers gain the helpers for free via the extension; the protocol
/// itself carries no requirements because every call site already reaches the
/// toast manager through its `.shared` singleton.
///
/// `@MainActor` because both helpers touch `ErrorToastManager.shared`, which is
/// main-actor isolated. All conforming view models are already `@MainActor`.
@MainActor
protocol ViewModelErrorHandling {}

extension ViewModelErrorHandling {
    /// Runs `block`, routing a thrown error through the standard log + toast
    /// path. Mirrors the original two-branch catch:
    ///
    /// - `RepositoryError`: logged under `context`, toast shows the error's
    ///   own `userMessage`.
    /// - any other error: logged under `"\(context) (unexpected)"`, toast
    ///   shows the supplied `fallback` (e.g. `.saveFailed` / `.deleteFailed`).
    ///
    /// Returns the block's result, or `nil` on failure. Discard the result for
    /// `Void`-returning blocks — control still returns to the caller so any
    /// post-catch work (state updates, reloads, notifications) runs exactly as
    /// it did before.
    @discardableResult
    func handleRepositoryWrite<T>(
        _ context: String,
        fallback: AppError,
        _ block: () throws -> T
    ) -> T? {
        do {
            return try block()
        } catch let error as RepositoryError {
            AppLogger.logError(error, category: AppLogger.viewModel, context: context)
            ErrorToastManager.shared.show(AppError(message: error.userMessage))
            return nil
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: "\(context) (unexpected)")
            ErrorToastManager.shared.show(fallback)
            return nil
        }
    }

    /// Runs `block`, routing any thrown error through a single log + toast
    /// path (no typed `RepositoryError` branch). Mirrors the call sites that
    /// used one untyped `catch`: logged under `context`, toast shows
    /// `fallback`.
    ///
    /// Returns the block's result, or `nil` on failure.
    @discardableResult
    func handleWrite<T>(
        _ context: String,
        fallback: AppError,
        _ block: () throws -> T
    ) -> T? {
        do {
            return try block()
        } catch {
            AppLogger.logError(error, category: AppLogger.viewModel, context: context)
            ErrorToastManager.shared.show(fallback)
            return nil
        }
    }
}
