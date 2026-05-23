//
//  CoreDataMappingHelpers.swift
//  KeepInTouch
//
//  Shared helpers used by every `*Entity+Mapping.swift` file. Consolidates
//  what was previously duplicated `private func requiredField<T>` bodies
//  across `PersonEntity`, `GroupEntity`, `TagEntity`, and
//  `TouchEventEntity` mappings (see issue #307, audit finding R2).
//

import CoreData

/// Returns `value` if non-nil; otherwise logs a data-corruption warning and
/// returns the fallback. Use when mapping Core Data attributes (which are
/// `Optional` at the codegen layer) to non-optional Domain fields.
///
/// - Parameters:
///   - value: The optional value read from a Core Data entity.
///   - entity: Human-readable entity name for the log message.
///   - field: Attribute name for the log message.
///   - fallback: Value to return when `value` is nil. Evaluated lazily.
func requiredField<T>(
    _ value: T?,
    entity: String,
    field: String,
    fallback: @autoclosure () -> T
) -> T {
    guard let value else {
        AppLogger.logWarning(
            "\(entity) has nil required field '\(field)' — possible data corruption",
            category: AppLogger.coreData
        )
        return fallback()
    }
    return value
}
