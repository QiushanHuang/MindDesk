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
    var startupCommand: String
    var usesPTY: Bool
}

final class CodexTerminalSession {
    private let process: Process
    private let masterHandle: FileHandle
    private let slaveHandle: FileHandle
    private let sessionDirectory: URL

    let sessionDirectoryPath: String
    let startupCommand: String

    init(
        process: Process,
        masterHandle: FileHandle,
        slaveHandle: FileHandle,
        sessionDirectory: URL,
        startupCommand: String
    ) {
        self.process = process
        self.masterHandle = masterHandle
        self.slaveHandle = slaveHandle
        self.sessionDirectory = sessionDirectory
        self.sessionDirectoryPath = sessionDirectory.path
        self.startupCommand = startupCommand
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
            startupCommand: launchPlan.startupCommand
        )
        return session
    }

    static func launchPlan(promptFilePath: String, sessionDirectoryPath: String) -> CodexTerminalLaunchPlan {
        CodexTerminalLaunchPlan(
            executablePath: "/bin/zsh",
            arguments: ["-l"],
            currentDirectoryPath: sessionDirectoryPath,
            promptFilePath: promptFilePath,
            startupCommand: CanvasCodexCommandBuilder.interactiveTerminalCommand(
                promptFilePath: promptFilePath,
                workingDirectory: sessionDirectoryPath
            ),
            usesPTY: true
        )
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
        return environment
    }
}

private struct CodexTerminalOutputSink: @unchecked Sendable {
    let handler: (CodexTerminalOutput) -> Void

    func send(_ output: CodexTerminalOutput) {
        handler(output)
    }
}
