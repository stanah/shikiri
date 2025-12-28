import ApplicationServices
import AppKit
import Foundation

/// スナップされたウィンドウを管理するマネージャー
/// ウィンドウの追跡、登録、解除、状態変更の検出を行う
@MainActor
final class SnappedWindowManager: ObservableObject {
    // MARK: - Published Properties

    /// 現在追跡中のスナップウィンドウ
    @Published private(set) var snappedWindows: [SnappedWindow] = []

    // MARK: - Dependencies

    private let windowController: WindowController

    // MARK: - Configuration

    /// スナップ解除と判定するしきい値（ピクセル）
    /// ウィンドウがゾーンからこの距離以上離れたらスナップ解除とみなす
    private let unsnappingThreshold: CGFloat = 50

    // MARK: - Initialization

    init(windowController: WindowController = WindowController()) {
        self.windowController = windowController
    }

    // MARK: - Public Methods

    /// ウィンドウをスナップウィンドウとして登録
    /// - Parameters:
    ///   - windowElement: ウィンドウのAXUIElement
    ///   - zoneId: スナップされるゾーンのID
    ///   - zone: ゾーン情報
    ///   - screenId: 画面識別子
    func registerSnappedWindow(
        windowElement: AXUIElement,
        zoneId: UUID,
        frame: CGRect,
        screenId: String
    ) {
        // 既に登録されている場合は更新
        if let index = snappedWindows.firstIndex(where: { isWindowElementEqual($0.windowElement, windowElement) }) {
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

    /// ウィンドウのスナップ登録を解除
    /// - Parameter windowElement: 解除するウィンドウのAXUIElement
    func unregisterSnappedWindow(_ windowElement: AXUIElement) {
        snappedWindows.removeAll { isWindowElementEqual($0.windowElement, windowElement) }
    }

    /// IDでウィンドウのスナップ登録を解除
    /// - Parameter id: スナップウィンドウのID
    func unregisterSnappedWindow(id: UUID) {
        snappedWindows.removeAll { $0.id == id }
    }

    /// 指定したゾーンにスナップされているウィンドウを取得
    /// - Parameter zoneId: ゾーンのID
    /// - Returns: スナップウィンドウ、見つからない場合はnil
    func snappedWindow(forZone zoneId: UUID) -> SnappedWindow? {
        return snappedWindows.first { $0.zoneId == zoneId }
    }

    /// 指定した画面上のすべてのスナップウィンドウを取得
    /// - Parameter screenId: 画面識別子
    /// - Returns: スナップウィンドウの配列
    func snappedWindows(forScreen screenId: String) -> [SnappedWindow] {
        return snappedWindows.filter { $0.screenId == screenId }
    }

    /// 全てのスナップウィンドウをクリア
    func clearAllSnappedWindows() {
        snappedWindows.removeAll()
    }

    /// スナップウィンドウの状態を更新
    /// ウィンドウが閉じられたり、大きく移動した場合は自動的に解除される
    func refreshSnappedWindowStates() {
        var windowsToRemove: [UUID] = []

        for snappedWindow in snappedWindows {
            // ウィンドウがまだ存在するか確認
            guard let currentFrame = try? windowController.getWindowFrame(snappedWindow.windowElement) else {
                // ウィンドウが取得できない（閉じられた可能性）
                windowsToRemove.append(snappedWindow.id)
                continue
            }

            // ウィンドウがゾーンから大きく離れたか確認
            let distance = frameDistance(snappedWindow.lastKnownFrame, currentFrame)
            if distance > unsnappingThreshold {
                windowsToRemove.append(snappedWindow.id)
            }
        }

        // 無効なウィンドウを削除
        for id in windowsToRemove {
            unregisterSnappedWindow(id: id)
        }
    }

    /// 隣接するスナップウィンドウを取得
    /// - Parameters:
    ///   - zone: 基準のゾーン
    ///   - direction: 検索方向
    /// - Returns: 隣接するスナップウィンドウの配列
    func adjacentSnappedWindows(to zoneId: UUID, inDirection direction: Direction) -> [SnappedWindow] {
        guard let baseWindow = snappedWindow(forZone: zoneId) else {
            return []
        }

        return snappedWindows.filter { window in
            guard window.zoneId != zoneId, window.screenId == baseWindow.screenId else {
                return false
            }

            return isAdjacent(baseWindow.lastKnownFrame, window.lastKnownFrame, in: direction)
        }
    }

    // MARK: - Private Methods

    /// 2つのAXUIElementが同じウィンドウを参照しているかを判定
    private func isWindowElementEqual(_ lhs: AXUIElement, _ rhs: AXUIElement) -> Bool {
        // AXUIElementはCFTypeRefを継承しているので、CFEqualで比較可能
        return CFEqual(lhs, rhs)
    }

    /// 2つのフレーム間の距離を計算
    private func frameDistance(_ frame1: CGRect, _ frame2: CGRect) -> CGFloat {
        let dx = abs(frame1.origin.x - frame2.origin.x)
        let dy = abs(frame1.origin.y - frame2.origin.y)
        let dWidth = abs(frame1.width - frame2.width)
        let dHeight = abs(frame1.height - frame2.height)

        return max(dx, dy, dWidth, dHeight)
    }

    /// 2つのフレームが指定方向で隣接しているかを判定
    private func isAdjacent(_ frame1: CGRect, _ frame2: CGRect, in direction: Direction) -> Bool {
        let tolerance: CGFloat = 10 // 許容誤差

        switch direction {
        case .left:
            // frame2がframe1の左側にある
            return abs(frame2.maxX - frame1.minX) < tolerance &&
                   hasVerticalOverlap(frame1, frame2)
        case .right:
            // frame2がframe1の右側にある
            return abs(frame1.maxX - frame2.minX) < tolerance &&
                   hasVerticalOverlap(frame1, frame2)
        case .up:
            // frame2がframe1の上側にある（macOS座標系では上が大きい）
            return abs(frame1.maxY - frame2.minY) < tolerance &&
                   hasHorizontalOverlap(frame1, frame2)
        case .down:
            // frame2がframe1の下側にある
            return abs(frame2.maxY - frame1.minY) < tolerance &&
                   hasHorizontalOverlap(frame1, frame2)
        }
    }

    /// 2つのフレームが垂直方向でオーバーラップしているかを判定
    private func hasVerticalOverlap(_ frame1: CGRect, _ frame2: CGRect) -> Bool {
        return frame1.minY < frame2.maxY && frame1.maxY > frame2.minY
    }

    /// 2つのフレームが水平方向でオーバーラップしているかを判定
    private func hasHorizontalOverlap(_ frame1: CGRect, _ frame2: CGRect) -> Bool {
        return frame1.minX < frame2.maxX && frame1.maxX > frame2.minX
    }
}

// MARK: - Direction

/// 方向を表す列挙型
enum Direction {
    case left
    case right
    case up
    case down
}
