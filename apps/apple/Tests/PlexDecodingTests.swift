import Foundation
import XCTest
@testable import FreyaPlayerCore

final class PlexDecodingTests: XCTestCase {
    func testLossyValuesDecodeAcrossRepresentations() throws {
        let decoder = JSONDecoder()
        let integer = try decoder.decode(Wrapper.self, from: Data(#"{"string":42,"integer":"8","boolean":"yes"}"#.utf8))
        let falseValue = try decoder.decode(Wrapper.self, from: Data(#"{"string":"value","boolean":0}"#.utf8))

        XCTAssertEqual(integer.string, "42")
        XCTAssertEqual(integer.integer, 8)
        XCTAssertEqual(integer.boolean, true)
        XCTAssertEqual(falseValue.boolean, false)
    }
}

private struct Wrapper: Decodable {
    let string: String
    let integer: Int?
    let boolean: Bool?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        string = try values.decodeLossyString(forKey: .string)
        integer = try values.decodeLossyIntIfPresent(forKey: .integer)
        boolean = try values.decodeLossyBoolIfPresent(forKey: .boolean)
    }

    private enum CodingKeys: String, CodingKey {
        case string
        case integer
        case boolean
    }
}
