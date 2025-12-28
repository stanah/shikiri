import XCTest
@testable import Shikiri

// MARK: - Mock Classes

/// Mock EventMonitor for testing
@MainActor
final class MockEventMonitor {
    weak var delegate: EventMonitorDelegate?
    private(set) var isRunning = false
    private(set) var isShiftKeyPressed = false
    private(set) var dragState: DragState = .idle

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    // Helper methods to simulate events
    func simulateSnapModeStarted(with windowInfo: DraggedWindowInfo?, modifiers: ModifierFlags = .shift) {
        guard let coordinator = delegate as? SnapCoordinator else { return }
        let dummyEventMonitor = EventMonitor()
        coordinator.eventMonitor(dummyEventMonitor, didStartSnapModeWith: windowInfo, modifiers: modifiers)
    }

    func simulateSnapModeEnded() {
        guard let coordinator = delegate as? SnapCoordinator else { return }
        let dummyEventMonitor = EventMonitor()
        coordinator.eventMonitorDidEndSnapMode(dummyEventMonitor)
    }

    func simulateDragMoved(to position: CGPoint) {
        guard let coordinator = delegate as? SnapCoordinator else { return }
        let dummyEventMonitor = EventMonitor()
        coordinator.eventMonitor(dummyEventMonitor, didDragTo: position)
    }

    func simulateShiftKeyStateChanged(_ isPressed: Bool) {
        isShiftKeyPressed = isPressed
        guard let coordinator = delegate as? SnapCoordinator else { return }
        let dummyEventMonitor = EventMonitor()
        coordinator.eventMonitor(dummyEventMonitor, shiftKeyStateChanged: isPressed)
    }
}

/// Mock OverlayController for testing
@MainActor
final class MockOverlayController: OverlayControlling {
    private(set) var showCalled = false
    private(set) var hideCalled = false
    private(set) var refreshCalled = false
    private(set) var lastHighlightedZoneId: UUID?
    private(set) var isVisible = false

    func show() {
        showCalled = true
        isVisible = true
    }

    func hide() {
        hideCalled = true
        isVisible = false
    }

    func refresh() {
        refreshCalled = true
    }

    func updateHighlightedZone(_ zoneId: UUID?) {
        lastHighlightedZoneId = zoneId
    }

    func clearHighlight() {
        lastHighlightedZoneId = nil
    }

    func reset() {
        showCalled = false
        hideCalled = false
        refreshCalled = false
        lastHighlightedZoneId = nil
        isVisible = false
    }
}

/// Mock WindowController for testing
@MainActor
final class MockWindowController: WindowControlling {
    private(set) var setFrameCalled = false
    private(set) var lastSetWindow: AXUIElement?
    private(set) var lastSetFrame: CGRect?
    var shouldThrowError = false

    func setWindowFrame(_ window: AXUIElement, frame: CGRect) throws {
        if shouldThrowError {
            throw WindowOperationError.cannotSetFrame(reason: "Mock error")
        }
        setFrameCalled = true
        lastSetWindow = window
        lastSetFrame = frame
    }

    func reset() {
        setFrameCalled = false
        lastSetWindow = nil
        lastSetFrame = nil
        shouldThrowError = false
    }
}

// MARK: - Tests

@MainActor
final class SnapCoordinatorTests: XCTestCase {

    var zoneManager: ZoneManager!
    var mockOverlayController: MockOverlayController!
    var mockWindowController: MockWindowController!
    var coordinator: SnapCoordinator!

