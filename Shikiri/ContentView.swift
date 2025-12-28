import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var accessibilityManager: AccessibilityManager
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if accessibilityManager.isAccessibilityEnabled {
                // 権限あり: 設定画面
                SettingsView(settings: settings)
            } else {
                // 権限なし: 権限リクエストUI
                AccessibilityPermissionView(accessibilityManager: accessibilityManager)
                Divider()
                Button("Shikiriを終了") {
                    NSApplication.shared.terminate(nil)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .frame(minWidth: 200)
        .onAppear {
            accessibilityManager.checkAccessibility()
            if !accessibilityManager.isAccessibilityEnabled {
                accessibilityManager.startPolling()
            }
        }
        .onChange(of: accessibilityManager.isAccessibilityEnabled) { _, isEnabled in
            if isEnabled {
                accessibilityManager.stopPolling()
            }
        }
    }
}

extension ContentView {
    init() {
        self.init(
            accessibilityManager: AccessibilityManager(),
            settings: Settings.shared
        )
    }
}
