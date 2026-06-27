import Foundation

public enum MindDeskJSONDocumentKind: Equatable, Sendable {
    case manifest
    case interchangePackage
    case proposalEnvelope
    case validationReport
    case unknown

    public static func classify(_ data: Data) -> MindDeskJSONDocumentKind {
        MindDeskJSONDocumentClassifier.classify(data).kind
    }
}

public struct MindDeskJSONDocumentClassification: Equatable, Sendable {
    public var kind: MindDeskJSONDocumentKind
    public var hasTopLevelFormat: Bool

    public init(kind: MindDeskJSONDocumentKind, hasTopLevelFormat: Bool) {
        self.kind = kind
        self.hasTopLevelFormat = hasTopLevelFormat
    }
}

public enum MindDeskJSONDocumentClassifier {
    public static func classify(_ data: Data) -> MindDeskJSONDocumentClassification {
        var scanner = MindDeskJSONTopLevelScanner(data: data)
        return scanner.classification()
    }
}

private struct MindDeskJSONTopLevelScanner {
    private static let maximumStringTokenLength = 256
    private static let maximumNestedDepth = 64

    private let bytes: [UInt8]
    private var index: Int = 0
    private var topLevelFormat: String?
    private var hasTopLevelFormat = false
    private var formatConflict = false
    private var hasSchemaVersion = false
    private var schemaVersionIsInteger = false
    private var schemaVersionConflict = false

    init(data: Data) {
        bytes = Array(data)
    }

    mutating func classification() -> MindDeskJSONDocumentClassification {
        guard scanTopLevelObject() else {
            return MindDeskJSONDocumentClassification(kind: .unknown, hasTopLevelFormat: hasTopLevelFormat)
        }
        let kind: MindDeskJSONDocumentKind
        if formatConflict {
            kind = .unknown
        } else if let topLevelFormat {
            switch topLevelFormat {
            case ExportManifest.currentFormat:
                kind = .manifest
            case MindDeskInterchangePackage.currentFormat:
                kind = .interchangePackage
            case MindDeskProposalEnvelope.currentFormat:
                kind = .proposalEnvelope
            case MindDeskValidationReport.currentFormat:
                kind = .validationReport
            default:
                kind = .unknown
            }
        } else if !hasTopLevelFormat,
                  hasSchemaVersion,
                  schemaVersionIsInteger,
                  !schemaVersionConflict {
            kind = .manifest
        } else {
            kind = .unknown
        }
        return MindDeskJSONDocumentClassification(kind: kind, hasTopLevelFormat: hasTopLevelFormat)
    }

    private mutating func scanTopLevelObject() -> Bool {
        skipWhitespace()
        guard consume(UInt8(ascii: "{")) else { return false }
        skipWhitespace()
        if consume(UInt8(ascii: "}")) {
            skipWhitespace()
            return isAtEnd
        }

        while true {
            skipWhitespace()
            guard let key = parseString(maximumLength: Self.maximumStringTokenLength) else { return false }
            skipWhitespace()
            guard consume(UInt8(ascii: ":")) else { return false }
            skipWhitespace()

            if key == "format" {
                guard scanTopLevelFormatValue() else { return false }
            } else if key == "schemaVersion" {
                guard scanTopLevelSchemaVersionValue() else { return false }
            } else {
                guard skipValue(depth: 1) else { return false }
            }

            skipWhitespace()
            if consume(UInt8(ascii: "}")) {
                skipWhitespace()
                return isAtEnd
            }
            guard consume(UInt8(ascii: ",")) else { return false }
        }
    }

    private mutating func scanTopLevelFormatValue() -> Bool {
        if hasTopLevelFormat {
            formatConflict = true
        }
        hasTopLevelFormat = true
        if currentByte == UInt8(ascii: "\"") {
            guard let value = parseString(maximumLength: Self.maximumStringTokenLength) else { return false }
            if let topLevelFormat,
               topLevelFormat != value {
                formatConflict = true
            }
            topLevelFormat = value
            return true
        }
        formatConflict = true
        return skipValue(depth: 1)
    }

