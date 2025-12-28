import XCTest
import CoreGraphics
@testable import Shikiri

// MARK: - Mock Delegate for testing
@MainActor
final class MockEventMonitorDelegate: EventMonitorDelegate {
    var snapModeStartedCalled = false
    var snapModeEndedCalled = false
    var lastWindowInfo: DraggedWindowInfo?
    var lastModifiers: ModifierFlags?
    var mouseDraggedPosition: CGPoint?
    var shiftKeyStateChanged: Bool?
    var modifiersChanged: ModifierFlags?

    func eventMonitor(_ monitor: EventMonitor, didStartSnapModeWith windowInfo: DraggedWindowInfo?, modifiers: ModifierFlags) {
        snapModeStartedCalled = true
        lastWindowInfo = windowInfo
        lastModifiers = modifiers
    }

    func eventMonitorDidEndSnapMode(_ monitor: EventMonitor) {
        snapModeEndedCalled = true
    }

    func eventMonitor(_ monitor: EventMonitor, didDragTo position: CGPoint) {
        mouseDraggedPosition = position
    }

    func eventMonitor(_ monitor: EventMonitor, shiftKeyStateChanged isPressed: Bool) {
        shiftKeyStateChanged = isPressed
    }

    func eventMonitor(_ monitor: EventMonitor, modifiersChanged modifiers: ModifierFlags) {
        self.modifiersChanged = modifiers
    }
}

// MARK: - Tests
@MainActor
final class EventMonitorTests: XCTestCase {
    var sut: EventMonitor!
    var mockDelegate: MockEventMonitorDelegate!

    override func setUp() async throws {
        try await super.setUp()
        mockDelegate = MockEventMonitorDelegate()
        sut = EventMonitor()
        sut.delegate = mockDelegate
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        mockDelegate = nil
        try await super.tearDown()
    }

    // MARK: - Basic Start/Stop Tests

    func testEventMonitor_InitiallyNotRunning() {
        XCTAssertFalse(sut.isRunning)
    }

    func testEventMonitor_StartsSuccessfully() {
        // Note: This test might fail without accessibility permissions
        // In a real scenario, we'd need to handle permission checking
        sut.start()
        // Even if the tap creation fails due to permissions,
        // the start method should complete without crashing
    }

    func testEventMonitor_StopsSuccessfully() {
        sut.start()
        sut.stop()
        XCTAssertFalse(sut.isRunning)
    }

    func testEventMonitor_CanRestartAfterStopping() {
        sut.start()
        sut.stop()
        sut.start()
        // Should not crash
    }

    // MARK: - Shift Key State Tests

    func testShiftKeyState_InitiallyFalse() {
        XCTAssertFalse(sut.isShiftKeyPressed)
    }

    // MARK: - Drag State Tests

    func testDragState_InitiallyIdle() {
        XCTAssertEqual(sut.dragState, .idle)
    }
}
