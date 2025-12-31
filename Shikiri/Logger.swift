import Foundation

/// アプリ全体で使用する共通ログユーティリティ
/// Debugビルドでのみログを出力し、Releaseビルドでは何もしない
enum ShikiriLogger {
    /// ログファイルのパス
    private static let logPath = "/tmp/shikiri_app.log"

    /// ログを出力する
    /// - Parameters:
    ///   - message: ログメッセージ
    ///   - category: ログのカテゴリ（クラス名など）
    static func log(_ message: String, category: String) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [\(category)] \(message)\n"
        print("[\(category)] \(message)")

        // ファイルにも書き込み
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let handle = FileHandle(forWritingAtPath: logPath) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: logPath, contents: data)
            }
        }
        #endif
    }
}
