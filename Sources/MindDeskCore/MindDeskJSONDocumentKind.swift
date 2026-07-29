import Foundation

private let mindDeskInterchangePackageFormat = "minddesk.interchange.package"
private let mindDeskProposalEnvelopeFormat = "minddesk.proposal.envelope"
private let mindDeskValidationReportFormat = "minddesk.validation.report"

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
    private static let maximumStringTokenScalars = 256
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
            return MindDeskJSONDocumentClassification(kind: .unknown, hasTopLevelFormat: false)
        }
        let kind: MindDeskJSONDocumentKind
        if formatConflict {
            kind = .unknown
        } else if let topLevelFormat {
            switch topLevelFormat {
            case ExportManifest.currentFormat:
                kind = .manifest
            case mindDeskInterchangePackageFormat:
                kind = .interchangePackage
            case mindDeskProposalEnvelopeFormat:
                kind = .proposalEnvelope
            case mindDeskValidationReportFormat:
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
            guard let key = parseString(maximumScalarCount: Self.maximumStringTokenScalars) else { return false }
            skipWhitespace()
            guard consume(UInt8(ascii: ":")) else { return false }
            skipWhitespace()

            if key == "format" {
                guard scanTopLevelFormatValue() else { return false }
            } else if key == "schemaVersion" {
                guard scanTopLevelSchemaVersionValue() else { return false }
            } else {
                guard skipValue(containerDepth: 0) else { return false }
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
            guard let value = parseString(maximumScalarCount: Self.maximumStringTokenScalars) else { return false }
            if let topLevelFormat,
               topLevelFormat != value {
                formatConflict = true
            }
            topLevelFormat = value
            return true
        }
        formatConflict = true
        return skipValue(containerDepth: 0)
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
        return skipValue(containerDepth: 0)
    }

    private mutating func skipValue(containerDepth: Int) -> Bool {
        skipWhitespace()
        guard let byte = currentByte else { return false }
        switch byte {
        case UInt8(ascii: "{"):
            return skipObject(depth: containerDepth + 1)
        case UInt8(ascii: "["):
            return skipArray(depth: containerDepth + 1)
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
            guard skipValue(containerDepth: depth) else { return false }
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
            guard skipValue(containerDepth: depth) else { return false }
            skipWhitespace()
            if consume(UInt8(ascii: "]")) { return true }
            guard consume(UInt8(ascii: ",")) else { return false }
        }
    }

    private mutating func parseString(maximumScalarCount: Int) -> String? {
        guard consume(UInt8(ascii: "\"")) else { return nil }
        var result = ""
        var scalarCount = 0

        while let byte = currentByte {
            if byte == UInt8(ascii: "\"") {
                index += 1
                return result
            }
            let scalar: UnicodeScalar
            if byte == UInt8(ascii: "\\") {
                index += 1
                guard let escapedScalar = parseEscapedScalar() else { return nil }
                scalar = escapedScalar
            } else {
                guard let unescapedScalar = parseUnescapedScalar() else { return nil }
                scalar = unescapedScalar
            }
            scalarCount += 1
            guard scalarCount <= maximumScalarCount else { return nil }
            result.unicodeScalars.append(scalar)
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
                guard parseEscapedScalar() != nil else { return false }
                continue
            }
            guard parseUnescapedScalar() != nil else { return false }
        }
        return false
    }

    private mutating func parseEscapedScalar() -> UnicodeScalar? {
        guard let byte = currentByte else { return nil }
        index += 1
        switch byte {
        case UInt8(ascii: "\""):
            return UnicodeScalar(0x22)
        case UInt8(ascii: "\\"):
            return UnicodeScalar(0x5C)
        case UInt8(ascii: "/"):
            return UnicodeScalar(0x2F)
        case UInt8(ascii: "b"):
            return UnicodeScalar(0x08)
        case UInt8(ascii: "f"):
            return UnicodeScalar(0x0C)
        case UInt8(ascii: "n"):
            return UnicodeScalar(0x0A)
        case UInt8(ascii: "r"):
            return UnicodeScalar(0x0D)
        case UInt8(ascii: "t"):
            return UnicodeScalar(0x09)
        case UInt8(ascii: "u"):
            return parseUnicodeEscapeScalar()
        default:
            return nil
        }
    }

    private mutating func parseUnicodeEscapeScalar() -> UnicodeScalar? {
        guard let firstCodeUnit = parseHexQuad() else { return nil }
        if (0xD800...0xDBFF).contains(firstCodeUnit) {
            guard consume(UInt8(ascii: "\\")),
                  consume(UInt8(ascii: "u")),
                  let secondCodeUnit = parseHexQuad(),
                  (0xDC00...0xDFFF).contains(secondCodeUnit) else {
                return nil
            }
            let value = 0x10000
                + ((firstCodeUnit - 0xD800) << 10)
                + (secondCodeUnit - 0xDC00)
            return UnicodeScalar(value)
        }
        guard !(0xDC00...0xDFFF).contains(firstCodeUnit) else { return nil }
        return UnicodeScalar(firstCodeUnit)
    }

    private mutating func parseHexQuad() -> UInt32? {
        guard index + 4 <= bytes.count else { return nil }
        var value: UInt32 = 0
        for _ in 0..<4 {
            guard let hex = hexValue(bytes[index]) else { return nil }
            value = value * 16 + UInt32(hex)
            index += 1
        }
        return value
    }

    private mutating func parseUnescapedScalar() -> UnicodeScalar? {
        guard let first = currentByte else { return nil }
        if (0x20...0x7F).contains(first) {
            index += 1
            return UnicodeScalar(UInt32(first))
        }

        let length: Int
        let initialValue: UInt32
        switch first {
        case 0xC2...0xDF:
            length = 2
            initialValue = UInt32(first & 0x1F)
        case 0xE0...0xEF:
            length = 3
            initialValue = UInt32(first & 0x0F)
        case 0xF0...0xF4:
            length = 4
            initialValue = UInt32(first & 0x07)
        default:
            return nil
        }

        guard index + length <= bytes.count else { return nil }
        let second = bytes[index + 1]
        switch first {
        case 0xE0 where second < 0xA0:
            return nil
        case 0xED where second > 0x9F:
            return nil
        case 0xF0 where second < 0x90:
            return nil
        case 0xF4 where second > 0x8F:
            return nil
        default:
            break
        }

        var value = initialValue
        for offset in 1..<length {
            let continuation = bytes[index + offset]
            guard (0x80...0xBF).contains(continuation) else { return nil }
            value = (value << 6) | UInt32(continuation & 0x3F)
        }
        guard let scalar = UnicodeScalar(value) else { return nil }
        index += length
        return scalar
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
