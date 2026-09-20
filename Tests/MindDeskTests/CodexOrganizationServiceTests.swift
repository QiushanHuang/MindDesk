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
