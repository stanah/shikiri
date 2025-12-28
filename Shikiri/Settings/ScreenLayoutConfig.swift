import Foundation

/// 画面ごと × 修飾キーごとのプリセット設定
struct ScreenModifierPreset: Codable, Equatable {
    /// 修飾キーの組み合わせ（ModifierFlags.rawValue）
    let modifiers: UInt64

    /// 割り当てられたプリセットのID（nilなら未設定）
    var presetId: String?

    /// カスタムプリセット（nilならビルトインを使用）
    var customPreset: ZoneLayoutPreset?

    /// 修飾キーの表示名を取得
    var modifiersDisplayName: String {
        ModifierFlags(rawValue: modifiers).displayName
    }

    /// この設定が有効か（プリセットが設定されているか）
    var isConfigured: Bool {
        presetId != nil || customPreset != nil
    }

    /// プリセットを取得
    func effectivePreset(fallback: ZoneLayoutPreset) -> ZoneLayoutPreset {
        if let custom = customPreset {
            return custom
        }
        if let presetId = presetId,
           let preset = ZoneLayoutPreset.allPresets.first(where: { $0.id == presetId }) {
            return preset
        }
        return fallback
    }
}

/// 画面ごとのレイアウト設定
/// 各画面に適用するプリセットを管理する（修飾キーごとに異なる設定が可能）
struct ScreenLayoutConfig: Codable, Equatable, Identifiable {
    /// 対象画面の識別子
    let screenIdentifier: ScreenIdentifier

    /// デフォルトのプリセットID（Shiftのみの場合に使用、nilならフォールバック）
    var selectedPresetId: String?

    /// デフォルトのカスタムプリセット（Shiftのみの場合に使用）
    var customPreset: ZoneLayoutPreset?

    /// 追加の修飾キーごとのプリセット設定（Shift+Option, Shift+Control など）
    var modifierPresets: [ScreenModifierPreset]

    // MARK: - Identifiable

    /// 設定のID（画面識別子のキーと同じ）
    var id: String {
        screenIdentifier.key
    }

    // MARK: - Initialization

    /// 画面識別子で初期化（プリセット未設定）
    /// - Parameter screenIdentifier: 対象画面の識別子
    init(screenIdentifier: ScreenIdentifier) {
        self.screenIdentifier = screenIdentifier
        self.selectedPresetId = nil
        self.customPreset = nil
        self.modifierPresets = []
    }

    /// 画面識別子とプリセットIDで初期化
    /// - Parameters:
    ///   - screenIdentifier: 対象画面の識別子
    ///   - selectedPresetId: 選択するプリセットのID
    init(screenIdentifier: ScreenIdentifier, selectedPresetId: String?) {
        self.screenIdentifier = screenIdentifier
        self.selectedPresetId = selectedPresetId
        self.customPreset = nil
        self.modifierPresets = []
    }

    // MARK: - Public Methods

    /// この画面に適用するプリセットを取得（デフォルト：Shiftのみ）
    /// 優先順位: カスタムプリセット > 選択中のビルトイン > フォールバック
    /// - Parameter fallback: フォールバックプリセット
    /// - Returns: 適用するプリセット
    func effectivePreset(fallback: ZoneLayoutPreset) -> ZoneLayoutPreset {
        // カスタムプリセットが設定されていればそれを使用
        if let custom = customPreset {
            return custom
        }

        // ビルトインプリセットIDが設定されていればそれを使用
        if let presetId = selectedPresetId,
           let preset = ZoneLayoutPreset.allPresets.first(where: { $0.id == presetId }) {
            return preset
        }

        // どちらも設定されていなければフォールバックを使用
        return fallback
    }

    /// 指定した修飾キーに対するプリセットを取得
    /// - Parameters:
    ///   - modifiers: 修飾キーの組み合わせ
    ///   - fallback: フォールバックプリセット
    /// - Returns: 適用するプリセット
    func effectivePreset(for modifiers: ModifierFlags, fallback: ZoneLayoutPreset) -> ZoneLayoutPreset {
        // Shiftのみの場合はデフォルト設定を使用
        if modifiers == .shift {
            return effectivePreset(fallback: fallback)
        }

        // 他の修飾キーの組み合わせの場合
        if let modifierPreset = modifierPresets.first(where: { $0.modifiers == modifiers.rawValue }),
           modifierPreset.isConfigured {
            return modifierPreset.effectivePreset(fallback: fallback)
        }

        // 設定がなければフォールバック
        return fallback
    }

    /// 指定した修飾キーのプリセット設定を更新
    /// - Parameters:
    ///   - modifiers: 修飾キーの組み合わせ
    ///   - presetId: プリセットID
    mutating func setPreset(for modifiers: ModifierFlags, presetId: String?) {
        if modifiers == .shift {
            selectedPresetId = presetId
            customPreset = nil
        } else {
            if let index = modifierPresets.firstIndex(where: { $0.modifiers == modifiers.rawValue }) {
                modifierPresets[index].presetId = presetId
                modifierPresets[index].customPreset = nil
            } else {
                modifierPresets.append(ScreenModifierPreset(
                    modifiers: modifiers.rawValue,
                    presetId: presetId,
                    customPreset: nil
                ))
            }
        }
    }

    /// 指定した修飾キーのカスタムプリセットを設定
    /// - Parameters:
    ///   - modifiers: 修飾キーの組み合わせ
    ///   - preset: カスタムプリセット
    mutating func setCustomPreset(for modifiers: ModifierFlags, preset: ZoneLayoutPreset?) {
        if modifiers == .shift {
            customPreset = preset
            if preset != nil {
                selectedPresetId = nil
            }
        } else {
            if let index = modifierPresets.firstIndex(where: { $0.modifiers == modifiers.rawValue }) {
                modifierPresets[index].customPreset = preset
                if preset != nil {
                    modifierPresets[index].presetId = nil
                }
            } else if let preset = preset {
                modifierPresets.append(ScreenModifierPreset(
                    modifiers: modifiers.rawValue,
                    presetId: nil,
                    customPreset: preset
                ))
            }
        }
    }

    /// 指定した修飾キーの現在のプリセットIDを取得
    /// - Parameter modifiers: 修飾キーの組み合わせ
    /// - Returns: プリセットID（未設定ならnil）
    func presetId(for modifiers: ModifierFlags) -> String? {
        if modifiers == .shift {
            return selectedPresetId
        }
        return modifierPresets.first { $0.modifiers == modifiers.rawValue }?.presetId
    }
}
