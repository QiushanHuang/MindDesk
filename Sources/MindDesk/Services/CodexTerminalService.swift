import Darwin
import Foundation
import MindDeskCore

enum CodexTerminalOutput: Equatable, Sendable {
    case text(String)
    case finished(Int32)
}

struct CodexTerminalLaunchPlan: Equatable, Sendable {
    var executablePath: String
    var arguments: [String]
    var currentDirectoryPath: String
    var promptFilePath: String
    var openCodexCommand: String
    var openCodexWithPromptCommand: String
    var usesPTY: Bool
}

final class CodexTerminalSession {
    private let process: Process
    private let masterHandle: FileHandle
    private let slaveHandle: FileHandle
    private let sessionDirectory: URL

    let sessionDirectoryPath: String
    let promptFilePath: String
    let openCodexCommand: String
    let openCodexWithPromptCommand: String

    init(
        process: Process,
        masterHandle: FileHandle,
        slaveHandle: FileHandle,
        sessionDirectory: URL,
        promptFilePath: String,
        openCodexCommand: String,
        openCodexWithPromptCommand: String
    ) {
        self.process = process
        self.masterHandle = masterHandle
        self.slaveHandle = slaveHandle
        self.sessionDirectory = sessionDirectory
        self.sessionDirectoryPath = sessionDirectory.path
        self.promptFilePath = promptFilePath
        self.openCodexCommand = openCodexCommand
        self.openCodexWithPromptCommand = openCodexWithPromptCommand
    }

    var isRunning: Bool {
        process.isRunning
    }

    func write(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        try? masterHandle.write(contentsOf: data)
    }

    func interrupt() {
        write("\u{3}")
    }

    func close() {
        masterHandle.readabilityHandler = nil
        write("\nexit\n")
        if process.isRunning {
            process.terminate()
        }
        try? masterHandle.close()
        try? slaveHandle.close()
        try? FileManager.default.removeItem(at: sessionDirectory)
    }
}

struct CodexTerminalService {
    typealias OutputHandler = (CodexTerminalOutput) -> Void

    func start(
        prompt: String,
        onOutput: @escaping OutputHandler
    ) throws -> CodexTerminalSession {
        let sessionDirectory = try Self.makeSessionDirectory()
        let promptFile = sessionDirectory.appendingPathComponent("minddesk-canvas-prompt.txt", isDirectory: false)
        try prompt.write(to: promptFile, atomically: true, encoding: .utf8)

        let launchPlan = Self.launchPlan(
            promptFilePath: promptFile.path,
            sessionDirectoryPath: sessionDirectory.path
        )
        try Self.writeExecutableScript(
            named: "minddesk-open-codex.sh",
            contents: Self.shellScript(command: CanvasCodexCommandBuilder.interactiveCodexCommand(workingDirectory: sessionDirectory.path)),
            in: sessionDirectory
        )
        try Self.writeExecutableScript(
            named: "minddesk-open-codex-with-prompt.sh",
            contents: Self.shellScript(command: CanvasCodexCommandBuilder.interactiveCodexPromptCommand(promptFilePath: promptFile.path, workingDirectory: sessionDirectory.path)),
            in: sessionDirectory
        )
        let outputSink = CodexTerminalOutputSink(handler: onOutput)

        var masterFileDescriptor: Int32 = -1
        var slaveFileDescriptor: Int32 = -1
        guard openpty(&masterFileDescriptor, &slaveFileDescriptor, nil, nil, nil) == 0 else {
            try? FileManager.default.removeItem(at: sessionDirectory)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        let masterHandle = FileHandle(fileDescriptor: masterFileDescriptor, closeOnDealloc: true)
        let slaveHandle = FileHandle(fileDescriptor: slaveFileDescriptor, closeOnDealloc: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPlan.executablePath)
        process.arguments = launchPlan.arguments
        process.currentDirectoryURL = URL(fileURLWithPath: launchPlan.currentDirectoryPath, isDirectory: true)
        process.environment = Self.environment()
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle

        masterHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            outputSink.send(.text(text))
        }
        process.terminationHandler = { process in
            masterHandle.readabilityHandler = nil
            try? FileManager.default.removeItem(at: sessionDirectory)
            outputSink.send(.finished(process.terminationStatus))
        }

        do {
            try process.run()
        } catch {
            masterHandle.readabilityHandler = nil
            try? FileManager.default.removeItem(at: sessionDirectory)
            throw error
        }

        let session = CodexTerminalSession(
            process: process,
            masterHandle: masterHandle,
            slaveHandle: slaveHandle,
            sessionDirectory: sessionDirectory,
            promptFilePath: launchPlan.promptFilePath,
            openCodexCommand: launchPlan.openCodexCommand,
            openCodexWithPromptCommand: launchPlan.openCodexWithPromptCommand
        )
        return session
    }

    static func launchPlan(promptFilePath: String, sessionDirectoryPath: String) -> CodexTerminalLaunchPlan {
        CodexTerminalLaunchPlan(
            executablePath: "/bin/zsh",
            arguments: ["-f"],
            currentDirectoryPath: sessionDirectoryPath,
            promptFilePath: promptFilePath,
            openCodexCommand: "./minddesk-open-codex.sh",
            openCodexWithPromptCommand: "./minddesk-open-codex-with-prompt.sh",
            usesPTY: true
        )
    }

    private static func shellScript(command: String) -> String {
        """
        #!/bin/zsh
        \(command)
        """
    }

    private static func writeExecutableScript(named name: String, contents: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(name, isDirectory: false)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    private static func makeSessionDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("minddesk-codex-terminal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let additions = [
            "\(home)/.npm-global/bin",
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
        let existingPath = environment["PATH"] ?? ""
        let pathItems = (additions + existingPath.split(separator: ":").map(String.init))
            .filter { !$0.isEmpty }
        let uniquePathItems = (NSOrderedSet(array: pathItems).array as? [String]) ?? pathItems
        environment["PATH"] = uniquePathItems.joined(separator: ":")
        environment["TERM"] = environment["TERM"] == "dumb" ? "xterm-256color" : (environment["TERM"] ?? "xterm-256color")
        environment["COLORTERM"] = environment["COLORTERM"] ?? "truecolor"
        environment["PS1"] = "minddesk:%~ %# "
        environment["PROMPT"] = "minddesk:%~ %# "
        environment["RPROMPT"] = ""
        environment["NO_COLOR"] = "1"
        return environment
    }
}

private struct CodexTerminalOutputSink: @unchecked Sendable {
    let handler: (CodexTerminalOutput) -> Void

    func send(_ output: CodexTerminalOutput) {
        handler(output)
    }
}
