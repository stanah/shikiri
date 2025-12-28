import AppKit

/// スナップモード時に画面全体に表示される透明オーバーレイウィンドウ
/// ゾーンの視覚的表示に使用され、マウスイベントを通過させる
final class OverlayWindow: NSWindow {

    // MARK: - Initialization

    /// 指定したフレームでオーバーレイウィンドウを初期化
    /// - Parameter frame: ウィンドウのフレーム（通常はスクリーンのフレーム）
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        configureWindow()
    }

    // MARK: - Private Methods

    private func configureWindow() {
        // ウィンドウレベルを設定（他のウィンドウより前面に表示）
        level = .floating

        // 透明度の設定
        isOpaque = false
        backgroundColor = .clear

        // マウスイベントを通過させる
        ignoresMouseEvents = true

        // マルチディスプレイとフルスクリーン対応
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        // シャドウを無効化
        hasShadow = false
    }
}
