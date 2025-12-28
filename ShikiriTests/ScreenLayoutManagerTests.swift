import XCTest
@testable import Shikiri

@MainActor
final class ScreenLayoutManagerTests: XCTestCase {

    // MARK: - Test Data

    private let screen1Id = ScreenIdentifier(localizedName: "Display 1", width: 1920, height: 1080)
    private let screen2Id = ScreenIdentifier(localizedName: "Display 2", width: 2560, height: 1440)
    private let portraitId = ScreenIdentifier(localizedName: "Portrait", width: 1080, height: 1920)

    private var manager: ScreenLayoutManager!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        // テスト用に新しいインスタンスを作成（UserDefaultsキーをクリア）
        UserDefaults.standard.removeObject(forKey: "shikiri.screenLayoutConfigs")
        UserDefaults.standard.removeObject(forKey: "shikiri.customPresets")
        manager = ScreenLayoutManager()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "shikiri.screenLayoutConfigs")
        UserDefaults.standard.removeObject(forKey: "shikiri.customPresets")
        manager = nil
    }

    // MARK: - Initialization Tests

    func testScreenLayoutManager_InitializesWithEmptyConfigs() {
        XCTAssertTrue(manager.screenConfigs.isEmpty)
        XCTAssertTrue(manager.customPresets.isEmpty)
    }

    // MARK: - Screen Config Management Tests

    func testScreenLayoutManager_SetConfigForScreen() {
        let config = ScreenLayoutConfig(
            screenIdentifier: screen1Id,
            selectedPresetId: "halfLeftRight"
        )

        manager.setConfig(config)

        XCTAssertEqual(manager.screenConfigs.count, 1)
        XCTAssertEqual(manager.screenConfigs.first?.screenIdentifier, screen1Id)
    }

    func testScreenLayoutManager_UpdateExistingConfig() {
        let config1 = ScreenLayoutConfig(
            screenIdentifier: screen1Id,
            selectedPresetId: "halfLeftRight"
        )
        manager.setConfig(config1)

        let config2 = ScreenLayoutConfig(
            screenIdentifier: screen1Id,
            selectedPresetId: "threeEqual"
        )
        manager.setConfig(config2)

        XCTAssertEqual(manager.screenConfigs.count, 1)
        XCTAssertEqual(manager.screenConfigs.first?.selectedPresetId, "threeEqual")
    }

    func testScreenLayoutManager_GetConfigForScreen() {
        let config = ScreenLayoutConfig(
            screenIdentifier: screen1Id,
            selectedPresetId: "grid2x2"
        )
        manager.setConfig(config)

        let retrieved = manager.config(for: screen1Id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.selectedPresetId, "grid2x2")
    }

    func testScreenLayoutManager_GetConfigReturnsNilForUnknownScreen() {
        let config = manager.config(for: screen1Id)

        XCTAssertNil(config)
    }

    func testScreenLayoutManager_RemoveConfig() {
        let config = ScreenLayoutConfig(screenIdentifier: screen1Id)
        manager.setConfig(config)
        XCTAssertEqual(manager.screenConfigs.count, 1)

        manager.removeConfig(for: screen1Id)

        XCTAssertEqual(manager.screenConfigs.count, 0)
    }

    // MARK: - Preset Retrieval Tests

    func testScreenLayoutManager_PresetReturnsConfiguredPreset() {
        let config = ScreenLayoutConfig(
            screenIdentifier: screen1Id,
            selectedPresetId: "threeEqual"
        )
        manager.setConfig(config)

        let preset = manager.preset(for: screen1Id, fallback: .halfLeftRight)

        XCTAssertEqual(preset.id, "threeEqual")
    }

    func testScreenLayoutManager_PresetReturnsFallbackForUnconfiguredScreen() {
        let preset = manager.preset(for: screen1Id, fallback: .halfLeftRight)

        XCTAssertEqual(preset.id, "halfLeftRight")
    }

    // MARK: - Custom Preset Tests

    func testScreenLayoutManager_AddCustomPreset() {
        let customPreset = ZoneLayoutPreset(
            id: "custom_1",
            name: "My Layout",
            zones: [ZoneDefinition(x: 0, y: 0, width: 1.0, height: 1.0)]
        )

        manager.addCustomPreset(customPreset)

        XCTAssertEqual(manager.customPresets.count, 1)
        XCTAssertEqual(manager.customPresets.first?.id, "custom_1")
    }

    func testScreenLayoutManager_UpdateCustomPreset() {
        let preset1 = ZoneLayoutPreset(
            id: "custom_1",
            name: "Original",
            zones: [ZoneDefinition(x: 0, y: 0, width: 0.5, height: 1.0)]
        )
        manager.addCustomPreset(preset1)

        let preset2 = ZoneLayoutPreset(
            id: "custom_1",
            name: "Updated",
            zones: [ZoneDefinition(x: 0, y: 0, width: 0.7, height: 1.0)]
        )
        manager.addCustomPreset(preset2)

        XCTAssertEqual(manager.customPresets.count, 1)
        XCTAssertEqual(manager.customPresets.first?.name, "Updated")
    }

    func testScreenLayoutManager_RemoveCustomPreset() {
        let preset = ZoneLayoutPreset(
            id: "custom_1",
            name: "Test",
            zones: []
        )
        manager.addCustomPreset(preset)
        XCTAssertEqual(manager.customPresets.count, 1)

        manager.removeCustomPreset(id: "custom_1")

        XCTAssertEqual(manager.customPresets.count, 0)
    }

    func testScreenLayoutManager_AllPresetsIncludesBuiltinAndCustom() {
        let customPreset = ZoneLayoutPreset(
            id: "custom_1",
            name: "Custom",
            zones: []
        )
        manager.addCustomPreset(customPreset)

        let allPresets = manager.allPresets

        XCTAssertTrue(allPresets.contains(where: { $0.id == "halfLeftRight" }))
        XCTAssertTrue(allPresets.contains(where: { $0.id == "custom_1" }))
    }

    // MARK: - Persistence Tests

    func testScreenLayoutManager_PersistsConfigsToUserDefaults() {
        let config = ScreenLayoutConfig(
            screenIdentifier: screen1Id,
            selectedPresetId: "threeEqual"
        )
        manager.setConfig(config)

        // 新しいマネージャーを作成してUserDefaultsから読み込み
        let newManager = ScreenLayoutManager()

        XCTAssertEqual(newManager.screenConfigs.count, 1)
        XCTAssertEqual(newManager.screenConfigs.first?.selectedPresetId, "threeEqual")
    }

    func testScreenLayoutManager_PersistsCustomPresetsToUserDefaults() {
        let preset = ZoneLayoutPreset(
            id: "custom_persistent",
            name: "Persistent",
            zones: [ZoneDefinition(x: 0, y: 0, width: 0.5, height: 1.0)]
        )
        manager.addCustomPreset(preset)

        // 新しいマネージャーを作成
        let newManager = ScreenLayoutManager()

        XCTAssertEqual(newManager.customPresets.count, 1)
        XCTAssertEqual(newManager.customPresets.first?.id, "custom_persistent")
    }

    // MARK: - Multiple Screen Tests

    func testScreenLayoutManager_HandlesMultipleScreenConfigs() {
        let config1 = ScreenLayoutConfig(
            screenIdentifier: screen1Id,
            selectedPresetId: "halfLeftRight"
        )
        let config2 = ScreenLayoutConfig(
            screenIdentifier: screen2Id,
            selectedPresetId: "threeEqual"
        )
        let config3 = ScreenLayoutConfig(
            screenIdentifier: portraitId,
            selectedPresetId: "grid2x2"
        )

        manager.setConfig(config1)
        manager.setConfig(config2)
        manager.setConfig(config3)

        XCTAssertEqual(manager.screenConfigs.count, 3)
        XCTAssertEqual(manager.preset(for: screen1Id, fallback: .halfLeftRight).id, "halfLeftRight")
        XCTAssertEqual(manager.preset(for: screen2Id, fallback: .halfLeftRight).id, "threeEqual")
        XCTAssertEqual(manager.preset(for: portraitId, fallback: .halfLeftRight).id, "grid2x2")
    }
}