    override func setUp() async throws {
        zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))

        mockOverlayController = MockOverlayController()
        mockWindowController = MockWindowController()
        coordinator = SnapCoordinator(
            zoneManager: zoneManager,
            overlayController: mockOverlayController,
            windowController: mockWindowController
        )
    }

    override func tearDown() async throws {
        coordinator = nil
        mockOverlayController = nil
        mockWindowController = nil
        zoneManager = nil
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertFalse(coordinator.isSnapping)
        XCTAssertNil(coordinator.currentWindowInfo)
    }

    // MARK: - Snap Mode Start Tests

    func testSnapModeStartedWithWindowInfo() {
        // Given
        let windowElement = AXUIElementCreateSystemWide() // Dummy element for testing
        let windowInfo = DraggedWindowInfo(
            windowElement: windowElement,
            pid: 1234,
            initialPosition: CGPoint(x: 100, y: 100),
            initialSize: CGSize(width: 800, height: 600)
        )

        // When
        coordinator.handleSnapModeStarted(with: windowInfo)

        // Then
        XCTAssertTrue(coordinator.isSnapping)
        XCTAssertNotNil(coordinator.currentWindowInfo)
        XCTAssertTrue(mockOverlayController.showCalled)
    }

    func testSnapModeStartedWithoutWindowInfo() {
        // When
        coordinator.handleSnapModeStarted(with: nil)

        // Then
        XCTAssertFalse(coordinator.isSnapping, "Should not start snapping without window info")
        XCTAssertFalse(mockOverlayController.showCalled)
    }

    // MARK: - Drag Movement Tests

    func testDragMovedUpdatesZoneHighlight() {
        // Given
        let windowElement = AXUIElementCreateSystemWide()
        let windowInfo = DraggedWindowInfo(
            windowElement: windowElement,
            pid: 1234,
            initialPosition: CGPoint(x: 100, y: 100),
            initialSize: CGSize(width: 800, height: 600)
        )
        coordinator.handleSnapModeStarted(with: windowInfo)
        // Re-setup zones for test (handleSnapModeStarted resets zones to per-screen presets)
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))

        // When - Move to left zone
        coordinator.handleDragMoved(to: CGPoint(x: 400, y: 500))

        // Then
        XCTAssertNotNil(zoneManager.activeZone)
        XCTAssertNotNil(mockOverlayController.lastHighlightedZoneId)
    }

    func testDragMovedOutsideZoneClearsHighlight() {
        // Given
        let windowElement = AXUIElementCreateSystemWide()
        let windowInfo = DraggedWindowInfo(
            windowElement: windowElement,
            pid: 1234,
            initialPosition: CGPoint(x: 100, y: 100),
            initialSize: CGSize(width: 800, height: 600)
        )
        coordinator.handleSnapModeStarted(with: windowInfo)
        // Re-setup zones for test (handleSnapModeStarted resets zones to per-screen presets)
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        coordinator.handleDragMoved(to: CGPoint(x: 400, y: 500)) // Inside zone

        // When - Move outside zones
        coordinator.handleDragMoved(to: CGPoint(x: -100, y: -100))

        // Then
        XCTAssertNil(zoneManager.activeZone)
    }

    // MARK: - Snap Mode End Tests

    func testSnapModeEndedWithActiveZone() {
        // Given
        let windowElement = AXUIElementCreateSystemWide()
        let windowInfo = DraggedWindowInfo(
            windowElement: windowElement,
            pid: 1234,
            initialPosition: CGPoint(x: 100, y: 100),
            initialSize: CGSize(width: 800, height: 600)
        )
        coordinator.handleSnapModeStarted(with: windowInfo)
        coordinator.handleDragMoved(to: CGPoint(x: 400, y: 500)) // Move to left zone

        // When
        coordinator.handleSnapModeEnded()

        // Then
        XCTAssertFalse(coordinator.isSnapping)
        XCTAssertNil(coordinator.currentWindowInfo)
        XCTAssertTrue(mockOverlayController.hideCalled)
        XCTAssertTrue(mockWindowController.setFrameCalled)
    }

    func testSnapModeEndedWithoutActiveZone() {
        // Given
        let windowElement = AXUIElementCreateSystemWide()
        let windowInfo = DraggedWindowInfo(
            windowElement: windowElement,
            pid: 1234,
            initialPosition: CGPoint(x: 100, y: 100),
            initialSize: CGSize(width: 800, height: 600)
        )
        coordinator.handleSnapModeStarted(with: windowInfo)
        // Don't move to any zone

        // When
        coordinator.handleSnapModeEnded()

        // Then
        XCTAssertFalse(coordinator.isSnapping)
        XCTAssertTrue(mockOverlayController.hideCalled)
        XCTAssertFalse(mockWindowController.setFrameCalled, "Should not set frame when no zone is active")
    }

    // MARK: - Shift Key Cancel Tests

    func testShiftKeyReleasedCancelsSnap() {
        // Given
        let windowElement = AXUIElementCreateSystemWide()
        let windowInfo = DraggedWindowInfo(
            windowElement: windowElement,
            pid: 1234,
            initialPosition: CGPoint(x: 100, y: 100),
            initialSize: CGSize(width: 800, height: 600)
        )
        coordinator.handleSnapModeStarted(with: windowInfo)
        coordinator.handleDragMoved(to: CGPoint(x: 400, y: 500)) // Move to zone

        // When - Simulate shift key release during snap
        coordinator.handleShiftKeyStateChanged(false)

        // Then
        XCTAssertFalse(coordinator.isSnapping)
        XCTAssertTrue(mockOverlayController.hideCalled)
        XCTAssertFalse(mockWindowController.setFrameCalled, "Should not snap when shift is released mid-drag")
    }

    // MARK: - Error Handling Tests

    func testSnapModeEndedWithWindowControllerError() {
        // Given
        let windowElement = AXUIElementCreateSystemWide()
        let windowInfo = DraggedWindowInfo(
            windowElement: windowElement,
            pid: 1234,
            initialPosition: CGPoint(x: 100, y: 100),
            initialSize: CGSize(width: 800, height: 600)
        )
        coordinator.handleSnapModeStarted(with: windowInfo)
        coordinator.handleDragMoved(to: CGPoint(x: 400, y: 500))
        mockWindowController.shouldThrowError = true

        // When
        coordinator.handleSnapModeEnded()

        // Then - Should still clean up state even on error
        XCTAssertFalse(coordinator.isSnapping)
        XCTAssertTrue(mockOverlayController.hideCalled)
    }
}
