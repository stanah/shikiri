import XCTest
@testable import Shikiri

@MainActor
final class BoundaryDragCoordinatorTests: XCTestCase {

    var coordinator: BoundaryDragCoordinator!
    var mockWindowController: MockBoundaryWindowController!

    override func setUp() async throws {
        mockWindowController = MockBoundaryWindowController()
        coordinator = BoundaryDragCoordinator(windowController: mockWindowController)
    }

    override func tearDown() async throws {
        coordinator = nil
        mockWindowController = nil
    }

    // MARK: - Initialization Tests

    func testBoundaryDragCoordinator_InitializesWithEmptyState() {
        XCTAssertFalse(coordinator.isDragging)
        XCTAssertNil(coordinator.activeBoundary)
        XCTAssertEqual(coordinator.snappedWindows.count, 0)
    }

    // MARK: - Boundary Detection Tests

    func testBoundaryDragCoordinator_SetupBoundaries_CreatesFromZones() {
        let leftZone = Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        let rightZone = Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))

        coordinator.setupBoundaries(from: [leftZone, rightZone])

        XCTAssertEqual(coordinator.boundaries.count, 1)
        XCTAssertEqual(coordinator.boundaries[0].position, 960)
    }

    // MARK: - Drag Start Tests

    func testBoundaryDragCoordinator_StartDrag_ActivatesBoundary() {
        let leftZone = Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        let rightZone = Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))

        coordinator.setupBoundaries(from: [leftZone, rightZone])
        let result = coordinator.startDragIfOnBoundary(at: CGPoint(x: 960, y: 540))

        XCTAssertTrue(result)
        XCTAssertTrue(coordinator.isDragging)
        XCTAssertNotNil(coordinator.activeBoundary)
    }

    func testBoundaryDragCoordinator_StartDrag_ReturnsFalseWhenNotOnBoundary() {
        let leftZone = Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        let rightZone = Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))

        coordinator.setupBoundaries(from: [leftZone, rightZone])
        let result = coordinator.startDragIfOnBoundary(at: CGPoint(x: 500, y: 540))

        XCTAssertFalse(result)
        XCTAssertFalse(coordinator.isDragging)
        XCTAssertNil(coordinator.activeBoundary)
    }

    // MARK: - Drag Movement Tests

    func testBoundaryDragCoordinator_UpdateDrag_CalculatesDelta() {
        let leftZone = Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        let rightZone = Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))

        coordinator.setupBoundaries(from: [leftZone, rightZone])
        _ = coordinator.startDragIfOnBoundary(at: CGPoint(x: 960, y: 540))

        let delta = coordinator.updateDrag(to: CGPoint(x: 980, y: 540))

        XCTAssertEqual(delta, 20)
    }

    func testBoundaryDragCoordinator_UpdateDrag_ReturnsZeroWhenNotDragging() {
        let delta = coordinator.updateDrag(to: CGPoint(x: 980, y: 540))

        XCTAssertEqual(delta, 0)
    }

    // MARK: - End Drag Tests

    func testBoundaryDragCoordinator_EndDrag_ResetsState() {
        let leftZone = Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        let rightZone = Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))

        coordinator.setupBoundaries(from: [leftZone, rightZone])
        _ = coordinator.startDragIfOnBoundary(at: CGPoint(x: 960, y: 540))
        coordinator.endDrag()

        XCTAssertFalse(coordinator.isDragging)
        XCTAssertNil(coordinator.activeBoundary)
    }

    // MARK: - Snapped Window Management Tests

    func testBoundaryDragCoordinator_RegisterSnappedWindow() {
        let windowElement = AXUIElementCreateSystemWide()
        let zoneId = UUID()
        let frame = CGRect(x: 0, y: 0, width: 960, height: 1080)

        coordinator.registerSnappedWindow(
            windowElement: windowElement,
            zoneId: zoneId,
            frame: frame,
            screenId: "Main"
        )

        XCTAssertEqual(coordinator.snappedWindows.count, 1)
        XCTAssertEqual(coordinator.snappedWindows[0].zoneId, zoneId)
    }

    func testBoundaryDragCoordinator_UnregisterSnappedWindow() {
        let windowElement = AXUIElementCreateSystemWide()
        let zoneId = UUID()
        let frame = CGRect(x: 0, y: 0, width: 960, height: 1080)

        coordinator.registerSnappedWindow(
            windowElement: windowElement,
            zoneId: zoneId,
            frame: frame,
            screenId: "Main"
        )

        let id = coordinator.snappedWindows[0].id
        coordinator.unregisterSnappedWindow(id: id)

        XCTAssertEqual(coordinator.snappedWindows.count, 0)
    }

    // MARK: - Window Resize Tests

    func testBoundaryDragCoordinator_ResizeWindowsForBoundary_Vertical() async {
        let leftZoneId = UUID()
        let rightZoneId = UUID()

        // Setup zones and boundary
        let leftZone = Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        let rightZone = Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))
        coordinator.setupBoundaries(from: [leftZone, rightZone])

        // Register windows
        let leftWindow = AXUIElementCreateApplication(1)
        let rightWindow = AXUIElementCreateApplication(2)

        coordinator.registerSnappedWindow(
            windowElement: leftWindow,
            zoneId: leftZoneId,
            frame: CGRect(x: 0, y: 0, width: 960, height: 1080),
            screenId: "Main"
        )
        coordinator.registerSnappedWindow(
            windowElement: rightWindow,
            zoneId: rightZoneId,
            frame: CGRect(x: 960, y: 0, width: 960, height: 1080),
            screenId: "Main"
        )

        // Start drag on boundary
        guard coordinator.boundaries.count > 0 else {
            XCTFail("No boundaries detected")
            return
        }

        let boundary = coordinator.boundaries[0]

        // Update snapped windows' zone IDs to match boundary
        coordinator.clearAllSnappedWindows()
        coordinator.registerSnappedWindow(
            windowElement: leftWindow,
            zoneId: boundary.leftOrTopZoneId,
            frame: CGRect(x: 0, y: 0, width: 960, height: 1080),
            screenId: "Main"
        )
        coordinator.registerSnappedWindow(
            windowElement: rightWindow,
            zoneId: boundary.rightOrBottomZoneId,
            frame: CGRect(x: 960, y: 0, width: 960, height: 1080),
            screenId: "Main"
        )

        // Start drag and move
        _ = coordinator.startDragIfOnBoundary(at: CGPoint(x: 960, y: 540))
        _ = coordinator.updateDrag(to: CGPoint(x: 1000, y: 540))
        coordinator.applyResize()

        // Verify resize was called
        XCTAssertEqual(mockWindowController.setFrameCallCount, 2)
    }

    // MARK: - Minimum Size Constraint Tests

    func testBoundaryDragCoordinator_EnforcesMinimumSize() {
        let leftZone = Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        let rightZone = Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))

        coordinator.setupBoundaries(from: [leftZone, rightZone])

        // Register snapped windows so clamping can work
        guard coordinator.boundaries.count > 0 else {
            XCTFail("No boundaries detected")
            return
        }

        let boundary = coordinator.boundaries[0]

        let leftWindow = AXUIElementCreateApplication(1)
        let rightWindow = AXUIElementCreateApplication(2)

        coordinator.registerSnappedWindow(
            windowElement: leftWindow,
            zoneId: boundary.leftOrTopZoneId,
            frame: CGRect(x: 0, y: 0, width: 960, height: 1080),
            screenId: "Main"
        )
        coordinator.registerSnappedWindow(
            windowElement: rightWindow,
            zoneId: boundary.rightOrBottomZoneId,
            frame: CGRect(x: 960, y: 0, width: 960, height: 1080),
            screenId: "Main"
        )

        _ = coordinator.startDragIfOnBoundary(at: CGPoint(x: 960, y: 540))

        // Try to drag past minimum size (to x=100, which would make left window 100px wide)
        let delta = coordinator.updateDrag(to: CGPoint(x: 100, y: 540))

        // Delta should be clamped: left window should not shrink below minimum width (200px)
        // Start position is 960, so max allowed left movement is 960 - 200 = 760
        // Requested delta is 100 - 960 = -860
        // Clamped delta should be -760
        let maxAllowedNegativeDelta = -(960 - BoundaryDragCoordinator.minimumWindowWidth)
        XCTAssertEqual(delta, maxAllowedNegativeDelta)
    }
}

// MARK: - Mock Classes

@MainActor
final class MockBoundaryWindowController: WindowControlling {
    var setFrameCallCount = 0
    var lastSetFrame: CGRect?
    var shouldThrowError = false

    func setWindowFrame(_ window: AXUIElement, frame: CGRect) throws {
        if shouldThrowError {
            throw WindowOperationError.cannotSetFrame(reason: "Mock error")
        }
        setFrameCallCount += 1
        lastSetFrame = frame
    }
}
