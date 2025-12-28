import AppKit
import SwiftUI

/// レイアウトエディタウィンドウを管理するコントローラ
/// ウィンドウの参照を保持し、シングルトンとして動作する
final class LayoutEditorWindowController: NSWindowController {
    static let shared = LayoutEditorWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "レイアウトエディタ"
        window.contentView = NSHostingView(rootView: LayoutEditorView())
        window.minSize = NSSize(width: 600, height: 400)
        window.isReleasedWhenClosed = false  // ウィンドウを閉じても解放しない

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// レイアウトエディタウィンドウを表示する
    func showWindow() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
