import Foundation
import XCTest
import MindDeskCore

final class MindDeskJSONDocumentClassifierTests: XCTestCase {
    func testClassifiesManifestAndRecognizedLegacyReviewFormatsWithoutFullDecode() {
        let cases: [(json: String, kind: MindDeskJSONDocumentKind, hasFormat: Bool)] = [
            (#"{"schemaVersion":999,"workspaces":"not decoded by classifier"}"#, .manifest, false),
            (#"{"format":"minddesk.export.manifest","formatVersion":1,"schemaVersion":999,"workspaces":"not decoded by classifier"}"#, .manifest, true),
            (#"{"format":"minddesk.interchange.package","manifest":{"schemaVersion":2}}"#, .interchangePackage, true),
            (#"{"format":"minddesk.proposal.envelope","schemaVersion":2,"proposals":"not decoded by classifier"}"#, .proposalEnvelope, true),
            (#"{"format":"minddesk.validation.report","issues":"not decoded by classifier"}"#, .validationReport, true),
            (#"{"format":"other.product.document","schemaVersion":2}"#, .unknown, true)
        ]

        for item in cases {
            let classification = classify(item.json)
            XCTAssertEqual(classification.kind, item.kind, item.json)
            XCTAssertEqual(classification.hasTopLevelFormat, item.hasFormat, item.json)
        }

        let malformed = MindDeskJSONDocumentClassifier.classify(Data("{".utf8))
        XCTAssertEqual(malformed, .init(kind: .unknown, hasTopLevelFormat: false))
    }

    func testRejectsNestedAndConflictingTopLevelMarkers() {
        let nestedManifest = classify(#"{"manifest":{"schemaVersion":2},"workspaces":[]}"#)
        let conflictingFormat = classify(#"{"format":"minddesk.interchange.package","format":"minddesk.proposal.envelope"}"#)
        let stringSchema = classify(#"{"schemaVersion":"2","workspaces":[]}"#)

        XCTAssertEqual(nestedManifest, .init(kind: .unknown, hasTopLevelFormat: false))
        XCTAssertEqual(conflictingFormat, .init(kind: .unknown, hasTopLevelFormat: true))
        XCTAssertEqual(stringSchema, .init(kind: .unknown, hasTopLevelFormat: false))
    }

    func testClassifierSourceDoesNotReferenceHistoricalDTOCurrentFormats() throws {
        let source = try classifierSourceFile()

        for forbidden in [
            "MindDeskInterchangePackage.currentFormat",
            "MindDeskProposalEnvelope.currentFormat",
            "MindDeskValidationReport.currentFormat"
        ] {
            XCTAssertFalse(source.contains(forbidden), "Historical DTO dependency remains: \(forbidden)")
        }

        let requiredDeclarations = [
            #"private let mindDeskInterchangePackageFormat = "minddesk.interchange.package""#,
            #"private let mindDeskProposalEnvelopeFormat = "minddesk.proposal.envelope""#,
            #"private let mindDeskValidationReportFormat = "minddesk.validation.report""#
        ]
        for declaration in requiredDeclarations {
            XCTAssertTrue(source.contains(declaration), "Missing file-private literal: \(declaration)")
        }
        for literal in [
            "minddesk.interchange.package",
            "minddesk.proposal.envelope",
            "minddesk.validation.report"
        ] {
            XCTAssertEqual(source.components(separatedBy: literal).count - 1, 1, "Literal must have one owner: \(literal)")
        }
    }

    func testDuplicateSameValueFormatIsAmbiguous() {
        let duplicate = classify(#"{"format":"minddesk.proposal.envelope","format":"minddesk.proposal.envelope"}"#)
        let escapedDuplicateKey = classify(#"{"format":"minddesk.validation.report","\u0066ormat":"minddesk.validation.report"}"#)

        XCTAssertEqual(duplicate, .init(kind: .unknown, hasTopLevelFormat: true))
        XCTAssertEqual(escapedDuplicateKey, .init(kind: .unknown, hasTopLevelFormat: true))
    }

    func testNonStringFormatIsAmbiguous() {
        for value in ["null", "true", "false", "0", "{}", "[]"] {
            let classification = classify("{\"format\":\(value)}")
            XCTAssertEqual(
                classification,
                .init(kind: .unknown, hasTopLevelFormat: true),
                "Non-string format was not treated as an ambiguous formatted document: \(value)"
            )
        }
    }

    func testDuplicateSchemaVersionMarkersAreUnknown() {
        let samples = [
            #"{"schemaVersion":2,"schemaVersion":2}"#,
            #"{"schemaVersion":2,"schemaVersion":3}"#,
            #"{}"#,
            #"{"schemaVersion":"2"}"#,
            #"{"schemaVersion":2.0}"#,
            #"{"schemaVersion":true}"#,
            #"{"schemaVersion":null}"#,
            #"{"schemaVersion":{}}"#,
            #"{"schemaVersion":[]}"#
        ]

        for json in samples {
            XCTAssertEqual(
                classify(json),
                .init(kind: .unknown, hasTopLevelFormat: false),
                json
            )
        }
    }

    func testNestedHistoricalFormatMarkerIsIgnored() {
        for literal in [
            "minddesk.interchange.package",
            "minddesk.proposal.envelope",
            "minddesk.validation.report"
        ] {
            let nestedOnly = classify("{\"payload\":{\"items\":[{\"format\":\"\(literal)\"}]}}")
            let nestedWithManifestMarker = classify("{\"schemaVersion\":2,\"payload\":{\"format\":\"\(literal)\"}}")

            XCTAssertEqual(nestedOnly, .init(kind: .unknown, hasTopLevelFormat: false), literal)
            XCTAssertEqual(nestedWithManifestMarker, .init(kind: .manifest, hasTopLevelFormat: false), literal)
        }

        let escapedNestedKey = classify(#"{"schemaVersion":2,"payload":{"\u0066ormat":"minddesk.proposal.envelope"}}"#)
        XCTAssertEqual(escapedNestedKey, .init(kind: .manifest, hasTopLevelFormat: false))
    }

    func testTrailingJSONContentIsUnknown() {
        let failedDocuments = [
            #"{"format":"minddesk.proposal.envelope"}[]"#,
            #"{"format":"minddesk.validation.report","payload":"#,
            #"{"format":"minddesk.interchange.package","payload":"\uD83D"}"#,
            #"{"format":"minddesk.interchange.package","payload":"\uDE00"}"#,
            #"{"format":"minddesk.interchange.package","payload":"\uDE00\uD83D"}"#,
            #"{"format":"minddesk.interchange.package","payload":"\uD83D\u0041"}"#,
            #"{"format":"minddesk.interchange.package","payload":"\uD83D\uDE0Z"}"#
        ]

        for json in failedDocuments {
            XCTAssertEqual(
                classify(json),
                .init(kind: .unknown, hasTopLevelFormat: false),
                json
            )
        }

        let invalidUTF8Sequences: [[UInt8]] = [
            [0xFF],
            [0xC0, 0xAF],
            [0xE2, 0x28, 0xA1],
            [0xED, 0xA0, 0x80],
            [0xF4, 0x90, 0x80, 0x80],
            [0xF0, 0x9F]
        ]
        for invalidSequence in invalidUTF8Sequences {
            var invalidUTF8 = Array(#"{"format":"minddesk.validation.report","payload":""#.utf8)
            invalidUTF8.append(contentsOf: invalidSequence)
            invalidUTF8.append(contentsOf: Array(#""}"#.utf8))
            XCTAssertEqual(
                MindDeskJSONDocumentClassifier.classify(Data(invalidUTF8)),
                .init(kind: .unknown, hasTopLevelFormat: false),
                "Invalid UTF-8 sequence was accepted: \(invalidSequence)"
            )
        }

        let validSurrogatePairKey = classify(#"{"\uD83D\uDE00":0,"schemaVersion":2}"#)
        let validSurrogatePairValue = classify(#"{"payload":"\uD83D\uDE00","schemaVersion":2}"#)
        let validRawNonBMPKey = classify(#"{"😀":0,"schemaVersion":2}"#)
        XCTAssertEqual(validSurrogatePairKey, .init(kind: .manifest, hasTopLevelFormat: false))
        XCTAssertEqual(validSurrogatePairValue, .init(kind: .manifest, hasTopLevelFormat: false))
        XCTAssertEqual(validRawNonBMPKey, .init(kind: .manifest, hasTopLevelFormat: false))
    }

    func testDepthLimitAcceptsMaximumAndRejectsOneBeyondMaximum() {
        for style in NestedContainerStyle.allCases {
            let maximum = nestedValue(depth: 64, style: style)
            let overLimit = nestedValue(depth: 65, style: style)

            XCTAssertEqual(
                classify("{\"payload\":\(maximum),\"schemaVersion\":2}"),
                .init(kind: .manifest, hasTopLevelFormat: false),
                "64 payload containers must be accepted for \(style)."
            )
            XCTAssertEqual(
                classify("{\"format\":\"other.product.document\",\"payload\":\(overLimit)}"),
                .init(kind: .unknown, hasTopLevelFormat: false),
                "65 payload containers must fail closed for \(style)."
            )
        }
    }

    func testMarkerTokenLimitAcceptsMaximumAndRejectsOneBeyondMaximum() {
        let rawMaximumKey = String(repeating: "a", count: 256)
        let rawOverLimitKey = String(repeating: "a", count: 257)
        XCTAssertEqual(classify(jsonWithUnknownKey(rawMaximumKey)), .init(kind: .manifest, hasTopLevelFormat: false))
        XCTAssertEqual(classify(jsonWithUnknownKey(rawOverLimitKey)), .init(kind: .unknown, hasTopLevelFormat: false))

        let escapedMaximumKey = String(repeating: #"\u0061"#, count: 256)
        let escapedOverLimitKey = String(repeating: #"\u0061"#, count: 257)
        XCTAssertEqual(classify(jsonWithUnknownKey(escapedMaximumKey)), .init(kind: .manifest, hasTopLevelFormat: false))
        XCTAssertEqual(classify(jsonWithUnknownKey(escapedOverLimitKey)), .init(kind: .unknown, hasTopLevelFormat: false))

        let combiningMaximumKey = "a" + String(repeating: "\u{0301}", count: 255)
        let combiningOverLimitKey = "a" + String(repeating: "\u{0301}", count: 256)
        XCTAssertEqual(combiningMaximumKey.unicodeScalars.count, 256)
        XCTAssertEqual(combiningOverLimitKey.unicodeScalars.count, 257)
        XCTAssertEqual(classify(jsonWithUnknownKey(combiningMaximumKey)), .init(kind: .manifest, hasTopLevelFormat: false))
        XCTAssertEqual(classify(jsonWithUnknownKey(combiningOverLimitKey)), .init(kind: .unknown, hasTopLevelFormat: false))

        let surrogateMaximumKey = String(repeating: "a", count: 255) + #"\uD83D\uDE00"#
        let surrogateOverLimitKey = String(repeating: "a", count: 256) + #"\uD83D\uDE00"#
        XCTAssertEqual(classify(jsonWithUnknownKey(surrogateMaximumKey)), .init(kind: .manifest, hasTopLevelFormat: false))
        XCTAssertEqual(classify(jsonWithUnknownKey(surrogateOverLimitKey)), .init(kind: .unknown, hasTopLevelFormat: false))

        let rawMaximumValue = String(repeating: "v", count: 256)
        let rawOverLimitValue = String(repeating: "v", count: 257)
        XCTAssertEqual(classify("{\"format\":\"\(rawMaximumValue)\"}"), .init(kind: .unknown, hasTopLevelFormat: true))
        XCTAssertEqual(classify("{\"format\":\"\(rawOverLimitValue)\"}"), .init(kind: .unknown, hasTopLevelFormat: false))

        let escapedMaximumValue = String(repeating: #"\u0076"#, count: 256)
        let escapedOverLimitValue = String(repeating: #"\u0076"#, count: 257)
        XCTAssertEqual(classify("{\"format\":\"\(escapedMaximumValue)\"}"), .init(kind: .unknown, hasTopLevelFormat: true))
        XCTAssertEqual(classify("{\"format\":\"\(escapedOverLimitValue)\"}"), .init(kind: .unknown, hasTopLevelFormat: false))

        let escapedRecognizedFormat = unicodeEscapedASCII("minddesk.proposal.envelope")
        XCTAssertEqual(
            classify("{\"format\":\"\(escapedRecognizedFormat)\"}"),
            .init(kind: .proposalEnvelope, hasTopLevelFormat: true)
        )
    }
}

private func classify(_ json: String) -> MindDeskJSONDocumentClassification {
    MindDeskJSONDocumentClassifier.classify(Data(json.utf8))
}

private func classifierSourceFile(file: StaticString = #filePath) throws -> String {
    let repositoryRoot = URL(fileURLWithPath: String(describing: file))
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDeskCore/MindDeskJSONDocumentKind.swift"),
        encoding: .utf8
    )
}

private enum NestedContainerStyle: CaseIterable {
    case object
    case array
    case mixed
}

private func nestedValue(depth: Int, style: NestedContainerStyle) -> String {
    var value = "null"
    for level in 0..<depth {
        let usesObject = switch style {
        case .object:
            true
        case .array:
            false
        case .mixed:
            level.isMultiple(of: 2)
        }
        value = usesObject ? "{\"value\":\(value)}" : "[\(value)]"
    }
    return value
}

private func jsonWithUnknownKey(_ key: String) -> String {
    "{\"\(key)\":null,\"schemaVersion\":2}"
}

private func unicodeEscapedASCII(_ value: String) -> String {
    value.unicodeScalars.map { String(format: "\\u%04X", $0.value) }.joined()
}
