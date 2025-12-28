import AppKit

/// ゾーンを視覚的に表示するためのビュー
/// 各ゾーンを半透明の矩形で描画し、ホバー中のゾーンをハイライト表示する
final class ZoneOverlayView: NSView {

    // MARK: - Properties

    /// 表示するゾーンのリスト
    private(set) var zones: [Zone] = []

    /// 現在ハイライトされているゾーンのID
    private(set) var highlightedZoneId: UUID?

    // MARK: - Drawing Colors

    /// ゾーンの背景色
    private let zoneBackgroundColor = NSColor.systemBlue.withAlphaComponent(0.1)

    /// ゾーンの境界線の色
    private let zoneBorderColor = NSColor.systemBlue.withAlphaComponent(0.5)

    /// ハイライトされたゾーンの背景色
    private let highlightedBackgroundColor = NSColor.systemBlue.withAlphaComponent(0.3)

    /// ハイライトされたゾーンの境界線の色
    private let highlightedBorderColor = NSColor.systemBlue.withAlphaComponent(0.8)

    /// 境界線の幅
    private let borderWidth: CGFloat = 2.0

    // MARK: - Initialization

    /// 指定したゾーンでビューを初期化
    /// - Parameter zones: 表示するゾーンのリスト
    init(zones: [Zone]) {
        self.zones = zones
        super.init(frame: .zero)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    // MARK: - Configuration

    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    // MARK: - View Properties

    override var isOpaque: Bool {
        return false
    }

    // MARK: - Public Methods

    /// ゾーンのリストを更新
    /// - Parameter zones: 新しいゾーンのリスト
    func updateZones(_ zones: [Zone]) {
        self.zones = zones
        needsDisplay = true
    }

    /// 指定したゾーンをハイライト
    /// - Parameter zoneId: ハイライトするゾーンのID
    func setHighlightedZone(_ zoneId: UUID?) {
        highlightedZoneId = zoneId
        needsDisplay = true
    }

    /// ハイライトをクリア
    func clearHighlight() {
        highlightedZoneId = nil
        needsDisplay = true
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        for zone in zones {
            let isHighlighted = zone.id == highlightedZoneId
            drawZone(zone, isHighlighted: isHighlighted, in: context)
        }
    }

    private func drawZone(_ zone: Zone, isHighlighted: Bool, in context: CGContext) {
        // ゾーンのフレームは既にローカル座標で渡されている
        let localFrame = zone.frame

        // 背景を描画
        let backgroundColor = isHighlighted ? highlightedBackgroundColor : zoneBackgroundColor
        context.setFillColor(backgroundColor.cgColor)
        context.fill(localFrame)

        // 境界線を描画
        let borderColor = isHighlighted ? highlightedBorderColor : zoneBorderColor
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(borderWidth)
        context.stroke(localFrame.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
    }
}
