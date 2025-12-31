import AppKit

/// ログを出力する
private func zoneLog(_ message: String) {
    ShikiriLogger.log(message, category: "ZoneManager")
}

/// ゾーンの管理を行うクラス
/// 画面を分割してゾーンを生成し、マウス位置からアクティブゾーンを判定する
@MainActor
final class ZoneManager: ObservableObject {
    // MARK: - Published Properties

    /// 現在定義されているゾーンのリスト
    @Published private(set) var zones: [Zone] = []

    /// 現在アクティブなゾーン（マウスホバー中のゾーン）
    @Published private(set) var activeZone: Zone?

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// 指定したフレームに対して左右2分割のゾーンを生成する
    /// - Parameter frame: ゾーンを生成する画面のフレーム（通常はvisibleFrame）
    func setupZones(for frame: NSRect) {
        setupZones(for: frame, preset: .halfLeftRight)
    }

    /// 指定したフレームに対してプリセットに基づいたゾーンを生成する
    /// - Parameters:
    ///   - frame: ゾーンを生成する画面のフレーム
    ///   - preset: 使用するレイアウトプリセット
    func setupZones(for frame: NSRect, preset: ZoneLayoutPreset) {
        zones = preset.generateZones(for: frame)
    }

    /// 指定したフレームに対してプリセットとギャップに基づいたゾーンを生成する
    /// - Parameters:
    ///   - frame: ゾーンを生成する画面のフレーム
    ///   - preset: 使用するレイアウトプリセット
    ///   - gap: ウィンドウ間のギャップ（ピクセル）
    func setupZones(for frame: NSRect, preset: ZoneLayoutPreset, gap: CGFloat) {
        zones = preset.generateZones(for: frame, gap: gap)
    }

    /// 指定した点を含むゾーンを返す
    /// - Parameter point: 判定対象の点
    /// - Returns: 点を含むゾーン、含むゾーンがない場合はnil
    func zoneAt(point: NSPoint) -> Zone? {
        return zones.first { $0.contains(point: point) }
    }

    /// 指定した点に基づいてアクティブゾーンを更新する
    /// - Parameter point: マウスカーソルの位置
    func updateActiveZone(for point: NSPoint) {
        activeZone = zoneAt(point: point)
    }

    /// アクティブゾーンをクリアする
    func clearActiveZone() {
        activeZone = nil
    }

    // MARK: - Multi-Display Support

    /// 複数画面のフレームに対してゾーンを生成する
    /// - Parameter screenFrames: 各画面のフレーム（通常はvisibleFrame）のリスト
    func setupZonesForScreens(_ screenFrames: [NSRect]) {
        setupZonesForScreens(screenFrames, preset: .halfLeftRight)
    }

    /// 複数画面のフレームに対してプリセットに基づいたゾーンを生成する
    /// - Parameters:
    ///   - screenFrames: 各画面のフレームのリスト
    ///   - preset: 使用するレイアウトプリセット
    func setupZonesForScreens(_ screenFrames: [NSRect], preset: ZoneLayoutPreset) {
        setupZonesForScreens(screenFrames, preset: preset, gap: 0)
    }

    /// 複数画面のフレームに対してプリセットとギャップに基づいたゾーンを生成する
    /// - Parameters:
    ///   - screenFrames: 各画面のフレームのリスト
    ///   - preset: 使用するレイアウトプリセット
    ///   - gap: ウィンドウ間のギャップ（ピクセル）
    func setupZonesForScreens(_ screenFrames: [NSRect], preset: ZoneLayoutPreset, gap: CGFloat) {
        var allZones: [Zone] = []

        for frame in screenFrames {
            allZones.append(contentsOf: preset.generateZones(for: frame, gap: gap))
        }

        zones = allZones
    }

    /// 現在接続されている全画面に対してゾーンをセットアップする
    func setupZonesWithCurrentScreens() {
        let screenFrames = NSScreen.screens.map { $0.visibleFrame }
        setupZonesForScreens(screenFrames)
    }

    /// 現在接続されている全画面に対して、指定したプリセットでゾーンをセットアップする
    /// - Parameter preset: 使用するレイアウトプリセット
    func setupZonesWithCurrentScreens(preset: ZoneLayoutPreset) {
        let screenFrames = NSScreen.screens.map { $0.visibleFrame }
        setupZonesForScreens(screenFrames, preset: preset)
    }

    /// 現在接続されている全画面に対して、指定したプリセットとギャップでゾーンをセットアップする
    /// - Parameters:
    ///   - preset: 使用するレイアウトプリセット
    ///   - gap: ウィンドウ間のギャップ（ピクセル）
    func setupZonesWithCurrentScreens(preset: ZoneLayoutPreset, gap: CGFloat) {
        let screenFrames = NSScreen.screens.map { $0.visibleFrame }
        setupZonesForScreens(screenFrames, preset: preset, gap: gap)
    }

    // MARK: - Per-Screen Preset Support

    /// 画面ごとに異なるプリセットでゾーンをセットアップする（デフォルト：Shiftのみ）
    /// ScreenLayoutManager から各画面の設定を取得する
    /// - Parameters:
    ///   - fallbackPreset: 設定がない画面に使用するフォールバックプリセット
    ///   - gap: ウィンドウ間のギャップ（ピクセル）
    func setupZonesWithPerScreenPresets(
        fallbackPreset: ZoneLayoutPreset = .halfLeftRight,
        gap: CGFloat = 0
    ) {
        setupZonesWithPerScreenPresets(modifiers: .shift, fallbackPreset: fallbackPreset, gap: gap)
    }

    /// 画面ごと × 修飾キーごとに異なるプリセットでゾーンをセットアップする
    /// ScreenLayoutManager から各画面の設定を取得する
    /// - Parameters:
    ///   - modifiers: 修飾キーの組み合わせ
    ///   - fallbackPreset: 設定がない画面に使用するフォールバックプリセット
    ///   - gap: ウィンドウ間のギャップ（ピクセル）
    func setupZonesWithPerScreenPresets(
        modifiers: ModifierFlags,
        fallbackPreset: ZoneLayoutPreset = .halfLeftRight,
        gap: CGFloat = 0
    ) {
        let layoutManager = ScreenLayoutManager.shared
        var allZones: [Zone] = []

        zoneLog("setupZonesWithPerScreenPresets called, modifiers: \(modifiers.displayName)")
        zoneLog("Available configs: \(layoutManager.screenConfigs.count)")

        for screen in NSScreen.screens {
            let identifier = ScreenIdentifier.from(screen)
            zoneLog("Screen: \(identifier.localizedName), frame: \(screen.frame), identifier: \(identifier.key)")

            let preset = layoutManager.preset(for: screen, modifiers: modifiers, fallback: fallbackPreset)
            zoneLog("  -> Using preset: \(preset.name) (id: \(preset.id))")

            let zonesForScreen = preset.generateZones(for: screen.visibleFrame, gap: gap)
            zoneLog("  -> Generated \(zonesForScreen.count) zones")
            allZones.append(contentsOf: zonesForScreen)
        }

        zones = allZones
        zoneLog("Total zones: \(zones.count)")
    }

    /// ゾーンを直接設定する（テスト用および内部用）
    /// - Parameter newZones: 設定するゾーン配列
    func setZones(_ newZones: [Zone]) {
        zones = newZones
    }
}
