import Foundation
import XCTest
import MindDeskCore

final class CanvasReviewCapabilityLockTests: XCTestCase {
    func testRequireEnabledAlwaysThrowsUnavailable() {
        requireSendable(CanvasReviewCapabilityError.unavailable)

        for attempt in 1...3 {
            XCTAssertThrowsError(
                try CanvasReviewCapabilityLock.requireEnabled(),
                "Attempt \(attempt) unexpectedly returned."
            ) { error in
                XCTAssertEqual(error as? CanvasReviewCapabilityError, .unavailable)
            }
        }
    }

    func testUnavailableMessageIsGenericAndContainsNoRecoveryInstruction() throws {
        let message = try XCTUnwrap(CanvasReviewCapabilityError.unavailable.errorDescription)

        XCTAssertEqual(message, "Canvas Review is unavailable in this version of MindDesk.")
        for forbidden in [
            "settings",
            "enable",
            "retry",
            "try again",
            "upgrade",
            "contact",
            "command",
            "path",
            "workspace",
            "import"
        ] {
            XCTAssertFalse(message.lowercased().contains(forbidden), "Unexpected recovery token: \(forbidden)")
        }
    }

    func testCapabilityLockSourceContainsNoReopenMechanism() throws {
        let source = try sourceFile("Sources/MindDeskCore/CanvasReviewCapabilityLock.swift")
        let approvedSource = """
        import Foundation

        public enum CanvasReviewCapabilityError: Error, Equatable, Sendable, LocalizedError {
            case unavailable

            public var errorDescription: String? {
                "Canvas Review is unavailable in this version of MindDesk."
            }
        }

        public enum CanvasReviewCapabilityLock {
            public static func requireEnabled() throws -> Never {
                throw CanvasReviewCapabilityError.unavailable
            }
        }
        """

        XCTAssertEqual(compactSource(source), compactSource(approvedSource))
    }
}

private func requireSendable<T: Sendable>(_: T) {}

private func sourceFile(_ relativePath: String, file: StaticString = #filePath) throws -> String {
    let repositoryRoot = URL(fileURLWithPath: String(describing: file))
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(
        contentsOf: repositoryRoot.appendingPathComponent(relativePath),
        encoding: .utf8
    )
}

private func compactSource(_ source: String) -> String {
    source.filter { !$0.isWhitespace }
}
