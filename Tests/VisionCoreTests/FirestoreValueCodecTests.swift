import XCTest
@testable import VisionCore

/// Direct port of FirestoreValueCodecTest.kt's real round-trip cases.
final class FirestoreValueCodecTests: XCTestCase {
    func test_encodingAString_producesStringValue() {
        let result = FirestoreValueCodec.encodeFields(["title": "Airtime R50"])
        let title = result["title"] as? [String: Any]
        XCTAssertEqual(title?["stringValue"] as? String, "Airtime R50")
    }

    func test_encodingAWholeNumberDouble_producesIntegerValue_notDoubleValue() {
        let result = FirestoreValueCodec.encodeFields(["pointsCost": 500.0])
        let field = result["pointsCost"] as? [String: Any]
        XCTAssertEqual(field?["integerValue"] as? String, "500")
        XCTAssertNil(field?["doubleValue"])
    }

    func test_encodingAFractionalDouble_producesDoubleValue() {
        let result = FirestoreValueCodec.encodeFields(["currencyValue": 49.99])
        let field = result["currencyValue"] as? [String: Any]
        XCTAssertEqual(field?["doubleValue"] as? Double, 49.99)
    }

    func test_encodingABool_producesBooleanValue_notMistakenForANumber() {
        let result = FirestoreValueCodec.encodeFields(["isActive": true])
        let field = result["isActive"] as? [String: Any]
        XCTAssertEqual(field?["booleanValue"] as? Bool, true)
        XCTAssertNil(field?["integerValue"])
    }

    func test_encodingNil_producesNullValue() {
        let result = FirestoreValueCodec.encodeFields(["voucherCode": nil])
        let field = result["voucherCode"] as? [String: Any]
        XCTAssertNotNil(field?["nullValue"])
    }

    func test_decodingARealFirestoreDocument_roundTripsEveryRealType() {
        let fields: [String: Any] = [
            "title": ["stringValue": "Airtime R50"],
            "pointsCost": ["integerValue": "500"],
            "currencyValue": ["doubleValue": 49.99],
            "isActive": ["booleanValue": true],
            "voucherCode": ["nullValue": NSNull()],
        ]
        let decoded = FirestoreValueCodec.decodeFields(fields)
        XCTAssertEqual(decoded["title"] as? String, "Airtime R50")
        XCTAssertEqual(decoded["pointsCost"] as? Int64, 500)
        XCTAssertEqual(decoded["currencyValue"] as? Double, 49.99)
        XCTAssertEqual(decoded["isActive"] as? Bool, true)
        XCTAssertTrue(decoded.keys.contains("voucherCode"))
        XCTAssertNil(decoded["voucherCode"] ?? nil)
    }

    func test_anEmptyFieldsObject_decodesToAnEmptyMap() {
        XCTAssertTrue(FirestoreValueCodec.decodeFields(nil).isEmpty)
        XCTAssertTrue(FirestoreValueCodec.decodeFields([:]).isEmpty)
    }
}
