import XCTest
@testable import VisionCore

/// Direct port of MobileValidationTest.kt's real cases (where that exists)
/// plus desktop's own rewardsCatalog test cases.
final class MobileValidationTests: XCTestCase {
    func test_aValidLocalNumber_isValid() {
        XCTAssertTrue(MobileValidation.isValidSouthAfricanMobileNumber("0821234567"))
    }

    func test_aValidLocalNumberWithSpaces_isValid() {
        XCTAssertTrue(MobileValidation.isValidSouthAfricanMobileNumber("082 123 4567"))
    }

    func test_aValidIntlNumber_isValid() {
        XCTAssertTrue(MobileValidation.isValidSouthAfricanMobileNumber("+27821234567"))
    }

    func test_tooFewDigits_isInvalid() {
        XCTAssertFalse(MobileValidation.isValidSouthAfricanMobileNumber("08212345"))
    }

    func test_missingLeadingZero_isInvalid() {
        XCTAssertFalse(MobileValidation.isValidSouthAfricanMobileNumber("821234567"))
    }

    func test_wrongCountryCode_isInvalid() {
        XCTAssertFalse(MobileValidation.isValidSouthAfricanMobileNumber("+1821234567"))
    }

    func test_nonDigitCharacters_isInvalid() {
        XCTAssertFalse(MobileValidation.isValidSouthAfricanMobileNumber("082abc4567"))
    }

    func test_maskingARealNumber_keepsTheFirst3AndLast4() {
        XCTAssertEqual(MobileValidation.maskMobileNumber("0821234567"), "082 ••• 4567")
    }

    func test_maskingATooShortNumber_returnsAllDots() {
        XCTAssertEqual(MobileValidation.maskMobileNumber("12345"), "•••")
    }
}
