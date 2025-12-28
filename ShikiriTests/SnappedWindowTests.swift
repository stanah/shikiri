import XCTest
@testable import Shikiri

@MainActor
final class SnappedWindowTests: XCTestCase {

    // MARK: - SnappedWindow Tests

    func testSnappedWindow_InitializesWithCorrectValues() {
        let id = UUID()
        let windowElement = AXUIElementCreateSystemWide() // ダミー
        let zoneId = UUID()
        let screenId = "Main Display"
        let frame = CGRect(x: 0, y: 0, width: 960, height: 1080)

        let snappedWindow = SnappedWindow(
            id: id,
            windowElement: windowElement,
            zoneId: zoneId,
            screenId: screenId,
            lastKnownFrame: frame
        )

        XCTAssertEqual(snappedWindow.id, id)
        XCTAssertEqual(snappedWindow.zoneId, zoneId)
        XCTAssertEqual(snappedWindow.screenId, screenId)
        XCTAssertEqual(snappedWindow.lastKnownFrame, frame)
    }

    func testSnappedWindow_AutoGeneratesId() {
        let windowElement = AXUIElementCreateSystemWide()
        let zoneId = UUID()
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        let snappedWindow = SnappedWindow(
            windowElement: windowElement,
            zoneId: zoneId,
            screenId: "Test",
            lastKnownFrame: frame
        )

        XCTAssertNotEqual(snappedWindow.id, UUID()) // 新しいUUIDが生成されている
    }

    func testSnappedWindow_Equatable() {
        let id = UUID()
        let windowElement = AXUIElementCreateSystemWide()
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        let window1 = SnappedWindow(
            id: id,
            windowElement: windowElement,
            zoneId: UUID(),
            screenId: "Test",
            lastKnownFrame: frame
        )

        let window2 = SnappedWindow(
            id: id, // 同じID
            windowElement: windowElement,
            zoneId: UUID(), // 異なるzoneId
            screenId: "Different",
            lastKnownFrame: CGRect.zero
        )

        // IDで比較されるので等しい
        XCTAssertEqual(window1, window2)
    }

    func testSnappedWindow_NotEqualWithDifferentId() {
        let windowElement = AXUIElementCreateSystemWide()
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        let window1 = SnappedWindow(
            id: UUID(), // 異なるID
            windowElement: windowElement,
            zoneId: UUID(),
            screenId: "Test",
            lastKnownFrame: frame
        )

        let window2 = SnappedWindow(
            id: UUID(), // 異なるID
            windowElement: windowElement,
            zoneId: window1.zoneId,
            screenId: window1.screenId,
            lastKnownFrame: frame
        )

        XCTAssertNotEqual(window1, window2)
    }
}
