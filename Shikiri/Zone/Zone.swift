import Foundation

/// 画面分割ゾーンを表すモデル
struct Zone: Identifiable, Equatable {
    /// ゾーンの一意識別子
    let id: UUID

    /// ゾーンのフレーム（位置とサイズ）
    let frame: NSRect

    /// ゾーンがハイライトされているかどうか
    var isHighlighted: Bool

    /// 初期化
    /// - Parameter frame: ゾーンのフレーム
    init(frame: NSRect) {
        self.id = UUID()
        self.frame = frame
        self.isHighlighted = false
    }

    /// 既存のIDを指定して初期化
    /// - Parameters:
    ///   - id: ゾーンの識別子
    ///   - frame: ゾーンのフレーム
    init(id: UUID, frame: NSRect) {
        self.id = id
        self.frame = frame
        self.isHighlighted = false
    }

    /// 指定した点がゾーン内に含まれるかを判定
    /// - Parameter point: 判定対象の点
    /// - Returns: 点がゾーン内にある場合はtrue
    func contains(point: NSPoint) -> Bool {
        return frame.contains(point)
    }
}
