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
        case .running: "Terminal"
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
    @Published private(set) var output = "Embedded Codex terminal will appear here.\n"

    private let service: CodexTerminalService
    private var session: CodexTerminalSession?
    private var currentRunID: UUID?

    init(service: CodexTerminalService = CodexTerminalService()) {
        self.service = service
    }

    var canRun: Bool {
        status != .running
    }

    var canUseTerminal: Bool {
        status == .running
    }

    var canStop: Bool {
        canUseTerminal
    }

    func start(prompt: CanvasCodexPrompt, workingDirectory _: String) {
        guard canRun else { return }
        let runID = UUID()
        currentRunID = runID
        status = .running
        output = "Starting embedded terminal...\n\n"
        do {
            let launchedSession = try service.start(prompt: prompt.body) { [weak self] event in
                Task { @MainActor in
                    self?.handle(event, runID: runID)
                }
            }
            session = launchedSession
            output = """
            Embedded terminal started.
            Session: \(launchedSession.sessionDirectoryPath)
            Canvas prompt: \(launchedSession.promptFilePath)

            Shell is ready. Edit the command field below, then use Run or + Prompt Run.

            """
        } catch {
            currentRunID = nil
            status = .failed
            appendOutput("Could not start embedded terminal: \(error.localizedDescription)\n")
        }
    }

    func sendInput(_ text: String) {
        session?.write(text)
    }

    func runCommand(_ command: String) {
        guard let session, canUseTerminal else { return }
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }
        session.write("\(trimmedCommand)\n")
    }

    func runCommandWithCanvasPrompt(_ command: String) {
        guard let session, canUseTerminal else { return }
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let commandLine = trimmedCommand.isEmpty
            ? session.openCodexWithPromptCommand
            : CanvasCodexCommandBuilder.promptAugmentedShellCommand(
                trimmedCommand,
                promptFilePath: session.promptFilePath
            )
        session.write("\(commandLine)\n")
    }

    func openCodex() {
        guard let session, canUseTerminal else { return }
        session.write("\(session.openCodexCommand)\n")
    }

    func openCodexWithCanvasPrompt() {
        runCommandWithCanvasPrompt("")
    }

    func interrupt() {
        guard canStop else { return }
        session?.interrupt()
        appendOutput("\n^C\n")
    }

    func reset() {
        session?.close()
        session = nil
        status = .ready
        output = "Embedded Codex terminal will appear here.\n"
        currentRunID = nil
    }

    private func handle(_ event: CodexTerminalOutput, runID: UUID) {
        guard currentRunID == runID else { return }
        switch event {
        case .text(let text):
            appendOutput(Self.cleanedTerminalOutput(text))
        case .finished(let statusCode):
            session = nil
            currentRunID = nil
            status = statusCode == 0 ? .finished : .failed
            appendOutput("\nEmbedded terminal exited with status \(statusCode).\n")
        }
    }

    private func appendOutput(_ text: String) {
        guard !text.isEmpty else { return }
        output += text
        guard output.count > Self.maximumOutputCharacters else { return }
        output = "[Earlier terminal output trimmed]\n" + String(output.suffix(Self.maximumOutputCharacters))
    }

    private static func cleanedTerminalOutput(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "\u{1B}\\][^\u{7}]*(\u{7}|\u{1B}\\\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\u{1B}\\[[0-?]*[ -/]*[@-~]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\u{1B}[()][A-Za-z0-9]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\u{1B}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"(?m)^%\s*$\n?"#, with: "", options: .regularExpression)
        while let backspaceIndex = cleaned.firstIndex(of: "\u{8}") {
            if backspaceIndex > cleaned.startIndex {
                let previousIndex = cleaned.index(before: backspaceIndex)
                cleaned.removeSubrange(previousIndex...backspaceIndex)
            } else {
                cleaned.remove(at: backspaceIndex)
            }
        }
        return cleaned
    }
}
