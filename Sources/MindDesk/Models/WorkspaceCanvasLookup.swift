import Foundation
import MindDeskCore
import SwiftData

struct WorkspacePrimaryCanvasScopedResolution: Equatable, Sendable {
    let resolution: WorkspacePrimaryCanvasResolution
    let contextID: Foundation.UUID
}

@MainActor
final class WorkspacePrimaryCanvasStore {
    typealias Lookup = @MainActor (
        String,
        WorkspacePrimaryCanvasResolutionPhase
    ) throws -> WorkspacePrimaryCanvasScopedResolution
    typealias BeginProvisioning = @MainActor (
        String
    ) throws -> WorkspacePrimaryCanvasScopedResolution
    typealias SaveProvisionedCanvas = @MainActor (
        Foundation.UUID,
        String
    ) -> Bool
    typealias DiscardProvisioning = @MainActor (Foundation.UUID) -> Void

    private let lookupImplementation: Lookup
    private let beginProvisioningImplementation: BeginProvisioning
    private let saveProvisionedCanvasImplementation: SaveProvisionedCanvas
    private let discardProvisioningImplementation: DiscardProvisioning

    init(
        lookup: @escaping Lookup,
        beginProvisioning: @escaping BeginProvisioning,
        saveProvisionedCanvas: @escaping SaveProvisionedCanvas,
        discardProvisioning: @escaping DiscardProvisioning
    ) {
        lookupImplementation = lookup
        beginProvisioningImplementation = beginProvisioning
        saveProvisionedCanvasImplementation = saveProvisionedCanvas
        discardProvisioningImplementation = discardProvisioning
    }

    func lookup(
        workspaceID: String,
        phase: WorkspacePrimaryCanvasResolutionPhase
    ) throws -> WorkspacePrimaryCanvasScopedResolution {
        try lookupImplementation(workspaceID, phase)
    }

    func beginProvisioning(
        workspaceID: String
    ) throws -> WorkspacePrimaryCanvasScopedResolution {
        try beginProvisioningImplementation(workspaceID)
    }

    func saveProvisionedCanvas(
        contextID: Foundation.UUID,
        workspaceID: String
    ) -> Bool {
        saveProvisionedCanvasImplementation(contextID, workspaceID)
    }

    func discardProvisioning(contextID: Foundation.UUID) {
        discardProvisioningImplementation(contextID)
    }

    static func live(container: ModelContainer) -> WorkspacePrimaryCanvasStore {
        let backend = WorkspacePrimaryCanvasLiveStoreBackend(container: container)
        return WorkspacePrimaryCanvasStore(
            lookup: { workspaceID, phase in
                try backend.lookup(workspaceID: workspaceID, phase: phase)
            },
            beginProvisioning: { workspaceID in
                try backend.beginProvisioning(workspaceID: workspaceID)
            },
            saveProvisionedCanvas: { contextID, workspaceID in
                backend.saveProvisionedCanvas(
                    contextID: contextID,
                    workspaceID: workspaceID
                )
            },
            discardProvisioning: { contextID in
                backend.discardProvisioning(contextID: contextID)
            }
        )
    }
}

@MainActor
private final class WorkspacePrimaryCanvasLiveStoreBackend {
    private let container: ModelContainer
    private var provisioningContexts: [Foundation.UUID: ModelContext] = [:]

    init(container: ModelContainer) {
        self.container = container
    }

    func lookup(
        workspaceID: String,
        phase: WorkspacePrimaryCanvasResolutionPhase
    ) throws -> WorkspacePrimaryCanvasScopedResolution {
        _ = phase
        let context = makeContext()
        return WorkspacePrimaryCanvasScopedResolution(
            resolution: try WorkspaceCanvasLookup.resolve(
                for: workspaceID,
                in: context
            ),
            contextID: Foundation.UUID()
        )
    }

    func beginProvisioning(
        workspaceID: String
    ) throws -> WorkspacePrimaryCanvasScopedResolution {
        let context = makeContext()
        let contextID = Foundation.UUID()
        let resolution = try WorkspaceCanvasLookup.resolve(
            for: workspaceID,
            in: context
        )
        if resolution == .missing {
            provisioningContexts[contextID] = context
        }
        return WorkspacePrimaryCanvasScopedResolution(
            resolution: resolution,
            contextID: contextID
        )
    }

    func saveProvisionedCanvas(
        contextID: Foundation.UUID,
        workspaceID: String
    ) -> Bool {
        guard let context = provisioningContexts.removeValue(forKey: contextID) else {
            return false
        }
        context.insert(
            CanvasModel(
                workspaceId: workspaceID,
                title: "Workspace Map"
            )
        )
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }

    func discardProvisioning(contextID: Foundation.UUID) {
        provisioningContexts.removeValue(forKey: contextID)
    }

    private func makeContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}

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
