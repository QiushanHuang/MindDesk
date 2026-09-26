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
    @AppStorage(OrganizationWorkflowLibrary.storageKey) private var savedWorkflowsRaw = ""
    @State private var intent: OrganizationIntent = .summarize
    @State private var scope: OrganizationContextScope = .selection
    @State private var instructions = ""
    @State private var feedback = ""
    @State private var selectedWorkflowID = ""
    @State private var inspectRequest = false
    @State private var manageWorkflows = false
    @State private var workflowSeed: OrganizationWorkflow?

    @State private var proposal: OrganizationProposal?
    @State private var generatedRequest: OrganizationRequest?
    @State private var inFlightRequest: OrganizationRequest?
    @State private var operation: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var busy = false
    @State private var includedExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Organize with Codex", systemImage: "sparkles")
                    .font(.title2.bold())
                Spacer()
                Text("\(selection.cards.count) selected cards").foregroundStyle(.secondary)
            }
            Text("Prepare context → Generate preview → Edit and apply")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            workflowControls
            Picker("Action", selection: $intent) {
                ForEach(OrganizationIntent.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .disabled(busy)
            .onChange(of: intent) { _, _ in invalidatePreview() }
            .onChange(of: scope) { _, _ in invalidatePreview() }
            .onChange(of: instructions) { _, _ in invalidatePreview() }
            Text(intent.explanation).font(.callout)
            HStack {
                Picker("Context", selection: $scope) {
                    ForEach(OrganizationContextScope.allCases) { Text($0.title).tag($0) }
                }.disabled(busy)
                Button("Inspect request", systemImage: "doc.text.magnifyingglass") { inspectRequest = true }
            }
            TextField("Instructions for this run (optional)", text: $instructions, axis: .vertical)
                .lineLimit(2...4).textFieldStyle(.roundedBorder).disabled(busy)
            contextSummary


            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    DisclosureGroup("Included cards and relationships", isExpanded: $includedExpanded) {
                        ForEach(currentRequest.cards + currentRequest.referenceCards) { card in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(card.title.isEmpty ? "Untitled card" : card.title).font(.headline)
                                    if currentRequest.referenceCards.contains(where: { $0.id == card.id }) {
                                        Label("Reference only", systemImage: "lock").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Text(card.body).font(.caption).foregroundStyle(.secondary).lineLimit(4).textSelection(.enabled)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                        }
                        ForEach(currentRequest.links, id: \.id) { link in
                            Text("\(title(for: link.sourceID)) \(link.directionSymbol) \(title(for: link.targetID)): \(link.label)")
                                .font(.caption).foregroundStyle(.secondary)
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
                        Divider()
                        HStack(alignment: .top) {
                            TextField("Feedback for a new preview", text: $feedback, axis: .vertical)
                                .lineLimit(2...4).textFieldStyle(.roundedBorder)
                            Button("Revise preview") { generate(revising: true) }
                                .disabled(busy || feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || feedback.utf8.count > 4_000)
                        }
                        Text("Feedback creates a replacement preview. Nothing is applied until you choose Apply changes.")
                            .font(.caption).foregroundStyle(.secondary)
                        if intent == .extractTasks && proposal.tasks.isEmpty {
                            Text("No actionable tasks found. Try a different selection.").foregroundStyle(.secondary)
                        }
                    }
                }.padding(2)
            }
            .frame(minHeight: 200, maxHeight: .infinity)
            if let issue = workflowIssue { Text(issue).font(.caption).foregroundStyle(.orange) }
            if let issue = inputIssue { Text(issue).font(.caption).foregroundStyle(.orange) }
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
                    Button(proposal == nil ? "Generate preview" : "Generate again") { generate() }
                        .disabled(inputIssue != nil)
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
        .frame(minWidth: 660, idealWidth: 760, minHeight: 640, idealHeight: 800)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $inspectRequest) {
            OrganizationRequestInspector(inspection: requestInspection)
        }
        .sheet(isPresented: $manageWorkflows) {
            OrganizationWorkflowEditor(workflows: workflows, seed: workflowSeed) { updated in
                savedWorkflowsRaw = try OrganizationWorkflowLibrary.encode(updated)
            }
        }
        .onChange(of: savedWorkflowsRaw) { _, _ in reconcileWorkflowSelection() }
        .onDisappear { operation?.cancel() }
    }

    private var currentRequest: OrganizationRequest { makeRequest(revising: false) }

    private func makeRequest(revising: Bool) -> OrganizationRequest {
        selection.request(intent: intent, scope: scope, instructions: instructions,
            feedback: revising ? feedback : "", previous: revising ? proposal : nil)
    }

    private var requestInspection: OrganizationRequestInspection {
        .resolve(current: currentRequest, generated: generatedRequest, inFlight: inFlightRequest,
                 revision: proposal != nil && !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? makeRequest(revising: true) : nil)
    }

    private var inputIssue: String? {
        do { try currentRequest.validate(); return nil } catch { return error.localizedDescription }
    }

    private var workflowIssue: String? {
        do { _ = try OrganizationWorkflowLibrary.decode(savedWorkflowsRaw); return nil }
        catch { return "Saved workflows could not be read. The stored library has been preserved." }
    }

    private var workflows: [OrganizationWorkflow] { (try? OrganizationWorkflowLibrary.decode(savedWorkflowsRaw)) ?? [] }

    private var workflowControls: some View {
        HStack {
            Picker("Workflow", selection: $selectedWorkflowID) {
                Text("Custom / current settings").tag("")
                ForEach(workflows) { Text($0.title).tag($0.id) }
            }
            .onChange(of: selectedWorkflowID) { _, id in
                guard let workflow = workflows.first(where: { $0.id == id }) else { return }
                intent = workflow.intent; scope = workflow.scope; instructions = workflow.instructions
            }
            Button("Save workflow…") {
                workflowSeed = .init(id: UUID().uuidString, title: "My workflow", intent: intent, scope: scope, instructions: instructions)
                manageWorkflows = true
            }.disabled(workflows.count >= OrganizationWorkflowLibrary.maximumCount || inputIssue != nil || workflowIssue != nil)
            Button("Manage…") { workflowSeed = nil; manageWorkflows = true }
                .disabled((try? OrganizationWorkflowLibrary.decode(savedWorkflowsRaw)) == nil)
        }.disabled(busy)
    }

    private var contextSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("\(currentRequest.cards.count) editable cards", systemImage: "square.on.square")
                Spacer()
                Text("\(currentRequest.referenceCards.count) references · \(currentRequest.links.count) links")
            }.font(.callout.weight(.medium))
            Text("Included titles, notes and relationships will be sent through your Codex account. File contents are not read. Reference-only cards cannot be changed by this preview.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if selection.selectedIDs.count > selection.cards.count {
                Text("Locked cards and frames are kept as reference context.").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(12).background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func title(for id: String) -> String {
        (currentRequest.cards + currentRequest.referenceCards).first { $0.id == id }?.title ?? id
    }

    private func reconcileWorkflowSelection() {
        guard let workflow = workflows.first(where: { $0.id == selectedWorkflowID }),
              workflow.intent == intent, workflow.scope == scope, workflow.instructions == instructions else {
            selectedWorkflowID = ""
            return
        }
    }

    private func invalidatePreview() {
        reconcileWorkflowSelection()
        proposal = nil; generatedRequest = nil; errorMessage = nil; feedback = ""
    }

    private func generate(revising: Bool = false) {
        let request = makeRequest(revising: revising)
        do { try request.validate() } catch { errorMessage = error.localizedDescription; return }
        inFlightRequest = request
        busy = true; errorMessage = nil; proposal = nil; generatedRequest = nil
        operation = Task { @MainActor in
            defer { busy = false; operation = nil; inFlightRequest = nil }
            do {
                let result = try await CodexOrganizationService().generate(request: request)
                try Task.checkCancellation()
                proposal = result; generatedRequest = request; includedExpanded = false
            } catch is CancellationError {
                errorMessage = "Generation cancelled. No changes were made."
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
