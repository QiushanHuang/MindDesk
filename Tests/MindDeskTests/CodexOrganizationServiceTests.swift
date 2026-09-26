import XCTest
@testable import MindDesk

@MainActor
final class CodexOrganizationServiceTests: XCTestCase {
    func testSignedInCodexProducesSyntheticPreview() async throws {
        guard ProcessInfo.processInfo.environment["MINDDESK_ORGANIZER_LIVE_SMOKE"] == "1" else {
            throw XCTSkip("Opt-in synthetic local Codex integration")
        }
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        let proposal = try await CodexOrganizationService(timeout: 120, environment: environment).generate(request: sampleRequest(.summarize))
        XCTAssertFalse(proposal.summary.isEmpty)
        XCTAssertTrue(proposal.groups.isEmpty)
        XCTAssertTrue(proposal.tasks.isEmpty)
    }

    func testSignedInCodexAcceptsContextAndRevisionFeedback() async throws {
        guard ProcessInfo.processInfo.environment["MINDDESK_ORGANIZER_LIVE_SMOKE"] == "1" else {
            throw XCTSkip("Opt-in synthetic context and revision acceptance")
        }
        var request = sampleRequest(.summarize)
        request.cards[0].body = "The team agreed to compare two prototypes next week. The budget is still unknown."
        request.instructions = "Write a short summary in Chinese. Keep unknown facts explicit."
        request.referenceCards = [.init(id: "b", title: "Read-only background", body: "No budget has been approved.", kind: "note", locked: true)]
        request.links = [.init(id: "ab", sourceID: "a", targetID: "b", label: "background", sourceArrow: "none", targetArrow: "none")]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        let service = CodexOrganizationService(timeout: 120, environment: environment)
        let first = try await service.generate(request: request)
        XCTAssertFalse(first.summary.isEmpty)
        XCTAssertNotNil(first.summary.range(of: "[\\p{Han}]", options: .regularExpression))
        request.previousProposal = first
        request.revisionFeedback = "Replace the summary with one short sentence in English. Preserve the unknown budget."
        request.instructions = "Write in English."
        let revised = try await service.generate(request: request)
        XCTAssertFalse(revised.summary.isEmpty)
        XCTAssertNotEqual(first.summary, revised.summary)
        XCTAssertTrue(revised.groups.isEmpty && revised.tasks.isEmpty)
        print("SYNTHETIC_CONTEXT_PREVIEW: \(first.summary)")
        print("SYNTHETIC_REVISED_PREVIEW: \(revised.summary)")
    }

    func testMissingExecutableIsFriendlyFailure() async {
        do {
            _ = try await CodexOrganizationService(executableURL: URL(fileURLWithPath: "/not/a/codex")).generate(request: sampleRequest(.summarize))
            XCTFail("Expected missing executable")
        } catch { XCTAssertTrue(error.localizedDescription.contains("not found")) }
    }

    func testFixtureProtocolAndCleanup() async throws {
        let executable = try fixture("""
        out=''
        while [ "$#" -gt 0 ]; do
          if [ "$1" = '--output-last-message' ]; then shift; out="$1"; fi
          shift
        done
        /bin/cat >/dev/null
        /usr/bin/printf '%s' '{"summary":"Fixture summary","groups":[],"tasks":[]}' > "$out"
        """)
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let result = try await CodexOrganizationService(executableURL: executable).generate(request: sampleRequest(.summarize))
        XCTAssertEqual(result.summary, "Fixture summary")
    }

    func testProcessFailure() async throws {
        let executable = try fixture("exit 7")
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        do {
            _ = try await CodexOrganizationService(executableURL: executable).generate(request: sampleRequest(.summarize))
            XCTFail("Expected failure")
        } catch { XCTAssertTrue(error.localizedDescription.contains("7")) }
    }

    func testMissingRuntimeDoesNotSuggestLoginFailure() {
        let message = OrganizationError.failed(127).localizedDescription
        XCTAssertTrue(message.contains("runtime"))
        XCTAssertFalse(message.contains("signed in"))
    }

    func testDesktopEnvironmentAddsRuntimePathsWithoutImportingProviderKeys() {
        let result = CodexOrganizationService.launchEnvironment([
            "PATH": "/usr/bin:/bin", "HOME": "/test/home", "OPENAI_API_KEY": "not-a-real-key"
        ])
        XCTAssertTrue(result["PATH"]!.split(separator: ":").contains("/usr/local/bin"))
        XCTAssertTrue(result["PATH"]!.split(separator: ":").contains("/opt/homebrew/bin"))
        XCTAssertEqual(result["HOME"], "/test/home")
        XCTAssertNil(result["OPENAI_API_KEY"])
        XCTAssertEqual(CodexOrganizationService.launchEnvironment(result), result)
    }

    func testCancellationAndTimeoutStopProcess() async throws {
        let executable = try fixture("exec /bin/sleep 30")
        defer { try? FileManager.default.removeItem(at: executable.deletingLastPathComponent()) }
        let start = Date()
        let task = Task { try await CodexOrganizationService(executableURL: executable).generate(request: sampleRequest(.summarize)) }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        do {
            _ = try await CodexOrganizationService(executableURL: executable, timeout: 0.1).generate(request: sampleRequest(.summarize))
            XCTFail("Expected timeout")
        } catch { XCTAssertTrue(error.localizedDescription.contains("too long")) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    private func fixture(_ body: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("organizer-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("codex-fixture")
        try Data(("#!/bin/sh\n" + body + "\n").utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }
}
