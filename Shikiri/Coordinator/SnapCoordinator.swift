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

/// ログを出力する
private func snapLog(_ message: String) {
    ShikiriLogger.log(message, category: "SnapCoordinator")
}

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

    /// モード決定待ちかどうか（ドラッグ開始直後、移動かリサイズか未確定）
    private var isPendingModeDecision = false

    /// 境界リサイズモードかどうか（スナップ済みウィンドウをリサイズ中）
    private var isBoundaryResizeMode = false

    /// 境界リサイズのドラッグ開始位置
    private var boundaryResizeStartPosition: CGPoint?

    /// 隣接ウィンドウの要素
    private var adjacentWindowElement: AXUIElement?

    /// 隣接ウィンドウの初期フレーム
    private var adjacentWindowInitialFrame: CGRect?

    /// ドラッグ中のエッジの向き
    private var draggingEdgeOrientation: BoundaryOrientation?

    /// 現在の修飾キー（モード決定時にゾーン生成に使用）
    private var pendingModifiers: ModifierFlags = .command

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
    func handleSnapModeStarted(with windowInfo: DraggedWindowInfo?, modifiers: ModifierFlags = .command) {
        snapLog("handleSnapModeStarted called, windowInfo: \(windowInfo != nil), modifiers: \(modifiers.displayName)")

        guard let windowInfo = windowInfo else {
            // ウィンドウ情報がない場合はスナップを開始しない
            snapLog("No windowInfo, returning without starting snap mode")
            return
        }

        // ウィンドウ情報と修飾キーを保存
        currentWindowInfo = windowInfo
        pendingModifiers = modifiers
        currentPreset = nil
        isSnapping = true

        // 直接スナップモードに入る（オーバーレイを表示）
        enterSnapMode()
    }

    /// 隣接するウィンドウを探す
    private func findAdjacentWindow(
        to windowElement: AXUIElement,
        at edgePosition: CGFloat,
        orientation: BoundaryOrientation,
        windowFrame: CGRect
    ) -> AXUIElement? {
        // 隣接判定の許容範囲（ウィンドウ間のギャップ + マージン）
        let adjacentTolerance: CGFloat = CGFloat(Settings.shared.windowGap) + 5

        // 画面上の全ウィンドウを取得
        let windows = getAllWindows()

        for window in windows {
            // 自分自身はスキップ
            if CFEqual(window, windowElement) {
                continue
            }

            guard let frame = getWindowFrame(window) else {
                continue
            }

            switch orientation {
            case .vertical:
                // 垂直方向のエッジ（左右）の場合
                // Y座標の範囲が重なっているか確認
                let overlapMinY = max(windowFrame.minY, frame.minY)
                let overlapMaxY = min(windowFrame.maxY, frame.maxY)
                guard overlapMinY < overlapMaxY else { continue }

                // 隣接しているか確認（エッジ位置が近い）
                if abs(frame.maxX - edgePosition) < adjacentTolerance ||
                   abs(frame.minX - edgePosition) < adjacentTolerance {
                    snapLog(" Found adjacent window at vertical edge")
                    return window
                }

            case .horizontal:
                // 水平方向のエッジ（上下）の場合
                // X座標の範囲が重なっているか確認
                let overlapMinX = max(windowFrame.minX, frame.minX)
                let overlapMaxX = min(windowFrame.maxX, frame.maxX)
                guard overlapMinX < overlapMaxX else { continue }

                // 隣接しているか確認（エッジ位置が近い）
                if abs(frame.maxY - edgePosition) < adjacentTolerance ||
                   abs(frame.minY - edgePosition) < adjacentTolerance {
                    snapLog(" Found adjacent window at horizontal edge")
                    return window
                }
            }
        }

        return nil
    }

    /// 画面上の全ウィンドウを取得
    private func getAllWindows() -> [AXUIElement] {
        var windows: [AXUIElement] = []

        // 実行中のアプリケーションを取得
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        for app in runningApps {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                appElement,
                kAXWindowsAttribute as CFString,
                &windowsRef
            )

            if result == .success, let windowArray = windowsRef as? [AXUIElement] {
                windows.append(contentsOf: windowArray)
            }
        }

        return windows
    }

    /// ウィンドウのフレームを取得（Quartz座標系）
    private func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        let posResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

        guard posResult == .success, sizeResult == .success,
              let positionRef = positionRef, let sizeRef = sizeRef else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        return CGRect(origin: position, size: size)
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

    /// サイズ変化を確認してモードを決定
    private func decideModeBasedOnSizeChange() {
        guard isPendingModeDecision, let windowInfo = currentWindowInfo else { return }

        isPendingModeDecision = false

        // 現在のウィンドウサイズを取得
        guard let currentSize = getWindowSize(windowInfo.windowElement) else {
            snapLog("Could not get current window size, defaulting to snap mode")
            enterSnapMode()
            return
        }

        let initialSize = windowInfo.initialSize
        let sizeTolerance: CGFloat = 5  // 5ピクセルの許容誤差

        let widthChanged = abs(currentSize.width - initialSize.width) > sizeTolerance
        let heightChanged = abs(currentSize.height - initialSize.height) > sizeTolerance

        snapLog("Size check: initial=\(initialSize), current=\(currentSize), widthChanged=\(widthChanged), heightChanged=\(heightChanged)")

        if widthChanged || heightChanged {
            // サイズが変化した → リサイズ中 → 境界リサイズモード
            snapLog("Size changed, entering boundary resize mode")
            enterBoundaryResizeMode(windowInfo: windowInfo)
        } else {
            // サイズが変化していない → 移動中 → 通常スナップモード
            snapLog("Size unchanged, entering snap mode")
            enterSnapMode()
        }
    }

    /// 通常のスナップモードに入る
    private func enterSnapMode() {
        // 画面ごと × 修飾キーごとの設定を使用
        zoneManager.setupZonesWithPerScreenPresets(
            modifiers: pendingModifiers,
            fallbackPreset: presetManager.currentPreset,
            gap: CGFloat(Settings.shared.windowGap)
        )

        snapLog("Showing overlay")
        overlayController.show()
    }

    /// 境界リサイズモードに入る
    private func enterBoundaryResizeMode(windowInfo: DraggedWindowInfo) {
        // 隣接ウィンドウを探す
        guard let adjacentWindow = findAdjacentWindowForResize(windowInfo: windowInfo) else {
            snapLog("No adjacent window found, falling back to snap mode")
            enterSnapMode()
            return
        }

        snapLog("Found adjacent window, entering boundary resize mode")

        isBoundaryResizeMode = true
        boundaryResizeStartPosition = windowInfo.dragStartMousePosition
        adjacentWindowElement = adjacentWindow.element
        adjacentWindowInitialFrame = adjacentWindow.initialFrame
        draggingEdgeOrientation = adjacentWindow.orientation
    }

    /// リサイズ用の隣接ウィンドウを探す
    private func findAdjacentWindowForResize(windowInfo: DraggedWindowInfo) -> (element: AXUIElement, initialFrame: CGRect, orientation: BoundaryOrientation)? {
        let windowFrame = CGRect(origin: windowInfo.initialPosition, size: windowInfo.initialSize)

        // 現在のウィンドウフレームを取得して、どの方向にリサイズされているか判定
        guard let currentFrame = getWindowFrame(windowInfo.windowElement) else {
            return nil
        }

        let initialSize = windowInfo.initialSize
        let widthDelta = currentFrame.width - initialSize.width
        let heightDelta = currentFrame.height - initialSize.height

        // どのエッジがリサイズされているかを判定
        var orientation: BoundaryOrientation
        var edgePosition: CGFloat

        if abs(widthDelta) > abs(heightDelta) {
            // 幅が変化 → 左右のエッジをリサイズ
            orientation = .vertical
            // 左端が変化したか右端が変化したかを判定
            if abs(currentFrame.minX - windowFrame.minX) > 1 {
                edgePosition = windowFrame.minX
            } else {
                edgePosition = windowFrame.maxX
            }
        } else {
            // 高さが変化 → 上下のエッジをリサイズ
            orientation = .horizontal
            // 上端が変化したか下端が変化したかを判定
            if abs(currentFrame.minY - windowFrame.minY) > 1 {
                edgePosition = windowFrame.minY
            } else {
                edgePosition = windowFrame.maxY
            }
        }

        // そのエッジに隣接するウィンドウを探す
        guard let adjacentWindow = findAdjacentWindow(
            to: windowInfo.windowElement,
            at: edgePosition,
            orientation: orientation,
            windowFrame: windowFrame
        ) else {
            return nil
        }

        guard let adjacentFrame = getWindowFrame(adjacentWindow) else {
            return nil
        }

        return (adjacentWindow, adjacentFrame, orientation)
    }

    /// ウィンドウのサイズを取得
    private func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var sizeRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

        guard result == .success, let sizeRef = sizeRef else {
            return nil
        }

        var size = CGSize.zero
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return size
    }

    /// 境界リサイズのドラッグ処理
    private func handleBoundaryResizeDrag(to position: CGPoint) {
        guard let startPosition = boundaryResizeStartPosition,
              let adjacentWindow = adjacentWindowElement,
              let initialFrame = adjacentWindowInitialFrame,
              let orientation = draggingEdgeOrientation else {
            return
        }

        // Cocoa座標をQuartz座標に変換
        let quartzPosition = convertCocoaToQuartzPoint(position)

        // 移動量を計算
        let delta: CGFloat
        switch orientation {
        case .vertical:
            delta = quartzPosition.x - startPosition.x
        case .horizontal:
            delta = quartzPosition.y - startPosition.y
        }

        // 隣接ウィンドウの新しいフレームを計算（Quartz座標系で計算）
        var newFrame = initialFrame

        switch orientation {
        case .vertical:
            // ドラッグしているエッジが隣接ウィンドウのどちら側かで処理を分ける
            // 隣接ウィンドウの右端がドラッグ位置に近い → 隣接ウィンドウは左側
            if abs(initialFrame.maxX - startPosition.x) < abs(initialFrame.minX - startPosition.x) {
                // 隣接ウィンドウが左側 → 幅を変更
                newFrame.size.width += delta
            } else {
                // 隣接ウィンドウが右側 → x位置と幅を変更
                newFrame.origin.x += delta
                newFrame.size.width -= delta
            }
        case .horizontal:
            if abs(initialFrame.maxY - startPosition.y) < abs(initialFrame.minY - startPosition.y) {
                // 隣接ウィンドウが上側 → 高さを変更
                newFrame.size.height += delta
            } else {
                // 隣接ウィンドウが下側 → y位置と高さを変更
                newFrame.origin.y += delta
                newFrame.size.height -= delta
            }
        }

        // 最小サイズチェック
        let minWidth: CGFloat = 200
        let minHeight: CGFloat = 100
        guard newFrame.width >= minWidth && newFrame.height >= minHeight else {
            return
        }

        // Quartz座標のままウィンドウをリサイズ
        do {
            try windowController.setWindowFrame(adjacentWindow, frame: newFrame)
        } catch {
            snapLog(" Failed to resize adjacent window: \(error)")
        }
    }

    /// Cocoa座標をQuartz座標に変換
    private func convertCocoaToQuartzPoint(_ cocoaPoint: CGPoint) -> CGPoint {
        guard let primaryScreen = NSScreen.screens.first else {
            return cocoaPoint
        }
        let primaryScreenHeight = primaryScreen.frame.height
        let quartzY = primaryScreenHeight - cocoaPoint.y
        return CGPoint(x: cocoaPoint.x, y: quartzY)
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
            snapLog(" Failed to set window frame: \(error)")
        }
    }

    /// 境界ドラッグ用にスナップウィンドウを登録
    private func registerSnappedWindowForBoundaryDrag(
        windowElement: AXUIElement,
        zone: Zone
    ) {
        guard let coordinator = boundaryDragCoordinator else {
            snapLog("registerSnappedWindow: No coordinator")
            return
        }

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

        snapLog("registerSnappedWindow: Registered window, total count: \(coordinator.snappedWindows.count), boundaries: \(coordinator.boundaries.count)")
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

    /// Commandキーの状態変化を処理
    /// - Parameter isPressed: Commandキーが押されているかどうか
    func handleCommandKeyStateChanged(_ isPressed: Bool) {
        if !isPressed && isSnapping {
            // Commandが離されたらスナップをキャンセル
            cancelSnap()
        }
    }

    /// 修飾キーの組み合わせ変化を処理
    /// - Parameter modifiers: 新しい修飾キーの組み合わせ
    func handleModifiersChanged(_ modifiers: ModifierFlags) {
        // スナップ中かつCommandが押されている場合のみオーバーレイを更新
        // Commandが離された場合はスナップモード終了処理で対応
        guard isSnapping, modifiers.containsCommand else { return }

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

        // モード決定待ち状態をクリア
        isPendingModeDecision = false

        // 境界リサイズモードの状態もクリア
        isBoundaryResizeMode = false
        boundaryResizeStartPosition = nil
        adjacentWindowElement = nil
        adjacentWindowInitialFrame = nil
        draggingEdgeOrientation = nil
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

    func eventMonitor(_ monitor: EventMonitor, commandKeyStateChanged isPressed: Bool) {
        handleCommandKeyStateChanged(isPressed)
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
