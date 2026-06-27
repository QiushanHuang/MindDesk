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

struct CanvasCodexProposalPreview: Equatable, Identifiable {
    let id: UUID
    let summaryText: String
    let detailText: String
    let statusText: String
    let isReviewable: Bool
    let gateResult: MindDeskProposalReviewGateResult?
}

@MainActor
final class CanvasCodexSessionController: ObservableObject {
    private static let maximumOutputCharacters = 80_000
    private static let maximumCapturedTranscriptCharacters = 220_000

    @Published private(set) var status: CanvasCodexSessionStatus = .ready
    @Published private(set) var output = "Embedded Codex terminal will appear here.\n"
    @Published private(set) var terminalDescriptor: CodexTerminalPreparedSession?
    @Published private(set) var pendingInput: CodexTerminalPendingInput?
    @Published private(set) var proposalPreview: CanvasCodexProposalPreview?

    private let service: CodexTerminalService
    private var sourcePackageData: Data?
    private var proposalTemplateJSON: String?
    private var capturedTerminalOutput = ""

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

    func start(
        prompt: CanvasCodexPrompt,
        workingDirectory _: String,
        sourcePackageData: Data? = nil,
        proposalTemplateJSON: String? = nil
    ) {
        guard canRun else { return }
        status = .running
        output = "Starting embedded terminal...\n\n"
        self.sourcePackageData = sourcePackageData
        self.proposalTemplateJSON = proposalTemplateJSON
        capturedTerminalOutput = ""
        proposalPreview = nil
        do {
            let preparedSession = try service.prepare(
                prompt: prompt.body,
                sourcePackageData: sourcePackageData,
                proposalTemplateJSON: proposalTemplateJSON
            )
            terminalDescriptor = preparedSession
            output = """
            Embedded terminal started.
            Session: \(preparedSession.sessionDirectoryPath)
            Canvas prompt: \(preparedSession.promptFilePath)
            Source package: \(preparedSession.sourcePackageFilePath)
            Proposal template: \(preparedSession.proposalTemplateFilePath)

            Shell is ready. Edit the command field below, then use Run or + Prompt Run.

            """
        } catch {
            status = .failed
            appendOutput("Could not start embedded terminal: \(error.localizedDescription)\n")
        }
    }

    func sendInput(_ text: String) {
        enqueueInput(text)
    }

