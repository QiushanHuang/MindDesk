import SwiftUI

struct OrganizationRequestInspector: View {
    let inspection: OrganizationRequestInspection
    @Environment(\.dismiss) private var dismiss
    private var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(inspection.request)).map { String(decoding: $0, as: UTF8.self) } ?? "Request could not be encoded."
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(inspection.title).font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("cards are editable targets. referenceCards and links explain the context. Instructions and feedback are included explicitly.")
                .font(.callout).foregroundStyle(.secondary)
            ScrollView {
                Text(json).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }.background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }.padding(24).frame(minWidth: 660, idealWidth: 760, minHeight: 560)
    }
}

struct OrganizationWorkflowEditor: View {
    @State private var draft: [OrganizationWorkflow]
    @State private var errorMessage: String?
    let save: ([OrganizationWorkflow]) throws -> Void
    @Environment(\.dismiss) private var dismiss

    init(workflows: [OrganizationWorkflow], seed: OrganizationWorkflow?, save: @escaping ([OrganizationWorkflow]) throws -> Void) {
        _draft = State(initialValue: workflows + (seed.map { [$0] } ?? []))
        self.save = save
    }
    private var validationMessage: String? {
        do { try OrganizationWorkflowLibrary.validate(draft); return nil } catch { return error.localizedDescription }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved workflows").font(.title2.weight(.semibold))
                    Text("Local presets for action, context and instructions.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    do { try save(draft); dismiss() } catch { errorMessage = error.localizedDescription }
                }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(validationMessage != nil)
            }
            ScrollView {
                VStack(spacing: 16) {
                    if draft.isEmpty { ContentUnavailableView("No saved workflows", systemImage: "slider.horizontal.3", description: Text("Add a workflow to reuse your preferred instructions.")) }
                    ForEach($draft) { $workflow in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    TextField("Workflow name", text: $workflow.title).font(.headline)
                                    Button {
                                        draft.append(.init(id: UUID().uuidString, title: String(workflow.title.prefix(40)) + " copy", intent: workflow.intent, scope: workflow.scope, instructions: workflow.instructions))
                                    } label: { Image(systemName: "plus.square.on.square") }
                                        .help("Duplicate workflow").disabled(draft.count >= OrganizationWorkflowLibrary.maximumCount)
                                    Button(role: .destructive) { draft.removeAll { $0.id == workflow.id } } label: { Image(systemName: "trash") }
                                        .help("Remove from this draft")
                                }
                                Picker("Action", selection: $workflow.intent) {
                                    ForEach(OrganizationIntent.allCases, id: \.self) { Text($0.title).tag($0) }
                                }
                                Picker("Context", selection: $workflow.scope) {
                                    ForEach(OrganizationContextScope.allCases) { Text($0.title).tag($0) }
                                }
                                TextEditor(text: $workflow.instructions).font(.body).frame(minHeight: 90)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                                Text("\(workflow.instructions.utf8.count) / 4,000 bytes").font(.caption).foregroundStyle(.secondary)
                            }.padding(6)
                        }
                    }
                }
            }
            if let issue = errorMessage ?? validationMessage { Text(issue).font(.caption).foregroundStyle(.red) }
            Button("Add workflow", systemImage: "plus") {
                draft.append(.init(id: UUID().uuidString, title: "New workflow", intent: .summarize, scope: .selection, instructions: ""))
            }.disabled(draft.count >= OrganizationWorkflowLibrary.maximumCount)
        }.padding(24).frame(minWidth: 640, idealWidth: 720, minHeight: 540, idealHeight: 700)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}
