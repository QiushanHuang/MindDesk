import Foundation
import MindDeskCore
import SwiftData
import XCTest
@testable import MindDesk

@MainActor
final class WorkspacePrimaryCanvasIntegrationTests: XCTestCase {
    func testLookupDescriptorUsesExactWorkspaceStableSortAndFetchLimitTwo() throws {
        let schema = Schema([CanvasModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let requestedWorkspaceID = "workspace-requested"

        for canvas in [
            CanvasModel(id: "canvas-20", workspaceId: requestedWorkspaceID),
            CanvasModel(id: "canvas-2", workspaceId: requestedWorkspaceID),
            CanvasModel(id: "canvas-10", workspaceId: requestedWorkspaceID),
            CanvasModel(id: "canvas-0", workspaceId: "workspace-requested-other"),
            CanvasModel(id: "canvas-15", workspaceId: "workspace")
        ] {
            context.insert(canvas)
        }
        try context.save()

        let canvases = try context.fetch(
            WorkspaceCanvasLookup.descriptor(for: requestedWorkspaceID)
        )

        XCTAssertEqual(canvases.count, 2)
        XCTAssertEqual(canvases.map(\.id), ["canvas-10", "canvas-2"])
        XCTAssertEqual(canvases.map(\.workspaceId), [requestedWorkspaceID, requestedWorkspaceID])
    }

    func testLookupExcludesForeignWorkspacesAndMapsScopedIDsThroughResolver() throws {
        let schema = Schema([CanvasModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        for canvas in [
            CanvasModel(id: " canvas-0-foreign ", workspaceId: "workspace-foreign"),
            CanvasModel(id: " canvas-unique ", workspaceId: "workspace-unique"),
            CanvasModel(id: "canvas-a", workspaceId: "workspace-duplicate"),
            CanvasModel(id: " canvas-b ", workspaceId: "workspace-duplicate")
        ] {
            context.insert(canvas)
        }
        try context.save()

        let missing = try WorkspaceCanvasLookup.resolve(for: "workspace-missing", in: context)
        let unique = try WorkspaceCanvasLookup.resolve(for: "workspace-unique", in: context)
        let duplicate = try WorkspaceCanvasLookup.resolve(for: "workspace-duplicate", in: context)

        XCTAssertEqual(missing, .missing)
        XCTAssertEqual(unique, .unique(canvasID: " canvas-unique "))
        XCTAssertEqual(duplicate, .duplicate(canvasIDs: [" canvas-b ", "canvas-a"]))
    }

    func testFingerprintIsOrderIndependentAndEncodesRecordCountAndByteLengths() throws {
        let forwardInput = ["A", "\u{00E9}", "e\u{301}"]
        let reverseInput = Array(forwardInput.reversed())
        let forwardRawBytes = forwardInput.map { Array($0.utf8) }
        let reverseRawBytes = reverseInput.map { Array($0.utf8) }
        let expectedForwardRawBytes: [[UInt8]] = [
            [0x41],
            [0xC3, 0xA9],
            [0x65, 0xCC, 0x81]
        ]

        XCTAssertEqual(forwardInput[1], forwardInput[2])
        XCTAssertNotEqual(forwardRawBytes[1], forwardRawBytes[2])
        XCTAssertEqual(forwardRawBytes, expectedForwardRawBytes)
        XCTAssertEqual(reverseRawBytes, Array(expectedForwardRawBytes.reversed()))

        let forwardFingerprint: String = WorkspacePrimaryCanvasFingerprint.make(
            canvasIDs: forwardInput
        )
        let reverseFingerprint: String = WorkspacePrimaryCanvasFingerprint.make(
            canvasIDs: reverseInput
        )

        XCTAssertEqual(forwardFingerprint, reverseFingerprint)
        let decodedPayload = try XCTUnwrap(Data(base64Encoded: forwardFingerprint))
        let expectedPayload = expectedFingerprintPayload(canvasIDs: forwardInput)
        XCTAssertEqual(decodedPayload, expectedPayload)
        XCTAssertEqual(decodedPayload.count, expectedPayload.count)
        XCTAssertEqual(forwardInput.map { Array($0.utf8) }, forwardRawBytes)
        XCTAssertEqual(reverseInput.map { Array($0.utf8) }, reverseRawBytes)
    }

    func testFingerprintDistinguishesSingleRepeatedAndBlankCanvasIDs() {
        let namedCases: [(name: String, canvasIDs: [String])] = [
            ("zeroRecords", []),
            ("oneEmpty", [""]),
            ("oneWhitespace", [" "]),
            ("oneA", ["A"]),
            ("repeatedA", ["A", "A"]),
            ("repeatedEmpty", ["", ""])
        ]
        let fingerprints = namedCases.map { testCase in
            (
                name: testCase.name,
                value: WorkspacePrimaryCanvasFingerprint.make(canvasIDs: testCase.canvasIDs)
            )
        }

        for leftIndex in fingerprints.indices {
            for rightIndex in fingerprints.indices where rightIndex > leftIndex {
                XCTAssertNotEqual(
                    fingerprints[leftIndex].value,
                    fingerprints[rightIndex].value,
                    "\(fingerprints[leftIndex].name) and \(fingerprints[rightIndex].name) must differ"
                )
            }
        }

        XCTAssertEqual(
            fingerprints[3].value,
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: ["A"])
        )
    }

    func testFingerprintDistinguishesConcatenationCollisions() {
        let acuteThenDotBelow = "a\u{301}\u{323}"
        let dotBelowThenAcute = "a\u{323}\u{301}"
        let acuteThenDotBelowBytes = Array(acuteThenDotBelow.utf8)
        let dotBelowThenAcuteBytes = Array(dotBelowThenAcute.utf8)

        XCTAssertEqual(acuteThenDotBelow, dotBelowThenAcute)
        XCTAssertNotEqual(acuteThenDotBelowBytes, dotBelowThenAcuteBytes)
        XCTAssertEqual(acuteThenDotBelowBytes.count, dotBelowThenAcuteBytes.count)

        XCTAssertNotEqual(
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: ["A"]),
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: ["AA"])
        )
        XCTAssertNotEqual(
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: ["AB", "C"]),
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: ["A", "BC"])
        )
        XCTAssertNotEqual(
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: [acuteThenDotBelow]),
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: [dotBelowThenAcute])
        )
    }

    func testFingerprintChangesWhenOnlyThirdCanvasChangesBeyondLookupFetchLimit() {
        let firstInput = ["A", "B", "C"]
        let secondInput = ["A", "B", "D"]
        let firstSortedRawBytes = firstInput.sorted {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }.map { Array($0.utf8) }
        let secondSortedRawBytes = secondInput.sorted {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }.map { Array($0.utf8) }
        let expectedPrefix: [[UInt8]] = [[0x41], [0x42]]

        XCTAssertEqual(firstSortedRawBytes.count, 3)
        XCTAssertEqual(secondSortedRawBytes.count, 3)
        XCTAssertEqual(Array(firstSortedRawBytes.prefix(2)), expectedPrefix)
        XCTAssertEqual(Array(secondSortedRawBytes.prefix(2)), expectedPrefix)

        let firstFingerprint = WorkspacePrimaryCanvasFingerprint.make(canvasIDs: firstInput)
        let secondFingerprint = WorkspacePrimaryCanvasFingerprint.make(canvasIDs: secondInput)

        XCTAssertEqual(
            firstFingerprint,
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: Array(firstInput.reversed()))
        )
        XCTAssertEqual(
            secondFingerprint,
            WorkspacePrimaryCanvasFingerprint.make(canvasIDs: Array(secondInput.reversed()))
        )
        XCTAssertNotEqual(firstFingerprint, secondFingerprint)
    }

    private func expectedFingerprintPayload(canvasIDs: [String]) -> Data {
        let sortedCanvasIDs = canvasIDs.sorted {
            $0.utf8.lexicographicallyPrecedes($1.utf8)
        }
        var payload = Data()

        func appendBigEndian(_ value: UInt64) {
            var bigEndian = value.bigEndian
            withUnsafeBytes(of: &bigEndian) { bytes in
                payload.append(contentsOf: bytes)
            }
        }

        appendBigEndian(UInt64(sortedCanvasIDs.count))
        for canvasID in sortedCanvasIDs {
            let bytes = Array(canvasID.utf8)
            appendBigEndian(UInt64(bytes.count))
            payload.append(contentsOf: bytes)
        }
        return payload
    }
}
