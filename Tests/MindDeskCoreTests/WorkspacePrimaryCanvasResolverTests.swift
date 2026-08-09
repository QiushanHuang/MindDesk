import XCTest
import MindDeskCore

final class WorkspacePrimaryCanvasResolverTests: XCTestCase {
    func testZeroRecordsResolveToMissing() {
        let input: [String] = []

        XCTAssertEqual(
            WorkspacePrimaryCanvasResolver.resolve(canvasIDs: input),
            .missing
        )
        XCTAssertEqual(input, [])
    }

    func testOneNonblankRecordResolvesToUnique() {
        let input = [" canvas-A "]
        let originalInput = input

        XCTAssertEqual(
            WorkspacePrimaryCanvasResolver.resolve(canvasIDs: input),
            .unique(canvasID: " canvas-A ")
        )
        XCTAssertEqual(input, originalInput)
    }

    func testTwoRecordsResolveToStableDuplicateWithoutSelectingOne() {
        let forwardInput = ["canvas-b", "canvas-a"]
        let reverseInput = ["canvas-a", "canvas-b"]
        let forwardOriginal = forwardInput
        let reverseOriginal = reverseInput
        let forwardResolution = WorkspacePrimaryCanvasResolver.resolve(canvasIDs: forwardInput)
        let reverseResolution = WorkspacePrimaryCanvasResolver.resolve(canvasIDs: reverseInput)

        XCTAssertEqual(forwardResolution, .duplicate(canvasIDs: ["canvas-a", "canvas-b"]))
        XCTAssertEqual(reverseResolution, .duplicate(canvasIDs: ["canvas-a", "canvas-b"]))
        if case .unique = forwardResolution {
            XCTFail("Two records must never resolve to a unique Canvas.")
        }
        if case .unique = reverseResolution {
            XCTFail("Two records must never resolve to a unique Canvas.")
        }
        XCTAssertEqual(forwardInput, forwardOriginal)
        XCTAssertEqual(reverseInput, reverseOriginal)

        let composed = "\u{00E9}"
        let decomposed = "e\u{0301}"
        let expectedUTF8: [[UInt8]] = [
            [0x65, 0xCC, 0x81],
            [0xC3, 0xA9],
        ]

        for input in [[composed, decomposed], [decomposed, composed]] {
            let originalUTF8 = input.map { Array($0.utf8) }
            let resolution = WorkspacePrimaryCanvasResolver.resolve(canvasIDs: input)

            guard case let .duplicate(canvasIDs) = resolution else {
                XCTFail("Canonically equivalent raw IDs must remain duplicate evidence.")
                continue
            }
            XCTAssertEqual(canvasIDs.map { Array($0.utf8) }, expectedUTF8)
            XCTAssertEqual(input.map { Array($0.utf8) }, originalUTF8)
        }
    }

    func testThreeRecordsResolveToStableDuplicate() {
        let input = ["canvas-c", "canvas-a", "canvas-b"]
        let originalInput = input
        let resolution = WorkspacePrimaryCanvasResolver.resolve(canvasIDs: input)

        guard case let .duplicate(canvasIDs) = resolution else {
            XCTFail("Three records must resolve to duplicate evidence.")
            return
        }
        XCTAssertEqual(canvasIDs, ["canvas-a", "canvas-b", "canvas-c"])
        XCTAssertEqual(canvasIDs.count, 3)
        XCTAssertEqual(input, originalInput)
    }

    func testBlankCanvasIDFailsClosedAsDuplicateCollision() {
        XCTAssertEqual(
            WorkspacePrimaryCanvasResolver.resolve(canvasIDs: [""]),
            .duplicate(canvasIDs: [""])
        )

        let whitespace = " \t\n"
        XCTAssertEqual(
            WorkspacePrimaryCanvasResolver.resolve(canvasIDs: [whitespace]),
            .unique(canvasID: whitespace)
        )
    }

    func testRepeatedCanvasIDsRemainRepeatedDuplicateEvidence() {
        let input = ["canvas-b", "canvas-a", "canvas-b"]
        let originalInput = input
        let resolution = WorkspacePrimaryCanvasResolver.resolve(canvasIDs: input)

        guard case let .duplicate(canvasIDs) = resolution else {
            XCTFail("Repeated records must remain duplicate evidence.")
            return
        }
        XCTAssertEqual(canvasIDs, ["canvas-a", "canvas-b", "canvas-b"])
        XCTAssertEqual(canvasIDs.count, 3)
        XCTAssertEqual(canvasIDs.filter { $0 == "canvas-b" }.count, 2)
        XCTAssertEqual(input, originalInput)
    }
}
