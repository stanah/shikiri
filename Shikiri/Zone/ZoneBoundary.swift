import AppKit
import Foundation

/// ゾーン境界の向きを表す列挙型
enum BoundaryOrientation {
    /// 垂直な境界（左右のゾーンを分ける）
    case vertical
    /// 水平な境界（上下のゾーンを分ける）
    case horizontal
}

/// ゾーン間の境界を表すモデル
/// 境界は隣接する2つのゾーンの間にあり、ドラッグ可能な領域を定義する
struct ZoneBoundary: Identifiable, Equatable {
    /// 境界の一意識別子
    let id: UUID

    /// 境界の向き
    let orientation: BoundaryOrientation

    /// 境界の位置（垂直境界ならx座標、水平境界ならy座標）
    let position: CGFloat

    /// 境界の有効範囲（垂直境界ならy座標の範囲、水平境界ならx座標の範囲）
    let range: Range<CGFloat>

    /// 境界の左側または上側にあるゾーンのID
    let leftOrTopZoneId: UUID

    /// 境界の右側または下側にあるゾーンのID
    let rightOrBottomZoneId: UUID

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        orientation: BoundaryOrientation,
        position: CGFloat,
        range: Range<CGFloat>,
        leftOrTopZoneId: UUID,
        rightOrBottomZoneId: UUID
    ) {
        self.id = id
        self.orientation = orientation
        self.position = position
        self.range = range
        self.leftOrTopZoneId = leftOrTopZoneId
        self.rightOrBottomZoneId = rightOrBottomZoneId
    }

    // MARK: - Hit Testing

    /// 指定した点がこの境界上にあるかを判定
    /// - Parameters:
    ///   - point: 判定対象の点
    ///   - tolerance: 境界からの許容距離（ピクセル）
    /// - Returns: 点が境界上にある場合はtrue
    func containsPoint(_ point: CGPoint, tolerance: CGFloat) -> Bool {
        switch orientation {
        case .vertical:
            // x座標が境界位置から許容範囲内か
            let xInRange = abs(point.x - position) <= tolerance
            // y座標が境界の範囲内か
            let yInRange = range.contains(point.y)
            return xInRange && yInRange

        case .horizontal:
            // y座標が境界位置から許容範囲内か
            let yInRange = abs(point.y - position) <= tolerance
            // x座標が境界の範囲内か
            let xInRange = range.contains(point.x)
            return xInRange && yInRange
        }
    }

    // MARK: - Cursor

    /// この境界に適したリサイズカーソル
    var resizeCursor: NSCursor {
        switch orientation {
        case .vertical:
            return NSCursor.resizeLeftRight
        case .horizontal:
            return NSCursor.resizeUpDown
        }
    }
}

// MARK: - BoundaryManager

/// ゾーン境界の検出と管理を行うマネージャー
enum BoundaryManager {

    /// ゾーンの配列から境界を検出する
    /// - Parameter zones: ゾーンの配列
    /// - Returns: 検出された境界の配列
    static func detectBoundaries(from zones: [Zone]) -> [ZoneBoundary] {
        var boundaries: [ZoneBoundary] = []
        var processedPairs: Set<String> = []

        for i in 0..<zones.count {
            for j in (i + 1)..<zones.count {
                let zone1 = zones[i]
                let zone2 = zones[j]

                // すでに処理済みのペアはスキップ
                let pairKey = "\(min(zone1.id.uuidString, zone2.id.uuidString))-\(max(zone1.id.uuidString, zone2.id.uuidString))"
                if processedPairs.contains(pairKey) {
                    continue
                }
                processedPairs.insert(pairKey)

                // 垂直境界（左右に隣接）をチェック
                if let boundary = detectVerticalBoundary(between: zone1, and: zone2) {
                    boundaries.append(boundary)
                }

                // 水平境界（上下に隣接）をチェック
                if let boundary = detectHorizontalBoundary(between: zone1, and: zone2) {
                    boundaries.append(boundary)
                }
            }
        }

        // 位置でソート
        return boundaries.sorted { $0.position < $1.position }
    }

    /// 指定した点に最も近い境界を検索
    /// - Parameters:
    ///   - point: 検索する点
    ///   - boundaries: 検索対象の境界配列
    ///   - tolerance: 許容距離
    /// - Returns: 見つかった境界、なければnil
    static func boundaryAt(point: CGPoint, in boundaries: [ZoneBoundary], tolerance: CGFloat) -> ZoneBoundary? {
        return boundaries.first { $0.containsPoint(point, tolerance: tolerance) }
    }

    // MARK: - Private Methods

    /// 2つのゾーン間の垂直境界を検出
    private static func detectVerticalBoundary(between zone1: Zone, and zone2: Zone) -> ZoneBoundary? {
        let tolerance: CGFloat = 2.0

        // zone1の右端とzone2の左端が一致するか
        if abs(zone1.frame.maxX - zone2.frame.minX) < tolerance {
            // 垂直方向にオーバーラップしているか
            let overlapMinY = max(zone1.frame.minY, zone2.frame.minY)
            let overlapMaxY = min(zone1.frame.maxY, zone2.frame.maxY)

            if overlapMinY < overlapMaxY {
                return ZoneBoundary(
                    orientation: .vertical,
                    position: zone1.frame.maxX,
                    range: overlapMinY..<overlapMaxY,
                    leftOrTopZoneId: zone1.id,
                    rightOrBottomZoneId: zone2.id
                )
            }
        }

        // zone2の右端とzone1の左端が一致するか
        if abs(zone2.frame.maxX - zone1.frame.minX) < tolerance {
            let overlapMinY = max(zone1.frame.minY, zone2.frame.minY)
            let overlapMaxY = min(zone1.frame.maxY, zone2.frame.maxY)

            if overlapMinY < overlapMaxY {
                return ZoneBoundary(
                    orientation: .vertical,
                    position: zone2.frame.maxX,
                    range: overlapMinY..<overlapMaxY,
                    leftOrTopZoneId: zone2.id,
                    rightOrBottomZoneId: zone1.id
                )
            }
        }

        return nil
    }

    /// 2つのゾーン間の水平境界を検出
    private static func detectHorizontalBoundary(between zone1: Zone, and zone2: Zone) -> ZoneBoundary? {
        let tolerance: CGFloat = 2.0

        // zone1の上端とzone2の下端が一致するか
        if abs(zone1.frame.maxY - zone2.frame.minY) < tolerance {
            // 水平方向にオーバーラップしているか
            let overlapMinX = max(zone1.frame.minX, zone2.frame.minX)
            let overlapMaxX = min(zone1.frame.maxX, zone2.frame.maxX)

            if overlapMinX < overlapMaxX {
                return ZoneBoundary(
                    orientation: .horizontal,
                    position: zone1.frame.maxY,
                    range: overlapMinX..<overlapMaxX,
                    leftOrTopZoneId: zone1.id,
                    rightOrBottomZoneId: zone2.id
                )
            }
        }

        // zone2の上端とzone1の下端が一致するか
        if abs(zone2.frame.maxY - zone1.frame.minY) < tolerance {
            let overlapMinX = max(zone1.frame.minX, zone2.frame.minX)
            let overlapMaxX = min(zone1.frame.maxX, zone2.frame.maxX)

            if overlapMinX < overlapMaxX {
                return ZoneBoundary(
                    orientation: .horizontal,
                    position: zone2.frame.maxY,
                    range: overlapMinX..<overlapMaxX,
                    leftOrTopZoneId: zone2.id,
                    rightOrBottomZoneId: zone1.id
                )
            }
        }

        return nil
    }
}
