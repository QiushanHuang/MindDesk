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

public enum AppPreferenceDefaults {
    public static let appearanceMode = AppAppearanceMode.system.rawValue
    public static let interfaceTextScale = AppInterfaceTextScale.system.rawValue
    public static let interfaceDensity = AppInterfaceDensity.balanced.rawValue
    public static let startupDestination = AppStartupDestination.home.rawValue
    public static let manifestExportScope = ManifestExportScope.completeWorkspaceMap.rawValue
    public static let manifestExportIncludesUsageDates = false
    public static let canvasScrollZoomDirection = CanvasScrollZoomDirection.scrollDownZoomsOut.rawValue
    public static let canvasDefaultZoomPercent = CanvasZoomBaseline.defaultPercent
    public static let canvasConnectSingleShot = true
    public static let workspaceCanvasTodoPanelDefaultOpen = true
    public static let workspaceCanvasTodoDoneColumnDefaultOpen = false
    public static let workspaceCanvasTodoColumnRatio = TodoBoardColumnSplit.defaultRatio

    public static let resettableKeys = [
        AppPreferenceKeys.appearanceMode,
        AppPreferenceKeys.interfaceTextScale,
        AppPreferenceKeys.interfaceDensity,
        AppPreferenceKeys.startupDestination,
        AppPreferenceKeys.manifestExportScope,
        AppPreferenceKeys.manifestExportIncludesUsageDates,
        AppPreferenceKeys.canvasScrollZoomDirection,
        AppPreferenceKeys.canvasDefaultZoomPercent,
        AppPreferenceKeys.canvasConnectSingleShot,
        AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen,
        AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen,
        AppPreferenceKeys.workspaceCanvasTodoColumnRatio
    ]

    public static let obsoleteKeys = [
        AppPreferenceKeys.workspaceCanvasTodoDoneColumnOpen
    ]

    public static func restore(in defaults: UserDefaults = .standard) {
        defaults.set(appearanceMode, forKey: AppPreferenceKeys.appearanceMode)
        defaults.set(interfaceTextScale, forKey: AppPreferenceKeys.interfaceTextScale)
        defaults.set(interfaceDensity, forKey: AppPreferenceKeys.interfaceDensity)
        defaults.set(startupDestination, forKey: AppPreferenceKeys.startupDestination)
        defaults.set(manifestExportScope, forKey: AppPreferenceKeys.manifestExportScope)
        defaults.set(manifestExportIncludesUsageDates, forKey: AppPreferenceKeys.manifestExportIncludesUsageDates)
        defaults.set(canvasScrollZoomDirection, forKey: AppPreferenceKeys.canvasScrollZoomDirection)
        defaults.set(canvasDefaultZoomPercent, forKey: AppPreferenceKeys.canvasDefaultZoomPercent)
        defaults.set(canvasConnectSingleShot, forKey: AppPreferenceKeys.canvasConnectSingleShot)
        defaults.set(workspaceCanvasTodoPanelDefaultOpen, forKey: AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen)
        defaults.set(workspaceCanvasTodoDoneColumnDefaultOpen, forKey: AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen)
        defaults.set(workspaceCanvasTodoColumnRatio, forKey: AppPreferenceKeys.workspaceCanvasTodoColumnRatio)

        for key in obsoleteKeys {
            defaults.removeObject(forKey: key)
        }
    }
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
