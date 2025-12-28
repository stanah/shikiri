import XCTest
import SwiftUI
@testable import Shikiri

@MainActor
final class AccessibilityPermissionViewTests: XCTestCase {
    var mockWrapper: MockAXWrapper!
    var accessibilityManager: AccessibilityManager!

    override func setUp() async throws {
        try await super.setUp()
        mockWrapper = MockAXWrapper()
        accessibilityManager = AccessibilityManager(axWrapper: mockWrapper)
    }

    override func tearDown() async throws {
        accessibilityManager = nil
        mockWrapper = nil
        try await super.tearDown()
    }

    func testAccessibilityPermissionView_Builds() {
        // View builds without crashing
        _ = AccessibilityPermissionView(accessibilityManager: accessibilityManager).body
    }

    func testAccessibilityPermissionView_ShowsRequestButton_WhenNotEnabled() {
        // Given
        mockWrapper.isProcessTrustedReturnValue = false
        accessibilityManager.checkAccessibility()

        // Then - View should build and show appropriate UI
        // (Full UI testing would require ViewInspector or similar)
        XCTAssertFalse(accessibilityManager.isAccessibilityEnabled)
    }
}
