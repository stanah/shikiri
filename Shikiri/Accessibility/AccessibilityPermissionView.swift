import SwiftUI
import AppKit

/// アクセシビリティ権限が必要な場合に表示するビュー
struct AccessibilityPermissionView: View {
    @ObservedObject var accessibilityManager: AccessibilityManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.circle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("アクセシビリティ権限が必要です")
                .font(.headline)

            Text("Shikiriはウィンドウを操作するために\nアクセシビリティ権限が必要です。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button("権限をリクエスト") {
                    accessibilityManager.requestAccessibility()
                }
                .buttonStyle(.borderedProminent)

                Button("システム設定を開く") {
                    openAccessibilitySettings()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 300)
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
