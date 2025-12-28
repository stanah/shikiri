import XCTest
@testable import Shikiri

// MARK: - Mock for testing
final class MockAXWrapper: AXWrapperProtocol, @unchecked Sendable {
    var isProcessTrustedReturnValue = false
    var requestAccessibilityCalled = false

    func isProcessTrusted() -> Bool {
        return isProcessTrustedReturnValue
    }

    func requestAccessibility() {
        requestAccessibilityCalled = true
    }
}

// MARK: - Tests
@MainActor
final class AccessibilityManagerTests: XCTestCase {
    var sut: AccessibilityManager!
    var mockWrapper: MockAXWrapper!

    override func setUp() async throws {
        try await super.setUp()
        mockWrapper = MockAXWrapper()
        sut = AccessibilityManager(axWrapper: mockWrapper)
    }

    override func tearDown() async throws {
        sut = nil
        mockWrapper = nil
        try await super.tearDown()
    }

    // MARK: - checkAccessibility Tests

    func testCheckAccessibility_WhenTrusted_ReturnsTrue() {
        // Given
        mockWrapper.isProcessTrustedReturnValue = true

        // When
        let result = sut.checkAccessibility()

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(sut.isAccessibilityEnabled)
    }

    func testCheckAccessibility_WhenNotTrusted_ReturnsFalse() {
        // Given
        mockWrapper.isProcessTrustedReturnValue = false

        // When
        let result = sut.checkAccessibility()

        // Then
        XCTAssertFalse(result)
        XCTAssertFalse(sut.isAccessibilityEnabled)
    }

    // MARK: - requestAccessibility Tests

    func testRequestAccessibility_CallsWrapper() {
        // When
        sut.requestAccessibility()

        // Then
        XCTAssertTrue(mockWrapper.requestAccessibilityCalled)
    }

    // MARK: - Polling Tests

    func testStartPolling_UpdatesStatusWhenPermissionChanges() async throws {
        // Given
        mockWrapper.isProcessTrustedReturnValue = false
        sut.checkAccessibility()
        XCTAssertFalse(sut.isAccessibilityEnabled)

        // When - 権限が変わった
        mockWrapper.isProcessTrustedReturnValue = true
        sut.startPolling(interval: 0.1)

        // Then - 少し待ってからチェック
        try await Task.sleep(for: .milliseconds(200))
        sut.stopPolling()

        XCTAssertTrue(sut.isAccessibilityEnabled)
    }

    func testStopPolling_StopsUpdatingStatus() async throws {
        // Given
        mockWrapper.isProcessTrustedReturnValue = false
        sut.startPolling(interval: 0.1)

        // When
        sut.stopPolling()

        // Then - 権限を変えてもステータスは更新されない
        mockWrapper.isProcessTrustedReturnValue = true
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertFalse(sut.isAccessibilityEnabled)
    }
}
