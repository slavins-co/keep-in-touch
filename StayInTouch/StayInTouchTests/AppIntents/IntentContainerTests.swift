//
//  IntentContainerTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

@MainActor
final class IntentContainerTests: XCTestCase {
    override func tearDown() {
        IntentContainer.reset()
        super.tearDown()
    }

    func testInstallOverridesCurrent() {
        let personRepo = MockPersonRepository()
        let deps = AppDependencies(
            personRepository: personRepo,
            cadenceRepository: MockCadenceRepository(),
            groupRepository: MockGroupRepository(),
            touchEventRepository: MockTouchEventRepository(),
            settingsRepository: MockSettingsRepository()
        )
        let container = IntentContainer.make(dependencies: deps)
        IntentContainer.install(container)

        XCTAssertTrue(IntentContainer.current.dependencies.personRepository as AnyObject === personRepo as AnyObject)
    }

    func testResetReturnsToShared() {
        let deps = AppDependencies(
            personRepository: MockPersonRepository(),
            cadenceRepository: MockCadenceRepository(),
            groupRepository: MockGroupRepository(),
            touchEventRepository: MockTouchEventRepository(),
            settingsRepository: MockSettingsRepository()
        )
        IntentContainer.install(IntentContainer.make(dependencies: deps))
        XCTAssertNotNil(IntentContainer.current)

        IntentContainer.reset()
        // After reset, current === shared (the default).
        XCTAssertTrue(IntentContainer.current === IntentContainer.shared)
    }

    func testDependenciesAreCachedAfterFirstAccess() {
        let deps = AppDependencies(
            personRepository: MockPersonRepository(),
            cadenceRepository: MockCadenceRepository(),
            groupRepository: MockGroupRepository(),
            touchEventRepository: MockTouchEventRepository(),
            settingsRepository: MockSettingsRepository()
        )
        let container = IntentContainer.make(dependencies: deps)
        let first = container.dependencies
        let second = container.dependencies
        // Same `personRepository` instance pointer on repeated access.
        XCTAssertTrue(first.personRepository as AnyObject === second.personRepository as AnyObject)
    }
}
