import Combine
import Foundation
import MindDeskCore

enum CanvasCodexSessionStatus: String, Equatable {
    case ready
    case running
    case finished
    case stopped
    case failed

    var title: String {
        switch self {
        case .ready: "Ready"
        case .running: "Running"
        case .finished: "Finished"
        case .stopped: "Stopped"
        case .failed: "Failed"
        }
    }
}

@MainActor
final class CanvasCodexSessionController: ObservableObject {
    private static let maximumOutputCharacters = 80_000

    @Published private(set) var status: CanvasCodexSessionStatus = .ready
    @Published private(set) var output = "Codex output will appear here.\n"

    private let service: CodexProcessService
    private var session: CodexProcessSession?
    private var bufferedStandardOutput = ""
    private var currentRunID: UUID?

    init(service: CodexProcessService = CodexProcessService()) {
        self.service = service
    }

    var canRun: Bool {
        status != .running
    }

    var canStop: Bool {
        status == .running
    }

    func start(prompt: CanvasCodexPrompt, workingDirectory: String) {
        guard canRun else { return }
        let runID = UUID()
        currentRunID = runID
        bufferedStandardOutput = ""
        status = .running
        output = "Starting in-sidebar Codex session...\n\n"
        do {
            let launchedSession = try service.start(prompt: prompt.body, workingDirectory: workingDirectory) { [weak self] event in
                Task { @MainActor in
                    self?.handle(event, runID: runID)
                }
            }
            session = launchedSession
            output = """
            $ codex -c service_tier="flex" exec --json --sandbox read-only --skip-git-repo-check --ephemeral --color never -C \(launchedSession.sessionDirectoryPath) -
            Starting in-sidebar Codex session...

            """
        } catch {
            currentRunID = nil
            status = .failed
            output += "Could not start Codex: \(error.localizedDescription)\n"
        }
    }

    func stop() {
        guard canStop else { return }
        session?.cancel()
        session = nil
        currentRunID = nil
        status = .stopped
        appendOutput("\nStopped Codex session.\n")
    }

    func reset() {
        if canStop {
            stop()
        }
        status = .ready
        output = "Codex output will appear here.\n"
        bufferedStandardOutput = ""
        currentRunID = nil
    }

    private func handle(_ event: CodexProcessOutput, runID: UUID) {
        guard currentRunID == runID else { return }
        switch event {
        case .standardOutput(let text):
            appendStandardOutput(text)
        case .standardError(let text):
            appendOutput(text)
        case .finished(let statusCode):
            flushBufferedOutput()
            session = nil
            currentRunID = nil
            status = statusCode == 0 ? .finished : .failed
            appendOutput("\nCodex exited with status \(statusCode).\n")
        }
    }

    private func appendStandardOutput(_ text: String) {
        bufferedStandardOutput += text
        while let newlineIndex = bufferedStandardOutput.firstIndex(of: "\n") {
            let line = String(bufferedStandardOutput[..<newlineIndex])
            bufferedStandardOutput.removeSubrange(...newlineIndex)
            appendOutput(Self.formattedOutputLine(line))
        }
    }

    private func flushBufferedOutput() {
        guard !bufferedStandardOutput.isEmpty else { return }
        appendOutput(Self.formattedOutputLine(bufferedStandardOutput))
        bufferedStandardOutput = ""
    }

    private func appendOutput(_ text: String) {
        guard !text.isEmpty else { return }
        output += text
        guard output.count > Self.maximumOutputCharacters else { return }
        output = "[Earlier Codex output trimmed]\n" + String(output.suffix(Self.maximumOutputCharacters))
    }

    private static func formattedOutputLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return "\(line)\n"
        }
        if let message = object["message"] as? String, !message.isEmpty {
            return "\(message)\n"
        }
        if let delta = object["delta"] as? String, !delta.isEmpty {
            return delta
        }
        if let text = object["text"] as? String, !text.isEmpty {
            return "\(text)\n"
        }
        if let type = object["type"] as? String {
            return "[\(type)]\n"
        }
        return "\(line)\n"
    }
}
