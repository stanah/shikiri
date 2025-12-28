import XCTest
import CoreGraphics
@testable import Shikiri

// MARK: - Zone Model Tests
final class ZoneTests: XCTestCase {

    // MARK: - Zone Initialization Tests

    func testZone_InitializesWithCorrectProperties() {
        let frame = NSRect(x: 0, y: 0, width: 960, height: 1080)
        let zone = Zone(frame: frame)

        XCTAssertEqual(zone.frame, frame)
        XCTAssertFalse(zone.isHighlighted)
    }

    func testZone_HasUniqueId() {
        let zone1 = Zone(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let zone2 = Zone(frame: NSRect(x: 100, y: 0, width: 100, height: 100))

        XCTAssertNotEqual(zone1.id, zone2.id)
    }

    // MARK: - Contains Point Tests

    func testZone_ContainsPointInside() {
        let zone = Zone(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let point = NSPoint(x: 50, y: 50)

        XCTAssertTrue(zone.contains(point: point))
    }

    func testZone_DoesNotContainPointOutside() {
        let zone = Zone(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let point = NSPoint(x: 150, y: 50)

        XCTAssertFalse(zone.contains(point: point))
    }

    func testZone_ContainsPointOnEdge() {
        let zone = Zone(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let pointOnEdge = NSPoint(x: 0, y: 50)

        XCTAssertTrue(zone.contains(point: pointOnEdge))
    }

    func testZone_DoesNotContainPointOnRightEdge() {
        // NSRectのcontainsは右端と上端を含まない
        let zone = Zone(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let pointOnRightEdge = NSPoint(x: 100, y: 50)

        XCTAssertFalse(zone.contains(point: pointOnRightEdge))
    }

    // MARK: - Highlight State Tests

    func testZone_CanToggleHighlight() {
        var zone = Zone(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertFalse(zone.isHighlighted)

        zone.isHighlighted = true
        XCTAssertTrue(zone.isHighlighted)
    }
}
