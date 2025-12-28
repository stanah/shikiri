import SwiftUI

/// 画面のプレビューを表示するキャンバス
/// ゾーンをドラッグ可能な矩形として表示する
struct ScreenPreviewCanvas: View {
    /// 対象画面の識別子
    let screenIdentifier: ScreenIdentifier

    /// 画面の実際のフレーム
    let screenFrame: CGRect

    /// 編集中のゾーン定義
    @Binding var zones: [ZoneDefinition]

    /// 編集モードかどうか
    let isEditing: Bool

    /// 選択中のゾーンインデックス
    @Binding var selectedZoneIndex: Int?

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = calculateCanvasSize(in: geometry.size)

            ZStack {
                // 画面背景
                screenBackground

                // ゾーン表示
                ForEach(zones.indices, id: \.self) { index in
                    ZoneRectView(
                        zone: zones[index],
                        index: index,
                        canvasSize: canvasSize,
                        isEditing: isEditing,
                        isSelected: selectedZoneIndex == index,
                        onUpdate: { newZone in
                            zones[index] = newZone
                        },
                        onSelect: {
                            selectedZoneIndex = index
                        }
                    )
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(screenFrame.width / screenFrame.height, contentMode: .fit)
        .onTapGesture {
            // キャンバスの空白部分をタップしたら選択解除
            selectedZoneIndex = nil
        }
    }

    // MARK: - Private Views

    /// 画面背景
    private var screenBackground: some View {
        ZStack {
            // 背景色
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))

            // 枠線
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.5), lineWidth: 2)

            // 画面情報
            VStack {
                Spacer()
                HStack {
                    Text("\(screenIdentifier.width) x \(screenIdentifier.height)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(4)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helper Methods

    /// キャンバスサイズを計算
    private func calculateCanvasSize(in containerSize: CGSize) -> CGSize {
        let aspectRatio = screenFrame.width / screenFrame.height

        if containerSize.width / containerSize.height > aspectRatio {
            // コンテナが横長の場合、高さに合わせる
            let height = containerSize.height
            let width = height * aspectRatio
            return CGSize(width: width, height: height)
        } else {
            // コンテナが縦長の場合、幅に合わせる
            let width = containerSize.width
            let height = width / aspectRatio
            return CGSize(width: width, height: height)
        }
    }
}
