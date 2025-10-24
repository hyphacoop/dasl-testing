#if canImport(Foundation)
import Foundation
#else
import FoundationEssentials
#endif
import CBOR

// CBOR Decoding methods for
// https://github.com/thecoolwinter/CBOR

struct CBORHandler: TestHandler {
    var link: String { "https://github.com/thecoolwinter/CBOR" }
    var version: String { "1.1.0" }

    func roundtrip<T: Codable>(_ type: T.Type, from data: Data) -> TestResult {
        let encoder = DAGCBOREncoder()
        let decoder = DAGCBORDecoder()
        do {
            let decoded = try decoder.decode(AnyCodable.self, from: data)
            let encoded = try encoder.encode(decoded)
            guard encoded == data else {
                return TestResult(pass: false, output: encoded)
            }
            return TestResult(pass: true)
        } catch {
            return TestResult(pass: false, error: error)
        }
    }

    func invalidEncode<T: Codable>(_ type: T.Type, from data: Data) -> TestResult {
        let decoder = DAGCBORDecoder()
        do {
            let decoded = try decoder.decode(T.self, from: data)
            return TestResult(pass: false, error: InvalidSuccessError(foundType: decoded))
        } catch {
            return TestResult(pass: true)
        }
    }

    func invalidDecode<T: Codable>(_ type: T.Type, from data: Data) -> TestResult {
        let encoder = DAGCBOREncoder()
        let decoder = DAGCBORDecoder()
        do {
            let decoded = try decoder.decode(AnyCodable.self, from: data)
            let encoded = try encoder.encode(decoded)
            return TestResult(pass: false, error: InvalidSuccessError(foundType: encoded))
        } catch {
            return TestResult(pass: true)
        }
    }
}
