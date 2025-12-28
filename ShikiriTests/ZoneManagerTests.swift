import XCTest
@testable import Shikiri

// MARK: - Mock Screen Provider for Testing
protocol ScreenProviderProtocol {
    var screens: [NSScreen] { get }
}

struct MockScreen {
    let frame: NSRect
    let visibleFrame: NSRect
}

final class MockScreenProvider: ScreenProviderProtocol {
    var mockScreens: [MockScreen] = []

    var screens: [NSScreen] {
        // テストでは直接NSScreenを使わず、ZoneManagerのDI対応が必要
        // このモックはZoneManagerがプロトコルを使うようになってから有効になる
        return []
    }
}

// MARK: - ZoneManager Tests
@MainActor
final class ZoneManagerTests: XCTestCase {

    var sut: ZoneManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = ZoneManager()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testZoneManager_InitiallyHasNoZones() {
        XCTAssertTrue(sut.zones.isEmpty)
    }

    func testZoneManager_InitiallyHasNoActiveZone() {
        XCTAssertNil(sut.activeZone)
    }

    // MARK: - Zone Setup Tests

    func testZoneManager_SetupZonesCreatesLeftAndRightZones() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        sut.setupZones(for: screenFrame)

        XCTAssertEqual(sut.zones.count, 2)
    }

    func testZoneManager_LeftZoneOccupiesLeftHalf() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        sut.setupZones(for: screenFrame)

        let leftZone = sut.zones[0]
        XCTAssertEqual(leftZone.frame.origin.x, 0)
        XCTAssertEqual(leftZone.frame.origin.y, 0)
        XCTAssertEqual(leftZone.frame.width, 960)
        XCTAssertEqual(leftZone.frame.height, 1080)
    }

    func testZoneManager_RightZoneOccupiesRightHalf() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        sut.setupZones(for: screenFrame)

        let rightZone = sut.zones[1]
        XCTAssertEqual(rightZone.frame.origin.x, 960)
        XCTAssertEqual(rightZone.frame.origin.y, 0)
        XCTAssertEqual(rightZone.frame.width, 960)
        XCTAssertEqual(rightZone.frame.height, 1080)
    }

    func testZoneManager_SetupZonesHandlesNonZeroOrigin() {
        // メニューバーやDockを考慮したvisibleFrame
        let screenFrame = NSRect(x: 0, y: 100, width: 1920, height: 980)

        sut.setupZones(for: screenFrame)

        let leftZone = sut.zones[0]
        XCTAssertEqual(leftZone.frame.origin.y, 100)
        XCTAssertEqual(leftZone.frame.height, 980)
    }

    // MARK: - Zone At Point Tests

    func testZoneManager_ZoneAtReturnsLeftZoneForLeftPoint() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        sut.setupZones(for: screenFrame)

        let leftPoint = NSPoint(x: 100, y: 540)
        let zone = sut.zoneAt(point: leftPoint)

        XCTAssertEqual(zone?.frame.origin.x, 0)
    }

    func testZoneManager_ZoneAtReturnsRightZoneForRightPoint() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        sut.setupZones(for: screenFrame)

        let rightPoint = NSPoint(x: 1500, y: 540)
        let zone = sut.zoneAt(point: rightPoint)

        XCTAssertEqual(zone?.frame.origin.x, 960)
    }

    func testZoneManager_ZoneAtReturnsNilForPointOutsideZones() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        sut.setupZones(for: screenFrame)

        let outsidePoint = NSPoint(x: 2000, y: 540)
        let zone = sut.zoneAt(point: outsidePoint)

        XCTAssertNil(zone)
    }

    // MARK: - Active Zone Tests

    func testZoneManager_UpdateActiveZoneSetsActiveZone() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        sut.setupZones(for: screenFrame)

        let leftPoint = NSPoint(x: 100, y: 540)
        sut.updateActiveZone(for: leftPoint)

        XCTAssertNotNil(sut.activeZone)
        XCTAssertEqual(sut.activeZone?.frame.origin.x, 0)
    }

    func testZoneManager_UpdateActiveZoneClearsWhenOutsideAllZones() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        sut.setupZones(for: screenFrame)

        // まず内部に設定
        sut.updateActiveZone(for: NSPoint(x: 100, y: 540))
        XCTAssertNotNil(sut.activeZone)

        // 外部に移動
        sut.updateActiveZone(for: NSPoint(x: 2000, y: 540))
        XCTAssertNil(sut.activeZone)
    }

    func testZoneManager_ClearActiveZone() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        sut.setupZones(for: screenFrame)
        sut.updateActiveZone(for: NSPoint(x: 100, y: 540))

        sut.clearActiveZone()

        XCTAssertNil(sut.activeZone)
    }

    // MARK: - Multi-Display Tests

    func testZoneManager_SetupZonesForMultipleScreensCreatesZonesForEach() {
        let screen1Frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let screen2Frame = NSRect(x: 1920, y: 0, width: 1920, height: 1080)

        sut.setupZonesForScreens([screen1Frame, screen2Frame])

        // 各画面に2ゾーン、計4ゾーン
        XCTAssertEqual(sut.zones.count, 4)
    }

    func testZoneManager_MultiDisplayZonesHaveCorrectFrames() {
        let screen1Frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let screen2Frame = NSRect(x: 1920, y: 0, width: 1920, height: 1080)

        sut.setupZonesForScreens([screen1Frame, screen2Frame])

        // Screen1の左ゾーン
        XCTAssertEqual(sut.zones[0].frame.origin.x, 0)
        // Screen1の右ゾーン
        XCTAssertEqual(sut.zones[1].frame.origin.x, 960)
        // Screen2の左ゾーン
        XCTAssertEqual(sut.zones[2].frame.origin.x, 1920)
        // Screen2の右ゾーン
        XCTAssertEqual(sut.zones[3].frame.origin.x, 2880)
    }

    func testZoneManager_ZoneAtPointWorksAcrossMultipleScreens() {
        let screen1Frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let screen2Frame = NSRect(x: 1920, y: 0, width: 1920, height: 1080)

        sut.setupZonesForScreens([screen1Frame, screen2Frame])

        // Screen1の左側
        let screen1LeftPoint = NSPoint(x: 100, y: 540)
        XCTAssertEqual(sut.zoneAt(point: screen1LeftPoint)?.frame.origin.x, 0)

        // Screen2の右側
        let screen2RightPoint = NSPoint(x: 3000, y: 540)
        XCTAssertEqual(sut.zoneAt(point: screen2RightPoint)?.frame.origin.x, 2880)
    }

    func testZoneManager_SetupZonesWithCurrentScreens() {
        // 現在の画面でゾーンをセットアップ
        sut.setupZonesWithCurrentScreens()

        // 少なくともメイン画面用の2ゾーンは存在するはず
        XCTAssertGreaterThanOrEqual(sut.zones.count, 2)
    }

    // MARK: - Preset Support Tests

    func testZoneManager_SetupZonesWithPreset() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        sut.setupZones(for: screenFrame, preset: .threeEqual)

        // 3等分プリセットなので3ゾーン
        XCTAssertEqual(sut.zones.count, 3)
    }

    func testZoneManager_SetupZonesWithGrid2x2Preset() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        sut.setupZones(for: screenFrame, preset: .grid2x2)

        // 4分割グリッドなので4ゾーン
        XCTAssertEqual(sut.zones.count, 4)
    }

    func testZoneManager_SetupZonesForScreensWithPreset() {
        let screen1Frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let screen2Frame = NSRect(x: 1920, y: 0, width: 1920, height: 1080)

        sut.setupZonesForScreens([screen1Frame, screen2Frame], preset: .threeEqual)

        // 各画面に3ゾーン、計6ゾーン
        XCTAssertEqual(sut.zones.count, 6)
    }

    func testZoneManager_PresetZonesHaveCorrectDimensions() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        sut.setupZones(for: screenFrame, preset: .oneThirdTwoThirds)

        // 左ゾーン（1/3）
        XCTAssertEqual(sut.zones[0].frame.origin.x, 0)
        XCTAssertEqual(sut.zones[0].frame.width, 640, accuracy: 1.0)

        // 右ゾーン（2/3）
        XCTAssertEqual(sut.zones[1].frame.origin.x, 640, accuracy: 1.0)
        XCTAssertEqual(sut.zones[1].frame.width, 1280, accuracy: 1.0)
    }
}
