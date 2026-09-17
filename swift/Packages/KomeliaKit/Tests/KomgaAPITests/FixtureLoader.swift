import Foundation
@testable import KomgaAPI

/// Loads JSON captured from the Komga fixture server (fixtures/komga, Komga 1.27.0).
enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try KomgaJSON.makeDecoder().decode(type, from: data(name))
    }
}

func encodedJSON<T: Encodable>(_ value: T) throws -> String {
    String(decoding: try KomgaJSON.makeEncoder().encode(value), as: UTF8.self)
}

import Testing
