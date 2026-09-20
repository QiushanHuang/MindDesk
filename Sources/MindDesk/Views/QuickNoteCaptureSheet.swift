import SwiftUI

struct QuickNoteCaptureSheet: View {
    let save: (String, String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var title = ""
    @State private var text = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Quick note", systemImage: "square.and.pencil").font(.title2.bold())
            Text("Capture the thought now. Organize it when you're ready.").foregroundStyle(.secondary)
            TextField("Title (optional)", text: $title).textFieldStyle(.roundedBorder)
            TextEditor(text: $text).font(.body).focused($focused).frame(minHeight: 200)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Write or paste your note…").foregroundStyle(.tertiary)
                            .padding(5).allowsHitTesting(false)
                    }
                }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Text("⌘ Return to save").font(.caption).foregroundStyle(.secondary)
                Button("Save to canvas") {
                    let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let explicitTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let effectiveTitle = explicitTitle.isEmpty
                        ? String((content.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Note").prefix(80))
                        : explicitTitle
                    do { try save(effectiveTitle, content); dismiss() }
                    catch { errorMessage = error.localizedDescription }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24).frame(width: 560, height: 380)
        .onAppear { focused = true }
        .interactiveDismissDisabled(!text.isEmpty)
    }
}
