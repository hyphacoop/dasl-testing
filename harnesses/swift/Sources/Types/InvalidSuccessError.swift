//
//  InvalidSuccessError.swift
//  swift
//
//  Created by Khan Winter on 10/20/25.
//

#if canImport(Foundation)
import Foundation
#else
import FoundationEssentials
#endif

// @unchecked Sendable is ugly but this is a test suite so whatever.
// Don't copy this if you're building an app
struct InvalidSuccessError: Error, @unchecked Sendable, LocalizedError {
    let foundType: Any?

    var errorDescription: String? {
        "Invalid success, was able to encode/decode: \(String(describing: foundType))"
    }
}
