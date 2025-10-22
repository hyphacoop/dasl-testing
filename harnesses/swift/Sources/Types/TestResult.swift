//
//  TestResult.swift
//  swift
//
//  Created by Khan Winter on 10/20/25.
//

#if canImport(Foundation)
import Foundation
#else
import FoundationEssentials
#endif

struct TestResult: Encodable {
    let pass: Bool
    let error: Error?
    let output: Data?

    init(pass: Bool, error: Error? = nil, output: Data? = nil) {
        self.pass = pass
        self.error = error
        self.output = output
    }

    enum CodingKeys: String, CodingKey {
        case pass, error, output
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pass, forKey: .pass)
        if let error {
            try container.encode(String(describing: error.self) + ": " + error.localizedDescription, forKey: .error)
        } else {
            try container.encodeNil(forKey: .error)
        }
        try container.encode(output?.hexString(), forKey: .output)
    }
}
