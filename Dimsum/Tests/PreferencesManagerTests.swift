import XCTest
@testable import Dimsum

final class PreferencesManagerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "com.dimsum.test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testDefaultValues() {
        let prefs = PreferencesManager(defaults: defaults)
        XCTAssertEqual(prefs.dimmingIntensity, 0.5, accuracy: 0.001)
        XCTAssertTrue(prefs.isDimmingEnabled)
        XCTAssertFalse(prefs.launchAtLogin)
    }

    func testIntensityPersistence() {
        let prefs = PreferencesManager(defaults: defaults)
        prefs.dimmingIntensity = 0.8
        let prefs2 = PreferencesManager(defaults: defaults)
        XCTAssertEqual(prefs2.dimmingIntensity, 0.8, accuracy: 0.001)
    }

    func testIntensityClampingAboveMax() {
        let prefs = PreferencesManager(defaults: defaults)
        prefs.dimmingIntensity = 1.5
        XCTAssertEqual(prefs.dimmingIntensity, 0.8, accuracy: 0.001)
    }

    func testIntensityClampingBelowMin() {
        let prefs = PreferencesManager(defaults: defaults)
        prefs.dimmingIntensity = -0.3
        XCTAssertEqual(prefs.dimmingIntensity, 0.1, accuracy: 0.001)
    }

    func testEnabledToggle() {
        let prefs = PreferencesManager(defaults: defaults)
        XCTAssertTrue(prefs.isDimmingEnabled)
        prefs.isDimmingEnabled = false
        XCTAssertFalse(prefs.isDimmingEnabled)
        let prefs2 = PreferencesManager(defaults: defaults)
        XCTAssertFalse(prefs2.isDimmingEnabled)
    }

    func testKeyPrefix() {
        let prefs = PreferencesManager(defaults: defaults)
        prefs.dimmingIntensity = 0.7
        let stored = defaults.double(forKey: "dimsum.dimmingIntensity")
        XCTAssertEqual(stored, 0.7, accuracy: 0.001)
    }
}
