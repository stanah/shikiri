import AppKit
import Foundation

/// ログをファイルに書き込む
private func layoutLog(_ message: String) {
    let logPath = "/tmp/shikiri_app.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logMessage = "[\(timestamp)] [ScreenLayoutManager] \(message)\n"
    print("[ScreenLayoutManager] \(message)")
    if let data = logMessage.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logPath) {
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: logPath))
        }
    }
}

/// 画面ごとのレイアウト設定を管理するマネージャー
/// 設定はUserDefaultsに永続化される
@MainActor
final class ScreenLayoutManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ScreenLayoutManager()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let screenConfigs = "shikiri.screenLayoutConfigs"
        static let customPresets = "shikiri.customPresets"
    }

    // MARK: - Published Properties

    /// 画面ごとの設定
    @Published private(set) var screenConfigs: [ScreenLayoutConfig] = []

    /// ユーザー定義のカスタムプリセット
    @Published private(set) var customPresets: [ZoneLayoutPreset] = []

    // MARK: - Computed Properties

    /// 全てのプリセット（ビルトイン + カスタム）
    var allPresets: [ZoneLayoutPreset] {
        ZoneLayoutPreset.allPresets + customPresets
    }

    // MARK: - Initialization

    init() {
        loadFromUserDefaults()
    }

    // MARK: - Screen Config Management

    /// 画面設定を追加または更新
    /// - Parameter config: 設定
    func setConfig(_ config: ScreenLayoutConfig) {
        if let index = screenConfigs.firstIndex(where: { $0.screenIdentifier == config.screenIdentifier }) {
            screenConfigs[index] = config
        } else {
            screenConfigs.append(config)
        }
        saveToUserDefaults()
    }

    /// 画面識別子で設定を取得
    /// - Parameter screenIdentifier: 画面識別子
    /// - Returns: 設定（存在しない場合はnil）
    func config(for screenIdentifier: ScreenIdentifier) -> ScreenLayoutConfig? {
        screenConfigs.first { $0.screenIdentifier == screenIdentifier }
    }

    /// 画面設定を削除
    /// - Parameter screenIdentifier: 画面識別子
    func removeConfig(for screenIdentifier: ScreenIdentifier) {
        screenConfigs.removeAll { $0.screenIdentifier == screenIdentifier }
        saveToUserDefaults()
    }

    /// 画面に適用するプリセットを取得
    /// - Parameters:
    ///   - screenIdentifier: 画面識別子
    ///   - fallback: フォールバックプリセット
    /// - Returns: 適用するプリセット
    func preset(for screenIdentifier: ScreenIdentifier, fallback: ZoneLayoutPreset) -> ZoneLayoutPreset {
        if let config = config(for: screenIdentifier) {
            return config.effectivePreset(fallback: fallback)
        }
        return fallback
    }

    /// NSScreenに適用するプリセットを取得（デフォルト：Shiftのみ）
    /// - Parameters:
    ///   - screen: 対象画面
    ///   - fallback: フォールバックプリセット
    /// - Returns: 適用するプリセット
    func preset(for screen: NSScreen, fallback: ZoneLayoutPreset) -> ZoneLayoutPreset {
        return preset(for: screen, modifiers: .shift, fallback: fallback)
    }

    /// NSScreenと修飾キーに適用するプリセットを取得
    /// - Parameters:
    ///   - screen: 対象画面
    ///   - modifiers: 修飾キーの組み合わせ
    ///   - fallback: フォールバックプリセット
    /// - Returns: 適用するプリセット
    func preset(for screen: NSScreen, modifiers: ModifierFlags, fallback: ZoneLayoutPreset) -> ZoneLayoutPreset {
        let identifier = ScreenIdentifier.from(screen)
        layoutLog("Looking for preset for: \(identifier.key), modifiers: \(modifiers.displayName)")

        if let config = config(for: identifier) {
            let preset = config.effectivePreset(for: modifiers, fallback: fallback)
            layoutLog("  Found config, using preset: \(preset.name)")
            return preset
        }

        layoutLog("  No config found, using fallback: \(fallback.name)")
        return fallback
    }

    /// 画面識別子と修飾キーに適用するプリセットを取得
    /// - Parameters:
    ///   - screenIdentifier: 画面識別子
    ///   - modifiers: 修飾キーの組み合わせ
    ///   - fallback: フォールバックプリセット
    /// - Returns: 適用するプリセット
    func preset(for screenIdentifier: ScreenIdentifier, modifiers: ModifierFlags, fallback: ZoneLayoutPreset) -> ZoneLayoutPreset {
        if let config = config(for: screenIdentifier) {
            return config.effectivePreset(for: modifiers, fallback: fallback)
        }
        return fallback
    }

    // MARK: - Custom Preset Management

    /// カスタムプリセットを追加または更新
    /// - Parameter preset: プリセット
    func addCustomPreset(_ preset: ZoneLayoutPreset) {
        if let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[index] = preset
        } else {
            customPresets.append(preset)
        }
        saveToUserDefaults()
    }

    /// カスタムプリセットを削除
    /// - Parameter id: プリセットID
    func removeCustomPreset(id: String) {
        customPresets.removeAll { $0.id == id }
        saveToUserDefaults()
    }

    // MARK: - Persistence

    private func loadFromUserDefaults() {
        // 画面設定を読み込み
        if let data = UserDefaults.standard.data(forKey: Keys.screenConfigs),
           let configs = try? JSONDecoder().decode([ScreenLayoutConfig].self, from: data) {
            screenConfigs = configs
            layoutLog("Loaded \(configs.count) screen configs:")
            for config in configs {
                layoutLog("  - \(config.screenIdentifier.key): preset=\(config.selectedPresetId ?? "custom")")
            }
        } else {
            layoutLog("No screen configs found in UserDefaults")
        }

        // カスタムプリセットを読み込み
        if let data = UserDefaults.standard.data(forKey: Keys.customPresets),
           let presets = try? JSONDecoder().decode([ZoneLayoutPreset].self, from: data) {
            customPresets = presets
            layoutLog("Loaded \(presets.count) custom presets")
        }
    }

    private func saveToUserDefaults() {
        // 画面設定を保存
        if let data = try? JSONEncoder().encode(screenConfigs) {
            UserDefaults.standard.set(data, forKey: Keys.screenConfigs)
        }

        // カスタムプリセットを保存
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: Keys.customPresets)
        }
    }
}
