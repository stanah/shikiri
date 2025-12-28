import XCTest
@testable import Shikiri

// MARK: - OverlayController Tests
final class OverlayControllerTests: XCTestCase {

    // MARK: - Initialization Tests

    @MainActor
    func testOverlayController_InitializesWithZoneManager() {
        let zoneManager = ZoneManager()
        let controller = OverlayController(zoneManager: zoneManager)

        XCTAssertNotNil(controller)
    }

    @MainActor
    func testOverlayController_InitiallyNotVisible() {
        let zoneManager = ZoneManager()
        let controller = OverlayController(zoneManager: zoneManager)

        XCTAssertFalse(controller.isVisible)
    }

    // MARK: - Show/Hide Tests

    @MainActor
    func testOverlayController_ShowMakesVisible() {
        let zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let controller = OverlayController(zoneManager: zoneManager)

        controller.show()

        XCTAssertTrue(controller.isVisible)
    }

    @MainActor
    func testOverlayController_HideMakesInvisible() {
        let zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let controller = OverlayController(zoneManager: zoneManager)
        controller.show()

        controller.hide()

        XCTAssertFalse(controller.isVisible)
    }

    @MainActor
    func testOverlayController_MultipleShowsAreSafe() {
        let zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let controller = OverlayController(zoneManager: zoneManager)

        controller.show()
        controller.show()
        controller.show()

        XCTAssertTrue(controller.isVisible)
    }

    @MainActor
    func testOverlayController_MultipleHidesAreSafe() {
        let zoneManager = ZoneManager()
        let controller = OverlayController(zoneManager: zoneManager)

        controller.hide()
        controller.hide()
        controller.hide()

        XCTAssertFalse(controller.isVisible)
    }

    // MARK: - Highlight Tests

    @MainActor
    func testOverlayController_UpdateHighlightedZone() {
        let zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let controller = OverlayController(zoneManager: zoneManager)
        controller.show()
        let zoneId = zoneManager.zones.first!.id

        controller.updateHighlightedZone(zoneId)

        XCTAssertEqual(controller.highlightedZoneId, zoneId)
    }

    @MainActor
    func testOverlayController_ClearHighlight() {
        let zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let controller = OverlayController(zoneManager: zoneManager)
        controller.show()
        let zoneId = zoneManager.zones.first!.id
        controller.updateHighlightedZone(zoneId)

        controller.clearHighlight()

        XCTAssertNil(controller.highlightedZoneId)
    }

    // MARK: - Animation Tests

    @MainActor
    func testOverlayController_AnimationEnabledByDefault() {
        let zoneManager = ZoneManager()
        let controller = OverlayController(zoneManager: zoneManager)

        XCTAssertTrue(controller.animationEnabled)
    }

    @MainActor
    func testOverlayController_CanDisableAnimation() {
        let zoneManager = ZoneManager()
        let controller = OverlayController(zoneManager: zoneManager)

        controller.animationEnabled = false

        XCTAssertFalse(controller.animationEnabled)
    }

    @MainActor
    func testOverlayController_FadeAnimationDuration() {
        XCTAssertEqual(OverlayController.fadeAnimationDuration, 0.2)
    }

    @MainActor
    func testOverlayController_ShowWithAnimationDisabled() {
        let zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let controller = OverlayController(zoneManager: zoneManager)
        controller.animationEnabled = false

        controller.show()

        XCTAssertTrue(controller.isVisible)
    }

    @MainActor
    func testOverlayController_HideWithAnimationDisabled() {
        let zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let controller = OverlayController(zoneManager: zoneManager)
        controller.animationEnabled = false
        controller.show()

        controller.hide()

        XCTAssertFalse(controller.isVisible)
    }

    // MARK: - Mouse Position Highlight Tests

    @MainActor
    func testOverlayController_UpdateHighlightForMousePositionInLeftZone() {
        let zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let controller = OverlayController(zoneManager: zoneManager)
        controller.animationEnabled = false
        controller.show()
        let leftZoneId = zoneManager.zones[0].id

        // 左ゾーン内の位置
        controller.updateHighlightForMousePosition(NSPoint(x: 100, y: 500))

        XCTAssertEqual(controller.highlightedZoneId, leftZoneId)
    }

    @MainActor
    func testOverlayController_UpdateHighlightForMousePositionInRightZone() {
        let zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let controller = OverlayController(zoneManager: zoneManager)
        controller.animationEnabled = false
        controller.show()
        let rightZoneId = zoneManager.zones[1].id

        // 右ゾーン内の位置
        controller.updateHighlightForMousePosition(NSPoint(x: 1500, y: 500))

        XCTAssertEqual(controller.highlightedZoneId, rightZoneId)
    }

    @MainActor
    func testOverlayController_UpdateHighlightForMousePositionOutsideZones() {
        let zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let controller = OverlayController(zoneManager: zoneManager)
        controller.animationEnabled = false
        controller.show()
        // まずハイライトを設定
        controller.updateHighlightedZone(zoneManager.zones[0].id)

        // ゾーン外の位置
        controller.updateHighlightForMousePosition(NSPoint(x: 2000, y: 500))

        XCTAssertNil(controller.highlightedZoneId)
    }

    @MainActor
    func testOverlayController_UpdateHighlightForMousePositionWhenNotVisible() {
        let zoneManager = ZoneManager()
        zoneManager.setupZones(for: NSRect(x: 0, y: 0, width: 1920, height: 1080))
        let controller = OverlayController(zoneManager: zoneManager)
        controller.animationEnabled = false
        // show()を呼ばない

        // 左ゾーン内の位置
        controller.updateHighlightForMousePosition(NSPoint(x: 100, y: 500))

        // 非表示のときは更新されない
        XCTAssertNil(controller.highlightedZoneId)
    }
}
