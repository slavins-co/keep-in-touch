//
//  DefaultDataSeederTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import XCTest
@testable import StayInTouch

final class DefaultDataSeederTests: XCTestCase {
    func testSeedCreatesDefaultCadencesGroupsAndSettings() throws {
        let testStack = CoreDataTestStack()
        let context = testStack.container.viewContext

        let seeder = DefaultDataSeeder(context: context)
        try seeder.seedIfNeeded()

        let cadenceRepo = CoreDataCadenceRepository(context: context)
        let groupRepo = CoreDataGroupRepository(context: context)
        let settingsRepo = CoreDataAppSettingsRepository(context: context)

        let cadences = cadenceRepo.fetchAll()
        let groups = groupRepo.fetchAll()
        let settings = settingsRepo.fetch()

        XCTAssertEqual(cadences.count, 4)
        XCTAssertEqual(groups.count, 4)
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings?.id, AppSettings.singletonId)
    }
}
