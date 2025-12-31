import SwiftUI
import Combine
import AppKit

/// ログを出力する
private func debugLog(_ message: String) {
    ShikiriLogger.log(message, category: "App")
}

/// アプリの初期化と状態管理を担当するクラス
/// シングルトンとして機能し、アプリ起動時に自動的にスナップシステムを初期化する
@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    let accessibilityManager = AccessibilityManager()
    let snapManager = SnapCoordinatorManager()
    let settings = Settings.shared
    let presetManager = PresetManager.shared

    private var isInitialized = false

    private init() {
        debugLog("AppController: init called")
        // 次のランループでセットアップを実行（StateObject初期化完了後）
        Task { @MainActor in
            self.setupIfNeeded()
        }
    }

    func setupIfNeeded() {
        guard !isInitialized else { return }
        isInitialized = true

        debugLog("AppController: Setting up accessibility callbacks...")

        // アクセシビリティ権限が有効になったときにスナップシステムを開始
        accessibilityManager.onAccessibilityEnabled = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                if self.settings.isEnabled {
                    debugLog("AppController: Accessibility enabled, starting snap system")
                    self.snapManager.setup(presetManager: self.presetManager)
                }
            }
        }

        // アクセシビリティ権限が無効になったときにスナップシステムを停止
        accessibilityManager.onAccessibilityDisabled = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                debugLog("AppController: Accessibility disabled, stopping snap system")
                self.snapManager.stop()
            }
        }

        // 初回チェック：すでに権限がある場合は即座に開始
        if accessibilityManager.checkAccessibility() {
            debugLog("AppController: Already has accessibility permission")
            if settings.isEnabled {
                debugLog("AppController: Settings enabled, starting snap system")
                snapManager.setup(presetManager: presetManager)
            }
        } else {
            debugLog("AppController: No accessibility permission yet")
        }

        // 権限状態のポーリングを開始（権限変更を検出するため）
        accessibilityManager.startPolling()
    }

    func handleSettingsChange(isEnabled: Bool) {
        debugLog("AppController: Settings changed, isEnabled = \(isEnabled)")
        if isEnabled {
            if accessibilityManager.isAccessibilityEnabled {
                snapManager.setup(presetManager: presetManager)
            }
        } else {
            snapManager.stop()
        }
    }
}

@main
struct ShikiriApp: App {
    @StateObject private var appController = AppController.shared

    var body: some Scene {
        MenuBarExtra("Shikiri", systemImage: "rectangle.split.2x1") {
            ContentView(
                accessibilityManager: appController.accessibilityManager,
                settings: appController.settings
            )
            .onAppear {
                // メニューを開いた時に再チェック
                appController.accessibilityManager.checkAccessibility()
            }
            .onChange(of: appController.settings.isEnabled) { _, newValue in
                appController.handleSettingsChange(isEnabled: newValue)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
