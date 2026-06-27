import Foundation
import MindDeskCore

enum CodexProcessOutput: Equatable, Sendable {
    case standardOutput(String)
    case standardError(String)
    case finished(Int32)
}

struct CodexProcessLaunchPlan: Equatable, Sendable {
    var executablePath: String
    var arguments: [String]
    var currentDirectoryPath: String
    var prompt: String
    var usesShell: Bool
}

final class CodexProcessSession {
    private let process: Process
    private let standardOutputPipe: Pipe
    private let standardErrorPipe: Pipe
    private let standardInputPipe: Pipe
    let sessionDirectoryPath: String

    init(
        process: Process,
        standardOutputPipe: Pipe,
        standardErrorPipe: Pipe,
        standardInputPipe: Pipe,
        sessionDirectoryPath: String
    ) {
        self.process = process
        self.standardOutputPipe = standardOutputPipe
        self.standardErrorPipe = standardErrorPipe
        self.standardInputPipe = standardInputPipe
        self.sessionDirectoryPath = sessionDirectoryPath
    }

    var isRunning: Bool {
        process.isRunning
    }

    func cancel() {
        standardOutputPipe.fileHandleForReading.readabilityHandler = nil
        standardErrorPipe.fileHandleForReading.readabilityHandler = nil
        try? standardInputPipe.fileHandleForWriting.close()
        guard process.isRunning else { return }
        process.interrupt()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.2) { [process] in
            if process.isRunning {
                process.terminate()
            }
        }
    }
}

struct CodexProcessService {
    typealias OutputHandler = (CodexProcessOutput) -> Void

    func start(
        prompt: String,
        workingDirectory: String,
        onOutput: @escaping OutputHandler
    ) throws -> CodexProcessSession {
        let process = Process()
        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        let standardInputPipe = Pipe()
        let sessionDirectory = try Self.makeSessionDirectory()
        let launchPlan = Self.launchPlan(prompt: prompt, sessionDirectoryPath: sessionDirectory.path)
        let outputSink = CodexProcessOutputSink(handler: onOutput)
        _ = workingDirectory

        process.executableURL = URL(fileURLWithPath: launchPlan.executablePath)
        process.arguments = launchPlan.arguments
        process.currentDirectoryURL = URL(fileURLWithPath: launchPlan.currentDirectoryPath, isDirectory: true)
        process.environment = Self.environment()
        process.standardInput = standardInputPipe
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        standardOutputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            outputSink.send(.standardOutput(text))
        }
        standardErrorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            outputSink.send(.standardError(text))
        }
        process.terminationHandler = { process in
            standardOutputPipe.fileHandleForReading.readabilityHandler = nil
            standardErrorPipe.fileHandleForReading.readabilityHandler = nil
            try? FileManager.default.removeItem(at: sessionDirectory)
            outputSink.send(.finished(process.terminationStatus))
        }

        do {
            try process.run()
        } catch {
            try? FileManager.default.removeItem(at: sessionDirectory)
            throw error
        }
        if let data = launchPlan.prompt.data(using: .utf8) {
            standardInputPipe.fileHandleForWriting.write(data)
        }
        try? standardInputPipe.fileHandleForWriting.close()

        return CodexProcessSession(
            process: process,
            standardOutputPipe: standardOutputPipe,
            standardErrorPipe: standardErrorPipe,
            standardInputPipe: standardInputPipe,
            sessionDirectoryPath: launchPlan.currentDirectoryPath
        )
    }

    static func launchPlan(prompt: String, sessionDirectoryPath: String) -> CodexProcessLaunchPlan {
        CodexProcessLaunchPlan(
            executablePath: "/usr/bin/env",
            arguments: [CanvasCodexCommandBuilder.executableName] + CanvasCodexCommandBuilder.execArguments(workingDirectory: sessionDirectoryPath),
            currentDirectoryPath: sessionDirectoryPath,
            prompt: prompt,
            usesShell: false
        )
    }

    private static func makeSessionDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("minddesk-codex-session-\(UUID().uuidString)", isDirectory: true)
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
        return environment
    }
}

private struct CodexProcessOutputSink: @unchecked Sendable {
    let handler: (CodexProcessOutput) -> Void

    func send(_ output: CodexProcessOutput) {
        handler(output)
    }
}
