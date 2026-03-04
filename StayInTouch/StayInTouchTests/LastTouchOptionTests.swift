//
//  LastTouchOptionTests.swift
//  KeepInTouchTests
//

import XCTest
@testable import StayInTouch

final class LastTouchOptionTests: XCTestCase {
    private let referenceDate = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 3))!

    func testThisWeekReturnsThreeDaysAgo() {
        let date = LastTouchOption.thisWeek.approximateDate(from: referenceDate)
        let expected = Calendar.current.date(byAdding: .day, value: -3, to: referenceDate)
        XCTAssertEqual(date, expected)
    }

    func testWithinTwoWeeksReturnsTenDaysAgo() {
        let date = LastTouchOption.withinTwoWeeks.approximateDate(from: referenceDate)
        let expected = Calendar.current.date(byAdding: .day, value: -10, to: referenceDate)
        XCTAssertEqual(date, expected)
    }

    func testThisMonthReturnsTwentyOneDaysAgo() {
        let date = LastTouchOption.thisMonth.approximateDate(from: referenceDate)
        let expected = Calendar.current.date(byAdding: .day, value: -21, to: referenceDate)
        XCTAssertEqual(date, expected)
    }

    func testFewMonthsAgoReturnsTwoMonthsAgo() {
        let date = LastTouchOption.fewMonthsAgo.approximateDate(from: referenceDate)
        let expected = Calendar.current.date(byAdding: .month, value: -2, to: referenceDate)
        XCTAssertEqual(date, expected)
    }

    func testSixPlusMonthsReturnsSixMonthsAgo() {
        let date = LastTouchOption.sixPlusMonths.approximateDate(from: referenceDate)
        let expected = Calendar.current.date(byAdding: .month, value: -6, to: referenceDate)
        XCTAssertEqual(date, expected)
    }

    func testCantRememberReturnsNil() {
        let date = LastTouchOption.cantRemember.approximateDate(from: referenceDate)
        XCTAssertNil(date)
    }

    func testAllOptionsReturnPastDates() {
        let now = Date()
        for option in LastTouchOption.allCases {
            if let date = option.approximateDate(from: now) {
                XCTAssertLessThan(date, now, "\(option.rawValue) should return a past date")
            }
        }
    }

    func testAllCasesCount() {
        XCTAssertEqual(LastTouchOption.allCases.count, 6)
    }
}
