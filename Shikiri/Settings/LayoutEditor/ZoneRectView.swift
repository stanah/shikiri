import SwiftUI

/// ゾーンを表す矩形ビュー
/// ドラッグ移動とリサイズをサポート
struct ZoneRectView: View {
    /// ゾーン定義
    let zone: ZoneDefinition

    /// ゾーンのインデックス（表示用）
    let index: Int

    /// プレビューキャンバスのサイズ
    let canvasSize: CGSize

    /// 編集モードかどうか
    let isEditing: Bool

    /// 選択されているかどうか
    let isSelected: Bool

    /// ゾーン更新コールバック
    var onUpdate: (ZoneDefinition) -> Void

    /// 選択コールバック
    var onSelect: () -> Void

    /// ドラッグオフセット
    @State private var dragOffset: CGSize = .zero

    /// ドラッグ中かどうか
    @State private var isDragging = false

    // MARK: - Body

    var body: some View {
        let rect = zoneRect

        ZStack {
            // ゾーン背景
            RoundedRectangle(cornerRadius: 4)
                .fill(fillColor)

            // 枠線
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: isSelected ? 3 : 2)

            // ゾーン番号
            Text("\(index + 1)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: rect.width, height: rect.height)
        .position(
            x: rect.midX + dragOffset.width,
            y: rect.midY + dragOffset.height
        )
        .gesture(tapGesture)
        .gesture(isEditing ? dragGesture : nil)
        .overlay(
            // リサイズハンドル（編集モードかつ選択時のみ）
            Group {
                if isEditing && isSelected {
                    resizeHandles(for: rect)
                }
            }
        )
    }

    // MARK: - Computed Properties

    /// ゾーンの矩形（キャンバス座標系）
    private var zoneRect: CGRect {
        CGRect(
            x: zone.x * canvasSize.width,
            y: (1 - zone.y - zone.height) * canvasSize.height, // Y軸反転
            width: zone.width * canvasSize.width,
            height: zone.height * canvasSize.height
        )
    }

    /// 塗りつぶし色
    private var fillColor: Color {
        if isDragging {
            return .blue.opacity(0.5)
        } else if isSelected {
            return .blue.opacity(0.4)
        } else {
            return .blue.opacity(0.25)
        }
    }

    /// 枠線色
    private var borderColor: Color {
        isSelected ? .blue : .blue.opacity(0.7)
    }

    // MARK: - Gestures

    /// タップジェスチャー
    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                onSelect()
            }
    }

    /// ドラッグジェスチャー
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                isDragging = false

                // 新しい位置を計算
                let deltaX = value.translation.width / canvasSize.width
                let deltaY = -value.translation.height / canvasSize.height // Y軸反転

                let newX = clamp(zone.x + deltaX, min: 0, max: 1 - zone.width)
                let newY = clamp(zone.y + deltaY, min: 0, max: 1 - zone.height)

                onUpdate(ZoneDefinition(
                    x: newX,
                    y: newY,
                    width: zone.width,
                    height: zone.height
                ))

                dragOffset = .zero
            }
    }

    // MARK: - Resize Handles

    /// リサイズハンドルを描画
    @ViewBuilder
    private func resizeHandles(for rect: CGRect) -> some View {
        let handleSize: CGFloat = 10

        // 右端ハンドル
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
            .frame(width: handleSize, height: handleSize)
            .position(x: rect.maxX, y: rect.midY)
            .gesture(resizeGesture(edge: .trailing))

        // 下端ハンドル
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
            .frame(width: handleSize, height: handleSize)
            .position(x: rect.midX, y: rect.maxY)
            .gesture(resizeGesture(edge: .bottom))

        // 右下角ハンドル
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
            .frame(width: handleSize, height: handleSize)
            .position(x: rect.maxX, y: rect.maxY)
            .gesture(resizeGesture(edge: .bottomTrailing))
    }

    /// リサイズジェスチャー
    private func resizeGesture(edge: Edge.Set) -> some Gesture {
        DragGesture()
            .onChanged { _ in
                isDragging = true
            }
            .onEnded { value in
                isDragging = false

                var newWidth = zone.width
                var newHeight = zone.height
                var newX = zone.x
                var newY = zone.y

                let deltaX = value.translation.width / canvasSize.width
                let deltaY = -value.translation.height / canvasSize.height

                if edge.contains(.trailing) {
                    newWidth = clamp(zone.width + deltaX, min: 0.1, max: 1 - zone.x)
                }

                if edge.contains(.bottom) {
                    let newHeightCandidate = zone.height - deltaY
                    if newHeightCandidate >= 0.1 && zone.y + deltaY >= 0 {
                        newHeight = newHeightCandidate
                        newY = zone.y + deltaY
                    }
                }

                onUpdate(ZoneDefinition(
                    x: newX,
                    y: newY,
                    width: newWidth,
                    height: newHeight
                ))
            }
    }

    // MARK: - Helper

    /// 値をクランプ
    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }
}

// MARK: - Edge.Set Extension

private extension Edge.Set {
    static let bottomTrailing: Edge.Set = [.bottom, .trailing]
}
