import XCTest
@testable import Shikiri

final class ScreenLayoutConfigTests: XCTestCase {

    // MARK: - Test Data

    private let testScreenId = ScreenIdentifier(
        localizedName: "Test Display",
        width: 1920,
        height: 1080
    )

    // MARK: - Initialization Tests

    func testScreenLayoutConfig_InitializesWithScreenIdentifier() {
        let config = ScreenLayoutConfig(screenIdentifier: testScreenId)

        XCTAssertEqual(config.screenIdentifier, testScreenId)
        XCTAssertNil(config.selectedPresetId)
        XCTAssertNil(config.customPreset)
    }

    func testScreenLayoutConfig_InitializesWithPresetId() {
        let config = ScreenLayoutConfig(
            screenIdentifier: testScreenId,
            selectedPresetId: "halfLeftRight"
        )

        XCTAssertEqual(config.selectedPresetId, "halfLeftRight")
    }

    // MARK: - Identifiable Tests

    func testScreenLayoutConfig_IdMatchesScreenIdentifierKey() {
        let config = ScreenLayoutConfig(screenIdentifier: testScreenId)

        XCTAssertEqual(config.id, testScreenId.key)
    }

    // MARK: - effectivePreset Tests

    func testScreenLayoutConfig_EffectivePresetReturnsFallbackWhenNoPresetSet() {
        let config = ScreenLayoutConfig(screenIdentifier: testScreenId)
        let fallback = ZoneLayoutPreset.halfLeftRight

        let effective = config.effectivePreset(fallback: fallback)

        XCTAssertEqual(effective, fallback)
    }

    func testScreenLayoutConfig_EffectivePresetReturnsSelectedBuiltinPreset() {
        let config = ScreenLayoutConfig(
            screenIdentifier: testScreenId,
            selectedPresetId: "threeEqual"
        )
        let fallback = ZoneLayoutPreset.halfLeftRight

        let effective = config.effectivePreset(fallback: fallback)

        XCTAssertEqual(effective.id, "threeEqual")
    }

    func testScreenLayoutConfig_EffectivePresetReturnsCustomPresetWhenSet() {
        let customZones = [
            ZoneDefinition(x: 0, y: 0, width: 0.3, height: 1.0),
            ZoneDefinition(x: 0.3, y: 0, width: 0.7, height: 1.0)
        ]
        let customPreset = ZoneLayoutPreset(
            id: "custom_test",
            name: "Custom Layout",
            zones: customZones
        )

        var config = ScreenLayoutConfig(screenIdentifier: testScreenId)
        config.customPreset = customPreset

        let fallback = ZoneLayoutPreset.halfLeftRight
        let effective = config.effectivePreset(fallback: fallback)

        XCTAssertEqual(effective.id, "custom_test")
        XCTAssertEqual(effective.zones.count, 2)
    }

    func testScreenLayoutConfig_CustomPresetTakesPriorityOverSelectedPreset() {
        let customPreset = ZoneLayoutPreset(
            id: "custom",
            name: "Custom",
            zones: [ZoneDefinition(x: 0, y: 0, width: 1.0, height: 1.0)]
        )

        var config = ScreenLayoutConfig(
            screenIdentifier: testScreenId,
            selectedPresetId: "halfLeftRight"
        )
        config.customPreset = customPreset

        let fallback = ZoneLayoutPreset.threeEqual
        let effective = config.effectivePreset(fallback: fallback)

        XCTAssertEqual(effective.id, "custom")
    }

    func testScreenLayoutConfig_EffectivePresetReturnsFallbackForInvalidPresetId() {
        let config = ScreenLayoutConfig(
            screenIdentifier: testScreenId,
            selectedPresetId: "nonexistent_preset"
        )
        let fallback = ZoneLayoutPreset.halfLeftRight

        let effective = config.effectivePreset(fallback: fallback)

        XCTAssertEqual(effective, fallback)
    }

    // MARK: - Codable Tests

    func testScreenLayoutConfig_EncodesAndDecodes() throws {
        var config = ScreenLayoutConfig(
            screenIdentifier: testScreenId,
            selectedPresetId: "grid2x2"
        )
        config.customPreset = ZoneLayoutPreset(
            id: "custom",
            name: "Custom",
            zones: [ZoneDefinition(x: 0, y: 0, width: 0.5, height: 1.0)]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScreenLayoutConfig.self, from: data)

        XCTAssertEqual(config.screenIdentifier, decoded.screenIdentifier)
        XCTAssertEqual(config.selectedPresetId, decoded.selectedPresetId)
        XCTAssertEqual(config.customPreset?.id, decoded.customPreset?.id)
    }

    // MARK: - Equatable Tests

    func testScreenLayoutConfig_EqualityWithSameValues() {
        let config1 = ScreenLayoutConfig(
            screenIdentifier: testScreenId,
            selectedPresetId: "halfLeftRight"
        )
        let config2 = ScreenLayoutConfig(
            screenIdentifier: testScreenId,
            selectedPresetId: "halfLeftRight"
        )

        XCTAssertEqual(config1, config2)
    }

    func testScreenLayoutConfig_InequalityWithDifferentPreset() {
        let config1 = ScreenLayoutConfig(
            screenIdentifier: testScreenId,
            selectedPresetId: "halfLeftRight"
        )
        let config2 = ScreenLayoutConfig(
            screenIdentifier: testScreenId,
            selectedPresetId: "threeEqual"
        )

        XCTAssertNotEqual(config1, config2)
    }
}
