import Foundation

/// ゾーンの定義（画面に対する相対位置と相対サイズ）
/// 0.0〜1.0の割合で指定する
struct ZoneDefinition: Codable, Equatable {
    /// X座標（画面幅に対する割合、0.0〜1.0）
    let x: CGFloat

    /// Y座標（画面高さに対する割合、0.0〜1.0）
    let y: CGFloat

    /// 幅（画面幅に対する割合、0.0〜1.0）
    let width: CGFloat

    /// 高さ（画面高さに対する割合、0.0〜1.0）
    let height: CGFloat

    /// 指定した画面フレームに対するNSRectを生成
    /// - Parameter screenFrame: 画面のフレーム
    /// - Returns: 実際のピクセル座標でのNSRect
    func toFrame(in screenFrame: NSRect) -> NSRect {
        return toFrame(in: screenFrame, gap: 0)
    }

    /// 指定した画面フレームに対するNSRectを生成（ギャップ適用）
    /// - Parameters:
    ///   - screenFrame: 画面のフレーム
    ///   - gap: ウィンドウ間のギャップ（ピクセル）
    /// - Returns: 実際のピクセル座標でのNSRect（ギャップ適用済み）
    func toFrame(in screenFrame: NSRect, gap: CGFloat) -> NSRect {
        let halfGap = gap / 2

        // 基本フレームを計算
        let baseX = screenFrame.origin.x + screenFrame.width * x
        let baseY = screenFrame.origin.y + screenFrame.height * y
        let baseWidth = screenFrame.width * width
        let baseHeight = screenFrame.height * height

        // 各辺にギャップを適用（内側に縮小）
        // 左端でなければ左にハーフギャップ
        let adjustedX = x > 0 ? baseX + halfGap : baseX
        // 下端でなければ下にハーフギャップ
        let adjustedY = y > 0 ? baseY + halfGap : baseY
        // 右端でなければ右にハーフギャップを引く
        let adjustedWidth = baseWidth - (x > 0 ? halfGap : 0) - (x + width < 1.0 ? halfGap : 0)
        // 上端でなければ上にハーフギャップを引く
        let adjustedHeight = baseHeight - (y > 0 ? halfGap : 0) - (y + height < 1.0 ? halfGap : 0)

        return NSRect(
            x: adjustedX,
            y: adjustedY,
            width: max(0, adjustedWidth),
            height: max(0, adjustedHeight)
        )
    }
}

/// レイアウトプリセット
/// 複数のゾーン定義をまとめて管理する
struct ZoneLayoutPreset: Identifiable, Codable, Equatable {
    /// プリセットの一意識別子
    let id: String

    /// プリセットの表示名
    let name: String

    /// ゾーン定義のリスト
    let zones: [ZoneDefinition]

    /// 指定した画面フレームに対するZoneオブジェクトのリストを生成
    /// - Parameter screenFrame: 画面のフレーム
    /// - Returns: Zoneオブジェクトのリスト
    func generateZones(for screenFrame: NSRect) -> [Zone] {
        return generateZones(for: screenFrame, gap: 0)
    }

    /// 指定した画面フレームに対するZoneオブジェクトのリストを生成（ギャップ適用）
    /// - Parameters:
    ///   - screenFrame: 画面のフレーム
    ///   - gap: ウィンドウ間のギャップ（ピクセル）
    /// - Returns: Zoneオブジェクトのリスト
    func generateZones(for screenFrame: NSRect, gap: CGFloat) -> [Zone] {
        return zones.map { definition in
            Zone(frame: definition.toFrame(in: screenFrame, gap: gap))
        }
    }
}

// MARK: - Default Presets

extension ZoneLayoutPreset {
    /// 左右2分割（50:50）
    static let halfLeftRight = ZoneLayoutPreset(
        id: "halfLeftRight",
        name: "左右2分割",
        zones: [
            ZoneDefinition(x: 0.0, y: 0.0, width: 0.5, height: 1.0),
            ZoneDefinition(x: 0.5, y: 0.0, width: 0.5, height: 1.0)
        ]
    )

