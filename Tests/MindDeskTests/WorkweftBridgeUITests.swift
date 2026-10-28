import AppKit
import Foundation
import MindDeskCore
import SwiftData
import SwiftUI
import XCTest
@testable import MindDesk

@MainActor
final class WorkweftBridgeUITests: XCTestCase {
    func testLinkedCardDescriptionCannotOverwriteWorkweftMetadata() {
        let originalDate = Date(timeIntervalSince1970: 100)
        for kind in ["task", "asset", "artifact"] {
            let node = CanvasNodeModel(
                canvasId: "bridge-canvas", title: "Source title", body: "Source description",
                nodeType: .note, objectType: "workweft.\(kind)", objectId: "source-id", x: 0, y: 0,
                updatedAt: originalDate
            )
            XCTAssertFalse(CanvasResourceCardNotePolicy.applyNoteChange("Local overwrite", node: node, resource: nil))
            XCTAssertEqual(node.body, "Source description")
            XCTAssertEqual(node.updatedAt, originalDate)
        }
    }

    func testOrdinaryNoteDescriptionRemainsEditable() {
        let node = CanvasNodeModel(canvasId: "ordinary-canvas", title: "Local note", body: "Before", nodeType: .note, x: 0, y: 0)
        XCTAssertTrue(CanvasResourceCardNotePolicy.applyNoteChange("After", node: node, resource: nil))
        XCTAssertEqual(node.body, "After")
    }

    func testLinkedCardTitleAndBodyHaveNoInlineEditingEntryPoint() {
        for kind in ["task", "asset", "artifact"] {
            let objectType = "workweft.\(kind)"
            XCTAssertFalse(CanvasNoteCardEditingPolicy.canRenameTitle(nodeType: .note, objectType: objectType))
            XCTAssertFalse(CanvasNoteCardEditingPolicy.shouldStartTitleEditing(nodeType: .note, clickCount: 2, objectType: objectType))
            XCTAssertFalse(CanvasNoteCardEditingPolicy.canEditBody(nodeType: .note, rendersDetails: true, objectType: objectType))
        }
        XCTAssertTrue(CanvasNoteCardEditingPolicy.canRenameTitle(nodeType: .note))
        XCTAssertTrue(CanvasNoteCardEditingPolicy.shouldStartTitleEditing(nodeType: .note, clickCount: 2))
        XCTAssertTrue(CanvasNoteCardEditingPolicy.canEditBody(nodeType: .note, rendersDetails: true))
    }

    func testApplyRequiresAPreviewEvenWithoutConflicts() {
        XCTAssertFalse(WorkweftBridgeReviewPolicy.canApply(hasPreview: false, conflictIDs: [], choices: [:]))
        XCTAssertTrue(WorkweftBridgeReviewPolicy.canApply(hasPreview: true, conflictIDs: [], choices: [:]))
    }

    func testEveryConflictRequiresAnExplicitChoice() {
        let conflicts = ["node:title", "viewport:x"]
        XCTAssertFalse(WorkweftBridgeReviewPolicy.canApply(hasPreview: true, conflictIDs: conflicts, choices: [:]))
        XCTAssertFalse(WorkweftBridgeReviewPolicy.canApply(hasPreview: true, conflictIDs: conflicts, choices: ["node:title": .local, "unrelated": .incoming]))
        XCTAssertTrue(WorkweftBridgeReviewPolicy.canApply(hasPreview: true, conflictIDs: conflicts, choices: ["node:title": .local, "viewport:x": .incoming]))
    }

    func testImportSizeLimitRejectsOversizedPayload() throws {
        XCTAssertEqual(WorkweftBridgeFileReader.maximumBytes, 2_500_000)
        try WorkweftBridgeFileReader.validateSize(Data(count: WorkweftBridgeFileReader.maximumBytes))
        XCTAssertThrowsError(try WorkweftBridgeFileReader.validateSize(Data(count: WorkweftBridgeFileReader.maximumBytes + 1)))
    }

    func testRenderBridgeSheetWithSyntheticInMemoryData() async throws {
        guard let directory = ProcessInfo.processInfo.environment["MINDDESK_BRIDGE_UI_PREVIEWS"] else {
            throw XCTSkip("Opt-in synthetic bridge sheet image")
        }
        let container = try ModelContainer(
            for: WorkspaceModel.self, ResourcePinModel.self, SnippetModel.self,
            WorkspaceTodoModel.self, WorkspaceTodoGroupModel.self, CanvasModel.self,
            CanvasNodeModel.self, CanvasEdgeModel.self, FinderAliasRecordModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        context.autosaveEnabled = false
        let workspace = WorkspaceModel(id: "bridge-ui-demo", title: "Demo workspace")
        context.insert(workspace)
        try context.save()
        let document = WorkweftCanvasDocument(
            viewport: .init(x: 25, y: 20, zoom: 0.85),
            nodes: [
                .init(id: "group", kind: "group", x: 30, y: 45, width: 800, height: 390, title: "Plan the next step"),
                .init(id: "note", kind: "note", x: 65, y: 130, width: 300, height: 220, parentID: "group", title: "Editable note", body: "Arrange the shared canvas here.\nExport the result when it is ready to review."),
                .init(id: "task:task-demo", kind: "task", refID: "task-demo", x: 440, y: 130, width: 300, height: 220, parentID: "group")
            ], edges: [.init(id: "link", source: "note", target: "task:task-demo", label: "next")]
        )
        let package = WorkweftBridgePackage(pairId: "demo-pair", projectId: "Demo project", document: document,
            references: [.init(kind: "task", refID: "task-demo", title: "Review the draft", status: "Ready", body: "Linked text belongs to Workweft.\nThe card position stays editable.")])
        let preview = try WorkweftBridgeService.preview(data: JSONEncoder().encode(package), workspaceID: workspace.id, context: context)
        _ = try WorkweftBridgeService.apply(preview: preview, context: context)
        for canvas in try context.fetch(FetchDescriptor<CanvasModel>()) { canvas.animationsEnabled = false }
        try context.save()
        let settings = try XCTUnwrap(UserDefaults(suiteName: "MindDesk.BridgePreview." + UUID().uuidString))
        let view = WorkweftBridgeSheet(workspace: workspace)
            .modelContainer(container).defaultAppStorage(settings)
            .environment(\.colorScheme, .light)
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for (name, size) in [
            ("workweft-bridge-sheet.png", CGSize(width: 1200, height: 680)),
            ("workweft-bridge-sheet-compact.png", CGSize(width: 1000, height: 600))
        ] {
            let host = NSHostingView(rootView: view
                .frame(width: size.width, height: size.height)
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.controlActiveState, .active)
                .preferredColorScheme(.light))
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            defer { window.close() }
            host.frame = CGRect(origin: .zero, size: size)
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(350))
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: output.appendingPathComponent(name))
            XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, 1000)
        }
    }
}
