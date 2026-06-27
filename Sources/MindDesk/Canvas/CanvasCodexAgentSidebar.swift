import MindDeskCore
import SwiftUI

struct CanvasCodexSidebarContextSummary: Equatable {
    var cardCount: Int
    var linkCount: Int
    var selectedCardCount: Int
    var selectedLinkCount: Int
    var promptByteCount: Int
    var promptWasTruncated: Bool
}

struct CanvasCodexAgentSidebar: View {
    @Binding var templateGroups: [CanvasCodexPromptTemplateGroup]
    @Binding var selectedGroupID: String
    @Binding var selectedTemplateID: String
    @Binding var customInstruction: String
    @ObservedObject var session: CanvasCodexSessionController

    var prompt: CanvasCodexPrompt
    var contextSummary: CanvasCodexSidebarContextSummary
    var onStartTerminal: () -> Void
    var onRunCommand: (String) -> Void
    var onRunCommandWithPrompt: (String) -> Void
    var onInterrupt: () -> Void
    var onCloseTerminal: () -> Void
    var onCopyPrompt: () -> Void
    var onResetTemplates: () -> Void

    @State private var isEditingTemplates = false
    @State private var commandDraft = CanvasCodexCommandBuilder.interactiveCodexCommandForCurrentDirectory()

    private var selectedGroup: CanvasCodexPromptTemplateGroup? {
        templateGroups.first { $0.id == selectedGroupID } ?? templateGroups.first
    }

    private var selectedTemplates: [CanvasCodexPromptTemplateOption] {
        selectedGroup?.templates ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    templateSection
                    contextSection
                    boundarySection
                }
                .padding(12)
            }
            .frame(maxHeight: 260)

            Divider()

            CodexTerminalScreen(output: session.output)
                .frame(minHeight: 180, maxHeight: .infinity)

            Divider()

            composer
                .padding(12)
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear(perform: reconcileTemplateSelection)
        .onChange(of: selectedGroupID) { _, _ in
            reconcileTemplateSelection()
        }
        .onChange(of: templateGroups) { _, _ in
            reconcileTemplateSelection()
        }
        .sheet(isPresented: $isEditingTemplates) {
            CanvasCodexTemplateEditorSheet(
                groups: $templateGroups,
                onReset: {
                    onResetTemplates()
                    reconcileTemplateSelection()
                }
            )
            .frame(minWidth: 560, minHeight: 520)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Agent")
                    .font(.headline)
                Text("Embedded interactive terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(session.status.title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusTint.opacity(0.16), in: Capsule())
                .foregroundStyle(statusTint)
        }
    }

    private var templateSection: some View {
        GroupBox("Prompt") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Group", selection: $selectedGroupID) {
                    ForEach(templateGroups) { group in
                        Text(group.title).tag(group.id)
                    }
                }

                Picker("Preset", selection: $selectedTemplateID) {
                    ForEach(selectedTemplates) { template in
                        Text(template.title).tag(template.id)
                    }
                }

                TextField("Add specific instructions for this run...", text: $customInstruction, axis: .vertical)
                    .lineLimit(3...7)

                HStack(spacing: 8) {
                    Button {
                        isEditingTemplates = true
                    } label: {
                        Label("Edit Templates", systemImage: "slider.horizontal.3")
                    }

                    Button(action: onCopyPrompt) {
                        Label("Copy Prompt", systemImage: "doc.on.doc")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var contextSection: some View {
        GroupBox("Context") {
            VStack(alignment: .leading, spacing: 6) {
                CanvasCodexSidebarMetricLine("Cards", value: "\(contextSummary.cardCount)")
                CanvasCodexSidebarMetricLine("Links", value: "\(contextSummary.linkCount)")
                CanvasCodexSidebarMetricLine("Selected Cards", value: "\(contextSummary.selectedCardCount)")
                CanvasCodexSidebarMetricLine("Selected Links", value: "\(contextSummary.selectedLinkCount)")
                CanvasCodexSidebarMetricLine("Prompt Bytes", value: "\(contextSummary.promptByteCount)")
                if contextSummary.promptWasTruncated {
                    Text("Prompt is bounded before Codex receives it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var boundarySection: some View {
        GroupBox("Boundary") {
            Text("The embedded terminal starts in a temporary session folder with a prompt file and helper scripts. MindDesk does not apply terminal output; use Proposal Review for any proposed changes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onStartTerminal) {
                    Label("Start Shell", systemImage: "terminal")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!session.canRun)

                Button(action: onInterrupt) {
                    Label("Interrupt", systemImage: "control")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!session.canUseTerminal)
            }

            TextField("Command or Codex input", text: $commandDraft, axis: .vertical)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Button {
                    onRunCommand(commandDraft)
                } label: {
                    Label("Run", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .disabled(commandDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    onRunCommandWithPrompt(commandDraft)
                } label: {
                    Label("+ Prompt Run", systemImage: "text.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .disabled(commandDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: 8) {
                Button(action: onCopyPrompt) {
                    Label("Copy Prompt", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }

                Button(action: onCloseTerminal) {
                    Label("Close", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!session.canUseTerminal)
            }
            .buttonStyle(.bordered)

            Text("Edit the command, then use Run or + Prompt Run. After Codex opens, send slash commands such as /model from this field.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusTint: Color {
        switch session.status {
        case .ready: .secondary
        case .running: .accentColor
        case .finished: .green
        case .stopped: .orange
        case .failed: .red
        }
    }

    private func reconcileTemplateSelection() {
        if !templateGroups.contains(where: { $0.id == selectedGroupID }) {
            selectedGroupID = CanvasCodexPromptTemplateLibrary.defaultGroupID
        }
        let templates = selectedTemplates
        if !templates.contains(where: { $0.id == selectedTemplateID }) {
            selectedTemplateID = templates.first?.id ?? CanvasCodexPromptTemplateLibrary.defaultTemplateID
        }
    }
}

private struct CanvasCodexSidebarMetricLine: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

private struct CanvasCodexTemplateEditorSheet: View {
    @Binding var groups: [CanvasCodexPromptTemplateGroup]
    var onReset: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Canvas Codex Templates")
                    .font(.headline)
                Spacer()
                Button("Reset Defaults") {
                    groups = CanvasCodexPromptTemplateLibrary.defaultGroups
                    onReset()
                }
                Button("Done") {
                    groups = CanvasCodexPromptTemplateLibrary.bounded(groups)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach($groups) { $group in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Group title", text: $group.title)
                                    .font(.headline)
                                ForEach($group.templates) { $template in
                                    VStack(alignment: .leading, spacing: 6) {
                                        TextField("Prompt title", text: $template.title)
                                        TextEditor(text: $template.body)
                                            .font(.system(.caption, design: .monospaced))
                                            .frame(minHeight: 86)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(.quaternary)
                                            )
                                    }
                                }
                            }
                        } label: {
                            Text(group.title.isEmpty ? "Prompt Group" : group.title)
                        }
                    }
                }
                .padding(12)
            }
        }
    }
}
