import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

/// ログをファイルに書き込む
private func eventLog(_ message: String) {
    let logPath = "/tmp/shikiri_app.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logMessage = "[\(timestamp)] [EventMonitor] \(message)\n"
    print("[EventMonitor] \(message)")
    if let data = logMessage.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logPath) {
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logPath, contents: data)
        }
    }
}

/// グローバルマウスイベントを監視するクラス
/// CGEventTapを使用してドラッグイベントとShiftキー状態を監視する
@MainActor
final class EventMonitor {
    // MARK: - Properties

    /// デリゲート
    weak var delegate: EventMonitorDelegate?

    /// 監視が実行中かどうか
    private(set) var isRunning = false

    /// Commandキーが押されているかどうか
    private(set) var isCommandKeyPressed = false

    /// 現在の修飾キーの組み合わせ
    private(set) var currentModifiers: ModifierFlags = ModifierFlags()

    /// 現在のドラッグ状態
    private(set) var dragState: DragState = .idle

    /// ドラッグ中のウィンドウ情報（ドラッグ開始時に取得して保存）
    private var draggingWindowInfo: DraggedWindowInfo?

    /// 境界ドラッグモードが有効かどうか
    /// trueの場合、マウス移動イベントと境界ドラッグイベントをデリゲートに通知する
    var isBoundaryDragModeEnabled = false

    // MARK: - Private Properties

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Initialization

    init() {}

    deinit {
        // Note: deinitはMainActorコンテキスト外で呼ばれる可能性があるため、
        // stopは非同期で実行する必要がある
    }

    // MARK: - Public Methods

    /// Input Monitoring権限を確認・リクエスト
    /// - Returns: 権限がある場合はtrue
    func checkAndRequestInputMonitoring() -> Bool {
        // Input Monitoring権限を確認
        let hasAccess = CGPreflightListenEventAccess()
        eventLog("Input Monitoring permission: \(hasAccess)")

        if !hasAccess {
            // 権限をリクエスト（システムダイアログが表示される）
            eventLog("Requesting Input Monitoring permission...")
            let granted = CGRequestListenEventAccess()
            eventLog("Input Monitoring permission granted: \(granted)")
            return granted
        }
        return true
    }

    /// イベント監視を開始
    func start() {
        guard !isRunning else {
            eventLog("Already running, skipping start()")
            return
        }

        eventLog("Starting event monitor...")

        // Input Monitoring権限を確認
        if !checkAndRequestInputMonitoring() {
            eventLog("Input Monitoring permission not granted. Cannot start event monitor.")
            return
        }

        // 監視するイベントタイプのマスク
        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        // イベントタップを作成
        // Note: Unmanaged.passUnretained(self)はselfの参照をCに渡すため、
        // selfが解放される前にstop()を呼ぶ必要がある
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            // コールバックが呼ばれたことを即座にログ出力
            NSLog("[EventMonitor] Callback received! type=%d", type.rawValue)

            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }

            let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()

            // MainActorコンテキストで処理を実行
            Task { @MainActor in
                monitor.handleEvent(type: type, event: event)
            }

            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap = eventTap else {
            // アクセシビリティ権限がない場合などはnilになる
            eventLog("Failed to create event tap. Check accessibility permissions.")
            eventLog("AXIsProcessTrusted = \(AXIsProcessTrusted())")
            return
        }

        eventLog("Event tap created successfully")

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource = runLoopSource else {
            eventLog("Failed to create run loop source")
            self.eventTap = nil
            return
        }

        // メインランループに追加（CFRunLoopGetCurrentではなくGetMainを使用）
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        // イベントタップが有効になっているか確認
        let tapEnabled = CGEvent.tapIsEnabled(tap: eventTap)
        eventLog("Event tap enabled: \(tapEnabled)")

