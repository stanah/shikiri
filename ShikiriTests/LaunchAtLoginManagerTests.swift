import XCTest
@testable import Shikiri

@MainActor
final class LaunchAtLoginManagerTests: XCTestCase {

    var manager: LaunchAtLoginManager!

    override func setUp() async throws {
        manager = LaunchAtLoginManager()
    }

    override func tearDown() async throws {
        manager = nil
    }

    // MARK: - Initialization Tests

    func testLaunchAtLoginManagerInitializes() {
        XCTAssertNotNil(manager)
    }

    // MARK: - Property Tests

    func testIsEnabledPropertyExists() {
        // isEnabled プロパティが存在し、Bool型であることを確認
        let _: Bool = manager.isEnabled
        // コンパイルが通れば成功
    }

    func testCanSetIsEnabled() {
        // isEnabledを設定できることを確認
        manager.setEnabled(true)
        manager.setEnabled(false)
        // 例外が発生しなければ成功
    }

    // MARK: - Availability Tests

    func testIsAvailableOnMacOS13OrLater() {
        // macOS 13.0以降で利用可能かどうかを確認
        let isAvailable = manager.isAvailable
        if #available(macOS 13.0, *) {
            XCTAssertTrue(isAvailable)
        } else {
            XCTAssertFalse(isAvailable)
        }
    }
}
