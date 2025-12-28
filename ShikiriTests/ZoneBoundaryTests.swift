import XCTest
@testable import Shikiri

@MainActor
final class ZoneBoundaryTests: XCTestCase {

    // MARK: - ZoneBoundary Tests

    func testZoneBoundary_InitializesWithCorrectValues() {
        let boundary = ZoneBoundary(
            orientation: .vertical,
            position: 960,
            range: 0..<1080,
            leftOrTopZoneId: UUID(),
            rightOrBottomZoneId: UUID()
        )

        XCTAssertEqual(boundary.orientation, .vertical)
        XCTAssertEqual(boundary.position, 960)
        XCTAssertEqual(boundary.range, 0..<1080)
    }

    func testZoneBoundary_ContainsPoint_Vertical() {
        let boundary = ZoneBoundary(
            orientation: .vertical,
            position: 960,
            range: 0..<1080,
            leftOrTopZoneId: UUID(),
            rightOrBottomZoneId: UUID()
        )

        // 境界上の点
        XCTAssertTrue(boundary.containsPoint(CGPoint(x: 960, y: 540), tolerance: 5))
        // 境界の少し左
        XCTAssertTrue(boundary.containsPoint(CGPoint(x: 957, y: 540), tolerance: 5))
        // 境界の少し右
        XCTAssertTrue(boundary.containsPoint(CGPoint(x: 963, y: 540), tolerance: 5))
        // 範囲内のy座標
        XCTAssertTrue(boundary.containsPoint(CGPoint(x: 960, y: 0), tolerance: 5))
        XCTAssertTrue(boundary.containsPoint(CGPoint(x: 960, y: 1079), tolerance: 5))
    }

    func testZoneBoundary_DoesNotContainPoint_OutsideTolerance() {
        let boundary = ZoneBoundary(
            orientation: .vertical,
            position: 960,
            range: 0..<1080,
            leftOrTopZoneId: UUID(),
            rightOrBottomZoneId: UUID()
        )

        // 許容範囲外の点
        XCTAssertFalse(boundary.containsPoint(CGPoint(x: 950, y: 540), tolerance: 5))
        XCTAssertFalse(boundary.containsPoint(CGPoint(x: 970, y: 540), tolerance: 5))
        // y座標が範囲外
        XCTAssertFalse(boundary.containsPoint(CGPoint(x: 960, y: -10), tolerance: 5))
        XCTAssertFalse(boundary.containsPoint(CGPoint(x: 960, y: 1090), tolerance: 5))
    }

    func testZoneBoundary_ContainsPoint_Horizontal() {
        let boundary = ZoneBoundary(
            orientation: .horizontal,
            position: 540,
            range: 0..<1920,
            leftOrTopZoneId: UUID(),
            rightOrBottomZoneId: UUID()
        )

        // 境界上の点
        XCTAssertTrue(boundary.containsPoint(CGPoint(x: 960, y: 540), tolerance: 5))
        // 境界の少し上
        XCTAssertTrue(boundary.containsPoint(CGPoint(x: 960, y: 543), tolerance: 5))
        // 境界の少し下
        XCTAssertTrue(boundary.containsPoint(CGPoint(x: 960, y: 537), tolerance: 5))
    }

    func testZoneBoundary_DoesNotContainPoint_Horizontal_OutsideRange() {
        let boundary = ZoneBoundary(
            orientation: .horizontal,
            position: 540,
            range: 0..<1920,
            leftOrTopZoneId: UUID(),
            rightOrBottomZoneId: UUID()
        )

        // x座標が範囲外
        XCTAssertFalse(boundary.containsPoint(CGPoint(x: -10, y: 540), tolerance: 5))
        XCTAssertFalse(boundary.containsPoint(CGPoint(x: 1930, y: 540), tolerance: 5))
    }

    func testZoneBoundary_ResizeCursor_Vertical() {
        let boundary = ZoneBoundary(
            orientation: .vertical,
            position: 960,
            range: 0..<1080,
            leftOrTopZoneId: UUID(),
            rightOrBottomZoneId: UUID()
        )

        XCTAssertEqual(boundary.resizeCursor, NSCursor.resizeLeftRight)
    }

    func testZoneBoundary_ResizeCursor_Horizontal() {
        let boundary = ZoneBoundary(
            orientation: .horizontal,
            position: 540,
            range: 0..<1920,
            leftOrTopZoneId: UUID(),
            rightOrBottomZoneId: UUID()
        )

        XCTAssertEqual(boundary.resizeCursor, NSCursor.resizeUpDown)
    }

    // MARK: - BoundaryManager Tests

    func testBoundaryManager_DetectsBoundaryFromZones_TwoHorizontalZones() {
        let leftZone = Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        let rightZone = Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))

        let boundaries = BoundaryManager.detectBoundaries(from: [leftZone, rightZone])

        XCTAssertEqual(boundaries.count, 1)
        XCTAssertEqual(boundaries[0].orientation, .vertical)
        XCTAssertEqual(boundaries[0].position, 960)
    }

    func testBoundaryManager_DetectsBoundaryFromZones_TwoVerticalZones() {
        let topZone = Zone(frame: NSRect(x: 0, y: 540, width: 1920, height: 540))
        let bottomZone = Zone(frame: NSRect(x: 0, y: 0, width: 1920, height: 540))

        let boundaries = BoundaryManager.detectBoundaries(from: [topZone, bottomZone])

        XCTAssertEqual(boundaries.count, 1)
        XCTAssertEqual(boundaries[0].orientation, .horizontal)
        XCTAssertEqual(boundaries[0].position, 540)
    }

    func testBoundaryManager_DetectsMultipleBoundaries_ThreeColumns() {
        let leftZone = Zone(frame: NSRect(x: 0, y: 0, width: 640, height: 1080))
        let centerZone = Zone(frame: NSRect(x: 640, y: 0, width: 640, height: 1080))
        let rightZone = Zone(frame: NSRect(x: 1280, y: 0, width: 640, height: 1080))

        let boundaries = BoundaryManager.detectBoundaries(from: [leftZone, centerZone, rightZone])

        XCTAssertEqual(boundaries.count, 2)
        // 位置でソートされているはず
        XCTAssertEqual(boundaries[0].position, 640)
        XCTAssertEqual(boundaries[1].position, 1280)
    }

    func testBoundaryManager_FindsBoundaryAtPoint() {
        let leftZone = Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        let rightZone = Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))

        let boundaries = BoundaryManager.detectBoundaries(from: [leftZone, rightZone])
        let found = BoundaryManager.boundaryAt(point: CGPoint(x: 960, y: 540), in: boundaries, tolerance: 10)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.position, 960)
    }

    func testBoundaryManager_ReturnsNilForNoMatchingBoundary() {
        let leftZone = Zone(frame: NSRect(x: 0, y: 0, width: 960, height: 1080))
        let rightZone = Zone(frame: NSRect(x: 960, y: 0, width: 960, height: 1080))

        let boundaries = BoundaryManager.detectBoundaries(from: [leftZone, rightZone])
        let found = BoundaryManager.boundaryAt(point: CGPoint(x: 500, y: 540), in: boundaries, tolerance: 10)

        XCTAssertNil(found)
    }
}
