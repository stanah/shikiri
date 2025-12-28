import ApplicationServices
import AppKit
import Foundation

/// 境界ドラッグによるウィンドウリサイズを調整するコーディネーター
/// ゾーン境界のドラッグ検出と、隣接ウィンドウの連動リサイズを行う
@MainActor
final class BoundaryDragCoordinator: ObservableObject {
    // MARK: - Constants

    /// ウィンドウの最小幅（ピクセル）
    static let minimumWindowWidth: CGFloat = 200

    /// ウィンドウの最小高さ（ピクセル）
    static let minimumWindowHeight: CGFloat = 100

    /// 境界検出の許容範囲（ピクセル）
    static let boundaryTolerance: CGFloat = 10

    // MARK: - Published Properties

    /// ドラッグ中かどうか
    @Published private(set) var isDragging = false

    /// 現在アクティブな境界
    @Published private(set) var activeBoundary: ZoneBoundary?

    // MARK: - Properties

    /// 検出された境界の配列
    private(set) var boundaries: [ZoneBoundary] = []

    /// スナップされているウィンドウの配列
    private(set) var snappedWindows: [SnappedWindow] = []

    /// ドラッグ開始位置
    private var dragStartPosition: CGPoint?

    /// 現在の累積移動量
    private var currentDelta: CGFloat = 0

    // MARK: - Dependencies

    private let windowController: WindowControlling

    // MARK: - Initialization

    init(windowController: WindowControlling = WindowController()) {
        self.windowController = windowController
    }

    // MARK: - Boundary Setup

    /// ゾーンの配列から境界を検出してセットアップ
    /// - Parameter zones: ゾーンの配列
    func setupBoundaries(from zones: [Zone]) {
        boundaries = BoundaryManager.detectBoundaries(from: zones)
    }

    /// 境界をクリア
    func clearBoundaries() {
        boundaries.removeAll()
    }

    // MARK: - Snapped Window Management

    /// ウィンドウをスナップウィンドウとして登録
    func registerSnappedWindow(
        windowElement: AXUIElement,
        zoneId: UUID,
        frame: CGRect,
        screenId: String
    ) {
        // 既に登録されている場合は更新
        if let index = snappedWindows.firstIndex(where: { CFEqual($0.windowElement, windowElement) }) {
            snappedWindows[index] = SnappedWindow(
                id: snappedWindows[index].id,
                windowElement: windowElement,
                zoneId: zoneId,
                screenId: screenId,
                lastKnownFrame: frame
            )
            return
        }

        // 新規登録
        let snappedWindow = SnappedWindow(
            windowElement: windowElement,
            zoneId: zoneId,
            screenId: screenId,
            lastKnownFrame: frame
        )
        snappedWindows.append(snappedWindow)
    }

    /// スナップウィンドウの登録を解除
    func unregisterSnappedWindow(id: UUID) {
        snappedWindows.removeAll { $0.id == id }
    }

    /// 全てのスナップウィンドウをクリア
    func clearAllSnappedWindows() {
        snappedWindows.removeAll()
    }

    // MARK: - Drag Handling

    /// 指定位置が境界上かチェックし、境界上ならドラッグを開始
    /// - Parameter position: マウス位置
    /// - Returns: ドラッグを開始した場合はtrue
    func startDragIfOnBoundary(at position: CGPoint) -> Bool {
        guard let boundary = BoundaryManager.boundaryAt(
            point: position,
            in: boundaries,
            tolerance: Self.boundaryTolerance
        ) else {
            return false
        }

        isDragging = true
        activeBoundary = boundary
        dragStartPosition = position
        currentDelta = 0

        return true
    }

    /// 境界上かどうかをチェック
    /// - Parameter position: マウス位置
    /// - Returns: 境界上にある場合はその境界、そうでなければnil
    func boundaryAt(position: CGPoint) -> ZoneBoundary? {
        return BoundaryManager.boundaryAt(
            point: position,
            in: boundaries,
            tolerance: Self.boundaryTolerance
        )
    }

