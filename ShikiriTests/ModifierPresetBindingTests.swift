import XCTest
import CoreGraphics
@testable import Shikiri

final class ModifierFlagsTests: XCTestCase {
    // MARK: - ModifierFlags Tests

    func testModifierFlags_shiftOnly() {
        let flags = ModifierFlags(rawValue: CGEventFlags.maskShift.rawValue)
        XCTAssertTrue(flags.contains(.shift))
        XCTAssertFalse(flags.contains(.control))
        XCTAssertFalse(flags.contains(.option))
    }

    func testModifierFlags_shiftControl() {
        let flags = ModifierFlags([.shift, .control])
        XCTAssertTrue(flags.contains(.shift))
        XCTAssertTrue(flags.contains(.control))
        XCTAssertFalse(flags.contains(.option))
    }

    func testModifierFlags_shiftOption() {
        let flags = ModifierFlags([.shift, .option])
        XCTAssertTrue(flags.contains(.shift))
        XCTAssertFalse(flags.contains(.control))
        XCTAssertTrue(flags.contains(.option))
    }

    func testModifierFlags_fromCGEventFlags() {
        let cgFlags: CGEventFlags = [.maskShift, .maskControl]
        let flags = ModifierFlags(cgEventFlags: cgFlags)
        XCTAssertTrue(flags.contains(.shift))
        XCTAssertTrue(flags.contains(.control))
        XCTAssertFalse(flags.contains(.option))
    }

    func testModifierFlags_equality() {
        let flags1 = ModifierFlags([.shift, .control])
        let flags2 = ModifierFlags([.control, .shift])
        XCTAssertEqual(flags1, flags2)
    }

    func testModifierFlags_displayName() {
        XCTAssertEqual(ModifierFlags([.shift]).displayName, "⇧")
        XCTAssertEqual(ModifierFlags([.shift, .control]).displayName, "⌃⇧")
        XCTAssertEqual(ModifierFlags([.shift, .option]).displayName, "⌥⇧")
        XCTAssertEqual(ModifierFlags([.shift, .control, .option]).displayName, "⌃⌥⇧")
    }

    func testModifierFlags_containsShift() {
        XCTAssertTrue(ModifierFlags([.shift]).containsShift)
        XCTAssertTrue(ModifierFlags([.shift, .control]).containsShift)
        XCTAssertTrue(ModifierFlags([.shift, .option]).containsShift)
        XCTAssertFalse(ModifierFlags([.control]).containsShift)
        XCTAssertFalse(ModifierFlags([.option]).containsShift)
        XCTAssertFalse(ModifierFlags([]).containsShift)
    }

    func testModifierFlags_codable() throws {
        let flags = ModifierFlags([.shift, .control])

        let encoder = JSONEncoder()
        let data = try encoder.encode(flags)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ModifierFlags.self, from: data)

        XCTAssertEqual(decoded, flags)
    }
}
