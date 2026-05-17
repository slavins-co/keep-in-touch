//
//  PrivacyOverlayManagerTests.swift
//  StayInTouchTests
//
//  Covers the state machine and notification-observer wiring for
//  PrivacyOverlayManager. Window/blur attachment is verified manually
//  on the simulator — UIWindow behaviour is not unit-testable.
//

import XCTest
import UIKit
@testable import StayInTouch

@MainActor
final class PrivacyOverlayManagerTests: XCTestCase {

    private var center: NotificationCenter!
    private var manager: PrivacyOverlayManager!

    override func setUp() {
        super.setUp()
        center = NotificationCenter()
        manager = PrivacyOverlayManager.testInstance(notificationCenter: center)
    }

    override func tearDown() {
        manager = nil
        center = nil
        super.tearDown()
    }

    func test_initialState_isHidden() {
        XCTAssertFalse(manager.isOverlayVisible)
    }

    func test_show_setsOverlayVisible() {
        manager.show()
        XCTAssertTrue(manager.isOverlayVisible)
    }

    func test_hide_clearsOverlayVisible() {
        manager.show()
        manager.hide()
        XCTAssertFalse(manager.isOverlayVisible)
    }

    func test_show_isIdempotent() {
        manager.show()
        manager.show()
        XCTAssertTrue(manager.isOverlayVisible)
    }

    func test_willResignActiveNotification_showsOverlay() {
        manager.start()
        center.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertTrue(manager.isOverlayVisible)
    }

    func test_didBecomeActiveNotification_hidesOverlay() {
        manager.start()
        manager.show()
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertFalse(manager.isOverlayVisible)
    }

    func test_start_isIdempotent() {
        manager.start()
        manager.start()
        center.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertTrue(manager.isOverlayVisible)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertFalse(manager.isOverlayVisible)
    }
}
