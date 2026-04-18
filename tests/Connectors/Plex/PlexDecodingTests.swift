import XCTest
#if os(tvOS)
@testable import freya_player
#else
@testable import freya_player_ipad
#endif

@MainActor
final class PlexDecodingTests: XCTestCase {
    func testLossyStringDecodesStringOrInt() throws {
        let value = try JSONDecoder().decode(Wrapper.self, from: jsonBody(["string": 42, "optional": "hello"]))
        XCTAssertEqual(value.string, "42")
        XCTAssertEqual(value.optional, "hello")
    }

    func testLossyIntDecodesStringOrInt() throws {
        let value = try JSONDecoder().decode(Wrapper.self, from: jsonBody(["string": "42"]))
        XCTAssertEqual(value.optionalInt, nil)
        XCTAssertEqual(value.lossyInt(from: ["string": "1", "int": "8"]), 8)
    }

    func testLossyBoolDecodesMultipleRepresentations() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(BoolWrapper.self, from: jsonBody(["value": true])).value, true)
        XCTAssertEqual(try decoder.decode(BoolWrapper.self, from: jsonBody(["value": 1])).value, true)
        XCTAssertEqual(try decoder.decode(BoolWrapper.self, from: jsonBody(["value": "no"])).value, false)
        XCTAssertNil(try decoder.decode(BoolWrapper.self, from: jsonBody(["value": "maybe"])).value)
    }
}

private struct Wrapper: Decodable {
    let string: String
    let optional: String?
    let optionalInt: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        string = try container.decodeLossyString(forKey: .string)
        optional = try container.decodeLossyStringIfPresent(forKey: .optional)
        optionalInt = try container.decodeLossyIntIfPresent(forKey: .int)
    }

    func lossyInt(from json: [String: Any]) -> Int? {
        try? JSONDecoder().decode(Self.self, from: jsonBody(json)).optionalInt
    }

    private enum CodingKeys: String, CodingKey {
        case string
        case optional
        case int
    }
}

private struct BoolWrapper: Decodable {
    let value: Bool?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeLossyBoolIfPresent(forKey: .value)
    }

    private enum CodingKeys: String, CodingKey {
        case value
    }
}
