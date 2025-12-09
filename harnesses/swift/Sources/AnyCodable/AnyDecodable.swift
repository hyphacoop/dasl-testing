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

struct AnyDecodable: Decodable {
    let value: Any?

    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}

@usableFromInline
protocol _AnyDecodable {
    var value: Any? { get }
    init<T>(_ value: T?)
}

extension AnyDecodable: _AnyDecodable {}

extension _AnyDecodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.init(Optional<Void>.none)
        } else if let bool = try? container.decode(Bool.self) {
            self.init(bool)
        } else if let int = try? container.decode(Int.self) {
            self.init(int)
        } else if let uint = try? container.decode(UInt.self) {
            self.init(uint)
        } else if #available(macOS 15.0, *), let int = try? container.decode(Int128.self) {
            self.init(int)
        } else if #available(macOS 15.0, *), let int = try? container.decode(UInt128.self) {
            self.init(int)
        } else if let double = try? container.decode(Double.self) {
            self.init(double)
        } else if let string = try? container.decode(String.self) {
            self.init(string)
        } else if let array = try? container.decode([AnyDecodable].self) {
            self.init(array.map { $0.value })
        } else if let dictionary = try? container.decode([String: AnyDecodable].self) {
            self.init(dictionary.mapValues { $0.value })
        } else if let data = try? container.decode(Data.self) {
            self.init(data)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyDecodable value cannot be decoded")
        }
    }
}
