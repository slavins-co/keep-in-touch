//
//  BrandColorsTests.swift
//  StayInTouchTests
//
//  Locks in the brand hex string shared between the app's DesignSystem
//  and the widget. Accidental edits to the hex constant should surface
//  as a test failure rather than a silent visual drift.
//

import XCTest
import SwiftUI
@testable import StayInTouch

final class BrandColorsTests: XCTestCase {

    func test_heroAccentGreenHex_isBrandValue() {
        XCTAssertEqual(BrandColors.heroAccentGreenHex, "3D6B4F")
    }

    func test_heroAccentGreen_resolvesFromSharedHex() {
        // BrandColors.heroAccentGreen must be built from the shared hex
        // constant, not a parallel literal. Comparing Color values
        // directly via `==` is reliable for constants created through
        // the same initializer path.
        XCTAssertEqual(BrandColors.heroAccentGreen, Color(hex: BrandColors.heroAccentGreenHex))
    }
}
