import CoreGraphics
import ApplicationServices

/// ドラッグ対象のウィンドウ情報
struct DraggedWindowInfo: Equatable {
    /// ウィンドウのAXUIElement参照
    let windowElement: AXUIElement
    /// ウィンドウが属するアプリケーションのPID
    let pid: pid_t
    /// ドラッグ開始時のウィンドウ位置（Quartz座標系）
    let initialPosition: CGPoint
    /// ドラッグ開始時のウィンドウサイズ
    let initialSize: CGSize
    /// ドラッグ開始時のマウス位置（Quartz座標系）
    let dragStartMousePosition: CGPoint

    static func == (lhs: DraggedWindowInfo, rhs: DraggedWindowInfo) -> Bool {
        return lhs.pid == rhs.pid &&
               lhs.initialPosition == rhs.initialPosition &&
               lhs.initialSize == rhs.initialSize &&
               lhs.dragStartMousePosition == rhs.dragStartMousePosition
    }
}

/// イベントモニターのデリゲートプロトコル
/// ドラッグイベントやCommandキー状態の変化を通知する
@MainActor
protocol EventMonitorDelegate: AnyObject {
    /// スナップモード（Command+ドラッグ）が開始された
    /// - Parameters:
    ///   - monitor: イベントモニター
    ///   - windowInfo: ドラッグ対象のウィンドウ情報（取得できない場合はnil）
    ///   - modifiers: ドラッグ開始時の修飾キーの組み合わせ
    func eventMonitor(_ monitor: EventMonitor, didStartSnapModeWith windowInfo: DraggedWindowInfo?, modifiers: ModifierFlags)

    /// スナップモードが終了した
    func eventMonitorDidEndSnapMode(_ monitor: EventMonitor)

    /// ドラッグ中にマウスが移動した
    func eventMonitor(_ monitor: EventMonitor, didDragTo position: CGPoint)

    /// Commandキーの状態が変化した
    func eventMonitor(_ monitor: EventMonitor, commandKeyStateChanged isPressed: Bool)

    /// 修飾キーの組み合わせが変化した
    func eventMonitor(_ monitor: EventMonitor, modifiersChanged modifiers: ModifierFlags)

    // MARK: - Boundary Drag Events

    /// マウスが移動した（境界ドラッグのカーソル変更用）
    func eventMonitor(_ monitor: EventMonitor, didMoveTo position: CGPoint)

    /// 境界ドラッグモードが開始された
    func eventMonitor(_ monitor: EventMonitor, didStartBoundaryDragAt position: CGPoint)

    /// 境界ドラッグ中にマウスが移動した
    func eventMonitor(_ monitor: EventMonitor, didBoundaryDragTo position: CGPoint)

    /// 境界ドラッグモードが終了した
    func eventMonitorDidEndBoundaryDrag(_ monitor: EventMonitor)

    /// マウスダウン時に境界ドラッグを開始するかどうかを確認
    /// - Parameters:
    ///   - monitor: イベントモニター
    ///   - position: マウスダウン位置
    /// - Returns: 境界ドラッグを開始した場合はtrue（通常のドラッグ処理をスキップ）
    func eventMonitor(_ monitor: EventMonitor, shouldStartBoundaryDragAt position: CGPoint) -> Bool
}

// MARK: - Backward compatibility
extension EventMonitorDelegate {
    func eventMonitorDidStartSnapMode(_ monitor: EventMonitor) {
        eventMonitor(monitor, didStartSnapModeWith: nil, modifiers: .command)
    }

    func eventMonitor(_ monitor: EventMonitor, didStartSnapModeWith windowInfo: DraggedWindowInfo?) {
        eventMonitor(monitor, didStartSnapModeWith: windowInfo, modifiers: .command)
    }

    func eventMonitor(_ monitor: EventMonitor, commandKeyStateChanged isPressed: Bool) {
        // Optional method - default implementation does nothing
    }

    func eventMonitor(_ monitor: EventMonitor, modifiersChanged modifiers: ModifierFlags) {
        // Optional method - default implementation does nothing
    }

    // MARK: - Boundary Drag Default Implementations

    func eventMonitor(_ monitor: EventMonitor, didMoveTo position: CGPoint) {
        // Optional method - default implementation does nothing
    }

    func eventMonitor(_ monitor: EventMonitor, didStartBoundaryDragAt position: CGPoint) {
        // Optional method - default implementation does nothing
    }

    func eventMonitor(_ monitor: EventMonitor, didBoundaryDragTo position: CGPoint) {
        // Optional method - default implementation does nothing
    }

    func eventMonitorDidEndBoundaryDrag(_ monitor: EventMonitor) {
        // Optional method - default implementation does nothing
    }

    func eventMonitor(_ monitor: EventMonitor, shouldStartBoundaryDragAt position: CGPoint) -> Bool {
        // Default implementation - boundary drag not started
        return false
    }
}
