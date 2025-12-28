import ApplicationServices

/// Accessibility API操作を抽象化するプロトコル
/// テスト時にモックに差し替えるためのDI基盤として使用
protocol AXWrapperProtocol: Sendable {
    /// プロセスがAccessibility権限を持っているかチェック
    func isProcessTrusted() -> Bool
    /// Accessibility権限をリクエスト（システムダイアログを表示）
    func requestAccessibility()
}

/// 実際のAX APIを呼び出す本番用実装
struct AXWrapper: AXWrapperProtocol {
    func isProcessTrusted() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestAccessibility() {
        // kAXTrustedCheckOptionPrompt は "AXTrustedCheckOptionPrompt" と同じ値
        // Swift 6 Strict Concurrency では直接参照できないため、文字列リテラルを使用
        let options = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