    func runCommand(_ command: String) {
        guard canUseTerminal else { return }
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }
        enqueueInput("\(trimmedCommand)\n")
    }

    func runCommandWithCanvasPrompt(
        _ command: String,
        prompt: CanvasCodexPrompt? = nil,
        sourcePackageData: Data? = nil,
        proposalTemplateJSON: String? = nil
    ) {
        guard let terminalDescriptor, canUseTerminal else { return }
        if let prompt {
            updatePreparedSession(
                terminalDescriptor,
                prompt: prompt,
                sourcePackageData: sourcePackageData,
                proposalTemplateJSON: proposalTemplateJSON
            )
        }
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let commandLine = trimmedCommand.isEmpty
            ? terminalDescriptor.openCodexWithPromptCommand
            : CanvasCodexCommandBuilder.promptAugmentedShellCommand(
                trimmedCommand,
                promptFilePath: terminalDescriptor.promptFilePath
            )
        enqueueInput("\(commandLine)\n")
    }

    func openCodex() {
        guard let terminalDescriptor, canUseTerminal else { return }
        enqueueInput("\(terminalDescriptor.openCodexCommand)\n")
    }

    func openCodexWithCanvasPrompt() {
        runCommandWithCanvasPrompt("")
    }

    func interrupt() {
        guard canStop else { return }
        enqueueInput("\u{3}")
        appendOutput("\n^C\n")
    }

    func reset() {
        if let terminalDescriptor {
            service.removePreparedSession(terminalDescriptor)
        }
        terminalDescriptor = nil
        pendingInput = nil
        proposalPreview = nil
        sourcePackageData = nil
        proposalTemplateJSON = nil
        capturedTerminalOutput = ""
        status = .ready
        output = "Embedded Codex terminal will appear here.\n"
    }

    func terminalProcessDidTerminate(sessionID: UUID, exitCode: Int32?) {
        guard terminalDescriptor?.id == sessionID else { return }
        if let terminalDescriptor {
            service.removePreparedSession(terminalDescriptor)
        }
        terminalDescriptor = nil
        pendingInput = nil
        status = exitCode == 0 ? .finished : .failed
        appendOutput("\nEmbedded terminal exited with status \(exitCode ?? -1).\n")
    }

    func terminalProcessDidTerminate(exitCode: Int32?) {
        guard let sessionID = terminalDescriptor?.id else { return }
        terminalProcessDidTerminate(sessionID: sessionID, exitCode: exitCode)
    }

    func captureTerminalOutput(_ text: String) {
        guard !text.isEmpty else { return }
        capturedTerminalOutput += text
        if capturedTerminalOutput.count > Self.maximumCapturedTranscriptCharacters {
            capturedTerminalOutput = String(capturedTerminalOutput.suffix(Self.maximumCapturedTranscriptCharacters))
        }
    }

    func refreshProposalPreview() {
        guard let envelopeData = MindDeskProposalEnvelopeExtractor.latestEnvelopeData(in: capturedTerminalOutput) else {
            proposalPreview = CanvasCodexProposalPreview(
                id: UUID(),
                summaryText: "No proposal envelope found.",
                detailText: "Ask Codex to return a complete minddesk.proposal.envelope JSON object, then use Preview again.",
                statusText: "No proposal",
                isReviewable: false,
                gateResult: nil
            )
            return
        }
        guard let sourcePackageData else {
            proposalPreview = CanvasCodexProposalPreview(
                id: UUID(),
                summaryText: "Proposal found, but no source package is available.",
                detailText: "Start a new Canvas Codex session so MindDesk can bind the proposal to the current Agent Review source package.",
                statusText: "Missing source package",
                isReviewable: false,
                gateResult: nil
            )
            return
        }

        do {
            let result = try ImportExportService().decodeProposalReviewImport(
                proposalEnvelopeData: envelopeData,
                sourcePackageData: sourcePackageData
            )
            proposalPreview = Self.preview(for: result)
        } catch {
            proposalPreview = CanvasCodexProposalPreview(
                id: UUID(),
                summaryText: "Proposal envelope could not be decoded.",
                detailText: error.localizedDescription,
                statusText: "Invalid proposal",
                isReviewable: false,
                gateResult: nil
            )
        }
    }

    func discardProposalPreview() {
        proposalPreview = nil
    }

    func requestProposalRevision(_ instruction: String) {
        guard canUseTerminal else { return }
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let message = """
        Revise the latest minddesk.proposal.envelope using this user feedback:
        \(trimmed)

        Return a complete replacement minddesk.proposal.envelope JSON object. Keep the proposal context copied exactly from the template/source package and do not claim changes were applied.
        """
        enqueueInput("\(message)\n")
    }

    private func appendOutput(_ text: String) {
        guard !text.isEmpty else { return }
        output += text
        guard output.count > Self.maximumOutputCharacters else { return }
        output = "[Earlier terminal output trimmed]\n" + String(output.suffix(Self.maximumOutputCharacters))
    }

    private func enqueueInput(_ text: String) {
        guard !text.isEmpty else { return }
        pendingInput = CodexTerminalPendingInput(id: UUID(), text: text)
    }

    private func updatePreparedSession(
        _ descriptor: CodexTerminalPreparedSession,
        prompt: CanvasCodexPrompt,
        sourcePackageData: Data?,
        proposalTemplateJSON: String?
    ) {
        if let sourcePackageData {
            self.sourcePackageData = sourcePackageData
        }
        if let proposalTemplateJSON {
            self.proposalTemplateJSON = proposalTemplateJSON
        }
        do {
            try service.updatePreparedSession(
                descriptor,
                prompt: prompt.body,
                sourcePackageData: sourcePackageData ?? self.sourcePackageData,
                proposalTemplateJSON: proposalTemplateJSON ?? self.proposalTemplateJSON
            )
        } catch {
            appendOutput("Could not refresh Canvas prompt: \(error.localizedDescription)\n")
        }
    }

    private static func preview(for result: MindDeskProposalReviewGateResult) -> CanvasCodexProposalPreview {
        switch result {
        case .ready(let session):
            let proposalCount = session.envelope.proposals.count
            let operations = session.envelope.proposals.flatMap(\.operations)
            let detailText = operations
                .prefix(8)
                .map { operation in
                    [
                        "\(operation.kind.rawValue): \(operation.title)",
                        operation.payload.proposedText.map { "Preview: \(excerpt($0))" }
                    ]
                    .compactMap { $0 }
                    .joined(separator: "\n")
                }
                .joined(separator: "\n\n")
            return CanvasCodexProposalPreview(
                id: UUID(),
                summaryText: "\(proposalCount) proposal\(proposalCount == 1 ? "" : "s"), \(operations.count) operation\(operations.count == 1 ? "" : "s") ready for Proposal Review.",
                detailText: detailText.isEmpty ? "No operations were included." : detailText,
                statusText: "Review ready",
                isReviewable: true,
                gateResult: result
            )
        case .blocked(let report):
            let issues = report.issues.filter { $0.severity == .error }
            let detailText = issues
                .prefix(6)
                .map { "\($0.code): \($0.message)" }
                .joined(separator: "\n")
            return CanvasCodexProposalPreview(
                id: UUID(),
                summaryText: "Proposal blocked by validation.",
                detailText: detailText.isEmpty ? "Validation did not return a specific error." : detailText,
                statusText: "Blocked",
                isReviewable: false,
                gateResult: result
            )
        }
    }

    private static func excerpt(_ value: String, limit: Int = 360) -> String {
        let flattened = value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flattened.count > limit else { return flattened }
        return "\(flattened.prefix(limit))..."
    }
}
