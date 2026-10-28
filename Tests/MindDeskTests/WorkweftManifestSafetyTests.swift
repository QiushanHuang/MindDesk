import Foundation
import MindDeskCore
import XCTest
@testable import MindDesk

@MainActor
final class WorkweftManifestSafetyTests: XCTestCase {
    func testCompleteManifestRefusesToSilentlyDiscardBridgePairing() throws {
        let workspace = WorkspaceModel(id: "workspace", title: "Project")
        let paired = CanvasModel(id: "paired", workspaceId: workspace.id, title: "Workweft")
        paired.workweftBridgeState = Data([1])
        let linked = CanvasNodeModel(id: "linked", canvasId: paired.id, title: "Linked task", nodeType: .note,
                                     objectType: "workweft.task", objectId: "task-1", x: 0, y: 0)

        XCTAssertThrowsError(try ImportExportService().makeManifest(
            workspaces: [workspace], resources: [], snippets: [], canvases: [paired], nodes: [linked],
            edges: [], aliases: [], todoGroups: [], todos: []
        )) { error in
            guard case ManifestExportError.pairedCanvasesRequireExplicitExclusion = error else {
                return XCTFail("Expected the paired-canvas export safety error, got \(error)")
            }
        }
    }

    func testExplicitExclusionKeepsOrdinaryCanvasAndProducesImportableManifest() throws {
        let workspace = WorkspaceModel(id: "workspace", title: "Project")
        let ordinary = CanvasModel(id: "ordinary", workspaceId: workspace.id, title: "Main")
        let paired = CanvasModel(id: "paired", workspaceId: workspace.id, title: "Workweft")
        paired.workweftBridgeState = Data([1])
        let noteA = CanvasNodeModel(id: "note-a", canvasId: ordinary.id, title: "A", nodeType: .note, x: 0, y: 0)
        let noteB = CanvasNodeModel(id: "note-b", canvasId: ordinary.id, title: "B", nodeType: .note, x: 260, y: 0)
        let linked = CanvasNodeModel(id: "linked", canvasId: paired.id, title: "Linked task", nodeType: .note,
                                     objectType: "workweft.task", objectId: "task-1", x: 0, y: 0)
        let bridgeNote = CanvasNodeModel(id: "bridge-note", canvasId: paired.id, title: "Bridge note", nodeType: .note, x: 260, y: 0)
        let normalEdge = CanvasEdgeModel(id: "normal-edge", canvasId: ordinary.id, sourceNodeId: noteA.id, targetNodeId: noteB.id)
        let bridgeEdge = CanvasEdgeModel(id: "bridge-edge", canvasId: paired.id, sourceNodeId: linked.id, targetNodeId: bridgeNote.id)
        let service = ImportExportService()

        let manifest = try service.makeManifest(
            workspaces: [workspace], resources: [], snippets: [], canvases: [ordinary, paired],
            nodes: [noteA, noteB, linked, bridgeNote], edges: [normalEdge, bridgeEdge],
            aliases: [], todoGroups: [], todos: [], allowExcludingPairedCanvases: true
        )

        XCTAssertEqual(manifest.canvases.map(\.id), [ordinary.id])
        XCTAssertEqual(Set(manifest.nodes.map(\.id)), Set([noteA.id, noteB.id]))
        XCTAssertEqual(manifest.edges.map(\.id), [normalEdge.id])
        let decoded = try service.decodeManifest(from: JSONEncoder.minddesk.encode(manifest))
        XCTAssertEqual(decoded.canvases.map(\.id), [ordinary.id])
        XCTAssertEqual(decoded.edges.map(\.id), [normalEdge.id])

        let globalOnly = ExportManifestScopePolicy.manifest(from: manifest, scope: .globalLibraryOnly)
        XCTAssertTrue(globalOnly.canvases.isEmpty)
        XCTAssertTrue(globalOnly.nodes.isEmpty)
        XCTAssertTrue(globalOnly.edges.isEmpty)
    }
}
