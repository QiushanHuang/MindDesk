import Foundation

public enum AppPreferenceKeys {
    public static let appearanceMode = "appearanceMode"
    public static let interfaceTextScale = "interfaceTextScale"
    public static let interfaceDensity = "interfaceDensity"
    public static let startupDestination = "startupDestination"
    public static let manifestExportScope = "manifestExportScope"
    public static let manifestExportIncludesUsageDates = "manifestExportIncludesUsageDates"
    public static let canvasScrollZoomDirection = "canvasScrollZoomDirection"
    public static let canvasDefaultZoomPercent = "canvasDefaultZoomPercent"
    public static let canvasConnectSingleShot = "canvasConnectSingleShot"
    public static let workspaceCanvasTodoPanelDefaultOpen = "workspaceCanvasTodoPanelDefaultOpen"
    public static let workspaceCanvasTodoDoneColumnDefaultOpen = "workspaceCanvasTodoDoneColumnDefaultOpen"
    public static let workspaceCanvasTodoDoneColumnOpen = "workspaceCanvasTodoDoneColumnOpen"
    public static let workspaceCanvasTodoColumnRatio = "workspaceCanvasTodoColumnRatio"
}

public enum AppAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public static func resolved(_ rawValue: String) -> AppAppearanceMode {
        AppAppearanceMode(rawValue: rawValue) ?? .system
    }
}

public enum AppInterfaceTextScale: String, CaseIterable, Identifiable, Sendable {
    case system
    case compact
    case standard
    case large
    case extraLarge

    public var id: String { rawValue }

    public static func resolved(_ rawValue: String) -> AppInterfaceTextScale {
        AppInterfaceTextScale(rawValue: rawValue) ?? .system
    }
}

public enum AppInterfaceDensity: String, CaseIterable, Identifiable, Sendable {
    case compact
    case balanced
    case spacious

    public var id: String { rawValue }

    public static func resolved(_ rawValue: String) -> AppInterfaceDensity {
        AppInterfaceDensity(rawValue: rawValue) ?? .balanced
    }
}

public enum AppStartupDestination: String, CaseIterable, Identifiable, Sendable {
    case home
    case mostRecentWorkspace
    case globalLibrary
    case pinnedFolders
    case pinnedFiles
    case snippets

    public var id: String { rawValue }

    public static func resolved(_ rawValue: String) -> AppStartupDestination {
        AppStartupDestination(rawValue: rawValue) ?? .home
    }
}

public enum ManifestExportScope: String, CaseIterable, Identifiable, Sendable {
    case completeWorkspaceMap
    case globalLibraryOnly

    public var id: String { rawValue }

    public static func resolved(_ rawValue: String) -> ManifestExportScope {
        ManifestExportScope(rawValue: rawValue) ?? .completeWorkspaceMap
    }
}
