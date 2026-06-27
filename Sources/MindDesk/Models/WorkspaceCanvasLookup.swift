import Foundation
import SwiftData

enum WorkspaceCanvasLookup {
    static func descriptor(for workspaceId: String) -> FetchDescriptor<CanvasModel> {
        var descriptor = FetchDescriptor<CanvasModel>(
            predicate: #Predicate { canvas in
                canvas.workspaceId == workspaceId
            }
        )
        descriptor.fetchLimit = 1
        return descriptor
    }
}
