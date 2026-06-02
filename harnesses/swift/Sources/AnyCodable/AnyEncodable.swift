/// Based on https://github.com/Flight-School/AnyCodable/blob/master/Sources/AnyCodable/AnyDecodable.swift
///
/// Swift's `Codable` API (the built-in Swift serialization protocol) does not perform a full 'decode' operation
/// until it actually decodes a Type from the data. This type, `AnyDecodable`, and `AnyEncodable` exercise every
/// decoding and encoding opportunity available in an available `Encoder` or `Decoder`.
///
/// TL;DR where other languages may be able to do `data.decode()`, Swift has to do `data.decode().exerciseValues`.

#if canImport(Foundation)
import Foundation
#else
import FoundationEssentials
#endif

struct AnyEncodable: Encodable {
    let value: Any?

    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}

protocol _AnyEncodable {
    var value: Any? { get }
    init<T>(_ value: T?)
}

extension AnyEncodable: _AnyEncodable {}

// MARK: - Encodable

extension _AnyEncodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if #available(macOS 15, *) {
            if let value = value as? Int128 {
                try container.encode(value)
                return
            } else if let value = value as? UInt128 {
                try container.encode(value)
                return
            }
        }

        switch value {
        case .none:
            try container.encodeNil()
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let int8 as Int8:
            try container.encode(int8)
        case let int16 as Int16:
            try container.encode(int16)
        case let int32 as Int32:
            try container.encode(int32)
        case let int64 as Int64:
            try container.encode(int64)
        case let uint as UInt:
            try container.encode(uint)
        case let uint8 as UInt8:
            try container.encode(uint8)
        case let uint16 as UInt16:
            try container.encode(uint16)
        case let uint32 as UInt32:
            try container.encode(uint32)
        case let uint64 as UInt64:
            try container.encode(uint64)
        case let float as Float:
            try container.encode(float)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let date as Date:
            try container.encode(date)
        case let array as [Any?]:
            try container.encode(array.map { AnyEncodable($0) })
        case let dictionary as [String: Any?]:
            try container.encode(dictionary.mapValues { AnyEncodable($0) })
        case let data as Data:
            try container.encode(data)
        case let encodable as Encodable:
            try encodable.encode(to: encoder)
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyEncodable value cannot be encoded")
            throw EncodingError.invalidValue(value as Any, context)
        }
    }
}
