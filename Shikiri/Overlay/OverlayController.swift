import AppKit

/// ログをファイルに書き込む
private func overlayLog(_ message: String) {
    let logPath = "/tmp/shikiri_app.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logMessage = "[\(timestamp)] [OverlayController] \(message)\n"
    print("[OverlayController] \(message)")
    if let data = logMessage.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logPath) {
            if let handle = FileHandle(forWritingAtPath: logPath) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: logPath))
        }
    }
}

/// オーバーレイの表示/非表示を管理するコントローラ
/// 各スクリーンに対応するオーバーレイウィンドウを管理し、
/// スナップモードの開始/終了に応じて表示を切り替える
@MainActor
final class OverlayController {

    // MARK: - Constants

    /// フェードアニメーションの持続時間
    static let fadeAnimationDuration: TimeInterval = 0.2

    // MARK: - Properties

    /// オーバーレイが表示中かどうか
    private(set) var isVisible = false

    /// 現在ハイライトされているゾーンのID
    private(set) var highlightedZoneId: UUID?

    /// アニメーションが有効かどうか
    var animationEnabled = true

    /// ゾーンマネージャー
    private let zoneManager: ZoneManager

    /// 各スクリーンに対応するオーバーレイウィンドウのリスト
    private var overlayWindows: [OverlayWindow] = []

    /// 各オーバーレイウィンドウに対応するビュー
    private var overlayViews: [ZoneOverlayView] = []

    // MARK: - Initialization

    /// 指定したゾーンマネージャーでコントローラを初期化
    /// - Parameter zoneManager: ゾーンマネージャー
    init(zoneManager: ZoneManager) {
        self.zoneManager = zoneManager
    }

    // MARK: - Public Methods

    /// オーバーレイを表示
    func show() {
        guard !isVisible else { return }

        // 前回のhideアニメーションが完了していない場合、即座にクリーンアップ
        if !overlayWindows.isEmpty {
            destroyOverlays()
        }

        createOverlays()
        showOverlaysWithAnimation()
        isVisible = true
    }

    /// オーバーレイを非表示
    func hide() {
        guard isVisible else { return }

        isVisible = false
        highlightedZoneId = nil

        // hideアニメーション中に現在のウィンドウをキャプチャ
        // show()が呼ばれた場合でも、この参照のウィンドウだけを破棄する
        let windowsToHide = overlayWindows
        overlayWindows = []
        overlayViews = []

        hideOverlaysWithAnimation(windows: windowsToHide)
    }

    /// オーバーレイを即座に更新（修飾キー切り替え時など）
    /// アニメーションなしで即座に破棄して再作成
    func refresh() {
        guard isVisible else { return }

        // 古いオーバーレイを即座に破棄
        destroyOverlays()

        // 新しいオーバーレイを作成して表示
        createOverlays()
        for window in overlayWindows {
            window.alphaValue = 1
            window.orderFront(nil)
        }
    }

    /// ハイライトされたゾーンを更新
    /// - Parameter zoneId: ハイライトするゾーンのID
    func updateHighlightedZone(_ zoneId: UUID?) {
        highlightedZoneId = zoneId
        for view in overlayViews {
            view.setHighlightedZone(zoneId)
        }
    }

    /// ハイライトをクリア
    func clearHighlight() {
        highlightedZoneId = nil
        for view in overlayViews {
            view.clearHighlight()
        }
    }

    /// マウス位置に基づいてハイライトを更新
    /// - Parameter point: マウスカーソルの位置（スクリーン座標）
    func updateHighlightForMousePosition(_ point: NSPoint) {
        guard isVisible else { return }

        // ZoneManagerを使ってマウス位置のゾーンを取得
        if let zone = zoneManager.zoneAt(point: point) {
            updateHighlightedZone(zone.id)
        } else {
            clearHighlight()
        }
    }

    // MARK: - Private Methods

    private func createOverlays() {
        overlayLog("createOverlays called, total zones: \(zoneManager.zones.count)")

        for screen in NSScreen.screens {
            let window = OverlayWindow(frame: screen.frame)
            // ゾーンはvisibleFrameで生成されているので、変換もvisibleFrameの原点を使用
            let visibleOrigin = screen.visibleFrame.origin

            overlayLog("Screen: \(screen.localizedName), frame: \(screen.frame), visibleFrame: \(screen.visibleFrame)")

            // この画面に属するゾーンのみをフィルタリング
            // ゾーンの中心点がこの画面内にあるかで判定
            let zonesForScreen = zoneManager.zones.filter { zone in
                let center = NSPoint(x: zone.frame.midX, y: zone.frame.midY)
                let contains = screen.frame.contains(center)
                overlayLog("  Zone frame: \(zone.frame), center: \(center), contains: \(contains)")
                return contains
            }

            overlayLog("  -> \(zonesForScreen.count) zones for this screen")

            // ゾーンのフレームをスクリーン座標からウィンドウのローカル座標に変換
            // ゾーンはvisibleFrameで生成されているので、visibleFrameの原点を基準に変換
            let localZones = zonesForScreen.map { zone in
                let localFrame = CGRect(
                    x: zone.frame.origin.x - visibleOrigin.x,
                    y: zone.frame.origin.y - visibleOrigin.y,
                    width: zone.frame.width,
                    height: zone.frame.height
                )
                overlayLog("  Zone local frame: \(localFrame)")
                return Zone(id: zone.id, frame: localFrame)
            }

            let view = ZoneOverlayView(zones: localZones)
            view.frame = NSRect(origin: .zero, size: screen.frame.size)

            window.contentView = view

            overlayWindows.append(window)
            overlayViews.append(view)
        }
    }

    private func showOverlaysWithAnimation() {
        if animationEnabled {
            // フェードイン: 透明度0から始めて1へ
            for window in overlayWindows {
                window.alphaValue = 0
                window.orderFront(nil)
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.fadeAnimationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                for window in self.overlayWindows {
                    window.animator().alphaValue = 1
                }
            }
        } else {
            for window in overlayWindows {
                window.alphaValue = 1
                window.orderFront(nil)
            }
        }
    }

    private func hideOverlaysWithAnimation(windows: [OverlayWindow]) {
        if animationEnabled {
            // フェードアウト: 透明度1から0へ
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Self.fadeAnimationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                for window in windows {
                    window.animator().alphaValue = 0
                }
            }, completionHandler: { [windows] in
                // MainActorで実行してキャプチャしたウィンドウを破棄
                Task { @MainActor in
                    for window in windows {
                        window.orderOut(nil)
                    }
                }
            })
        } else {
            for window in windows {
                window.orderOut(nil)
            }
        }
    }

    private func destroyOverlays() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        overlayViews.removeAll()
    }
}
