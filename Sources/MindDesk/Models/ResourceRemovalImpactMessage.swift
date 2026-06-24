import Foundation
import MindDeskCore

enum ResourceRemovalImpactMessage {
    static func text(displayName: String, cleanup: CleanupPlan) -> String {
        """
        This removes \(displayName) from MindDesk metadata only.

        Canvas cards removed: \(cleanup.canvasNodeIdsToDelete.count)
        Canvas links removed: \(cleanup.canvasEdgeIdsToDelete.count)
        Todo linked resources cleared: \(cleanup.todoIdsClearingLinkedResource.count)
        Command working directories cleared: \(cleanup.snippetIdsClearingWorkingDirectory.count)
        Alias records marked missing: \(cleanup.aliasIdsMarkingMissing.count)
        Finder items affected: 0
        """
    }
}

struct ResourceRemovalRequest: Identifiable {
    let resource: ResourcePinModel
    let displayName: String
    let cleanup: CleanupPlan

    var id: String { resource.id }

    var message: String {
        ResourceRemovalImpactMessage.text(displayName: displayName, cleanup: cleanup)
    }

    init(resource: ResourcePinModel, cleanup: CleanupPlan) {
        self.resource = resource
        self.displayName = resource.displayName
        self.cleanup = cleanup
    }
}
