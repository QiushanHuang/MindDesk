import AppKit
import MindDeskCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum WorkweftBridgeReviewPolicy {
    static func canApply(hasPreview: Bool, conflictIDs: [String], choices: [String: WorkweftBridgeChoice]) -> Bool {
        hasPreview && conflictIDs.allSatisfy { choices[$0] != nil }
    }
}

struct WorkweftBridgeReviewCard: Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let status: String?
    let isHidden: Bool
}

struct WorkweftBridgeReviewLink: Identifiable, Equatable {
    let id: String
    let sourceTitle: String
    let targetTitle: String
    let label: String
}

struct WorkweftBridgeReviewContent {
    let cards: [WorkweftBridgeReviewCard]
    let links: [WorkweftBridgeReviewLink]

    static func make(document: WorkweftCanvasDocument, references: [WorkweftBridgeReference]?) -> Self {
        let referencesByID = Dictionary((references ?? []).map { ("\($0.kind):\($0.refID)", $0) }, uniquingKeysWith: { first, _ in first })
        let hiddenIDs = document.effectiveHiddenIDs
        let cards = document.nodes.map { node in
            let reference = referencesByID[node.id]
            let referenceTitle = reference?.title ?? ""
            let title = node.isReference
                ? (referenceTitle.isEmpty ? "\(node.kind.capitalized): \(node.refID ?? node.id)" : referenceTitle)
                : node.title
            return WorkweftBridgeReviewCard(
                id: node.id, title: title, body: node.isReference ? (reference?.body ?? "") : node.body,
                status: node.isReference ? reference?.status : nil, isHidden: hiddenIDs.contains(node.id)
            )
        }
        let titles = Dictionary(cards.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        let links = document.edges.map { edge in
            WorkweftBridgeReviewLink(id: edge.id, sourceTitle: titles[edge.source] ?? edge.source,
                                    targetTitle: titles[edge.target] ?? edge.target, label: edge.label)
        }
        return Self(cards: cards, links: links)
    }
}

enum WorkweftBridgeFileReader {
    static let maximumBytes = 2_500_000

    static func validateSize(_ data: Data) throws {
        guard data.count <= maximumBytes else {
            throw WorkweftBridgeError("Bridge JSON must be 2.5 MB or smaller.")
        }
    }

    // Only the URL explicitly selected in the Open panel reaches this reader.
    static func readSelectedJSON(at url: URL) throws -> Data {
        guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw WorkweftBridgeError("Choose a regular JSON file.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= maximumBytes {
            guard let chunk = try handle.read(upToCount: min(64 * 1024, maximumBytes + 1 - data.count)),
                  !chunk.isEmpty else { break }
            data.append(chunk)
        }
        try validateSize(data)
        return data
    }
}

struct WorkweftBridgeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var canvases: [CanvasModel]
    @Query private var nodes: [CanvasNodeModel]
    @Query private var edges: [CanvasEdgeModel]
    @StateObject private var scopeController = WorkspaceWindowScopeController()
    let workspace: WorkspaceModel

    @State private var selectedCanvasID: String?
    @State private var isPasteJSONPresented = false
    @State private var preview: WorkweftBridgeImportPreview?
    @State private var choices: [String: WorkweftBridgeChoice] = [:]
    @State private var undoReceipt: WorkweftBridgeUndoReceipt?
    @State private var status: String?
    @State private var errorMessage: String?

