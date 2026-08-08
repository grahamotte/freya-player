import Foundation

extension KeyedDecodingContainer {
    func decodeLossyStringIfPresent(forKey key: Key) throws -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return string
        }

        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return String(int)
        }

        return nil
    }

    func decodeLossyString(forKey key: Key) throws -> String {
        if let string = try? decode(String.self, forKey: key) {
            return string
        }

        if let int = try? decode(Int.self, forKey: key) {
            return String(int)
        }

        throw DecodingError.typeMismatch(
            String.self,
            .init(codingPath: codingPath + [key], debugDescription: "Expected a String or Int.")
        )
    }

    func decodeLossyIntIfPresent(forKey key: Key) throws -> Int? {
        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return int
        }

        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Int(string)
        }

        return nil
    }

    func decodeLossyBoolIfPresent(forKey key: Key) throws -> Bool? {
        if let bool = try? decodeIfPresent(Bool.self, forKey: key) {
            return bool
        }

        if let int = try decodeLossyIntIfPresent(forKey: key) {
            return int != 0
        }

        if let string = try? decodeIfPresent(String.self, forKey: key) {
            switch string.lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }

        return nil
    }
}
