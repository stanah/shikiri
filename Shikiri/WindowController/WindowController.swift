import ApplicationServices
import AppKit

/// ウィンドウの操作を行うコントローラー
/// Accessibility APIを使用してウィンドウの位置とサイズを取得・設定する
@MainActor
final class WindowController {
    // MARK: - Properties

    private let axWrapper: AXWrapperProtocol

    /// アクセシビリティ権限があるかどうか
    var hasAccessibilityPermission: Bool {
        return axWrapper.isProcessTrusted()
    }

    // MARK: - Initialization

    init(axWrapper: AXWrapperProtocol = AXWrapper()) {
        self.axWrapper = axWrapper
    }

    // MARK: - Coordinate Conversion

    /// NSScreen座標系（左下原点）からAccessibility座標系（左上原点）に変換
    /// - Parameters:
    ///   - point: NSScreen座標系の点
    ///   - screenHeight: 画面の高さ
    /// - Returns: Accessibility座標系の点
    func convertToAXCoordinates(point: NSPoint, screenHeight: CGFloat) -> CGPoint {
        return CGPoint(
            x: point.x,
            y: screenHeight - point.y
        )
    }

    /// Accessibility座標系（左上原点）からNSScreen座標系（左下原点）に変換
    /// - Parameters:
    ///   - point: Accessibility座標系の点
    ///   - screenHeight: 画面の高さ
    /// - Returns: NSScreen座標系の点
    func convertFromAXCoordinates(point: CGPoint, screenHeight: CGFloat) -> NSPoint {
        return NSPoint(
            x: point.x,
            y: screenHeight - point.y
        )
    }

    // MARK: - Window Operations

    /// 指定位置にあるウィンドウを取得
    /// - Parameter position: 画面上の位置（Accessibility座標系）
    /// - Returns: ウィンドウのAXUIElement、見つからない場合はnil
    /// - Throws: WindowOperationError
    func getWindowAt(position: CGPoint) throws -> AXUIElement? {
        guard hasAccessibilityPermission else {
            throw WindowOperationError.accessibilityPermissionDenied
        }

        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?

        let result = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(position.x),
            Float(position.y),
            &element
        )

        guard result == .success, let element = element else {
            return nil
        }

        // 要素からウィンドウ要素を探す
        return findWindowElement(from: element)
    }

    /// ウィンドウの現在のフレームを取得
    /// - Parameter window: 対象のウィンドウ
    /// - Returns: ウィンドウのフレーム
    /// - Throws: WindowOperationError
    func getWindowFrame(_ window: AXUIElement) throws -> CGRect {
        guard let position = getWindowPosition(window) else {
            throw WindowOperationError.cannotGetPosition
        }

        guard let size = getWindowSize(window) else {
            throw WindowOperationError.cannotGetSize
        }

        return CGRect(origin: position, size: size)
    }

    /// ウィンドウのフレームを設定
    /// - Parameters:
    ///   - window: 対象のウィンドウ
    ///   - frame: 設定するフレーム
    /// - Throws: WindowOperationError
    func setWindowFrame(_ window: AXUIElement, frame: CGRect) throws {
        // 位置を設定
        var position = frame.origin
        guard let positionValue = AXValueCreate(.cgPoint, &position) else {
            throw WindowOperationError.cannotSetFrame(reason: "位置の値を作成できません")
        }

        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )

        guard positionResult == .success else {
            throw WindowOperationError.cannotSetFrame(reason: "位置の設定に失敗しました (error: \(positionResult.rawValue))")
        }

        // サイズを設定
        var size = frame.size
        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw WindowOperationError.cannotSetFrame(reason: "サイズの値を作成できません")
        }

        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        guard sizeResult == .success else {
            throw WindowOperationError.cannotSetFrame(reason: "サイズの設定に失敗しました (error: \(sizeResult.rawValue))")
        }
    }

    // MARK: - Private Methods

    /// 要素からウィンドウ要素を見つける
    private func findWindowElement(from element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        var role: CFTypeRef?

        while let currentElement = current {
            let result = AXUIElementCopyAttributeValue(
                currentElement,
                kAXRoleAttribute as CFString,
                &role
            )

            if result == .success,
               let roleString = role as? String,
               roleString == kAXWindowRole as String {
                return currentElement
            }

            // 親要素を取得
            var parent: CFTypeRef?
            let parentResult = AXUIElementCopyAttributeValue(
                currentElement,
                kAXParentAttribute as CFString,
                &parent
            )

            if parentResult == .success, let parentElement = parent {
                current = (parentElement as! AXUIElement)
            } else {
                break
            }
        }

        return nil
    }

    /// ウィンドウの位置を取得
    private func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
        var positionValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &positionValue
        )

        guard result == .success, let positionValue = positionValue else {
            return nil
        }

        var position = CGPoint.zero
        if AXValueGetValue(positionValue as! AXValue, .cgPoint, &position) {
            return position
        }

        return nil
    }

    /// ウィンドウのサイズを取得
    private func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var sizeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            &sizeValue
        )

        guard result == .success, let sizeValue = sizeValue else {
            return nil
        }

        var size = CGSize.zero
        if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
            return size
        }

        return nil
    }
}
