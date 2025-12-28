import AppKit

/// 画面構成変更を監視するクラス
/// ディスプレイの接続/切断/解像度変更時にコールバックを呼び出す
@MainActor
final class ScreenMonitor {
    // MARK: - Properties

    /// 画面構成が変更されたときのコールバック
    var onScreenConfigurationChanged: (() -> Void)?

    /// 監視が実行中かどうか
    private(set) var isMonitoring = false

    // MARK: - Initialization

    init() {}

    deinit {
        // Note: deinitはMainActorコンテキスト外で呼ばれる可能性があるため、
        // NotificationCenterからの削除は安全に行う必要がある
    }

    // MARK: - Public Methods

    /// 画面構成変更の監視を開始
    func startMonitoring() {
        guard !isMonitoring else { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenConfigurationChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        isMonitoring = true
    }

    /// 画面構成変更の監視を停止
    func stopMonitoring() {
        guard isMonitoring else { return }

        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        isMonitoring = false
    }

    // MARK: - Private Methods

    @objc private func handleScreenConfigurationChange(_ notification: Notification) {
        Task { @MainActor in
            onScreenConfigurationChanged?()
        }
    }
}
