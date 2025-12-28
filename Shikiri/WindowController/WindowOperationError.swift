import Foundation

/// ウィンドウ操作中に発生するエラー
enum WindowOperationError: LocalizedError {
    /// アクセシビリティ権限がない
    case accessibilityPermissionDenied
    /// ウィンドウが見つからない
    case windowNotFound
    /// ウィンドウの位置を取得できない
    case cannotGetPosition
    /// ウィンドウのサイズを取得できない
    case cannotGetSize
    /// ウィンドウのフレームを設定できない
    case cannotSetFrame(reason: String)
    /// フルスクリーンウィンドウは操作できない
    case windowIsFullscreen
    /// 最小化されたウィンドウは操作できない
    case windowIsMinimized

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "アクセシビリティ権限がありません"
        case .windowNotFound:
            return "ウィンドウが見つかりません"
        case .cannotGetPosition:
            return "ウィンドウの位置を取得できません"
        case .cannotGetSize:
            return "ウィンドウのサイズを取得できません"
        case .cannotSetFrame(let reason):
            return "ウィンドウのフレームを設定できません: \(reason)"
        case .windowIsFullscreen:
            return "フルスクリーンウィンドウは操作できません"
        case .windowIsMinimized:
            return "最小化されたウィンドウは操作できません"
        }
    }
}