    private mutating func scanTopLevelSchemaVersionValue() -> Bool {
        if hasSchemaVersion {
            schemaVersionConflict = true
        }
        hasSchemaVersion = true
        if skipIntegerToken() {
            schemaVersionIsInteger = true
            return true
        }
        schemaVersionIsInteger = false
        return skipValue(depth: 1)
    }

    private mutating func skipValue(depth: Int) -> Bool {
        guard depth <= Self.maximumNestedDepth else { return false }
        skipWhitespace()
        guard let byte = currentByte else { return false }
        switch byte {
        case UInt8(ascii: "{"):
            return skipObject(depth: depth + 1)
        case UInt8(ascii: "["):
            return skipArray(depth: depth + 1)
        case UInt8(ascii: "\""):
            return skipString()
        case UInt8(ascii: "t"):
            return consumeLiteral("true")
        case UInt8(ascii: "f"):
            return consumeLiteral("false")
        case UInt8(ascii: "n"):
            return consumeLiteral("null")
        default:
            return skipNumber()
        }
    }

    private mutating func skipObject(depth: Int) -> Bool {
        guard depth <= Self.maximumNestedDepth,
              consume(UInt8(ascii: "{")) else { return false }
        skipWhitespace()
        if consume(UInt8(ascii: "}")) { return true }
        while true {
            skipWhitespace()
            guard skipString() else { return false }
            skipWhitespace()
            guard consume(UInt8(ascii: ":")) else { return false }
            guard skipValue(depth: depth + 1) else { return false }
            skipWhitespace()
            if consume(UInt8(ascii: "}")) { return true }
            guard consume(UInt8(ascii: ",")) else { return false }
        }
    }

    private mutating func skipArray(depth: Int) -> Bool {
        guard depth <= Self.maximumNestedDepth,
              consume(UInt8(ascii: "[")) else { return false }
        skipWhitespace()
        if consume(UInt8(ascii: "]")) { return true }
        while true {
            guard skipValue(depth: depth + 1) else { return false }
            skipWhitespace()
            if consume(UInt8(ascii: "]")) { return true }
            guard consume(UInt8(ascii: ",")) else { return false }
        }
    }

    private mutating func parseString(maximumLength: Int) -> String? {
        guard consume(UInt8(ascii: "\"")) else { return nil }
        var result = ""
        var segmentStart = index

        while let byte = currentByte {
            if byte == UInt8(ascii: "\"") {
                guard appendSegment(from: segmentStart, to: index, into: &result),
                      result.count <= maximumLength else { return nil }
                index += 1
                return result
            }
            if byte == UInt8(ascii: "\\") {
                guard appendSegment(from: segmentStart, to: index, into: &result),
                      result.count <= maximumLength else { return nil }
                index += 1
                guard let escaped = parseEscapedCharacter() else { return nil }
                result.append(escaped)
                guard result.count <= maximumLength else { return nil }
                segmentStart = index
                continue
            }
            guard byte >= 0x20 else { return nil }
            index += 1
        }
        return nil
    }

    private mutating func skipString() -> Bool {
        guard consume(UInt8(ascii: "\"")) else { return false }
        while let byte = currentByte {
            if byte == UInt8(ascii: "\"") {
                index += 1
                return true
            }
            if byte == UInt8(ascii: "\\") {
                index += 1
                guard skipEscapedCharacter() else { return false }
                continue
            }
            guard byte >= 0x20 else { return false }
            index += 1
        }
        return false
    }

    private mutating func parseEscapedCharacter() -> Character? {
        guard let byte = currentByte else { return nil }
        index += 1
        switch byte {
        case UInt8(ascii: "\""):
            return "\""
        case UInt8(ascii: "\\"):
            return "\\"
        case UInt8(ascii: "/"):
            return "/"
        case UInt8(ascii: "b"):
            return "\u{8}"
        case UInt8(ascii: "f"):
            return "\u{c}"
        case UInt8(ascii: "n"):
            return "\n"
        case UInt8(ascii: "r"):
            return "\r"
        case UInt8(ascii: "t"):
            return "\t"
        case UInt8(ascii: "u"):
            guard let scalar = parseUnicodeScalarEscape() else { return nil }
            return Character(scalar)
        default:
            return nil
        }
    }

