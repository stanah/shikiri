import Foundation
import ServiceManagement

/// ログイン時の自動起動を管理するクラス
/// macOS 13.0以降ではSMAppServiceを使用する
@MainActor
final class LaunchAtLoginManager: ObservableObject {

    // MARK: - Published Properties

    /// 自動起動が有効かどうか
    @Published private(set) var isEnabled: Bool = false

    // MARK: - Computed Properties

    /// この機能がシステムで利用可能かどうか
    /// macOS 13.0以降でのみ利用可能
    var isAvailable: Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }

    // MARK: - Initialization

    init() {
        refreshStatus()
    }

    // MARK: - Public Methods

    /// 自動起動の有効/無効を設定する
    /// - Parameter enabled: 有効にする場合はtrue
    func setEnabled(_ enabled: Bool) {
        guard isAvailable else { return }

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                refreshStatus()
            } catch {
                // エラーが発生した場合はログに記録
                print("[LaunchAtLogin] Error: \(error.localizedDescription)")
            }
        }
    }

    /// システムから現在の状態を取得して更新する
    func refreshStatus() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        } else {
            isEnabled = false
        }
    }
}
