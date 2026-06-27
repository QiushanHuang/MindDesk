enum WorkspaceDetailTab: String, CaseIterable, Identifiable {
    case overview
    case tasks
    case canvas
    case resources
    case snippets

    var id: String { rawValue }

    static var defaultTab: WorkspaceDetailTab { .overview }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .tasks: "Tasks"
        case .canvas: "Canvas"
        case .resources: "Resources"
        case .snippets: "Snippets"
        }
    }

    var activatesCanvas: Bool {
        self == .canvas
    }

    static func tabAfterWorkspaceChange(from _: WorkspaceDetailTab) -> WorkspaceDetailTab {
        defaultTab
    }
}