    private var pairedCanvases: [CanvasModel] {
        canvases.filter { $0.workspaceId == workspace.id && $0.workweftBridgeState != nil }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private var selectedCanvas: CanvasModel? {
        pairedCanvases.first { $0.id == selectedCanvasID }
    }

    private func reviewedMerge(_ preview: WorkweftBridgeImportPreview) -> Result<WorkweftBridgeMergePreview, Error> {
        Result { try WorkweftBridgeService.review(preview: preview, choices: choices) }
    }

    private func canApply(_ review: Result<WorkweftBridgeMergePreview, Error>) -> Bool {
        guard case .success(let merge) = review, merge.unresolved.isEmpty else { return false }
        return WorkweftBridgeReviewPolicy.canApply(
            hasPreview: preview != nil,
            conflictIDs: merge.conflicts.map(\.id),
            choices: choices
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Workweft Canvas Bridge").font(.title2.bold())
                        InformationButton(subject: "Workweft Canvas Bridge", text: "Exchange notes, groups, links, and layout through JSON. Linked Workweft titles and descriptions are read-only. Changes are exchanged only when you import or export.")
                    }
                    Text(workspace.title).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack {
                Picker("Paired canvas", selection: $selectedCanvasID) {
                    Text("Select a canvas").tag(String?.none)
                    ForEach(pairedCanvases) { canvas in
                        Text(canvas.title).tag(Optional(canvas.id))
                    }
                }
                .disabled(preview != nil || pairedCanvases.isEmpty)
                .frame(maxWidth: 500)
                Spacer()
            }
            HStack {
                Button("Choose JSON & Preview…", action: chooseImport)
                    .disabled(preview != nil)
                    .buttonStyle(.borderedProminent)
                Button("Paste JSON…") { isPasteJSONPresented = true }
                    .disabled(preview != nil)
                Button("Export JSON…", action: exportSelected)
                    .disabled(selectedCanvas == nil || preview != nil)
                if undoReceipt != nil {
                    Button("Undo Last Import", action: undoLastImport)
                        .disabled(preview != nil)
                        .help("Undo the last import while the imported canvas is unchanged.")
                }
                Spacer()
            }

            HSplitView {
                if let preview {
                    reviewPanel(preview, review: reviewedMerge(preview))
                        .frame(minWidth: 290, idealWidth: 320, maxWidth: 440)
                }
                canvasEditor
                    .frame(minWidth: 650, maxWidth: .infinity, maxHeight: .infinity)
                    .disabled(preview != nil)
            }
            .frame(maxHeight: .infinity)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).textSelection(.enabled)
                    .lineLimit(3).help(errorMessage)
            } else if let status {
                Text(status).foregroundStyle(.secondary).textSelection(.enabled)
                    .lineLimit(2).help(status)
            }
            Text("Deleting a linked card hides it on the shared canvas.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 1000, idealWidth: 1200, minHeight: 600, idealHeight: 680)
        .sheet(isPresented: $isPasteJSONPresented) {
            WorkweftBridgePasteSheet { data in
                try preparePreview(data)
                isPasteJSONPresented = false
            }
        }
        .onAppear {
            if selectedCanvasID == nil { selectedCanvasID = pairedCanvases.first?.id }
            bindSelectedCanvas()
        }
        .onChange(of: selectedCanvasID) { _, _ in bindSelectedCanvas() }
        .onChange(of: pairedCanvases.map(\.id)) { _, ids in
            if let selectedCanvasID, !ids.contains(selectedCanvasID) { self.selectedCanvasID = nil }
            bindSelectedCanvas()
        }
    }

    @ViewBuilder
    private var canvasEditor: some View {
        if let canvas = selectedCanvas,
           let scope = scopeController.boundCanvas, scope.canvasID == canvas.id {
            WorkspaceCanvasView(
                workspaceWindowScopeController: scopeController,
                canvasScope: scope,
                nodeOwnershipReader: .live(container: modelContext.container),
                canvas: canvas,
                resources: [], allResources: [], workspaces: [workspace], snippets: [], todos: [], todoGroups: [],
                nodes: nodes.filter { $0.canvasId == canvas.id },
                edges: edges.filter { $0.canvasId == canvas.id },
                openTodoPanelRequest: nil,
                onOpenTodoPanelRequestHandled: { _ in },
                onStatus: { status = $0; errorMessage = nil },
                onInspect: { _ in },
                onOpenWorkspace: { _ in }
            )
            .id(canvas.id)
        } else {
            ContentUnavailableView(
                preview?.isNew == true ? "Ready to create a paired canvas" : "No paired canvas selected",
                systemImage: "rectangle.3.group"
            )
        }
    }