    /// ドラッグ位置を更新
    /// - Parameter position: 現在のマウス位置
    /// - Returns: 移動量（ピクセル）
    func updateDrag(to position: CGPoint) -> CGFloat {
        guard isDragging,
              let boundary = activeBoundary,
              let startPosition = dragStartPosition else {
            return 0
        }

        // 境界の向きに応じた移動量を計算
        let rawDelta: CGFloat
        switch boundary.orientation {
        case .vertical:
            rawDelta = position.x - startPosition.x
        case .horizontal:
            rawDelta = position.y - startPosition.y
        }

        // 最小サイズ制約を適用
        currentDelta = clampDelta(rawDelta, for: boundary)

        return currentDelta
    }

    /// リサイズを適用
    func applyResize() {
        guard isDragging,
              let boundary = activeBoundary,
              currentDelta != 0 else {
            return
        }

        // 境界に隣接するウィンドウを取得
        let leftOrTopWindow = snappedWindows.first { $0.zoneId == boundary.leftOrTopZoneId }
        let rightOrBottomWindow = snappedWindows.first { $0.zoneId == boundary.rightOrBottomZoneId }

        // 左/上のウィンドウをリサイズ
        if let window = leftOrTopWindow {
            let newFrame = calculateNewFrame(for: window, boundary: boundary, isLeftOrTop: true)
            do {
                try windowController.setWindowFrame(window.windowElement, frame: newFrame)
            } catch {
                print("BoundaryDragCoordinator: Failed to resize left/top window: \(error)")
            }
        }

        // 右/下のウィンドウをリサイズ
        if let window = rightOrBottomWindow {
            let newFrame = calculateNewFrame(for: window, boundary: boundary, isLeftOrTop: false)
            do {
                try windowController.setWindowFrame(window.windowElement, frame: newFrame)
            } catch {
                print("BoundaryDragCoordinator: Failed to resize right/bottom window: \(error)")
            }
        }
    }

    /// ドラッグを終了
    func endDrag() {
        isDragging = false
        activeBoundary = nil
        dragStartPosition = nil
        currentDelta = 0
    }

    // MARK: - Private Methods

    /// 移動量を最小サイズ制約に基づいてクランプ
    private func clampDelta(_ delta: CGFloat, for boundary: ZoneBoundary) -> CGFloat {
        let leftOrTopWindow = snappedWindows.first { $0.zoneId == boundary.leftOrTopZoneId }
        let rightOrBottomWindow = snappedWindows.first { $0.zoneId == boundary.rightOrBottomZoneId }

        var clampedDelta = delta

        switch boundary.orientation {
        case .vertical:
            // 左のウィンドウの最小幅を確保
            if let leftWindow = leftOrTopWindow {
                let minDelta = Self.minimumWindowWidth - leftWindow.lastKnownFrame.width
                clampedDelta = max(clampedDelta, minDelta)
            }

            // 右のウィンドウの最小幅を確保
            if let rightWindow = rightOrBottomWindow {
                let maxDelta = rightWindow.lastKnownFrame.width - Self.minimumWindowWidth
                clampedDelta = min(clampedDelta, maxDelta)
            }

        case .horizontal:
            // 上のウィンドウの最小高さを確保
            if let topWindow = leftOrTopWindow {
                let minDelta = Self.minimumWindowHeight - topWindow.lastKnownFrame.height
                clampedDelta = max(clampedDelta, minDelta)
            }

            // 下のウィンドウの最小高さを確保
            if let bottomWindow = rightOrBottomWindow {
                let maxDelta = bottomWindow.lastKnownFrame.height - Self.minimumWindowHeight
                clampedDelta = min(clampedDelta, maxDelta)
            }
        }

        return clampedDelta
    }

    /// ウィンドウの新しいフレームを計算
    private func calculateNewFrame(for window: SnappedWindow, boundary: ZoneBoundary, isLeftOrTop: Bool) -> CGRect {
        var newFrame = window.lastKnownFrame

        switch boundary.orientation {
        case .vertical:
            if isLeftOrTop {
                // 左のウィンドウ：幅を変更
                newFrame.size.width += currentDelta
            } else {
                // 右のウィンドウ：x位置と幅を変更
                newFrame.origin.x += currentDelta
                newFrame.size.width -= currentDelta
            }

        case .horizontal:
            if isLeftOrTop {
                // 上のウィンドウ：高さを変更（macOS座標系では下端がminY）
                newFrame.size.height += currentDelta
            } else {
                // 下のウィンドウ：y位置と高さを変更
                newFrame.origin.y += currentDelta
                newFrame.size.height -= currentDelta
            }
        }

        return newFrame
    }
}
