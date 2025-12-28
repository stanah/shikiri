import ApplicationServices
import AppKit
import CoreGraphics

// MARK: - Protocols for Dependency Injection

/// オーバーレイコントローラーのプロトコル
@MainActor
protocol OverlayControlling: AnyObject {
    var isVisible: Bool { get }
    func show()
    func hide()
    func refresh()
    func updateHighlightedZone(_ zoneId: UUID?)
    func clearHighlight()
}

/// ウィンドウコントローラーのプロトコル
@MainActor
protocol WindowControlling: AnyObject {
    func setWindowFrame(_ window: AXUIElement, frame: CGRect) throws
}

// MARK: - Protocol Extensions for Existing Classes

extension OverlayController: OverlayControlling {}

extension WindowController: WindowControlling {}

// MARK: - SnapCoordinator

/// スナップ処理全体を調整するコーディネーター
/// イベント監視、ゾーン管理、オーバーレイ、ウィンドウ操作を統合する
@MainActor
final class SnapCoordinator: EventMonitorDelegate {
    // MARK: - Properties

    /// スナップモードが有効かどうか
    private(set) var isSnapping = false

    /// 現在ドラッグ中のウィンドウ情報
    private(set) var currentWindowInfo: DraggedWindowInfo?

    /// 現在使用中のプリセット
    private(set) var currentPreset: ZoneLayoutPreset?

    /// 境界ドラッグが有効かどうか
    var isBoundaryDragEnabled: Bool {
        get { boundaryDragCoordinator != nil }
    }

    // MARK: - Dependencies

    private let zoneManager: ZoneManager
    private let overlayController: OverlayControlling
    private let windowController: WindowControlling
    private let presetManager: PresetManager

    /// 境界ドラッグコーディネーター（nilの場合は境界ドラッグ無効）
    private var boundaryDragCoordinator: BoundaryDragCoordinator?

    /// EventMonitorへの弱参照（境界ドラッグモード開始のため）
    private weak var eventMonitorRef: EventMonitor?

    // MARK: - Initialization

    /// 依存コンポーネントを注入して初期化
    /// - Parameters:
    ///   - zoneManager: ゾーンマネージャー
    ///   - overlayController: オーバーレイコントローラー
    ///   - windowController: ウィンドウコントローラー
    ///   - presetManager: プリセットマネージャー（省略時は共有インスタンスを使用）
    init(
        zoneManager: ZoneManager,
        overlayController: OverlayControlling,
        windowController: WindowControlling,
        presetManager: PresetManager = PresetManager.shared
    ) {
        self.zoneManager = zoneManager
        self.overlayController = overlayController
        self.windowController = windowController
        self.presetManager = presetManager
    }

    // MARK: - Public Methods

    /// 境界ドラッグモードを有効化
    /// - Parameters:
    ///   - windowController: ウィンドウコントローラー
    ///   - eventMonitor: イベントモニター（境界ドラッグ開始用）
    func enableBoundaryDrag(with windowController: WindowControlling, eventMonitor: EventMonitor? = nil) {
        guard boundaryDragCoordinator == nil else { return }

        boundaryDragCoordinator = BoundaryDragCoordinator(windowController: windowController)
        eventMonitorRef = eventMonitor

        // 現在のゾーンから境界を検出
        boundaryDragCoordinator?.setupBoundaries(from: zoneManager.zones)
    }

    /// 境界ドラッグモードを無効化
    func disableBoundaryDrag() {
        boundaryDragCoordinator = nil
    }

    /// スナップモードを開始
    /// - Parameters:
    ///   - windowInfo: ドラッグ対象のウィンドウ情報
    ///   - modifiers: 押されている修飾キーの組み合わせ
    func handleSnapModeStarted(with windowInfo: DraggedWindowInfo?, modifiers: ModifierFlags = .shift) {
        guard let windowInfo = windowInfo else {
            // ウィンドウ情報がない場合はスナップを開始しない
            return
        }

        // 画面ごと × 修飾キーごとの設定を使用
        // 各画面に対して、その画面の修飾キー設定に基づいたプリセットを適用
        zoneManager.setupZonesWithPerScreenPresets(
            modifiers: modifiers,
            fallbackPreset: presetManager.currentPreset,
            gap: CGFloat(Settings.shared.windowGap)
        )
        currentPreset = nil  // 画面ごとに異なるため nil

        isSnapping = true
        currentWindowInfo = windowInfo
        overlayController.show()
    }

