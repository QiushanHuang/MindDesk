import AppKit
import SwiftTerm
import SwiftUI

struct CodexTerminalScreen: NSViewRepresentable {
    var descriptor: CodexTerminalPreparedSession?
    var pendingInput: CodexTerminalPendingInput?
    var onOutput: @MainActor @Sendable (String) -> Void
    var onProcessTerminated: @MainActor @Sendable (UUID, Int32?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOutput: onOutput, onProcessTerminated: onProcessTerminated)
    }

    func makeNSView(context: Context) -> CodexTerminalHostView {
        let view = CodexTerminalHostView()
        view.configure(descriptor: descriptor, delegate: context.coordinator)
        return view
    }

    func updateNSView(_ view: CodexTerminalHostView, context: Context) {
        context.coordinator.onOutput = onOutput
        context.coordinator.onProcessTerminated = onProcessTerminated
        view.configure(descriptor: descriptor, delegate: context.coordinator)
        guard let pendingInput, context.coordinator.lastInputID != pendingInput.id else { return }
        context.coordinator.lastInputID = pendingInput.id
        view.send(pendingInput.text)
    }

    static func dismantleNSView(_ view: CodexTerminalHostView, coordinator: Coordinator) {
        coordinator.currentSessionID = nil
        view.stopTerminal()
    }

    final class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var onOutput: @MainActor @Sendable (String) -> Void
        var onProcessTerminated: @MainActor @Sendable (UUID, Int32?) -> Void
        var lastInputID: UUID?
        var currentSessionID: UUID?

        init(
            onOutput: @escaping @MainActor @Sendable (String) -> Void,
            onProcessTerminated: @escaping @MainActor @Sendable (UUID, Int32?) -> Void
        ) {
            self.onOutput = onOutput
            self.onProcessTerminated = onProcessTerminated
        }

        func sizeChanged(source _: LocalProcessTerminalView, newCols _: Int, newRows _: Int) {}

        func setTerminalTitle(source _: LocalProcessTerminalView, title _: String) {}

        func hostCurrentDirectoryUpdate(source _: TerminalView, directory _: String?) {}

        func processTerminated(source _: TerminalView, exitCode: Int32?) {
            guard let currentSessionID else { return }
            let onProcessTerminated = onProcessTerminated
            Task { @MainActor in
                onProcessTerminated(currentSessionID, exitCode)
            }
        }

        func captureOutput(_ text: String) {
            let onOutput = onOutput
            Task { @MainActor in
                onOutput(text)
            }
        }
    }
}

final class CodexTerminalHostView: NSView {
    private var terminal: CodexLocalProcessTerminalView?
    private var placeholder: NSTextField?
    private var activeDescriptorID: UUID?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
        showPlaceholder()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
        showPlaceholder()
    }

    func configure(
        descriptor: CodexTerminalPreparedSession?,
        delegate: CodexTerminalScreen.Coordinator
    ) {
        guard activeDescriptorID != descriptor?.id else { return }
        terminal?.terminate()
        terminal?.removeFromSuperview()
        terminal = nil
        activeDescriptorID = descriptor?.id

        guard let descriptor else {
            delegate.currentSessionID = nil
            showPlaceholder()
            return
        }
        delegate.currentSessionID = descriptor.id

        placeholder?.removeFromSuperview()
        placeholder = nil

        let terminal = CodexLocalProcessTerminalView(frame: bounds)
        terminal.wantsLayer = true
        terminal.autoresizingMask = [.width, .height]
        terminal.processDelegate = delegate
        terminal.onOutput = { [weak delegate] text in
            delegate?.captureOutput(text)
        }
        terminal.metalBufferingMode = .perFrameAggregated
        try? terminal.setUseMetal(false)

        let foreground = NSColor(calibratedWhite: 0.88, alpha: 1)
        let background = NSColor(calibratedWhite: 0.03, alpha: 1)
        terminal.nativeForegroundColor = foreground
        terminal.nativeBackgroundColor = background
        terminal.layer?.backgroundColor = background.cgColor
        terminal.caretColor = .systemGreen
        terminal.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        terminal.getTerminal().setCursorStyle(.steadyBlock)
        addSubview(terminal)
        self.terminal = terminal

        terminal.startProcess(
            executable: descriptor.launchPlan.executablePath,
            args: descriptor.launchPlan.arguments,
            environment: descriptor.environmentArray,
            execName: "zsh",
            currentDirectory: descriptor.launchPlan.currentDirectoryPath
        )
        DispatchQueue.main.async {
            terminal.window?.makeFirstResponder(terminal)
        }
    }

    func send(_ text: String) {
        guard let terminal, !text.isEmpty else { return }
        let bytes = Array(text.utf8)
        terminal.send(source: terminal, data: bytes[...])
        DispatchQueue.main.async {
            terminal.window?.makeFirstResponder(terminal)
        }
    }

    func stopTerminal() {
        terminal?.terminate()
        terminal?.removeFromSuperview()
        terminal = nil
        activeDescriptorID = nil
        showPlaceholder()
    }

    private func showPlaceholder() {
        guard placeholder == nil else { return }
        let label = NSTextField(labelWithString: "Start Shell or use Run to open the embedded terminal.")
        label.textColor = .secondaryLabelColor
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12)
        ])
        placeholder = label
    }

    deinit {
        MainActor.assumeIsolated {
            terminal?.terminate()
        }
    }
}

final class CodexLocalProcessTerminalView: LocalProcessTerminalView {
    var onOutput: (String) -> Void = { _ in }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        guard let text = String(bytes: slice, encoding: .utf8), !text.isEmpty else { return }
        onOutput(text)
    }
}
