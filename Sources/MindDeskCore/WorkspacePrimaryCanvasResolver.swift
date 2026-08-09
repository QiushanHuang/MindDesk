public enum WorkspacePrimaryCanvasResolution: Equatable, Sendable {
    case missing
    case unique(canvasID: String)
    case duplicate(canvasIDs: [String])
}

public enum WorkspacePrimaryCanvasResolver {
    public static func resolve(canvasIDs: [String]) -> WorkspacePrimaryCanvasResolution {
        switch canvasIDs.count {
        case 0:
            return .missing
        case 1:
            let canvasID = canvasIDs[0]
            if canvasID.isEmpty {
                return .duplicate(canvasIDs: [canvasID])
            }
            return .unique(canvasID: canvasID)
        default:
            return .duplicate(
                canvasIDs: canvasIDs.sorted {
                    $0.utf8.lexicographicallyPrecedes($1.utf8)
                }
            )
        }
    }
}
