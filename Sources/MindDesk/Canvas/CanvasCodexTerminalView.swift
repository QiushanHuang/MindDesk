import AppKit
import SwiftUI

struct CodexTerminalScreen: NSViewRepresentable {
    var output: String

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

        let textView = NSTextView()
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
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != output {
            textView.string = output
            textView.scrollToEndOfDocument(nil)
        }
        context.coordinator.textView = textView
    }

    final class Coordinator {
        fileprivate weak var textView: NSTextView?
    }
}