    /// ドラッグ中の移動を処理
    /// - Parameter position: マウスの現在位置
    func handleDragMoved(to position: CGPoint) {
        guard isSnapping else { return }

        // ゾーンの更新
        let point = NSPoint(x: position.x, y: position.y)
        zoneManager.updateActiveZone(for: point)

        // ハイライトの更新
        if let activeZone = zoneManager.activeZone {
            overlayController.updateHighlightedZone(activeZone.id)
        } else {
            overlayController.clearHighlight()
        }
    }

    /// スナップモードを終了（ウィンドウをスナップ）
    func handleSnapModeEnded() {
        defer {
            cleanupSnapState()
        }

        guard isSnapping,
              let windowInfo = currentWindowInfo,
              let activeZone = zoneManager.activeZone else {
            return
        }

        // ゾーンのフレームをCocoa座標からQuartz座標に変換
        // AXUIElementはQuartz座標（左上原点）を使用する
        let quartzFrame = convertCocoaToQuartzFrame(activeZone.frame)

        // ウィンドウをゾーンにスナップ
        do {
            try windowController.setWindowFrame(
                windowInfo.windowElement,
                frame: quartzFrame
            )

            // 境界ドラッグ用にスナップウィンドウを登録
            registerSnappedWindowForBoundaryDrag(
                windowElement: windowInfo.windowElement,
                zone: activeZone
            )
        } catch {
            // エラーが発生してもクリーンアップは行う
            print("SnapCoordinator: Failed to set window frame: \(error)")
        }
    }

    /// 境界ドラッグ用にスナップウィンドウを登録
    private func registerSnappedWindowForBoundaryDrag(
        windowElement: AXUIElement,
        zone: Zone
    ) {
        guard let coordinator = boundaryDragCoordinator else { return }

        // 画面IDを取得
        let screenId = getScreenId(for: zone.frame)

        coordinator.registerSnappedWindow(
            windowElement: windowElement,
            zoneId: zone.id,
            frame: zone.frame,
            screenId: screenId
        )

        // ゾーンから境界を再検出（ゾーンが変わっている可能性があるため）
        coordinator.setupBoundaries(from: zoneManager.zones)
    }

    // MARK: - Coordinate Conversion

    /// Cocoa座標系（左下原点）からQuartz座標系（左上原点）にフレームを変換
    /// - Parameter cocoaFrame: Cocoa座標系のフレーム
    /// - Returns: Quartz座標系のフレーム
    private func convertCocoaToQuartzFrame(_ cocoaFrame: CGRect) -> CGRect {
        // プライマリスクリーン（メニューバーがあるスクリーン）の高さを取得
        guard let primaryScreen = NSScreen.screens.first else {
            return cocoaFrame
        }
        let primaryScreenHeight = primaryScreen.frame.height

        // Cocoa座標のY（左下原点）をQuartz座標のY（左上原点）に変換
        // Quartz Y = 画面高さ - Cocoa Y - フレーム高さ
        let quartzY = primaryScreenHeight - cocoaFrame.origin.y - cocoaFrame.height

        return CGRect(
            x: cocoaFrame.origin.x,
            y: quartzY,
            width: cocoaFrame.width,
            height: cocoaFrame.height
        )
    }

    /// フレームが属する画面のIDを取得
    private func getScreenId(for frame: CGRect) -> String {
        // フレームの中心点を含む画面を探す
        let center = CGPoint(x: frame.midX, y: frame.midY)
        for screen in NSScreen.screens {
            if screen.frame.contains(center) {
                return screen.localizedName
            }
        }
        return NSScreen.main?.localizedName ?? "Main"
    }

    /// Shiftキーの状態変化を処理
    /// - Parameter isPressed: Shiftキーが押されているかどうか
    func handleShiftKeyStateChanged(_ isPressed: Bool) {
        if !isPressed && isSnapping {
            // Shiftが離されたらスナップをキャンセル
            cancelSnap()
        }
    }

