import Foundation
import CoreGraphics

/// 修飾キーのフラグ（Shift, Control, Optionなど）
/// CGEventFlagsをラップして使いやすくしたもの
struct ModifierFlags: OptionSet, Codable, Equatable, Hashable {
    let rawValue: UInt64

    static let shift = ModifierFlags(rawValue: CGEventFlags.maskShift.rawValue)
    static let control = ModifierFlags(rawValue: CGEventFlags.maskControl.rawValue)
    static let option = ModifierFlags(rawValue: CGEventFlags.maskAlternate.rawValue)
    static let command = ModifierFlags(rawValue: CGEventFlags.maskCommand.rawValue)

    /// CGEventFlagsから初期化
    init(cgEventFlags: CGEventFlags) {
        // 修飾キーのマスクのみを抽出
        var flags: ModifierFlags = []
        if cgEventFlags.contains(.maskShift) {
            flags.insert(.shift)
        }
        if cgEventFlags.contains(.maskControl) {
            flags.insert(.control)
        }
        if cgEventFlags.contains(.maskAlternate) {
            flags.insert(.option)
        }
        if cgEventFlags.contains(.maskCommand) {
            flags.insert(.command)
        }
        self.rawValue = flags.rawValue
    }

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// 表示用の名前（例: "⇧" "⌃⇧" "⌥⇧"）
    var displayName: String {
        var parts: [String] = []
        if contains(.control) {
            parts.append("⌃")
        }
        if contains(.option) {
            parts.append("⌥")
        }
        if contains(.command) {
            parts.append("⌘")
        }
        if contains(.shift) {
            parts.append("⇧")
        }
        return parts.joined()
    }

    /// Shiftキーが含まれているかどうか
    var containsShift: Bool {
        contains(.shift)
    }
}
