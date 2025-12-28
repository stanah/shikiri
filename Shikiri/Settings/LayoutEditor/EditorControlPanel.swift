import SwiftUI

/// レイアウトエディタのコントロールパネル
struct EditorControlPanel: View {
    /// 対象画面の識別子
    let screenIdentifier: ScreenIdentifier

    /// 編集中のゾーン定義
    @Binding var zones: [ZoneDefinition]

    /// 選択中のゾーンインデックス
    @Binding var selectedZoneIndex: Int?

    /// 選択中のプリセットID
    @Binding var selectedPresetId: String?

    /// 編集モードかどうか
    @Binding var isEditing: Bool

    /// 保存コールバック
    var onSave: () -> Void

    /// 利用可能なプリセット
    private var availablePresets: [ZoneLayoutPreset] {
        ZoneLayoutPreset.allPresets + ScreenLayoutManager.shared.customPresets
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // プリセット選択
            presetSelector

            Divider()

            // 編集コントロール
            if isEditing {
                editControls
            }

            Divider()

            // アクションボタン
            actionButtons
        }
        .padding()
    }

    // MARK: - Preset Selector

    private var presetSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("プリセット")
                .font(.headline)

            Picker("プリセット", selection: $selectedPresetId) {
                Text("カスタム").tag(nil as String?)

                ForEach(availablePresets, id: \.id) { preset in
                    Text(preset.name).tag(preset.id as String?)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedPresetId) { _, newValue in
                if let presetId = newValue,
                   let preset = availablePresets.first(where: { $0.id == presetId }) {
                    zones = preset.zones
                    selectedZoneIndex = nil
                    isEditing = false
                }
            }
        }
    }

    // MARK: - Edit Controls

    private var editControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ゾーン編集")
                .font(.headline)

            HStack {
                // ゾーン追加
                Button(action: addZone) {
                    Label("追加", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                // ゾーン削除
                Button(action: removeSelectedZone) {
                    Label("削除", systemImage: "minus")
                }
                .buttonStyle(.bordered)
                .disabled(selectedZoneIndex == nil || zones.count <= 1)
            }

            // 選択中のゾーン情報
            if let index = selectedZoneIndex, index < zones.count {
                zoneInfoView(for: zones[index], index: index)
            }
        }
    }

    /// ゾーン情報ビュー
    private func zoneInfoView(for zone: ZoneDefinition, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ゾーン \(index + 1)")
                .font(.subheadline)
                .fontWeight(.medium)

            Grid(alignment: .leading, horizontalSpacing: 8) {
                GridRow {
                    Text("位置:")
                        .foregroundColor(.secondary)
                    Text("X: \(Int(zone.x * 100))%, Y: \(Int(zone.y * 100))%")
                }
                GridRow {
                    Text("サイズ:")
                        .foregroundColor(.secondary)
                    Text("W: \(Int(zone.width * 100))%, H: \(Int(zone.height * 100))%")
                }
            }
            .font(.caption)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack {
            if isEditing {
                Button("編集終了") {
                    isEditing = false
                    selectedZoneIndex = nil
                }
                .buttonStyle(.bordered)
            } else {
                Button("カスタマイズ") {
                    isEditing = true
                    selectedPresetId = nil
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button("保存") {
                onSave()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    /// ゾーンを追加
    private func addZone() {
        let newZone = ZoneDefinition(
            x: 0.1,
            y: 0.1,
            width: 0.3,
            height: 0.3
        )
        zones.append(newZone)
        selectedZoneIndex = zones.count - 1
    }

    /// 選択中のゾーンを削除
    private func removeSelectedZone() {
        guard let index = selectedZoneIndex, zones.count > 1 else { return }

        zones.remove(at: index)
        selectedZoneIndex = nil
    }
}