    /// 修飾キーの組み合わせ変化を処理
    /// - Parameter modifiers: 新しい修飾キーの組み合わせ
    func handleModifiersChanged(_ modifiers: ModifierFlags) {
        // スナップ中かつShiftが押されている場合のみオーバーレイを更新
        // Shiftが離された場合はスナップモード終了処理で対応
        guard isSnapping, modifiers.containsShift else { return }

        // スナップ中に修飾キーが変わったらゾーンを再生成してオーバーレイを更新
        // refreshOverlayを使って即座に切り替え（アニメーションなし）
        zoneManager.setupZonesWithPerScreenPresets(
            modifiers: modifiers,
            fallbackPreset: presetManager.currentPreset,
            gap: CGFloat(Settings.shared.windowGap)
        )

        overlayController.refresh()
    }

    /// スナップをキャンセル
    func cancelSnap() {
        cleanupSnapState()
    }

    // MARK: - Private Methods

    private func cleanupSnapState() {
        isSnapping = false
        currentWindowInfo = nil
        currentPreset = nil
        zoneManager.clearActiveZone()
        overlayController.hide()
    }

    // MARK: - EventMonitorDelegate

    func eventMonitor(_ monitor: EventMonitor, didStartSnapModeWith windowInfo: DraggedWindowInfo?, modifiers: ModifierFlags) {
        handleSnapModeStarted(with: windowInfo, modifiers: modifiers)
    }

    func eventMonitorDidEndSnapMode(_ monitor: EventMonitor) {
        handleSnapModeEnded()
    }

    func eventMonitor(_ monitor: EventMonitor, didDragTo position: CGPoint) {
        handleDragMoved(to: position)
    }

    func eventMonitor(_ monitor: EventMonitor, shiftKeyStateChanged isPressed: Bool) {
        handleShiftKeyStateChanged(isPressed)
    }

    func eventMonitor(_ monitor: EventMonitor, modifiersChanged modifiers: ModifierFlags) {
        handleModifiersChanged(modifiers)
    }

    // MARK: - Boundary Drag EventMonitorDelegate

    func eventMonitor(_ monitor: EventMonitor, didMoveTo position: CGPoint) {
        // 境界上にマウスがあるかチェックしてカーソルを変更
        handleMouseMoved(to: position, monitor: monitor)
    }

    func eventMonitor(_ monitor: EventMonitor, didStartBoundaryDragAt position: CGPoint) {
        // 境界ドラッグを開始
        handleBoundaryDragStarted(at: position)
    }

    func eventMonitor(_ monitor: EventMonitor, didBoundaryDragTo position: CGPoint) {
        // 境界ドラッグ中の移動を処理
        handleBoundaryDragMoved(to: position)
    }

    func eventMonitorDidEndBoundaryDrag(_ monitor: EventMonitor) {
        // 境界ドラッグを終了
        handleBoundaryDragEnded()
    }

    // MARK: - Boundary Drag Check

    func eventMonitor(_ monitor: EventMonitor, shouldStartBoundaryDragAt position: CGPoint) -> Bool {
        guard let coordinator = boundaryDragCoordinator else { return false }

        // 境界上にマウスがあるかチェック
        if coordinator.startDragIfOnBoundary(at: position) {
            // 境界ドラッグを開始
            monitor.startBoundaryDrag(at: position)
            return true
        }

        return false
    }

    // MARK: - Boundary Drag Handling

    /// マウス移動を処理（カーソル変更用）
    private func handleMouseMoved(to position: CGPoint, monitor: EventMonitor) {
        guard let coordinator = boundaryDragCoordinator else { return }

        // 境界上にマウスがあるかチェック
        if let boundary = coordinator.boundaryAt(position: position) {
            // カーソルを変更
            boundary.resizeCursor.set()
        } else {
            // デフォルトカーソルに戻す
            NSCursor.arrow.set()
        }
    }

    /// 境界ドラッグ開始
    private func handleBoundaryDragStarted(at position: CGPoint) {
        guard let coordinator = boundaryDragCoordinator else { return }

        // 境界上でドラッグ開始
        _ = coordinator.startDragIfOnBoundary(at: position)
    }

    /// 境界ドラッグ中の移動
    private func handleBoundaryDragMoved(to position: CGPoint) {
        guard let coordinator = boundaryDragCoordinator,
              coordinator.isDragging else { return }

        // ドラッグの差分を計算してリサイズを適用
        _ = coordinator.updateDrag(to: position)
        coordinator.applyResize()
    }

    /// 境界ドラッグ終了
    private func handleBoundaryDragEnded() {
        guard let coordinator = boundaryDragCoordinator else { return }

        coordinator.endDrag()
        NSCursor.arrow.set()
    }
}
