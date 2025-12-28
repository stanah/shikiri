import SwiftUI

/// 設定画面のView
struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager

    init(
        settings: Settings,
        launchAtLoginManager: LaunchAtLoginManager = LaunchAtLoginManager()
    ) {
        self.settings = settings
        self.launchAtLoginManager = launchAtLoginManager
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // メイン設定
            Toggle("Shikiriを有効にする", isOn: $settings.isEnabled)

            Toggle("オーバーレイアニメーション", isOn: $settings.showOverlayAnimation)

            // 自動起動設定
            if launchAtLoginManager.isAvailable {
                Toggle("ログイン時に起動", isOn: Binding(
                    get: { launchAtLoginManager.isEnabled },
                    set: { launchAtLoginManager.setEnabled($0) }
                ))
            }

            // ウィンドウ間のギャップ設定
            windowGapView

            Divider()

            // レイアウト設定
            presetSelectionView

            Divider()

            // アプリ情報
            appInfoView

            Divider()

            // 終了ボタン
            Button("Shikiriを終了") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 320)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var windowGapView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("ウィンドウ間隔")
                Spacer()
                Text("\(Int(settings.windowGap))px")
                    .foregroundColor(.secondary)
            }

            Slider(
                value: $settings.windowGap,
                in: Settings.minGap...Settings.maxGap,
                step: 1
            )
        }
    }

    @ViewBuilder
    private var presetSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("レイアウト設定")
                .font(.headline)

            // レイアウトエディタを開くボタン
            Button(action: openLayoutEditor) {
                Label("画面ごとのレイアウトを設定...", systemImage: "rectangle.split.2x2")
            }
            .buttonStyle(.bordered)
        }
    }

    /// レイアウトエディタを開く
    private func openLayoutEditor() {
        LayoutEditorWindowController.shared.showWindow()
    }

    @ViewBuilder
    private var appInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Shikiri")
                .font(.headline)

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("バージョン \(version)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView(
        settings: Settings(),
        launchAtLoginManager: LaunchAtLoginManager()
    )
}
