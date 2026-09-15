//
//  TestCase.swift
//  swift
//
//  Created by Khan Winter on 10/20/25.
//

struct TestCase: Codable {
    enum TestType: String, Codable {
        case roundTrip = "roundtrip"
        case invalidIn = "invalid_in"
        case invalidOut = "invalid_out"
    }

    let type: TestType
    let data: String
    let name: String
    let tags: [String]
    let desc: String
}
