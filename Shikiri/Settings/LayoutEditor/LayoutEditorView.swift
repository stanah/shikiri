import SwiftUI
import AppKit

/// レイアウトエディタのメインビュー
struct LayoutEditorView: View {
    /// レイアウトマネージャー
    @ObservedObject private var layoutManager = ScreenLayoutManager.shared

    /// 接続されている画面のリスト
    @State private var screens: [NSScreen] = NSScreen.screens

    /// 選択中の画面インデックス
    @State private var selectedScreenIndex: Int = 0

    /// 選択中の修飾キー
    @State private var selectedModifiers: ModifierFlags = .shift

    /// 編集中のゾーン定義
    @State private var editingZones: [ZoneDefinition] = []

    /// 選択中のプリセットID
    @State private var selectedPresetId: String?

    /// 編集モードかどうか
    @State private var isEditing: Bool = false

    /// 選択中のゾーンインデックス
    @State private var selectedZoneIndex: Int?

    /// 変更があるかどうか
    @State private var hasChanges: Bool = false

    /// 利用可能な修飾キーの組み合わせ
    private let availableModifiers: [ModifierFlags] = [
        .shift,
        ModifierFlags([.shift, .option]),
        ModifierFlags([.shift, .control])
    ]

    // MARK: - Body

    var body: some View {
        HSplitView {
            // 左ペイン: 画面プレビュー
            previewPane
                .frame(minWidth: 350)

            // 右ペイン: コントロールパネル
            controlPane
                .frame(minWidth: 200, maxWidth: 280)
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            loadCurrentConfig()
        }
    }

    // MARK: - Preview Pane

    private var previewPane: some View {
        VStack(spacing: 0) {
            // 画面選択タブ
            screenTabs

            Divider()

            // 修飾キー選択タブ
            modifierTabs

            Divider()

            // 画面プレビュー
            if screens.indices.contains(selectedScreenIndex) {
                let screen = screens[selectedScreenIndex]
                let identifier = ScreenIdentifier.from(screen)

                ScreenPreviewCanvas(
                    screenIdentifier: identifier,
                    screenFrame: screen.frame,
                    zones: $editingZones,
                    isEditing: isEditing,
                    selectedZoneIndex: $selectedZoneIndex
                )
                .padding()
                .onChange(of: editingZones) { _, _ in
                    hasChanges = true
                }
            } else {
                Text("画面が見つかりません")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Screen Tabs

    private var screenTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(screens.indices, id: \.self) { index in
                    screenTabButton(for: index)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color.secondary.opacity(0.1))
    }

    private func screenTabButton(for index: Int) -> some View {
        let screen = screens[index]
        let identifier = ScreenIdentifier.from(screen)
        let isSelected = selectedScreenIndex == index

        return Button(action: {
            selectScreen(at: index)
        }) {
            VStack(spacing: 2) {
                Image(systemName: identifier.isPortrait ? "rectangle.portrait" : "rectangle")
                    .font(.system(size: 16))

                Text(screen.localizedName)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Modifier Tabs

    private var modifierTabs: some View {
        HStack(spacing: 8) {
            Text("修飾キー:")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(availableModifiers, id: \.rawValue) { modifiers in
                modifierTabButton(for: modifiers)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.05))
    }

    private func modifierTabButton(for modifiers: ModifierFlags) -> some View {
        let isSelected = selectedModifiers == modifiers

        return Button(action: {
            selectModifiers(modifiers)
        }) {
            Text(modifiers.displayName)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Control Pane

    private var controlPane: some View {
        VStack {
            if screens.indices.contains(selectedScreenIndex) {
                let identifier = ScreenIdentifier.from(screens[selectedScreenIndex])

                EditorControlPanel(
                    screenIdentifier: identifier,
                    zones: $editingZones,
                    selectedZoneIndex: $selectedZoneIndex,
                    selectedPresetId: $selectedPresetId,
                    isEditing: $isEditing,
                    onSave: saveConfig
                )
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Actions

    /// 画面を選択
    private func selectScreen(at index: Int) {
        guard index != selectedScreenIndex else { return }

        // 変更があれば保存確認
        if hasChanges {
            saveConfig()
        }

        selectedScreenIndex = index
        loadCurrentConfig()
    }

    /// 修飾キーを選択
    private func selectModifiers(_ modifiers: ModifierFlags) {
        guard modifiers != selectedModifiers else { return }

        // 変更があれば保存確認
        if hasChanges {
            saveConfig()
        }

        selectedModifiers = modifiers
        loadCurrentConfig()
    }

    /// 現在の設定を読み込み
    private func loadCurrentConfig() {
        guard screens.indices.contains(selectedScreenIndex) else { return }

        let screen = screens[selectedScreenIndex]
        let identifier = ScreenIdentifier.from(screen)

        // 画面の設定を取得
        if let config = layoutManager.config(for: identifier) {
            // 選択中の修飾キーに対する設定を取得
            if selectedModifiers == .shift {
                // Shiftのみの場合はデフォルト設定
                if let customPreset = config.customPreset {
                    editingZones = customPreset.zones
                    selectedPresetId = nil
                    isEditing = false
                } else if let presetId = config.selectedPresetId,
                          let preset = ZoneLayoutPreset.allPresets.first(where: { $0.id == presetId }) {
                    editingZones = preset.zones
                    selectedPresetId = presetId
                    isEditing = false
                } else {
                    loadDefaultPreset()
                }
            } else {
                // 他の修飾キーの場合
                if let modifierPreset = config.modifierPresets.first(where: { $0.modifiers == selectedModifiers.rawValue }) {
                    if let customPreset = modifierPreset.customPreset {
                        editingZones = customPreset.zones
                        selectedPresetId = nil
                        isEditing = false
                    } else if let presetId = modifierPreset.presetId,
                              let preset = ZoneLayoutPreset.allPresets.first(where: { $0.id == presetId }) {
                        editingZones = preset.zones
                        selectedPresetId = presetId
                        isEditing = false
                    } else {
                        loadDefaultPreset()
                    }
                } else {
                    loadDefaultPreset()
                }
            }
        } else {
            loadDefaultPreset()
        }

        selectedZoneIndex = nil
        hasChanges = false
    }

    /// デフォルトプリセットを読み込み
    private func loadDefaultPreset() {
        editingZones = ZoneLayoutPreset.halfLeftRight.zones
        selectedPresetId = "halfLeftRight"
        isEditing = false
    }

    /// 設定を保存
    private func saveConfig() {
        guard screens.indices.contains(selectedScreenIndex) else { return }

        let screen = screens[selectedScreenIndex]
        let identifier = ScreenIdentifier.from(screen)

        // 既存の設定を取得、なければ新規作成
        var config = layoutManager.config(for: identifier) ?? ScreenLayoutConfig(screenIdentifier: identifier)

        if let presetId = selectedPresetId {
            // プリセットを選択している場合
            config.setPreset(for: selectedModifiers, presetId: presetId)
        } else {
            // カスタムレイアウトの場合
            let customPreset = ZoneLayoutPreset(
                id: "custom_\(identifier.key)_\(selectedModifiers.displayName)",
                name: "\(screen.localizedName) \(selectedModifiers.displayName) カスタム",
                zones: editingZones
            )
            config.setCustomPreset(for: selectedModifiers, preset: customPreset)
        }

        layoutManager.setConfig(config)
        hasChanges = false
    }
}

// MARK: - Preview

#Preview {
    LayoutEditorView()
        .frame(width: 700, height: 500)
}
