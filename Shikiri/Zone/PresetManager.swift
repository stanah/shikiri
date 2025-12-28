import SwiftUI

/// レイアウトプリセットを管理するクラス
/// 選択中のプリセットを保持し、UserDefaultsに永続化する
@MainActor
final class PresetManager: ObservableObject {
    // MARK: - Static Properties

    /// 共有インスタンス
    static let shared = PresetManager()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let selectedPresetId = "shikiri.selectedPresetId"
    }

    // MARK: - Published Properties

    /// 現在選択されているプリセット
    @Published private(set) var currentPreset: ZoneLayoutPreset

    // MARK: - Computed Properties

    /// 利用可能な全てのプリセット
    var availablePresets: [ZoneLayoutPreset] {
        ZoneLayoutPreset.allPresets
    }

    // MARK: - Initialization

    init() {
        // 保存されたプリセットIDを読み込む
        if let savedId = UserDefaults.standard.string(forKey: Keys.selectedPresetId),
           let preset = ZoneLayoutPreset.allPresets.first(where: { $0.id == savedId }) {
            self.currentPreset = preset
        } else {
            // デフォルトは左右2分割
            self.currentPreset = .halfLeftRight
        }
    }

    // MARK: - Public Methods

    /// 指定したIDのプリセットを選択する
    /// - Parameter id: プリセットのID
    func selectPreset(id: String) {
        guard let preset = availablePresets.first(where: { $0.id == id }) else {
            return
        }

        currentPreset = preset
        UserDefaults.standard.set(id, forKey: Keys.selectedPresetId)
    }

    /// 現在のプリセットを使って指定した画面フレームに対するゾーンを生成する
    /// - Parameter screenFrame: 画面のフレーム
    /// - Returns: Zoneオブジェクトのリスト
    func generateZones(for screenFrame: NSRect) -> [Zone] {
        currentPreset.generateZones(for: screenFrame)
    }

    /// 現在のプリセットを使って複数画面に対するゾーンを生成する
    /// - Parameter screenFrames: 各画面のフレームのリスト
    /// - Returns: 全画面分のZoneオブジェクトのリスト
    func generateZonesForScreens(_ screenFrames: [NSRect]) -> [Zone] {
        var allZones: [Zone] = []
        for frame in screenFrames {
            allZones.append(contentsOf: generateZones(for: frame))
        }
        return allZones
    }
}
