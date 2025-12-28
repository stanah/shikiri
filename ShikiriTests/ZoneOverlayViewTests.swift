import XCTest
@testable import Shikiri

// MARK: - ZoneOverlayView Tests
final class ZoneOverlayViewTests: XCTestCase {

    // MARK: - Initialization Tests

    @MainActor
    func testZoneOverlayView_InitializesWithZones() {
        let zones = [
            Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080)),
            Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))
        ]
        let view = ZoneOverlayView(zones: zones)

        XCTAssertEqual(view.zones.count, 2)
    }

    @MainActor
    func testZoneOverlayView_InitializesWithNoHighlightedZone() {
        let zones = [
            Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        ]
        let view = ZoneOverlayView(zones: zones)

        XCTAssertNil(view.highlightedZoneId)
    }

    // MARK: - Zone Update Tests

    @MainActor
    func testZoneOverlayView_UpdateZones() {
        let initialZones = [
            Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        ]
        let view = ZoneOverlayView(zones: initialZones)

        let newZones = [
            Zone(frame: NSRect(x: 0, y: 0, width: 640, height: 1080)),
            Zone(frame: NSRect(x: 640, y: 0, width: 640, height: 1080)),
            Zone(frame: NSRect(x: 1280, y: 0, width: 640, height: 1080))
        ]
        view.updateZones(newZones)

        XCTAssertEqual(view.zones.count, 3)
    }

    // MARK: - Highlight Tests

    @MainActor
    func testZoneOverlayView_SetHighlightedZone() {
        let zones = [
            Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080)),
            Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))
        ]
        let view = ZoneOverlayView(zones: zones)
        let zoneId = zones[0].id

        view.setHighlightedZone(zoneId)

        XCTAssertEqual(view.highlightedZoneId, zoneId)
    }

    @MainActor
    func testZoneOverlayView_ClearHighlight() {
        let zones = [
            Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        ]
        let view = ZoneOverlayView(zones: zones)
        view.setHighlightedZone(zones[0].id)

        view.clearHighlight()

        XCTAssertNil(view.highlightedZoneId)
    }

    // MARK: - View Properties Tests

    @MainActor
    func testZoneOverlayView_IsNotOpaque() {
        let zones = [Zone(frame: NSRect(x: 0, y: 0, width: 100, height: 100))]
        let view = ZoneOverlayView(zones: zones)

        XCTAssertFalse(view.isOpaque)
    }

    @MainActor
    func testZoneOverlayView_WantsLayerForAnimations() {
        let zones = [Zone(frame: NSRect(x: 0, y: 0, width: 100, height: 100))]
        let view = ZoneOverlayView(zones: zones)

        XCTAssertTrue(view.wantsLayer)
    }
}
