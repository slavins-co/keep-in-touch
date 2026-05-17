//
//  SelectionCoordinatorTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

@MainActor
final class SelectionCoordinatorTests: XCTestCase {

    func testInitialStateIsIdle() {
        let sut = SelectionCoordinator()
        XCTAssertFalse(sut.isSelectMode)
        XCTAssertTrue(sut.selection.isEmpty)
        XCTAssertFalse(sut.hasSelection)
        XCTAssertEqual(sut.count, 0)
    }

    func testEnterWithoutPreselectIsEmpty() {
        let sut = SelectionCoordinator()
        sut.enter(origin: .home)
        XCTAssertTrue(sut.isSelectMode)
        XCTAssertEqual(sut.origin, .home)
        XCTAssertTrue(sut.selection.isEmpty)
    }

    func testEnterWithPreselectAddsThatPerson() {
        let sut = SelectionCoordinator()
        let id = UUID()
        sut.enter(origin: .people, preselect: id)
        XCTAssertTrue(sut.isSelectMode)
        XCTAssertEqual(sut.origin, .people)
        XCTAssertEqual(sut.selection, [id])
    }

    func testToggleAddsAndRemoves() {
        let sut = SelectionCoordinator()
        let a = UUID()
        sut.enter(origin: .home)
        sut.toggle(a)
        XCTAssertTrue(sut.contains(a))
        sut.toggle(a)
        XCTAssertFalse(sut.contains(a))
    }

    func testSetSelectionReplacesEntire() {
        let sut = SelectionCoordinator()
        let a = UUID(), b = UUID(), c = UUID()
        sut.enter(origin: .home, preselect: a)
        sut.setSelection([b, c])
        XCTAssertFalse(sut.contains(a))
        XCTAssertTrue(sut.contains(b))
        XCTAssertTrue(sut.contains(c))
        XCTAssertEqual(sut.count, 2)
    }

    func testRemoveTakesOutOneSelection() {
        let sut = SelectionCoordinator()
        let a = UUID(), b = UUID()
        sut.enter(origin: .home)
        sut.toggle(a)
        sut.toggle(b)
        sut.remove(a)
        XCTAssertEqual(sut.selection, [b])
    }

    func testExitClearsModeAndSelection() {
        let sut = SelectionCoordinator()
        sut.enter(origin: .home, preselect: UUID())
        sut.toggle(UUID())
        sut.exit()
        XCTAssertFalse(sut.isSelectMode)
        XCTAssertTrue(sut.selection.isEmpty)
    }
}
