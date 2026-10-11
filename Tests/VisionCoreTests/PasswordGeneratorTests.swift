import XCTest
@testable import VisionCore

final class PasswordGeneratorTests: XCTestCase {
    func testDefaultLengthAndMinimumLength() {
        XCTAssertEqual(PasswordGenerator.generate().count, 20)
        XCTAssertEqual(PasswordGenerator.generate(length: 3).count, 8)
        XCTAssertEqual(PasswordGenerator.generate(length: 40).count, 40)
    }

    func testAlwaysHasEveryCharacterClassAndNoAmbiguousCharacters() {
        for _ in 0..<200 {
            let password = PasswordGenerator.generate(length: 12)
            XCTAssertTrue(password.contains { "abcdefghijkmnopqrstuvwxyz".contains($0) })
            XCTAssertTrue(password.contains { "ABCDEFGHJKLMNPQRSTUVWXYZ".contains($0) })
            XCTAssertTrue(password.contains { "23456789".contains($0) })
            XCTAssertTrue(password.contains { "!@#$%^&*-_=+".contains($0) })
            XCTAssertFalse(password.contains { "lIO01".contains($0) })
        }
    }

    func testTwoPasswordsDiffer() {
        XCTAssertNotEqual(PasswordGenerator.generate(), PasswordGenerator.generate())
    }
}
