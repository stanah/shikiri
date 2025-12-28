import XCTest
@testable import Shikiri

/// レイアウトプリセットシステムのテスト
@MainActor
final class ZoneLayoutPresetTests: XCTestCase {

    // MARK: - ZoneDefinition Tests

    func testZoneDefinition_InitializesWithCorrectValues() {
        let definition = ZoneDefinition(x: 0.0, y: 0.0, width: 0.5, height: 1.0)

        XCTAssertEqual(definition.x, 0.0)
        XCTAssertEqual(definition.y, 0.0)
        XCTAssertEqual(definition.width, 0.5)
        XCTAssertEqual(definition.height, 1.0)
    }

    func testZoneDefinition_ConvertsToFrameCorrectly() {
        let definition = ZoneDefinition(x: 0.0, y: 0.0, width: 0.5, height: 1.0)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let frame = definition.toFrame(in: screenFrame)

        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.origin.y, 0)
        XCTAssertEqual(frame.width, 960)
        XCTAssertEqual(frame.height, 1080)
    }

    func testZoneDefinition_ConvertsToFrameWithOffset() {
        let definition = ZoneDefinition(x: 0.5, y: 0.0, width: 0.5, height: 1.0)
        let screenFrame = NSRect(x: 100, y: 50, width: 1920, height: 1080)

        let frame = definition.toFrame(in: screenFrame)

        XCTAssertEqual(frame.origin.x, 100 + 960)
        XCTAssertEqual(frame.origin.y, 50)
        XCTAssertEqual(frame.width, 960)
        XCTAssertEqual(frame.height, 1080)
    }

    func testZoneDefinition_Codable() throws {
        let original = ZoneDefinition(x: 0.25, y: 0.0, width: 0.5, height: 0.5)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ZoneDefinition.self, from: encoded)

        XCTAssertEqual(decoded.x, original.x)
        XCTAssertEqual(decoded.y, original.y)
        XCTAssertEqual(decoded.width, original.width)
        XCTAssertEqual(decoded.height, original.height)
    }

    // MARK: - ZoneLayoutPreset Tests

    func testZoneLayoutPreset_InitializesWithCorrectValues() {
        let zones = [
            ZoneDefinition(x: 0.0, y: 0.0, width: 0.5, height: 1.0),
            ZoneDefinition(x: 0.5, y: 0.0, width: 0.5, height: 1.0)
        ]
        let preset = ZoneLayoutPreset(id: "half", name: "左右2分割", zones: zones)

        XCTAssertEqual(preset.id, "half")
        XCTAssertEqual(preset.name, "左右2分割")
        XCTAssertEqual(preset.zones.count, 2)
    }

    func testZoneLayoutPreset_GeneratesZonesForScreen() {
        let zones = [
            ZoneDefinition(x: 0.0, y: 0.0, width: 0.5, height: 1.0),
            ZoneDefinition(x: 0.5, y: 0.0, width: 0.5, height: 1.0)
        ]
        let preset = ZoneLayoutPreset(id: "half", name: "左右2分割", zones: zones)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let generatedZones = preset.generateZones(for: screenFrame)

        XCTAssertEqual(generatedZones.count, 2)
        XCTAssertEqual(generatedZones[0].frame.width, 960)
        XCTAssertEqual(generatedZones[1].frame.origin.x, 960)
    }

    func testZoneLayoutPreset_Codable() throws {
        let zones = [
            ZoneDefinition(x: 0.0, y: 0.0, width: 0.5, height: 1.0),
            ZoneDefinition(x: 0.5, y: 0.0, width: 0.5, height: 1.0)
        ]
        let original = ZoneLayoutPreset(id: "half", name: "左右2分割", zones: zones)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ZoneLayoutPreset.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.zones.count, original.zones.count)
    }

    func testZoneLayoutPreset_Identifiable() {
        let zones = [ZoneDefinition(x: 0.0, y: 0.0, width: 1.0, height: 1.0)]
        let preset = ZoneLayoutPreset(id: "test", name: "Test", zones: zones)

        XCTAssertEqual(preset.id, "test")
    }

    // MARK: - Default Presets Tests

    func testDefaultPresets_HalfLeftRight() {
        let preset = ZoneLayoutPreset.halfLeftRight
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let zones = preset.generateZones(for: screenFrame)

        XCTAssertEqual(zones.count, 2)
        // 左ゾーン
        XCTAssertEqual(zones[0].frame.origin.x, 0)
        XCTAssertEqual(zones[0].frame.width, 960)
        // 右ゾーン
        XCTAssertEqual(zones[1].frame.origin.x, 960)
        XCTAssertEqual(zones[1].frame.width, 960)
    }

    func testDefaultPresets_OneThirdTwoThirds() {
        let preset = ZoneLayoutPreset.oneThirdTwoThirds
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let zones = preset.generateZones(for: screenFrame)

        XCTAssertEqual(zones.count, 2)
        // 左ゾーン（1/3）
        XCTAssertEqual(zones[0].frame.origin.x, 0)
        XCTAssertEqual(zones[0].frame.width, 640, accuracy: 1.0)
        // 右ゾーン（2/3）
        XCTAssertEqual(zones[1].frame.origin.x, 640, accuracy: 1.0)
        XCTAssertEqual(zones[1].frame.width, 1280, accuracy: 1.0)
    }

    func testDefaultPresets_ThreeEqual() {
        let preset = ZoneLayoutPreset.threeEqual
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let zones = preset.generateZones(for: screenFrame)

        XCTAssertEqual(zones.count, 3)
        // 各ゾーンは1/3ずつ
        XCTAssertEqual(zones[0].frame.width, 640, accuracy: 1.0)
        XCTAssertEqual(zones[1].frame.width, 640, accuracy: 1.0)
        XCTAssertEqual(zones[2].frame.width, 640, accuracy: 1.0)
    }

    func testDefaultPresets_Grid2x2() {
        let preset = ZoneLayoutPreset.grid2x2
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let zones = preset.generateZones(for: screenFrame)

        XCTAssertEqual(zones.count, 4)
        // 左上
        XCTAssertEqual(zones[0].frame.origin.x, 0)
        XCTAssertEqual(zones[0].frame.origin.y, 540)
        XCTAssertEqual(zones[0].frame.width, 960)
        XCTAssertEqual(zones[0].frame.height, 540)
        // 右上
        XCTAssertEqual(zones[1].frame.origin.x, 960)
        XCTAssertEqual(zones[1].frame.origin.y, 540)
        // 左下
        XCTAssertEqual(zones[2].frame.origin.x, 0)
        XCTAssertEqual(zones[2].frame.origin.y, 0)
        // 右下
        XCTAssertEqual(zones[3].frame.origin.x, 960)
        XCTAssertEqual(zones[3].frame.origin.y, 0)
    }

    func testDefaultPresets_AllPresetsAvailable() {
        let allPresets = ZoneLayoutPreset.allPresets

        XCTAssertGreaterThanOrEqual(allPresets.count, 4)
        XCTAssertTrue(allPresets.contains { $0.id == "halfLeftRight" })
        XCTAssertTrue(allPresets.contains { $0.id == "oneThirdTwoThirds" })
        XCTAssertTrue(allPresets.contains { $0.id == "threeEqual" })
        XCTAssertTrue(allPresets.contains { $0.id == "grid2x2" })
    }

    // MARK: - Gap Tests

    func testZoneDefinition_ToFrameWithZeroGap() {
        let definition = ZoneDefinition(x: 0.0, y: 0.0, width: 0.5, height: 1.0)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let frame = definition.toFrame(in: screenFrame, gap: 0)

        // ギャップ0の場合は通常のフレームと同じ
        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.origin.y, 0)
        XCTAssertEqual(frame.width, 960)
        XCTAssertEqual(frame.height, 1080)
    }

    func testZoneDefinition_ToFrameWithGap_LeftZone() {
        // 左側ゾーン（画面の左端に接している）
        let definition = ZoneDefinition(x: 0.0, y: 0.0, width: 0.5, height: 1.0)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let gap: CGFloat = 10

        let frame = definition.toFrame(in: screenFrame, gap: gap)

        // 左端・下端は画面端なのでギャップなし
        // 右端には半分のギャップ（5px）
        XCTAssertEqual(frame.origin.x, 0)
        XCTAssertEqual(frame.origin.y, 0)
        XCTAssertEqual(frame.width, 960 - 5) // 右に半分のギャップ
        XCTAssertEqual(frame.height, 1080)
    }

    func testZoneDefinition_ToFrameWithGap_RightZone() {
        // 右側ゾーン（画面の右端に接している）
        let definition = ZoneDefinition(x: 0.5, y: 0.0, width: 0.5, height: 1.0)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let gap: CGFloat = 10

        let frame = definition.toFrame(in: screenFrame, gap: gap)

        // 左端には半分のギャップ（5px）、右端は画面端なのでギャップなし
        XCTAssertEqual(frame.origin.x, 960 + 5)
        XCTAssertEqual(frame.origin.y, 0)
        XCTAssertEqual(frame.width, 960 - 5)
        XCTAssertEqual(frame.height, 1080)
    }

    func testZoneDefinition_ToFrameWithGap_CenterZone() {
        // 中央ゾーン（左右どちらにも接していない）
        let definition = ZoneDefinition(x: 1.0 / 3.0, y: 0.0, width: 1.0 / 3.0, height: 1.0)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let gap: CGFloat = 10

        let frame = definition.toFrame(in: screenFrame, gap: gap)

        // 両端にギャップ適用（左右に5pxずつ縮小）
        XCTAssertEqual(frame.origin.x, 640 + 5, accuracy: 1.0) // 1920/3 = 640
        XCTAssertEqual(frame.width, 640 - 10, accuracy: 1.0) // 両側で10px縮小
    }

    func testZoneLayoutPreset_GeneratesZonesWithGap() {
        let preset = ZoneLayoutPreset.halfLeftRight
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let gap: CGFloat = 10

        let zones = preset.generateZones(for: screenFrame, gap: gap)

        XCTAssertEqual(zones.count, 2)

        // 左ゾーン
        XCTAssertEqual(zones[0].frame.origin.x, 0)
        XCTAssertEqual(zones[0].frame.width, 960 - 5)

        // 右ゾーン
        XCTAssertEqual(zones[1].frame.origin.x, 960 + 5)
        XCTAssertEqual(zones[1].frame.width, 960 - 5)

        // 2つのゾーン間にギャップ10pxがあることを確認
        let leftZoneRightEdge = zones[0].frame.origin.x + zones[0].frame.width
        let rightZoneLeftEdge = zones[1].frame.origin.x
        XCTAssertEqual(rightZoneLeftEdge - leftZoneRightEdge, gap)
    }

    func testZoneLayoutPreset_Grid2x2WithGap() {
        let preset = ZoneLayoutPreset.grid2x2
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let gap: CGFloat = 10

        let zones = preset.generateZones(for: screenFrame, gap: gap)

        XCTAssertEqual(zones.count, 4)

        // 左上ゾーン（x=0, y=0.5）- 上端と右端にギャップ
        XCTAssertEqual(zones[0].frame.origin.x, 0)
        XCTAssertEqual(zones[0].frame.origin.y, 540 + 5) // 上に5px
        XCTAssertEqual(zones[0].frame.width, 960 - 5) // 右に5px
        XCTAssertEqual(zones[0].frame.height, 540 - 5) // 上に5px

        // 右下ゾーン（x=0.5, y=0）- 左端と下端にギャップ
        XCTAssertEqual(zones[3].frame.origin.x, 960 + 5) // 左に5px
        XCTAssertEqual(zones[3].frame.origin.y, 0)
        XCTAssertEqual(zones[3].frame.width, 960 - 5) // 左に5px
        XCTAssertEqual(zones[3].frame.height, 540 - 5) // 上に5px
    }
}
