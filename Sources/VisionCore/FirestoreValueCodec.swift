import Foundation

/// Real encode/decode between plain Swift values and Firestore's typed REST
/// wire format (every field must be explicitly typed, e.g.
/// {"stringValue": "x"} rather than a plain JSON string) — direct port of
/// FirestoreValueCodec.kt, using `[String: Any]`/`Any` the same way the
/// Kotlin original uses `Map<String, Any?>`/`Any`, since Firestore's own
/// REST JSON shape has no fixed Codable structure to decode into (a
/// document's fields are whatever the admin's catalog schema happens to
/// hold). Only the shapes this app's real data ever needs:
/// string/number/boolean/null, plus nested maps/arrays for completeness.
public enum FirestoreValueCodec {
    public static func encodeFields(_ obj: [String: Any?]) -> [String: Any] {
        var fields: [String: Any] = [:]
        for (key, value) in obj {
            fields[key] = value == nil ? ["nullValue": NSNull()] : encodeValue(value!)
        }
        return fields
    }

    private static func encodeValue(_ value: Any) -> [String: Any] {
        switch value {
        case let v as String:
            return ["stringValue": v]
        case let v as Bool:
            // Must be checked before Int/Double — Bool bridges to NSNumber
            // in Swift's Any-boxing the same way it does in Kotlin's Any,
            // so an Int check alone would wrongly catch every Bool first.
            return ["booleanValue": v]
        case let v as Int:
            return ["integerValue": String(v)]
        case let v as Double:
            if v == v.rounded(.towardZero) && v.isFinite {
                return ["integerValue": String(Int64(v))]
            }
            return ["doubleValue": v]
        case let v as [Any?]:
            let values = v.map { $0 == nil ? ["nullValue": NSNull()] : encodeValue($0!) }
            return ["arrayValue": ["values": values]]
        case let v as [String: Any?]:
            return ["mapValue": ["fields": encodeFields(v)]]
        default:
            preconditionFailure("Cannot encode value of type \(type(of: value)) for Firestore")
        }
    }

    public static func decodeFields(_ fields: [String: Any]?) -> [String: Any?] {
        guard let fields else { return [:] }
        var result: [String: Any?] = [:]
        for (key, value) in fields {
            result[key] = decodeValue(value as? [String: Any] ?? [:])
        }
        return result
    }

    private static func decodeValue(_ value: [String: Any]) -> Any? {
        if let s = value["stringValue"] as? String { return s }
        if let i = value["integerValue"] as? String { return Int64(i) }
        if let d = value["doubleValue"] as? Double { return d }
        if let b = value["booleanValue"] as? Bool { return b }
        if value["nullValue"] != nil { return nil }
        if let arr = value["arrayValue"] as? [String: Any] {
            let values = arr["values"] as? [[String: Any]] ?? []
            return values.map { decodeValue($0) }
        }
        if let map = value["mapValue"] as? [String: Any] {
            return decodeFields(map["fields"] as? [String: Any])
        }
        preconditionFailure("Unrecognized Firestore value shape: \(value)")
    }
}
