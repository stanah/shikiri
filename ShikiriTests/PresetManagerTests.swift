import XCTest
@testable import Shikiri

/// PresetManagerのテスト
@MainActor
final class PresetManagerTests: XCTestCase {

    var sut: PresetManager!

    override func setUp() async throws {
        try await super.setUp()
        // テスト用のUserDefaultsをクリア
        UserDefaults.standard.removeObject(forKey: "shikiri.selectedPresetId")
        sut = PresetManager()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "shikiri.selectedPresetId")
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Available Presets Tests

    func testPresetManager_HasAllDefaultPresets() {
        XCTAssertEqual(sut.availablePresets.count, ZoneLayoutPreset.allPresets.count)
    }

    func testPresetManager_AvailablePresetsContainsExpectedPresets() {
        XCTAssertTrue(sut.availablePresets.contains { $0.id == "halfLeftRight" })
        XCTAssertTrue(sut.availablePresets.contains { $0.id == "oneThirdTwoThirds" })
        XCTAssertTrue(sut.availablePresets.contains { $0.id == "threeEqual" })
        XCTAssertTrue(sut.availablePresets.contains { $0.id == "grid2x2" })
    }

    // MARK: - Current Preset Tests

    func testPresetManager_DefaultsToHalfLeftRight() {
        XCTAssertEqual(sut.currentPreset.id, "halfLeftRight")
    }

    func testPresetManager_SelectPresetUpdatesCurrentPreset() {
        sut.selectPreset(id: "grid2x2")

        XCTAssertEqual(sut.currentPreset.id, "grid2x2")
    }

    func testPresetManager_SelectInvalidPresetKeepsCurrent() {
        let originalPreset = sut.currentPreset

        sut.selectPreset(id: "nonexistent")

        XCTAssertEqual(sut.currentPreset.id, originalPreset.id)
    }

    // MARK: - Persistence Tests

    func testPresetManager_SavesSelectedPresetToUserDefaults() {
        sut.selectPreset(id: "threeEqual")

        let savedId = UserDefaults.standard.string(forKey: "shikiri.selectedPresetId")
        XCTAssertEqual(savedId, "threeEqual")
    }

    func testPresetManager_LoadsSavedPresetOnInit() {
        // 事前にUserDefaultsに保存
        UserDefaults.standard.set("oneThirdTwoThirds", forKey: "shikiri.selectedPresetId")

        // 新しいインスタンスを作成
        let newManager = PresetManager()

        XCTAssertEqual(newManager.currentPreset.id, "oneThirdTwoThirds")
    }

    func testPresetManager_DefaultsToHalfLeftRightWhenNoSavedValue() {
        UserDefaults.standard.removeObject(forKey: "shikiri.selectedPresetId")

        let newManager = PresetManager()

        XCTAssertEqual(newManager.currentPreset.id, "halfLeftRight")
    }

    func testPresetManager_DefaultsToHalfLeftRightWhenInvalidSavedValue() {
        UserDefaults.standard.set("invalid", forKey: "shikiri.selectedPresetId")

        let newManager = PresetManager()

        XCTAssertEqual(newManager.currentPreset.id, "halfLeftRight")
    }

    // MARK: - Zone Generation Tests

    func testPresetManager_GeneratesZonesForCurrentPreset() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let zones = sut.generateZones(for: screenFrame)

        // デフォルトのhalfLeftRightは2ゾーン
        XCTAssertEqual(zones.count, 2)
    }

    func testPresetManager_GeneratesCorrectZonesAfterPresetChange() {
        sut.selectPreset(id: "grid2x2")
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let zones = sut.generateZones(for: screenFrame)

        // grid2x2は4ゾーン
        XCTAssertEqual(zones.count, 4)
    }

    // MARK: - ObservableObject Tests

    func testPresetManager_PublishesChangesOnPresetSelection() {
        var changeCount = 0
        let cancellable = sut.objectWillChange.sink {
            changeCount += 1
        }

        sut.selectPreset(id: "threeEqual")

        // objectWillChangeが呼ばれるはず
        XCTAssertGreaterThan(changeCount, 0)

        cancellable.cancel()
    }
}
