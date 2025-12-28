import XCTest
@testable import Shikiri

// MARK: - OverlayWindow Tests
final class OverlayWindowTests: XCTestCase {

    // MARK: - Initialization Tests

    @MainActor
    func testOverlayWindow_InitializesWithCorrectFrame() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlayWindow = OverlayWindow(frame: frame)

        XCTAssertEqual(overlayWindow.frame, frame)
    }

    @MainActor
    func testOverlayWindow_IsBorderless() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlayWindow = OverlayWindow(frame: frame)

        XCTAssertTrue(overlayWindow.styleMask.contains(.borderless))
    }

    @MainActor
    func testOverlayWindow_IsNotOpaque() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlayWindow = OverlayWindow(frame: frame)

        XCTAssertFalse(overlayWindow.isOpaque)
    }

    @MainActor
    func testOverlayWindow_HasClearBackground() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlayWindow = OverlayWindow(frame: frame)

        XCTAssertEqual(overlayWindow.backgroundColor, NSColor.clear)
    }

    @MainActor
    func testOverlayWindow_IgnoresMouseEvents() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlayWindow = OverlayWindow(frame: frame)

        XCTAssertTrue(overlayWindow.ignoresMouseEvents)
    }

    @MainActor
    func testOverlayWindow_HasFloatingLevel() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlayWindow = OverlayWindow(frame: frame)

        XCTAssertEqual(overlayWindow.level, .floating)
    }

    @MainActor
    func testOverlayWindow_CanJoinAllSpaces() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlayWindow = OverlayWindow(frame: frame)

        XCTAssertTrue(overlayWindow.collectionBehavior.contains(.canJoinAllSpaces))
    }

    @MainActor
    func testOverlayWindow_IsFullScreenAuxiliary() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlayWindow = OverlayWindow(frame: frame)

        XCTAssertTrue(overlayWindow.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    @MainActor
    func testOverlayWindow_HasStationary() {
        let frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlayWindow = OverlayWindow(frame: frame)

        XCTAssertTrue(overlayWindow.collectionBehavior.contains(.stationary))
    }
}