    private func reviewPanel(_ preview: WorkweftBridgeImportPreview, review: Result<WorkweftBridgeMergePreview, Error>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import Preview").font(.headline)
            Text(preview.isNew ? "Create a dedicated canvas" : "Update the paired canvas").font(.subheadline)
            LabeledContent("Project", value: preview.package.projectId)
                .lineLimit(2).help(preview.package.projectId)
            LabeledContent("Pair", value: preview.package.pairId)
                .lineLimit(2).help(preview.package.pairId)
            if case .success(let merge) = review {
                let cardCount = merge.document.nodes.count
                let linkCount = merge.document.edges.count
                Text("\(cardCount) card\(cardCount == 1 ? "" : "s") · \(linkCount) link\(linkCount == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
            }
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    switch review {
                    case .failure(let error):
                        Text("Could not review these choices: \(error.localizedDescription)")
                            .foregroundStyle(.red).textSelection(.enabled)
                    case .success(let merge):
                        let content = WorkweftBridgeReviewContent.make(document: merge.document, references: preview.package.references)
                        if merge.conflicts.isEmpty { Text("No conflicts") }
                        ForEach(merge.conflicts) { conflict in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(conflict.label).font(.subheadline.bold())
                                Text("MindDesk: \(conflict.local)").textSelection(.enabled)
                                Text("Incoming: \(conflict.incoming)").textSelection(.enabled)
                                Picker("Keep", selection: Binding(
                                    get: { choices[conflict.id] },
                                    set: { choices[conflict.id] = $0 }
                                )) {
                                    Text("Choose…").tag(WorkweftBridgeChoice?.none)
                                    Text("MindDesk").tag(Optional(WorkweftBridgeChoice.local))
                                    Text("Incoming").tag(Optional(WorkweftBridgeChoice.incoming))
                                }
                            }
                        }
                        if !content.cards.isEmpty {
                            Text(merge.unresolved.isEmpty ? "Cards after import" : "Cards pending choices")
                                .font(.subheadline.weight(.semibold))
                            ForEach(content.cards) { card in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(card.title).fontWeight(.medium)
                                        if card.isHidden {
                                            Label("Hidden", systemImage: "eye.slash")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if let status = card.status, !status.isEmpty {
                                        Text(status).foregroundStyle(.secondary)
                                    }
                                    if !card.body.isEmpty {
                                        Text(card.body).foregroundStyle(.secondary).textSelection(.enabled)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        if !content.links.isEmpty {
                            Text(merge.unresolved.isEmpty ? "Links after import" : "Links pending choices")
                                .font(.subheadline.weight(.semibold))
                            ForEach(content.links) { link in
                                Text("\(link.sourceTitle) → \(link.targetTitle)\(link.label.isEmpty ? "" : ": \(link.label)")")
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Keep this window open and the imported canvas unchanged to undo the import.")
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancel Preview") { self.preview = nil; choices = [:]; errorMessage = nil }
                Spacer()
                Button("Apply Import", action: applyImport)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply(review))
            }
        }
        .padding(12)
    }

    private func bindSelectedCanvas() {
        guard let canvas = selectedCanvas else { return }
        let focus = scopeController.focus(workspaceID: workspace.id)
        scopeController.bind(.unique(canvasID: canvas.id), for: focus)
    }

    private func chooseImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a Workweft Canvas Bridge JSON file (up to 2.5 MB)."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try WorkweftBridgeFileReader.readSelectedJSON(at: url)
            try preparePreview(data)
        } catch { errorMessage = error.localizedDescription }
    }

    private func preparePreview(_ data: Data) throws {
        try WorkweftBridgeFileReader.validateSize(data)
        let next = try WorkweftBridgeService.preview(data: data, workspaceID: workspace.id, context: modelContext)
        choices = [:]
        preview = next
        selectedCanvasID = next.isNew ? nil : next.canvasID
        errorMessage = nil
        status = nil
    }

    private func applyImport() {
        guard let preview, canApply(reviewedMerge(preview)) else { return }
        do {
            let receipt = try WorkweftBridgeService.apply(preview: preview, choices: choices, context: modelContext)
            undoReceipt = receipt
            selectedCanvasID = receipt.canvasID
            self.preview = nil
            choices = [:]
            errorMessage = nil
            status = "Import applied. Edit the canvas here, then export JSON to return the changes to Workweft."
            bindSelectedCanvas()
        } catch { errorMessage = error.localizedDescription }
    }

    private func exportSelected() {
        guard let selectedCanvas else { return }
        do {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "workweft-canvas.bridge.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            let data = try WorkweftBridgeService.export(canvasID: selectedCanvas.id, context: modelContext)
            try data.write(to: url, options: .atomic)
            errorMessage = nil
            status = "Bridge JSON exported to \(url.lastPathComponent). Import it in Workweft to review these changes."
        } catch { errorMessage = error.localizedDescription }
    }

    private func undoLastImport() {
        guard let undoReceipt else { return }
        do {
            try WorkweftBridgeService.undo(receipt: undoReceipt, context: modelContext)
            self.undoReceipt = nil
            errorMessage = nil
            status = "Last import undone."
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct WorkweftBridgePasteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var json = ""
    @State private var errorMessage: String?
    let onPreview: (Data) throws -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste Workweft Bridge JSON").font(.headline)
            TextEditor(text: $json)
                .font(.system(.body, design: .monospaced))
                .border(.secondary.opacity(0.35))
                .accessibilityLabel("Bridge JSON")
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).textSelection(.enabled)
            }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Preview Import") {
                    do { try onPreview(Data(json.utf8)) }
                    catch { errorMessage = error.localizedDescription }
                }
                .disabled(json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 680, height: 520)
    }
}