    /// 左1:右2分割（サイドバー風）
    static let oneThirdTwoThirds = ZoneLayoutPreset(
        id: "oneThirdTwoThirds",
        name: "左1:右2分割",
        zones: [
            ZoneDefinition(x: 0.0, y: 0.0, width: 1.0 / 3.0, height: 1.0),
            ZoneDefinition(x: 1.0 / 3.0, y: 0.0, width: 2.0 / 3.0, height: 1.0)
        ]
    )

    /// 3等分
    static let threeEqual = ZoneLayoutPreset(
        id: "threeEqual",
        name: "3等分",
        zones: [
            ZoneDefinition(x: 0.0, y: 0.0, width: 1.0 / 3.0, height: 1.0),
            ZoneDefinition(x: 1.0 / 3.0, y: 0.0, width: 1.0 / 3.0, height: 1.0),
            ZoneDefinition(x: 2.0 / 3.0, y: 0.0, width: 1.0 / 3.0, height: 1.0)
        ]
    )

    /// 4分割グリッド（2x2）
    /// macOSの座標系は左下が原点なので、上段のyは0.5、下段のyは0.0
    static let grid2x2 = ZoneLayoutPreset(
        id: "grid2x2",
        name: "4分割グリッド",
        zones: [
            // 左上
            ZoneDefinition(x: 0.0, y: 0.5, width: 0.5, height: 0.5),
            // 右上
            ZoneDefinition(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
            // 左下
            ZoneDefinition(x: 0.0, y: 0.0, width: 0.5, height: 0.5),
            // 右下
            ZoneDefinition(x: 0.5, y: 0.0, width: 0.5, height: 0.5)
        ]
    )

    /// 上下2分割（50:50）- 縦置きモニター向け
    /// macOSの座標系は左下が原点なので、上段のyは0.5、下段のyは0.0
    static let halfTopBottom = ZoneLayoutPreset(
        id: "halfTopBottom",
        name: "上下2分割",
        zones: [
            // 上
            ZoneDefinition(x: 0.0, y: 0.5, width: 1.0, height: 0.5),
            // 下
            ZoneDefinition(x: 0.0, y: 0.0, width: 1.0, height: 0.5)
        ]
    )

    /// 上中下3分割 - 縦置きモニター向け
    /// macOSの座標系は左下が原点なので、上段のyは2/3、中段は1/3、下段は0
    static let threeEqualVertical = ZoneLayoutPreset(
        id: "threeEqualVertical",
        name: "上下3分割",
        zones: [
            // 上
            ZoneDefinition(x: 0.0, y: 2.0 / 3.0, width: 1.0, height: 1.0 / 3.0),
            // 中
            ZoneDefinition(x: 0.0, y: 1.0 / 3.0, width: 1.0, height: 1.0 / 3.0),
            // 下
            ZoneDefinition(x: 0.0, y: 0.0, width: 1.0, height: 1.0 / 3.0)
        ]
    )

    /// 6分割グリッド（3x2）
    /// macOSの座標系は左下が原点なので、上段のyは0.5、下段のyは0.0
    static let grid3x2 = ZoneLayoutPreset(
        id: "grid3x2",
        name: "6分割グリッド",
        zones: [
            // 上段（左から右）
            ZoneDefinition(x: 0.0, y: 0.5, width: 1.0 / 3.0, height: 0.5),
            ZoneDefinition(x: 1.0 / 3.0, y: 0.5, width: 1.0 / 3.0, height: 0.5),
            ZoneDefinition(x: 2.0 / 3.0, y: 0.5, width: 1.0 / 3.0, height: 0.5),
            // 下段（左から右）
            ZoneDefinition(x: 0.0, y: 0.0, width: 1.0 / 3.0, height: 0.5),
            ZoneDefinition(x: 1.0 / 3.0, y: 0.0, width: 1.0 / 3.0, height: 0.5),
            ZoneDefinition(x: 2.0 / 3.0, y: 0.0, width: 1.0 / 3.0, height: 0.5)
        ]
    )

    /// 利用可能な全てのプリセット
    static let allPresets: [ZoneLayoutPreset] = [
        .halfLeftRight,
        .oneThirdTwoThirds,
        .threeEqual,
        .grid2x2,
        .grid3x2,
        .halfTopBottom,
        .threeEqualVertical
    ]
}
