import ApplicationServices
import Foundation

/// スナップされたウィンドウを表すモデル
/// ウィンドウとそれがスナップされたゾーンの関連を保持する
struct SnappedWindow: Identifiable, Equatable {
    /// 一意識別子
    let id: UUID

    /// ウィンドウのAXUIElement（比較には使用しない）
    let windowElement: AXUIElement

    /// スナップされているゾーンのID
    let zoneId: UUID

    /// ウィンドウが属する画面の識別子
    let screenId: String

    /// 最後に確認されたウィンドウのフレーム
    var lastKnownFrame: CGRect

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        windowElement: AXUIElement,
        zoneId: UUID,
        screenId: String,
        lastKnownFrame: CGRect
    ) {
        self.id = id
        self.windowElement = windowElement
        self.zoneId = zoneId
        self.screenId = screenId
        self.lastKnownFrame = lastKnownFrame
    }

    // MARK: - Equatable

    /// AXUIElementは比較できないため、idで比較
    static func == (lhs: SnappedWindow, rhs: SnappedWindow) -> Bool {
        return lhs.id == rhs.id
    }
}
