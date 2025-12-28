import SwiftUI
import ApplicationServices

/// アクセシビリティ権限の管理を担当するクラス
@MainActor
final class AccessibilityManager: ObservableObject {
    /// アクセシビリティ権限が有効かどうか
    @Published private(set) var isAccessibilityEnabled = false

    private let axWrapper: AXWrapperProtocol
    private var pollingTask: Task<Void, Never>?

    /// 権限が有効になったときに呼ばれるコールバック
    var onAccessibilityEnabled: (() -> Void)?

    /// 権限が無効になったときに呼ばれるコールバック
    var onAccessibilityDisabled: (() -> Void)?

    init(axWrapper: AXWrapperProtocol = AXWrapper()) {
        self.axWrapper = axWrapper
    }

    /// 現在のアクセシビリティ権限状態をチェック
    /// - Returns: 権限が有効な場合はtrue
    @discardableResult
    func checkAccessibility() -> Bool {
        let trusted = axWrapper.isProcessTrusted()
        let wasEnabled = isAccessibilityEnabled
        isAccessibilityEnabled = trusted

        // 権限が無効→有効に変わった場合、コールバックを呼ぶ
        if !wasEnabled && trusted {
            onAccessibilityEnabled?()
        }

        // 権限が有効→無効に変わった場合、コールバックを呼ぶ
        if wasEnabled && !trusted {
            onAccessibilityDisabled?()
        }

        return trusted
    }

    /// アクセシビリティ権限をリクエスト
    /// システム設定ダイアログを表示する
    func requestAccessibility() {
        axWrapper.requestAccessibility()
    }

    /// 権限状態のポーリングを開始
    /// - Parameter interval: ポーリング間隔（秒）
    func startPolling(interval: TimeInterval = 1.0) {
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                self?.checkAccessibility()
            }
        }
    }

    /// 権限状態のポーリングを停止
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
