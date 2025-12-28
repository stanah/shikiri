import XCTest
import ApplicationServices
@testable import Shikiri

// MARK: - Mock AX Wrapper for Testing
final class MockAXWrapperForWindow: AXWrapperProtocol, @unchecked Sendable {
    private var _isProcessTrustedReturnValue = true
    private var _requestAccessibilityCalled = false

    var isProcessTrustedReturnValue: Bool {
        get { _isProcessTrustedReturnValue }
        set { _isProcessTrustedReturnValue = newValue }
    }

    var requestAccessibilityCalled: Bool {
        get { _requestAccessibilityCalled }
        set { _requestAccessibilityCalled = newValue }
    }

    func isProcessTrusted() -> Bool {
        return _isProcessTrustedReturnValue
    }

    func requestAccessibility() {
        _requestAccessibilityCalled = true
    }
}

// MARK: - WindowController Tests
@MainActor
final class WindowControllerTests: XCTestCase {

    var sut: WindowController!
    var mockAXWrapper: MockAXWrapperForWindow!

    override func setUp() async throws {
        try await super.setUp()
        mockAXWrapper = MockAXWrapperForWindow()
        sut = WindowController(axWrapper: mockAXWrapper)
    }

    override func tearDown() async throws {
        sut = nil
        mockAXWrapper = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testWindowController_Initializes() {
        XCTAssertNotNil(sut)
    }

    // MARK: - Error Type Tests

    func testWindowOperationError_HasExpectedCases() {
        let permissionError = WindowOperationError.accessibilityPermissionDenied
        let notFoundError = WindowOperationError.windowNotFound
        let positionError = WindowOperationError.cannotGetPosition
        let sizeError = WindowOperationError.cannotGetSize
        let setFrameError = WindowOperationError.cannotSetFrame(reason: "test")

        XCTAssertEqual(permissionError.localizedDescription.isEmpty, false)
        XCTAssertEqual(notFoundError.localizedDescription.isEmpty, false)
        XCTAssertEqual(positionError.localizedDescription.isEmpty, false)
        XCTAssertEqual(sizeError.localizedDescription.isEmpty, false)
        XCTAssertEqual(setFrameError.localizedDescription.isEmpty, false)
    }

    // MARK: - Permission Check Tests

    func testWindowController_ChecksAccessibilityPermission() {
        mockAXWrapper.isProcessTrustedReturnValue = false

        // アクセシビリティ権限がない場合、操作は失敗するべき
        XCTAssertFalse(sut.hasAccessibilityPermission)
    }

    func testWindowController_HasAccessibilityPermissionWhenTrusted() {
        mockAXWrapper.isProcessTrustedReturnValue = true

        XCTAssertTrue(sut.hasAccessibilityPermission)
    }

    // MARK: - Coordinate Conversion Tests

    func testWindowController_ConvertsNSScreenToAXCoordinates() {
        // NSScreen座標系: 左下原点
        // AX座標系: 左上原点
        let screenHeight: CGFloat = 1080
        let nsPoint = NSPoint(x: 100, y: 200) // 左下から200上

        let axPoint = sut.convertToAXCoordinates(point: nsPoint, screenHeight: screenHeight)

        // AX座標では左上から880下（1080 - 200 = 880）
        XCTAssertEqual(axPoint.x, 100)
        XCTAssertEqual(axPoint.y, 880)
    }

    func testWindowController_ConvertsAXToNSScreenCoordinates() {
        let screenHeight: CGFloat = 1080
        let axPoint = CGPoint(x: 100, y: 880) // 左上から880下

        let nsPoint = sut.convertFromAXCoordinates(point: axPoint, screenHeight: screenHeight)

        // NSScreen座標では左下から200上
        XCTAssertEqual(nsPoint.x, 100)
        XCTAssertEqual(nsPoint.y, 200)
    }

    func testWindowController_CoordinateConversionIsReversible() {
        let screenHeight: CGFloat = 1080
        let originalPoint = NSPoint(x: 500, y: 300)

        let axPoint = sut.convertToAXCoordinates(point: originalPoint, screenHeight: screenHeight)
        let convertedBack = sut.convertFromAXCoordinates(point: axPoint, screenHeight: screenHeight)

        XCTAssertEqual(convertedBack.x, originalPoint.x, accuracy: 0.001)
        XCTAssertEqual(convertedBack.y, originalPoint.y, accuracy: 0.001)
    }
}
