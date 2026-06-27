import AppKit
import SwiftUI

struct CodexTerminalScreen: NSViewRepresentable {
    var output: String
    var onInput: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.black.withAlphaComponent(0.88)

        let textView = TerminalTextView()
        textView.onInput = onInput
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false
        textView.importsGraphics = false
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.backgroundColor = NSColor.clear
        textView.textColor = NSColor.white
        textView.insertionPointColor = NSColor.white
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.string = output

        scrollView.documentView = textView
        context.coordinator.textView = textView
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? TerminalTextView else { return }
        textView.onInput = onInput
        if textView.string != output {
            textView.string = output
            textView.scrollToEndOfDocument(nil)
        }
        context.coordinator.textView = textView
    }

    final class Coordinator {
        fileprivate weak var textView: TerminalTextView?
    }
}

private final class TerminalTextView: NSTextView {
    var onInput: ((String) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func paste(_ sender: Any?) {
        if let pasted = NSPasteboard.general.string(forType: .string), !pasted.isEmpty {
            onInput?(pasted)
        } else {
            super.paste(sender)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command),
           let characters = event.charactersIgnoringModifiers?.lowercased() {
            switch characters {
            case "c":
                copy(nil)
                return
            case "v":
                paste(nil)
                return
            case "a":
                selectAll(nil)
                return
            default:
                break
            }
        }

        switch event.keyCode {
        case 36:
            onInput?("\r")
        case 48:
            onInput?("\t")
        case 51:
            onInput?("\u{7F}")
        case 53:
            onInput?("\u{1B}")
        case 115:
            onInput?("\u{1B}[H")
        case 119:
            onInput?("\u{1B}[F")
        case 123:
            onInput?("\u{1B}[D")
        case 124:
            onInput?("\u{1B}[C")
        case 125:
            onInput?("\u{1B}[B")
        case 126:
            onInput?("\u{1B}[A")
        default:
            if let characters = event.characters, !characters.isEmpty {
                onInput?(characters)
            } else {
                super.keyDown(with: event)
            }
        }
    }
}
