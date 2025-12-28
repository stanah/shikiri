import XCTest
@testable import Shikiri

@MainActor
final class SettingsTests: XCTestCase {

    var settings: Settings!

    override func setUp() async throws {
        settings = Settings()
        // テスト用にUserDefaultsをリセット
        settings.resetToDefaults()
    }

    override func tearDown() async throws {
        settings = nil
    }

    // MARK: - Default Values Tests

    func testDefaultIsEnabledIsTrue() {
        XCTAssertTrue(settings.isEnabled)
    }

    func testDefaultShowOverlayAnimationIsTrue() {
        XCTAssertTrue(settings.showOverlayAnimation)
    }

    func testDefaultWindowGapIsZero() {
        XCTAssertEqual(settings.windowGap, 0)
    }

    func testWindowGapBounds() {
        XCTAssertEqual(Settings.minGap, 0)
        XCTAssertEqual(Settings.maxGap, 20)
    }

    // MARK: - Persistence Tests

    func testIsEnabledPersists() {
        settings.isEnabled = false
        XCTAssertFalse(settings.isEnabled)

        // 新しいインスタンスを作成して確認
        let newSettings = Settings()
        XCTAssertFalse(newSettings.isEnabled)
    }

    func testShowOverlayAnimationPersists() {
        settings.showOverlayAnimation = false
        XCTAssertFalse(settings.showOverlayAnimation)

        // 新しいインスタンスを作成して確認
        let newSettings = Settings()
        XCTAssertFalse(newSettings.showOverlayAnimation)
    }

    // MARK: - Reset Tests

    func testResetToDefaultsRestoresAllDefaults() {
        settings.isEnabled = false
        settings.showOverlayAnimation = false
        settings.windowGap = 10

        settings.resetToDefaults()

        XCTAssertTrue(settings.isEnabled)
        XCTAssertTrue(settings.showOverlayAnimation)
        XCTAssertEqual(settings.windowGap, 0)
    }

    func testWindowGapPersists() {
        settings.windowGap = 15
        XCTAssertEqual(settings.windowGap, 15)

        // 新しいインスタンスを作成して確認
        let newSettings = Settings()
        XCTAssertEqual(newSettings.windowGap, 15)
    }
}
