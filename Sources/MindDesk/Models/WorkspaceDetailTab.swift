import MindDeskCore

enum WorkspaceDetailTab: String, CaseIterable, Identifiable {
    case overview
    case tasks
    case canvas
    case resources
    case snippets

    var id: String { rawValue }

    static var defaultTab: WorkspaceDetailTab { .canvas }

    static func defaultTab(for openDestinationRaw: String) -> WorkspaceDetailTab {
        switch AppWorkspaceOpenDestination.resolved(openDestinationRaw) {
        case .overview:
            .overview
        case .tasks:
            .tasks
        case .canvas:
            .canvas
        case .resources:
            .resources
        case .snippets:
            .snippets
        }
    }

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

    static func tabAfterWorkspaceChange(
        from _: WorkspaceDetailTab,
        openDestinationRaw: String = AppPreferenceDefaults.workspaceOpenDestination
    ) -> WorkspaceDetailTab {
        defaultTab(for: openDestinationRaw)
    }
}
