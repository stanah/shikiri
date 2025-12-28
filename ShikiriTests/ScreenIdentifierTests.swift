import XCTest
@testable import Shikiri

final class ScreenIdentifierTests: XCTestCase {

    // MARK: - Initialization Tests

    func testScreenIdentifier_InitializesWithCorrectProperties() {
        let identifier = ScreenIdentifier(
            localizedName: "Built-in Retina Display",
            width: 3024,
            height: 1964
        )

        XCTAssertEqual(identifier.localizedName, "Built-in Retina Display")
        XCTAssertEqual(identifier.width, 3024)
        XCTAssertEqual(identifier.height, 1964)
    }

    // MARK: - Key Generation Tests

    func testScreenIdentifier_GeneratesCorrectKey() {
        let identifier = ScreenIdentifier(
            localizedName: "LG ULTRAGEAR+",
            width: 5120,
            height: 2160
        )

        XCTAssertEqual(identifier.key, "LG ULTRAGEAR+_5120x2160")
    }

    func testScreenIdentifier_KeyIsUniqueForDifferentScreens() {
        let screen1 = ScreenIdentifier(localizedName: "Display A", width: 1920, height: 1080)
        let screen2 = ScreenIdentifier(localizedName: "Display B", width: 1920, height: 1080)
        let screen3 = ScreenIdentifier(localizedName: "Display A", width: 2560, height: 1440)

        XCTAssertNotEqual(screen1.key, screen2.key)
        XCTAssertNotEqual(screen1.key, screen3.key)
        XCTAssertNotEqual(screen2.key, screen3.key)
    }

    // MARK: - Equatable Tests

    func testScreenIdentifier_EqualityWithSameValues() {
        let id1 = ScreenIdentifier(localizedName: "Test", width: 1920, height: 1080)
        let id2 = ScreenIdentifier(localizedName: "Test", width: 1920, height: 1080)

        XCTAssertEqual(id1, id2)
    }

    func testScreenIdentifier_InequalityWithDifferentName() {
        let id1 = ScreenIdentifier(localizedName: "Display A", width: 1920, height: 1080)
        let id2 = ScreenIdentifier(localizedName: "Display B", width: 1920, height: 1080)

        XCTAssertNotEqual(id1, id2)
    }

    func testScreenIdentifier_InequalityWithDifferentSize() {
        let id1 = ScreenIdentifier(localizedName: "Test", width: 1920, height: 1080)
        let id2 = ScreenIdentifier(localizedName: "Test", width: 2560, height: 1440)

        XCTAssertNotEqual(id1, id2)
    }

    // MARK: - Hashable Tests

    func testScreenIdentifier_HashableWorksInSet() {
        let id1 = ScreenIdentifier(localizedName: "Test", width: 1920, height: 1080)
        let id2 = ScreenIdentifier(localizedName: "Test", width: 1920, height: 1080)
        let id3 = ScreenIdentifier(localizedName: "Other", width: 1920, height: 1080)

        var set: Set<ScreenIdentifier> = []
        set.insert(id1)
        set.insert(id2)
        set.insert(id3)

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Codable Tests

    func testScreenIdentifier_EncodesAndDecodes() throws {
        let original = ScreenIdentifier(
            localizedName: "Test Display",
            width: 2560,
            height: 1440
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScreenIdentifier.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Portrait Display Tests

    func testScreenIdentifier_WorksWithPortraitDisplay() {
        // 縦置きディスプレイ（幅 < 高さ）
        let portrait = ScreenIdentifier(
            localizedName: "Portrait Monitor",
            width: 1440,
            height: 2560
        )

        XCTAssertEqual(portrait.key, "Portrait Monitor_1440x2560")
        XCTAssertTrue(portrait.height > portrait.width)
    }

    // MARK: - isPortrait Tests

    func testScreenIdentifier_IsPortraitReturnsTrueForPortrait() {
        let portrait = ScreenIdentifier(localizedName: "Test", width: 1080, height: 1920)
        XCTAssertTrue(portrait.isPortrait)
    }

    func testScreenIdentifier_IsPortraitReturnsFalseForLandscape() {
        let landscape = ScreenIdentifier(localizedName: "Test", width: 1920, height: 1080)
        XCTAssertFalse(landscape.isPortrait)
    }

    func testScreenIdentifier_IsPortraitReturnsFalseForSquare() {
        let square = ScreenIdentifier(localizedName: "Test", width: 1000, height: 1000)
        XCTAssertFalse(square.isPortrait)
    }
}
