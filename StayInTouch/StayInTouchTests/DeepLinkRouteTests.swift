//
//  DeepLinkRouteTests.swift
//  KeepInTouchTests
//
//  Contract tests for the widget <-> app URL scheme. The widget constructs
//  URLs via `url()`, the app parses them via `init?(url:)`. Round-trip
//  parity is what makes the scheme safe to evolve.
//

import XCTest
@testable import StayInTouch

final class DeepLinkRouteTests: XCTestCase {

    func test_parse_overdue() {
        let url = URL(string: "keepintouch://overdue")!
        XCTAssertEqual(DeepLinkRoute(url: url), .overdue)
    }

    func test_parse_person_withUUID() {
        let id = UUID()
        let url = URL(string: "keepintouch://person/\(id.uuidString)")!
        XCTAssertEqual(DeepLinkRoute(url: url), .person(id))
    }

    func test_parse_rejectsForeignScheme() {
        let url = URL(string: "https://keepintouch/overdue")!
        XCTAssertNil(DeepLinkRoute(url: url))
    }

    func test_parse_rejectsUnknownHost() {
        let url = URL(string: "keepintouch://settings")!
        XCTAssertNil(DeepLinkRoute(url: url))
    }

    func test_parse_rejectsPersonWithoutUUID() {
        let url = URL(string: "keepintouch://person/not-a-uuid")!
        XCTAssertNil(DeepLinkRoute(url: url))
    }

    func test_parse_rejectsPersonWithoutID() {
        let url = URL(string: "keepintouch://person")!
        XCTAssertNil(DeepLinkRoute(url: url))
    }

    func test_parse_rejectsExtraPathComponents() {
        let id = UUID()
        let url = URL(string: "keepintouch://person/\(id.uuidString)/extra")!
        XCTAssertNil(DeepLinkRoute(url: url))
    }

    func test_url_overdue() {
        XCTAssertEqual(
            DeepLinkRoute.overdue.url().absoluteString,
            "keepintouch://overdue"
        )
    }

    func test_url_person() {
        let id = UUID()
        XCTAssertEqual(
            DeepLinkRoute.person(id).url().absoluteString,
            "keepintouch://person/\(id.uuidString)"
        )
    }

    func test_roundTrip_overdue() {
        let route = DeepLinkRoute.overdue
        XCTAssertEqual(DeepLinkRoute(url: route.url()), route)
    }

    func test_roundTrip_person() {
        let route = DeepLinkRoute.person(UUID())
        XCTAssertEqual(DeepLinkRoute(url: route.url()), route)
    }

    // MARK: - Router integration

    @MainActor
    func test_router_handleURL_overdueSetsHomeDestination() {
        let router = DeepLinkRouter.shared
        router.pending = nil

        let handled = router.handleURL(URL(string: "keepintouch://overdue")!)

        XCTAssertTrue(handled)
        XCTAssertEqual(router.pending, .home)
    }

    @MainActor
    func test_router_handleURL_personSetsPersonDestination() {
        let router = DeepLinkRouter.shared
        router.pending = nil
        let id = UUID()

        let handled = router.handleURL(URL(string: "keepintouch://person/\(id.uuidString)")!)

        XCTAssertTrue(handled)
        XCTAssertEqual(router.pending, .person(id))
    }

    @MainActor
    func test_router_handleURL_unknownReturnsFalseAndLeavesPendingNil() {
        let router = DeepLinkRouter.shared
        router.pending = nil

        let handled = router.handleURL(URL(string: "https://example.com")!)

        XCTAssertFalse(handled)
        XCTAssertNil(router.pending)
    }
}
