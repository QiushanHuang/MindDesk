import SwiftUI

extension OrganizationIntent {
    var title: String {
        switch self {
        case .summarize: "Summarize"
        case .classify: "Suggest groups"
        case .extractTasks: "Extract tasks"
        case .arrange: "Arrange canvas"
        }
    }

    var explanation: String {
        switch self {
        case .summarize: "Create a summary note. Your original cards stay unchanged."
        case .classify: "Suggest meaningful groups, then place the chosen cards in named frames."
        case .extractTasks: "Turn actionable items into workspace tasks with their source cards."
        case .arrange: "Organize selected cards into readable groups with room between them."
        }
    }
}

struct OrganizationSheet: View {
    let selection: OrganizationSelection
    let apply: (OrganizationProposal, OrganizationRequest) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var intent: OrganizationIntent = .summarize
    @State private var proposal: OrganizationProposal?
    @State private var generatedRequest: OrganizationRequest?
    @State private var operation: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Organize with Codex", systemImage: "sparkles")
                    .font(.title2.bold())
                Spacer()
                Text("\(selection.cards.count) selected cards").foregroundStyle(.secondary)
            }
            Text("Selected card text will be sent through your signed-in Codex account. Review the result before changing anything.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Picker("Action", selection: $intent) {
                ForEach(OrganizationIntent.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .disabled(busy)
            .onChange(of: intent) { _, _ in proposal = nil; generatedRequest = nil; errorMessage = nil }
            Text(intent.explanation).font(.callout)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    DisclosureGroup("Included cards") {
                        ForEach(selection.cards, id: \.card.id) { snapshot in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snapshot.card.title.isEmpty ? "Untitled card" : snapshot.card.title).font(.headline)
                                Text(snapshot.card.body).font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(4).textSelection(.enabled)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                        }
                    }
                    if let proposal {
                        Divider()
                        Text("Preview — nothing applied yet").font(.headline)
                        if !proposal.groups.isEmpty {
                            Text("These cards will move into new named frames beside the current content. Files and original card text stay unchanged.")
                                .font(.caption).foregroundStyle(.secondary)
                            let assigned = Set(proposal.groups.flatMap(\.cardIDs))
                            let remaining = selection.cards.filter { !assigned.contains($0.card.id) }
                            if !remaining.isEmpty {
                                Text("\(remaining.count) selected cards have no group suggestion and will stay where they are.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if !proposal.summary.isEmpty {
                            TextEditor(text: Binding(
                                get: { self.proposal?.summary ?? "" },
                                set: { self.proposal?.summary = $0 }
                            )).frame(minHeight: 180)
                        }
                        ForEach(Array(proposal.groups.enumerated()), id: \.offset) { index, group in
                            GroupBox {
                                VStack(alignment: .leading, spacing: 6) {
                                    TextField("Group name", text: Binding(
                                        get: { self.proposal?.groups[index].name ?? "" },
                                        set: { self.proposal?.groups[index].name = $0 }
                                    )).font(.headline)
                                    ForEach(group.cardIDs, id: \.self) { id in
                                        Text(selection.cards.first { $0.card.id == id }?.card.title ?? id)
                                            .font(.callout)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        ForEach(Array(proposal.tasks.enumerated()), id: \.offset) { index, task in
                            GroupBox {
                                VStack(alignment: .leading, spacing: 6) {
                                    TextField("Task title", text: Binding(
                                        get: { self.proposal?.tasks[index].title ?? "" },
                                        set: { self.proposal?.tasks[index].title = $0 }
                                    )).font(.headline)
                                    TextField("Task details", text: Binding(
                                        get: { self.proposal?.tasks[index].details ?? "" },
                                        set: { self.proposal?.tasks[index].details = $0 }
                                    ), axis: .vertical).font(.callout)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        if intent == .extractTasks && proposal.tasks.isEmpty {
                            Text("No actionable tasks found. Try a different selection.").foregroundStyle(.secondary)
                        }
                    }
                }.padding(2)
            }
            .frame(minHeight: 200, maxHeight: .infinity)
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Button(busy ? "Cancel generation" : "Close") {
                    operation?.cancel()
                    if !busy { dismiss() }
                }.keyboardShortcut(.cancelAction)
                Spacer()
                if busy {
                    ProgressView().controlSize(.small)
                    Text("Preparing a preview…").foregroundStyle(.secondary)
                } else {
                    Button(proposal == nil ? "Generate preview" : "Generate again", action: generate)
                    if let proposal, let generatedRequest {
                        Button("Apply changes") {
                            do { try apply(proposal, generatedRequest); dismiss() }
                            catch { errorMessage = error.localizedDescription }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(intent == .extractTasks && proposal.tasks.isEmpty)
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 620, idealWidth: 700, minHeight: 520, idealHeight: 660)
        .onDisappear { operation?.cancel() }
    }

    private func generate() {
        let request = selection.request(intent: intent)
        busy = true; errorMessage = nil; proposal = nil; generatedRequest = nil
        operation = Task { @MainActor in
            defer { busy = false; operation = nil }
            do {
                let result = try await CodexOrganizationService().generate(request: request)
                try Task.checkCancellation()
                proposal = result; generatedRequest = request
            } catch is CancellationError {
                errorMessage = "Generation cancelled. No changes were made."
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
