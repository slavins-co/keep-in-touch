//
//  DefaultDataSeederTests.swift
//  KeepInTouchTests
//
//  Created by Codex on 2/2/26.
//

import XCTest
@testable import StayInTouch

final class DefaultDataSeederTests: XCTestCase {
    func testSeedCreatesDefaultGroupsTagsAndSettings() throws {
        let testStack = CoreDataTestStack()
        let context = testStack.container.viewContext

        let seeder = DefaultDataSeeder(context: context)
        try seeder.seedIfNeeded()

        let groupRepo = CoreDataGroupRepository(context: context)
        let tagRepo = CoreDataTagRepository(context: context)
        let settingsRepo = CoreDataAppSettingsRepository(context: context)

        let groups = groupRepo.fetchAll()
        let tags = tagRepo.fetchAll()
        let settings = settingsRepo.fetch()

        XCTAssertEqual(groups.count, 4)
        XCTAssertEqual(tags.count, 4)
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings?.id, AppSettings.singletonId)
    }
}
