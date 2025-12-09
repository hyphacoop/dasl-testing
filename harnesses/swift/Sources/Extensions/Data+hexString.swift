//
//  Data+hexString.swift
//  CBOR
//
//  Created by Khan Winter on 9/1/25.
//

#if canImport(Foundation)
import Foundation
#else
import FoundationEssentials
#endif

extension Data {
    private static let hexAlphabet = Array("0123456789abcdef".unicodeScalars)

    func hexString() -> String {
        // I'd rather use: map { String(format: "%02hhX", $0) }.joined()
        // but that doesn't compile on linux...
        String(reduce(into: "".unicodeScalars) { result, value in
            result.append(Self.hexAlphabet[Int(value / 0x10)])
            result.append(Self.hexAlphabet[Int(value % 0x10)])
        })
    }
}

extension String {
    func asHexData() -> Data {
        guard self.count.isMultiple(of: 2) else {
            fatalError()
        }

        let chars = self.map { $0 }
        let bytes = stride(from: 0, to: chars.count, by: 2)
            .map { String(chars[$0]) + String(chars[$0 + 1]) }
            .compactMap { UInt8($0, radix: 16) }

        guard self.count / bytes.count == 2 else { fatalError() }
        return Data(bytes)
    }
}
