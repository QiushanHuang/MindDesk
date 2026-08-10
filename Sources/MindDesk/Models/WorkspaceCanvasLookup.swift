import Foundation
import MindDeskCore
import SwiftData

enum WorkspaceCanvasLookup {
    static func descriptor(for workspaceId: String) -> FetchDescriptor<CanvasModel> {
        var descriptor = FetchDescriptor<CanvasModel>(
            predicate: #Predicate { canvas in
                canvas.workspaceId == workspaceId
            }
        )
        descriptor.sortBy = [SortDescriptor(\CanvasModel.id, comparator: .lexical)]
        descriptor.fetchLimit = 2
        return descriptor
    }

    @MainActor
    static func resolve(
        for workspaceId: String,
        in context: ModelContext
    ) throws -> WorkspacePrimaryCanvasResolution {
        let canvases = try context.fetch(descriptor(for: workspaceId))
        return WorkspacePrimaryCanvasResolver.resolve(canvasIDs: canvases.map(\.id))
    }
}
