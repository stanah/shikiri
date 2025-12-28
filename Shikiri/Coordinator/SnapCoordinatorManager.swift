import Foundation
import AppKit

/// スナップコーディネーターのライフサイクルを管理するマネージャー
/// アプリ起動時にセットアップし、コンポーネントの参照を保持する
@MainActor
final class SnapCoordinatorManager: ObservableObject {
    // MARK: - Properties

    private var eventMonitor: EventMonitor?
    private var snapCoordinator: SnapCoordinator?
    private var zoneManager: ZoneManager?
    private var overlayController: OverlayController?
    private var windowController: WindowController?
    private var screenMonitor: ScreenMonitor?

    /// スナップ機能が有効かどうか
    private(set) var isEnabled = false

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// スナップシステムをセットアップして開始
    /// - Parameter presetManager: 使用するプリセットマネージャー
    func setup(presetManager: PresetManager = PresetManager.shared) {
        guard !isEnabled else { return }

        // コンポーネントの初期化
        let zoneManager = ZoneManager()
        let overlayController = OverlayController(zoneManager: zoneManager)
        let windowController = WindowController()

        // 画面ごとのプリセットでゾーンをセットアップ
        zoneManager.setupZonesWithPerScreenPresets(
            fallbackPreset: presetManager.currentPreset,
            gap: CGFloat(Settings.shared.windowGap)
        )

        let coordinator = SnapCoordinator(
            zoneManager: zoneManager,
            overlayController: overlayController,
            windowController: windowController
        )

        let monitor = EventMonitor()

        // 境界ドラッグモードを有効化（EventMonitorへの参照も渡す）
        coordinator.enableBoundaryDrag(with: windowController, eventMonitor: monitor)

        monitor.delegate = coordinator
        monitor.isBoundaryDragModeEnabled = true

        // 画面構成変更の監視をセットアップ
        let screenMonitor = ScreenMonitor()
        screenMonitor.onScreenConfigurationChanged = { [weak zoneManager] in
            zoneManager?.setupZonesWithPerScreenPresets(
                fallbackPreset: presetManager.currentPreset,
                gap: CGFloat(Settings.shared.windowGap)
            )
        }
        screenMonitor.startMonitoring()

        // イベント監視を開始
        monitor.start()

        // 参照を保持
        self.zoneManager = zoneManager
        self.overlayController = overlayController
        self.windowController = windowController
        self.snapCoordinator = coordinator
        self.eventMonitor = monitor
        self.screenMonitor = screenMonitor
        self.isEnabled = true

        print("SnapCoordinatorManager: Snap system started")
    }

    /// プリセット変更時にゾーンを再セットアップ
    /// - Parameter preset: 新しいプリセット
    func updatePreset(_ preset: ZoneLayoutPreset) {
        guard isEnabled, let zoneManager = zoneManager else { return }

        let screenFrames = NSScreen.screens.map { $0.visibleFrame }
        zoneManager.setupZonesForScreens(screenFrames, preset: preset)

        print("SnapCoordinatorManager: Zones updated for preset: \(preset.name)")
    }

    /// スナップシステムを停止
    func stop() {
        guard isEnabled else { return }

        eventMonitor?.stop()
        screenMonitor?.stopMonitoring()

        eventMonitor = nil
        snapCoordinator = nil
        overlayController = nil
        windowController = nil
        zoneManager = nil
        screenMonitor = nil
        isEnabled = false

        print("SnapCoordinatorManager: Snap system stopped")
    }
}
