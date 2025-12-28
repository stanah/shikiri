import SwiftUI

/// アプリケーションの設定を管理するクラス
/// @AppStorageを使用してUserDefaultsに永続化する
@MainActor
final class Settings: ObservableObject {
    // MARK: - Static Properties

    /// 共有インスタンス
    static let shared = Settings()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let isEnabled = "shikiri.isEnabled"
        static let showOverlayAnimation = "shikiri.showOverlayAnimation"
        static let windowGap = "shikiri.windowGap"
    }

    // MARK: - Published Properties

    /// スナップ機能が有効かどうか
    @AppStorage(Keys.isEnabled)
    var isEnabled = true

    /// オーバーレイアニメーションを表示するかどうか
    @AppStorage(Keys.showOverlayAnimation)
    var showOverlayAnimation = true

    /// ウィンドウ間のギャップ（ピクセル単位、0〜20）
    @AppStorage(Keys.windowGap)
    var windowGap: Double = 0

    /// ギャップの最小値
    static let minGap: Double = 0

    /// ギャップの最大値
    static let maxGap: Double = 20

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// 設定をデフォルト値にリセット
    func resetToDefaults() {
        isEnabled = true
        showOverlayAnimation = true
        windowGap = 0
    }
}
