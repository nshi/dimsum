import XCTest
@testable import Dimsum

final class AppearanceAwareTests: XCTestCase {
    func testLightModeBoostsIntensity() {
        let result = adaptedIntensity(base: 0.5, isDarkMode: false)
        XCTAssertEqual(result, 0.57, accuracy: 1e-10)
    }

    func testDarkModeReducesIntensity() {
        let result = adaptedIntensity(base: 0.5, isDarkMode: true)
        XCTAssertEqual(result, 0.43, accuracy: 1e-10)
    }

    func testClampsAtMaxInLightMode() {
        let result = adaptedIntensity(base: 0.8, isDarkMode: false)
        XCTAssertEqual(result, 0.8, accuracy: 1e-10)
    }

    func testClampsAtMinInDarkMode() {
        let result = adaptedIntensity(base: 0.1, isDarkMode: true)
        XCTAssertEqual(result, 0.1, accuracy: 1e-10)
    }

    func testMidpointLightMode() {
        let result = adaptedIntensity(base: 0.4, isDarkMode: false)
        XCTAssertEqual(result, 0.47, accuracy: 1e-10)
    }

    func testMidpointDarkMode() {
        let result = adaptedIntensity(base: 0.4, isDarkMode: true)
        XCTAssertEqual(result, 0.33, accuracy: 1e-10)
    }

    func testBoundaryMinLightMode() {
        let result = adaptedIntensity(base: 0.1, isDarkMode: false)
        XCTAssertEqual(result, 0.17, accuracy: 1e-10)
    }

    func testBoundaryMaxDarkMode() {
        let result = adaptedIntensity(base: 0.8, isDarkMode: true)
        XCTAssertEqual(result, 0.73, accuracy: 1e-10)
    }
}
