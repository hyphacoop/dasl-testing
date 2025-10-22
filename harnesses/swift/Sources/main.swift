#if canImport(Foundation)
import Foundation
#else
import FoundationEssentials
#endif

protocol TestHandler {
    var link: String { get }
    var version: String { get }
    func roundtrip<T: Codable>(_ type: T.Type, from data: Data) -> TestResult
    func invalidEncode<T: Codable>(_ type: T.Type, from data: Data) -> TestResult
    func invalidDecode<T: Codable>(_ type: T.Type, from data: Data) -> TestResult
}

let fixturesDir = "../../fixtures/cbor/";
typealias Fixture = (group: String, tests: [TestCase])

func readFixtures() throws -> [Fixture] {
    let decoder = JSONDecoder()
    let files = try FileManager.default.contentsOfDirectory(atPath: fixturesDir)
    var fixtures: [Fixture] = []
    for file in files {
        let url = URL(fileURLWithPath: fixturesDir + "/" + file)
        let data = try Data(contentsOf: url)
        let tests = try decoder.decode([TestCase].self, from: data)
        fixtures.append((group: url.lastPathComponent, tests: tests))
    }
    return fixtures
}

func runTests(fixtures: [Fixture], handler: TestHandler) throws {
    var files: [String: [TestResult]] = [:]
    for group in fixtures {
        files[group.group] = group.tests.map { runTest(test: $0, handler: handler) }
    }
    let results = Results(
        metadata: .init(link: "https://github.com/thecoolwinter/CBOR.git", version: "1.1.0"),
        files: files
    )
    print(String(decoding: try JSONEncoder().encode(results), as: UTF8.self))
}

func runTest(test: TestCase, handler: TestHandler) -> TestResult {
    let data = test.data.asHexData()

    return switch test.type {
        case .roundTrip:
            handler.roundtrip(AnyCodable.self, from: data)
        case .invalidIn:
            handler.invalidDecode(AnyCodable.self, from: data)
        case .invalidOut:
            handler.invalidEncode(AnyCodable.self, from: data)
        }
}

// If you're adding more libraries, add your `TestHandler` type here by checking arguments
let handler: TestHandler = CBORHandler()

try runTests(fixtures: readFixtures(), handler: handler)