        isRunning = true
        eventLog("Event monitor started successfully, isRunning = \(isRunning)")
    }

    /// イベント監視を停止
    func stop() {
        guard isRunning else { return }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil
        isRunning = false

        // 状態をリセット
        resetState()
    }

    // MARK: - Private Methods

    private func handleEvent(type: CGEventType, event: CGEvent) {
        // 全イベントをログ出力（デバッグ用）
        eventLog("Received event type: \(type.rawValue)")

        switch type {
        case .flagsChanged:
            eventLog("flagsChanged event received")
            handleFlagsChanged(event: event)

        case .leftMouseDown:
            handleMouseDown(event: event)

        case .leftMouseDragged:
            handleMouseDragged(event: event)

        case .leftMouseUp:
            handleMouseUp(event: event)

        case .mouseMoved:
            handleMouseMoved(event: event)

        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // イベントタップが無効化された場合は再有効化を試みる
            eventLog("Event tap disabled! Attempting to re-enable...")
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                let enabled = CGEvent.tapIsEnabled(tap: eventTap)
                eventLog("Re-enabled event tap: \(enabled)")
            }

        default:
            break
        }
    }

    private func handleFlagsChanged(event: CGEvent) {
        let newCommandState = event.flags.contains(.maskCommand)
        let newModifiers = ModifierFlags(cgEventFlags: event.flags)

        // 修飾キーの変化を通知
        if newModifiers != currentModifiers {
            let oldModifiers = currentModifiers
            currentModifiers = newModifiers
            eventLog("Modifiers changed: \(oldModifiers.displayName) -> \(newModifiers.displayName)")
            delegate?.eventMonitor(self, modifiersChanged: newModifiers)
        }

        if newCommandState != isCommandKeyPressed {
            isCommandKeyPressed = newCommandState
            eventLog("Command key state changed to \(newCommandState), dragState = \(dragState)")
            delegate?.eventMonitor(self, commandKeyStateChanged: newCommandState)
        }

        // ドラッグ中に修飾キーが変わった場合の処理
        switch dragState {
        case .dragging(let startPosition):
            // スナップ可能な修飾キーの組み合わせになったらスナップモード開始
            if newModifiers.containsCommand {
                dragState = .snapping(startPosition: startPosition)
                // ドラッグ開始時に保存したウィンドウ情報を使用
                eventLog("Starting snap mode with modifiers: \(newModifiers.displayName), windowInfo: \(String(describing: draggingWindowInfo))")
                delegate?.eventMonitor(self, didStartSnapModeWith: draggingWindowInfo, modifiers: newModifiers)
            }

        case .snapping(let startPosition):
            // スナップ修飾キーでなくなったらスナップモード終了
            // ただし、まだドラッグ中なので dragging 状態に戻す
            if !newModifiers.containsCommand {
                eventLog("Ending snap mode - modifiers no longer valid, back to dragging")
                dragState = .dragging(startPosition: startPosition)
                delegate?.eventMonitorDidEndSnapMode(self)
            }

        case .boundaryDragging:
            // 境界ドラッグ中は修飾キーの変化を無視
            break

        case .idle:
            break
        }
    }

    private func handleMouseDown(event: CGEvent) {
        let quartzPosition = event.location
        let cocoaPosition = convertQuartzToCocoaCoordinates(quartzPosition)
        // イベントから現在の修飾キーを取得して更新
        currentModifiers = ModifierFlags(cgEventFlags: event.flags)
        isCommandKeyPressed = event.flags.contains(.maskCommand)

        eventLog("Mouse down at \(cocoaPosition) (quartz: \(quartzPosition)), modifiers = \(currentModifiers.displayName)")

        // Command+境界上でクリック → 境界リサイズモードを優先
        // （ウィンドウ移動ドラッグより先にチェックする）
        if currentModifiers.containsCommand && isBoundaryDragModeEnabled {
            if let delegate = delegate, delegate.eventMonitor(self, shouldStartBoundaryDragAt: cocoaPosition) {
                eventLog("Boundary drag started by delegate at \(cocoaPosition)")
                return
            }
        }

        // スナップ可能な修飾キーの組み合わせならスナップモード開始
        if currentModifiers.containsCommand {
            dragState = .snapping(startPosition: cocoaPosition)
            // AXUIElementCopyElementAtPosition はQuartz座標を使用するため、quartzPositionを渡す
            // draggingWindowInfo に保存しておく（Command を離して再度押した時に使う）
            draggingWindowInfo = getWindowInfoAtPosition(quartzPosition)
            eventLog("Starting snap mode with modifiers: \(currentModifiers.displayName), windowInfo = \(String(describing: draggingWindowInfo))")
            delegate?.eventMonitor(self, didStartSnapModeWith: draggingWindowInfo, modifiers: currentModifiers)
            return
        }

        // 通常のドラッグ - ウィンドウ情報を取得して保存
        draggingWindowInfo = getWindowInfoAtPosition(quartzPosition)
        dragState = .dragging(startPosition: cocoaPosition)
    }

    /// 境界ドラッグモードを開始
    /// デリゲートが境界上でクリックされたことを検出した場合に呼び出す
    func startBoundaryDrag(at position: CGPoint) {
        guard isBoundaryDragModeEnabled else { return }

        dragState = .boundaryDragging(startPosition: position)
        eventLog("Starting boundary drag at \(position)")
        delegate?.eventMonitor(self, didStartBoundaryDragAt: position)
    }

    private func handleMouseDragged(event: CGEvent) {
        let quartzPosition = event.location
        let cocoaPosition = convertQuartzToCocoaCoordinates(quartzPosition)

        switch dragState {
        case .snapping:
            delegate?.eventMonitor(self, didDragTo: cocoaPosition)

        case .boundaryDragging:
            delegate?.eventMonitor(self, didBoundaryDragTo: cocoaPosition)

        case .dragging:
            // Shiftが押されていなければ通常のドラッグ（何もしない）
            break

        case .idle:
            // ドラッグイベントが来たが状態がidleの場合（異常ケース）
            dragState = .dragging(startPosition: cocoaPosition)
        }
    }

    private func handleMouseUp(event: CGEvent) {
        switch dragState {
        case .snapping:
            delegate?.eventMonitorDidEndSnapMode(self)

        case .boundaryDragging:
            delegate?.eventMonitorDidEndBoundaryDrag(self)

        case .dragging, .idle:
            break
        }

        dragState = .idle
        draggingWindowInfo = nil
    }

    private func handleMouseMoved(event: CGEvent) {
        // 境界ドラッグモードが有効な場合のみ通知
        guard isBoundaryDragModeEnabled else { return }

        let quartzPosition = event.location
        let cocoaPosition = convertQuartzToCocoaCoordinates(quartzPosition)
        delegate?.eventMonitor(self, didMoveTo: cocoaPosition)
    }

    private func resetState() {
        isCommandKeyPressed = false
        currentModifiers = ModifierFlags()
        dragState = .idle
        draggingWindowInfo = nil
    }

    // MARK: - Coordinate Conversion

    /// Quartz座標（左上原点）をCocoa座標（左下原点）に変換
    /// - Parameter quartzPoint: Quartz座標系の点
    /// - Returns: Cocoa座標系の点
    private func convertQuartzToCocoaCoordinates(_ quartzPoint: CGPoint) -> NSPoint {
        // プライマリスクリーン（メニューバーがあるスクリーン）の高さを取得
        // Cocoaでは左下原点、Quartzでは左上原点なので、Y座標を反転させる
        guard let primaryScreen = NSScreen.screens.first else {
            return NSPoint(x: quartzPoint.x, y: quartzPoint.y)
        }
        let primaryScreenHeight = primaryScreen.frame.height
        let cocoaY = primaryScreenHeight - quartzPoint.y
        return NSPoint(x: quartzPoint.x, y: cocoaY)
    }

    /// Cocoa座標（左下原点）をQuartz座標（左上原点）に変換
    /// - Parameter cocoaPoint: Cocoa座標系の点
    /// - Returns: Quartz座標系の点
    private func convertCocoaToQuartzCoordinates(_ cocoaPoint: NSPoint) -> CGPoint {
        guard let primaryScreen = NSScreen.screens.first else {
            return CGPoint(x: cocoaPoint.x, y: cocoaPoint.y)
        }
        let primaryScreenHeight = primaryScreen.frame.height
        let quartzY = primaryScreenHeight - cocoaPoint.y
        return CGPoint(x: cocoaPoint.x, y: quartzY)
    }

    /// 指定位置にあるウィンドウの情報を取得
    /// - Parameter mousePosition: マウスのクリック位置（Quartz座標系）
    private func getWindowInfoAtPosition(_ mousePosition: CGPoint) -> DraggedWindowInfo? {
        var element: AXUIElement?
        let systemWide = AXUIElementCreateSystemWide()

        // 指定位置にある要素を取得
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(mousePosition.x), Float(mousePosition.y), &element)

        guard result == .success, let element = element else {
            return nil
        }

        // ウィンドウ要素を取得（要素がウィンドウでない場合は親をたどる）
        let windowElement = findWindowElement(from: element)
        guard let windowElement = windowElement else {
            return nil
        }

        // PIDを取得
        var pid: pid_t = 0
        let pidResult = AXUIElementGetPid(windowElement, &pid)
        guard pidResult == .success else {
            return nil
        }

        // ウィンドウの位置とサイズを取得
        guard let windowPosition = getWindowPosition(windowElement),
              let windowSize = getWindowSize(windowElement) else {
            return nil
        }

        return DraggedWindowInfo(
            windowElement: windowElement,
            pid: pid,
            initialPosition: windowPosition,
            initialSize: windowSize,
            dragStartMousePosition: mousePosition
        )
    }

    /// 要素からウィンドウ要素を見つける
    private func findWindowElement(from element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        var role: CFTypeRef?

        while let currentElement = current {
            let result = AXUIElementCopyAttributeValue(currentElement, kAXRoleAttribute as CFString, &role)
            if result == .success,
               let roleString = role as? String,
               roleString == kAXWindowRole as String {
                return currentElement
            }

            // 親要素を取得
            var parent: CFTypeRef?
            let parentResult = AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute as CFString, &parent)
            if parentResult == .success, let parentElement = parent {
                current = (parentElement as! AXUIElement)
            } else {
                break
            }
        }

        return nil
    }

    /// ウィンドウの位置を取得
    private func getWindowPosition(_ windowElement: AXUIElement) -> CGPoint? {
        var positionValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &positionValue)

        guard result == .success, let positionValue = positionValue else {
            return nil
        }

        var position = CGPoint.zero
        if AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) {
            return position
        }

        return nil
    }

    /// ウィンドウのサイズを取得
    private func getWindowSize(_ windowElement: AXUIElement) -> CGSize? {
        var sizeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeValue)

        guard result == .success, let sizeValue = sizeValue else {
            return nil
        }

        var size = CGSize.zero
        if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
            return size
        }

        return nil
    }
}
