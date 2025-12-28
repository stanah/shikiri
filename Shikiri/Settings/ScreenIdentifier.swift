import AppKit

/// 画面を一意に識別するための構造体
/// localizedName と解像度の組み合わせで画面を識別する
struct ScreenIdentifier: Codable, Equatable, Hashable {
    /// 画面のローカライズ名（例: "Built-in Retina Display", "LG ULTRAGEAR+"）
    let localizedName: String

    /// 画面の幅（ピクセル）
    let width: Int

    /// 画面の高さ（ピクセル）
    let height: Int

    // MARK: - Computed Properties

    /// 一意識別用のキー文字列
    /// フォーマット: "{localizedName}_{width}x{height}"
    var key: String {
        "\(localizedName)_\(width)x\(height)"
    }

    /// 縦向き（ポートレート）かどうか
    /// 高さが幅より大きい場合にtrueを返す
    var isPortrait: Bool {
        height > width
    }

    /// アスペクト比（幅/高さ）
    var aspectRatio: CGFloat {
        guard height > 0 else { return 1.0 }
        return CGFloat(width) / CGFloat(height)
    }

    // MARK: - Factory Methods

    /// NSScreenから ScreenIdentifier を生成
    /// - Parameter screen: 対象の NSScreen
    /// - Returns: 画面識別子
    static func from(_ screen: NSScreen) -> ScreenIdentifier {
        ScreenIdentifier(
            localizedName: screen.localizedName,
            width: Int(screen.frame.width),
            height: Int(screen.frame.height)
        )
    }
}
