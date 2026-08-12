/// Based on https://github.com/Flight-School/AnyCodable/blob/master/Sources/AnyCodable/AnyDecodable.swift
///
/// Swift's `Codable` API (the built-in Swift serialization protocol) does not perform a full 'decode' operation
/// until it actually decodes a Type from the data. This type, `AnyDecodable`, and `AnyEncodable` exercise every
/// decoding and encoding opportunity available in an available `Encoder` or `Decoder`.
///
/// TL;DR where other languages may be able to do `data.decode()`, Swift has to do `data.decode().exerciseValues`.

struct AnyCodable: Codable {
    public let value: Any?

    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}

extension AnyCodable: _AnyEncodable, _AnyDecodable {}
