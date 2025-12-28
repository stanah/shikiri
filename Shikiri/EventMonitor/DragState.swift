import CoreGraphics

/// ドラッグ操作の状態を表す列挙型
enum DragState: Equatable {
    /// ドラッグしていない状態
    case idle
    /// ドラッグ開始（スナップモード判定中）
    case dragging(startPosition: CGPoint)
    /// スナップモードでドラッグ中
    case snapping(startPosition: CGPoint)
    /// 境界ドラッグ中
    case boundaryDragging(startPosition: CGPoint)
}