    private mutating func skipEscapedCharacter() -> Bool {
        guard let byte = currentByte else { return false }
        index += 1
        switch byte {
        case UInt8(ascii: "\""),
             UInt8(ascii: "\\"),
             UInt8(ascii: "/"),
             UInt8(ascii: "b"),
             UInt8(ascii: "f"),
             UInt8(ascii: "n"),
             UInt8(ascii: "r"),
             UInt8(ascii: "t"):
            return true
        case UInt8(ascii: "u"):
            return skipUnicodeScalarEscape()
        default:
            return false
        }
    }

    private mutating func parseUnicodeScalarEscape() -> UnicodeScalar? {
        guard index + 4 <= bytes.count else { return nil }
        var value = 0
        for _ in 0..<4 {
            guard let hex = hexValue(bytes[index]) else { return nil }
            value = value * 16 + hex
            index += 1
        }
        return UnicodeScalar(value)
    }

    private mutating func skipUnicodeScalarEscape() -> Bool {
        guard index + 4 <= bytes.count else { return false }
        for _ in 0..<4 {
            guard hexValue(bytes[index]) != nil else { return false }
            index += 1
        }
        return true
    }

    private mutating func skipIntegerToken() -> Bool {
        let start = index
        if consume(UInt8(ascii: "-")) {
            guard currentByte?.isDigit == true else {
                index = start
                return false
            }
        }
        guard currentByte?.isDigit == true else { return false }
        if currentByte == UInt8(ascii: "0") {
            index += 1
        } else {
            while currentByte?.isDigit == true {
                index += 1
            }
        }
        if currentByte == UInt8(ascii: ".") ||
            currentByte == UInt8(ascii: "e") ||
            currentByte == UInt8(ascii: "E") {
            index = start
            return false
        }
        return true
    }

    private mutating func skipNumber() -> Bool {
        let start = index
        _ = consume(UInt8(ascii: "-"))
        guard currentByte?.isDigit == true else { return false }
        if currentByte == UInt8(ascii: "0") {
            index += 1
        } else {
            while currentByte?.isDigit == true {
                index += 1
            }
        }
        if consume(UInt8(ascii: ".")) {
            guard currentByte?.isDigit == true else {
                index = start
                return false
            }
            while currentByte?.isDigit == true {
                index += 1
            }
        }
        if currentByte == UInt8(ascii: "e") || currentByte == UInt8(ascii: "E") {
            index += 1
            if currentByte == UInt8(ascii: "+") || currentByte == UInt8(ascii: "-") {
                index += 1
            }
            guard currentByte?.isDigit == true else {
                index = start
                return false
            }
            while currentByte?.isDigit == true {
                index += 1
            }
        }
        return true
    }

    private mutating func consumeLiteral(_ literal: String) -> Bool {
        for byte in literal.utf8 {
            guard consume(byte) else { return false }
        }
        return true
    }

    private mutating func skipWhitespace() {
        while let byte = currentByte,
              byte == UInt8(ascii: " ") ||
              byte == UInt8(ascii: "\n") ||
              byte == UInt8(ascii: "\r") ||
              byte == UInt8(ascii: "\t") {
            index += 1
        }
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard currentByte == byte else { return false }
        index += 1
        return true
    }

    private func appendSegment(from start: Int, to end: Int, into result: inout String) -> Bool {
        guard start <= end else { return false }
        if start == end { return true }
        guard let segment = String(data: Data(bytes[start..<end]), encoding: .utf8) else {
            return false
        }
        result.append(segment)
        return true
    }

    private func hexValue(_ byte: UInt8) -> Int? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            return Int(byte - UInt8(ascii: "0"))
        case UInt8(ascii: "a")...UInt8(ascii: "f"):
            return Int(byte - UInt8(ascii: "a")) + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"):
            return Int(byte - UInt8(ascii: "A")) + 10
        default:
            return nil
        }
    }

    private var currentByte: UInt8? {
        index < bytes.count ? bytes[index] : nil
    }

    private var isAtEnd: Bool {
        index >= bytes.count
    }
}

private extension UInt8 {
    var isDigit: Bool {
        self >= UInt8(ascii: "0") && self <= UInt8(ascii: "9")
    }
}
