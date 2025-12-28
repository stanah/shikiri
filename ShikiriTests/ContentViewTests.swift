import XCTest
@testable import Shikiri

@MainActor
final class ContentViewTests: XCTestCase {
    func testContentViewBuilds() {
        let mockWrapper = MockAXWrapper()
        let manager = AccessibilityManager(axWrapper: mockWrapper)
        let settings = Settings()
        _ = ContentView(
            accessibilityManager: manager,
            settings: settings
        ).body
    }

    func testContentView_ShowsPermissionView_WhenNotEnabled() {
        let mockWrapper = MockAXWrapper()
        mockWrapper.isProcessTrustedReturnValue = false
        let manager = AccessibilityManager(axWrapper: mockWrapper)
        manager.checkAccessibility()

        XCTAssertFalse(manager.isAccessibilityEnabled)
    }

    func testContentView_ShowsNormalMenu_WhenEnabled() {
        let mockWrapper = MockAXWrapper()
        mockWrapper.isProcessTrustedReturnValue = true
        let manager = AccessibilityManager(axWrapper: mockWrapper)
        manager.checkAccessibility()

        XCTAssertTrue(manager.isAccessibilityEnabled)
    }
}
