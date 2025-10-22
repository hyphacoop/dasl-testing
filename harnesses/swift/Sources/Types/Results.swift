//
//  Results.swift
//  swift
//
//  Created by Khan Winter on 10/20/25.
//

struct Results: Encodable {
    struct Metadata: Encodable {
        let link: String
        let version: String
    }

    let metadata: Metadata
    let files: [String: [TestResult]]
}
