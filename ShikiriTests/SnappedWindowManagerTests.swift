import XCTest
@testable import Shikiri

@MainActor
final class SnappedWindowManagerTests: XCTestCase {

    var manager: SnappedWindowManager!

    override func setUp() async throws {
        manager = SnappedWindowManager()
    }

    override func tearDown() async throws {
        manager = nil
    }

    // MARK: - Initialization Tests

    func testSnappedWindowManager_StartsWithEmptyList() {
        XCTAssertTrue(manager.snappedWindows.isEmpty)
    }

    // MARK: - Registration Tests

    func testSnappedWindowManager_RegistersWindow() {
        let windowElement = AXUIElementCreateSystemWide()
        let zoneId = UUID()
        let frame = CGRect(x: 0, y: 0, width: 960, height: 1080)

        manager.registerSnappedWindow(
            windowElement: windowElement,
            zoneId: zoneId,
            frame: frame,
            screenId: "Main"
        )

        XCTAssertEqual(manager.snappedWindows.count, 1)
        XCTAssertEqual(manager.snappedWindows[0].zoneId, zoneId)
        XCTAssertEqual(manager.snappedWindows[0].screenId, "Main")
        XCTAssertEqual(manager.snappedWindows[0].lastKnownFrame, frame)
    }

    func testSnappedWindowManager_UnregistersWindowById() {
        let windowElement = AXUIElementCreateSystemWide()
        let zoneId = UUID()
        let frame = CGRect(x: 0, y: 0, width: 960, height: 1080)

        manager.registerSnappedWindow(
            windowElement: windowElement,
            zoneId: zoneId,
            frame: frame,
            screenId: "Main"
        )

        let registeredId = manager.snappedWindows[0].id
        manager.unregisterSnappedWindow(id: registeredId)

        XCTAssertTrue(manager.snappedWindows.isEmpty)
    }

    func testSnappedWindowManager_ClearsAllWindows() {
        // 異なるPIDを使って異なるAXUIElementを作成
        let windowElement1 = AXUIElementCreateApplication(1)
        let windowElement2 = AXUIElementCreateApplication(2)
        let frame = CGRect(x: 0, y: 0, width: 960, height: 1080)

        manager.registerSnappedWindow(
            windowElement: windowElement1,
            zoneId: UUID(),
            frame: frame,
            screenId: "Main"
        )
        manager.registerSnappedWindow(
            windowElement: windowElement2,
            zoneId: UUID(),
            frame: frame,
            screenId: "Main"
        )

        XCTAssertEqual(manager.snappedWindows.count, 2)

        manager.clearAllSnappedWindows()

        XCTAssertTrue(manager.snappedWindows.isEmpty)
    }

    // MARK: - Query Tests

    func testSnappedWindowManager_FindsByZoneId() {
        let windowElement = AXUIElementCreateSystemWide()
        let zoneId = UUID()
        let frame = CGRect(x: 0, y: 0, width: 960, height: 1080)

        manager.registerSnappedWindow(
            windowElement: windowElement,
            zoneId: zoneId,
            frame: frame,
            screenId: "Main"
        )

        let found = manager.snappedWindow(forZone: zoneId)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.zoneId, zoneId)
    }

    func testSnappedWindowManager_ReturnsNilForUnknownZoneId() {
        let found = manager.snappedWindow(forZone: UUID())

        XCTAssertNil(found)
    }

    func testSnappedWindowManager_FiltersByScreenId() {
        let frame = CGRect(x: 0, y: 0, width: 960, height: 1080)

        // 異なるPIDを使って異なるAXUIElementを作成
        manager.registerSnappedWindow(
            windowElement: AXUIElementCreateApplication(1),
            zoneId: UUID(),
            frame: frame,
            screenId: "Main"
        )
        manager.registerSnappedWindow(
            windowElement: AXUIElementCreateApplication(2),
            zoneId: UUID(),
            frame: frame,
            screenId: "External"
        )
        manager.registerSnappedWindow(
            windowElement: AXUIElementCreateApplication(3),
            zoneId: UUID(),
            frame: frame,
            screenId: "Main"
        )

        let mainScreenWindows = manager.snappedWindows(forScreen: "Main")
        let externalScreenWindows = manager.snappedWindows(forScreen: "External")

        XCTAssertEqual(mainScreenWindows.count, 2)
        XCTAssertEqual(externalScreenWindows.count, 1)
    }
}
