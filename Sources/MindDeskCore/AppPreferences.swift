import Foundation

public enum AppPreferenceKeys {
    public static let appearanceMode = "appearanceMode"
    public static let interfaceTextScale = "interfaceTextScale"
    public static let interfaceDensity = "interfaceDensity"
    public static let startupDestination = "startupDestination"
    public static let workspaceOpenDestination = "workspaceOpenDestination"
    public static let settingsSelectedPane = "settingsSelectedPane"
    public static let manifestExportScope = "manifestExportScope"
    public static let manifestExportIncludesUsageDates = "manifestExportIncludesUsageDates"
    public static let agentReviewCustomPromptGuidance = "agentReviewCustomPromptGuidance"
    public static let canvasScrollZoomDirection = "canvasScrollZoomDirection"
    public static let canvasDefaultZoomPercent = "canvasDefaultZoomPercent"
    public static let canvasConnectSingleShot = "canvasConnectSingleShot"
    public static let canvasAnimationFrameRate = "canvasAnimationFrameRate"
    public static let canvasZoomCommitCadence = "canvasZoomCommitCadence"
    public static let workspaceCanvasTodoPanelDefaultOpen = "workspaceCanvasTodoPanelDefaultOpen"
    public static let workspaceCanvasTodoDoneColumnDefaultOpen = "workspaceCanvasTodoDoneColumnDefaultOpen"
    public static let workspaceCanvasTodoDoneColumnOpen = "workspaceCanvasTodoDoneColumnOpen"
    public static let workspaceCanvasTodoColumnRatio = "workspaceCanvasTodoColumnRatio"
}

public enum AppSettingsPaneSelection: String, CaseIterable, Identifiable, Sendable {
    case general
    case appearance
    case canvas
    case tasks
    case data
    case help

    public var id: String { rawValue }

    public static func resolved(_ rawValue: String) -> AppSettingsPaneSelection {
        AppSettingsPaneSelection(rawValue: rawValue) ?? .general
    }
}

public enum AppSettingsPaneSelectionDescriptor {
    public static let preferenceKey = AppPreferenceKeys.settingsSelectedPane
    public static let defaultRawValue = AppPreferenceDefaults.settingsSelectedPane
    public static let optionRawValues = AppSettingsPaneSelection.allCases.map(\.rawValue)
}

public enum AppPreferenceDefaults {
    public static let appearanceMode = AppAppearanceMode.system.rawValue
    public static let interfaceTextScale = AppInterfaceTextScale.system.rawValue
    public static let interfaceDensity = AppInterfaceDensity.balanced.rawValue
    public static let startupDestination = AppStartupDestination.home.rawValue
    public static let workspaceOpenDestination = AppWorkspaceOpenDestination.canvas.rawValue
    public static let settingsSelectedPane = AppSettingsPaneSelection.general.rawValue
    public static let manifestExportScope = ManifestExportScope.completeWorkspaceMap.rawValue
    public static let manifestExportIncludesUsageDates = false
    public static let agentReviewCustomPromptGuidance = ""
    public static let canvasScrollZoomDirection = CanvasScrollZoomDirection.scrollDownZoomsOut.rawValue
    public static let canvasDefaultZoomPercent = CanvasZoomBaseline.defaultPercent
    public static let canvasConnectSingleShot = true
    public static let canvasAnimationFrameRate = CanvasAnimationFrameRate.balanced.rawValue
    public static let canvasZoomCommitCadence = CanvasZoomCommitCadence.balanced.rawValue
    public static let workspaceCanvasTodoPanelDefaultOpen = false
    public static let workspaceCanvasTodoDoneColumnDefaultOpen = false
    public static let workspaceCanvasTodoColumnRatio = TodoBoardColumnSplit.defaultRatio

    public static var resettableKeys: [String] {
        AppSettingsResetDescriptor.resetItems.map(\.key)
    }

    public static let obsoleteKeys = [
        AppPreferenceKeys.workspaceCanvasTodoDoneColumnOpen
    ]

    public static func restore(in defaults: UserDefaults = .standard) {
        for item in AppSettingsResetDescriptor.resetItems {
            item.writeDefault(to: defaults)
        }

        for key in obsoleteKeys {
            defaults.removeObject(forKey: key)
        }
    }
}

public enum AppSettingsResetCategory: String, CaseIterable, Sendable {
    case general
    case appearance
    case canvas
    case workspaceTasks
    case data
}

public enum AppSettingsStoredPreferenceValue: Equatable, Sendable {
    case string(String)
    case bool(Bool)
    case double(Double)

    public func write(to defaults: UserDefaults, forKey key: String) {
        switch self {
        case .string(let value):
            defaults.set(value, forKey: key)
        case .bool(let value):
            defaults.set(value, forKey: key)
        case .double(let value):
            defaults.set(value, forKey: key)
        }
    }

    public func storedValue(in defaults: UserDefaults, forKey key: String) -> AppSettingsStoredPreferenceValue? {
        guard let storedValue = defaults.object(forKey: key) else {
            return nil
        }
        switch self {
        case .string:
            guard let value = storedValue as? String else { return nil }
            return .string(value)
        case .bool:
            guard let value = storedValue as? Bool else { return nil }
            return .bool(value)
        case .double:
            guard let value = storedValue as? Double else { return nil }
            return .double(value)
        }
    }
}

public struct AppSettingsResetItem: Equatable, Sendable {
    public var key: String
    public var category: AppSettingsResetCategory
    public var title: String
    public var defaultStoredValue: AppSettingsStoredPreferenceValue
    public var defaultValueDescription: String

    public init(
        key: String,
        category: AppSettingsResetCategory,
        title: String,
        defaultStoredValue: AppSettingsStoredPreferenceValue,
        defaultValueDescription: String
    ) {
        self.key = key
        self.category = category
        self.title = title
        self.defaultStoredValue = defaultStoredValue
        self.defaultValueDescription = defaultValueDescription
    }

    public func writeDefault(to defaults: UserDefaults) {
        defaultStoredValue.write(to: defaults, forKey: key)
    }

    public func storedValue(in defaults: UserDefaults) -> AppSettingsStoredPreferenceValue? {
        defaultStoredValue.storedValue(in: defaults, forKey: key)
    }
}

public enum AppSettingsResetDescriptor {
    public static let settingsPaneButtonTitle = "Reset All Settings..."
    public static let alertTitle = "Reset all MindDesk settings?"
    public static let confirmButtonTitle = "Reset Settings"
    public static let cancelButtonTitle = "Cancel"
    public static let resetScopeSummary = "Reset All Settings restores launch destination, workspace open destination, appearance, text scale, control density, Canvas interaction, workspace task defaults, portable JSON defaults, and Custom Agent Review Guidance to product defaults."
    public static let obsoleteKeySummary = "It also removes old preference entries left by previous versions, including obsolete settings keys."
    public static let protectedDataSummary = "It does not delete workspaces, resources, snippets, tasks, canvases, cards, exports, raw backups, quarantine, or local recovery data."

    public static var settingsPaneHelpText: String {
        "\(resetScopeSummary) \(obsoleteKeySummary) \(protectedDataSummary)"
    }

    public static var reviewableSummaryLines: [String] {
        resetItems.map { "\($0.title): \($0.defaultValueDescription)" } + [
            "Obsolete settings keys cleared: \(obsoleteKeysCleared.joined(separator: ", "))",
            protectedDataSummary
        ]
    }

    public static var reviewableSummaryText: String {
        reviewableSummaryLines.joined(separator: "\n")
    }

    public static var alertInformativeText: String {
        "\(resetScopeSummary) Custom Agent Review Guidance will be cleared. Defaults include Home launch, Workspaces opening to Canvas, system appearance and text scale, balanced density, Complete Workspace Map export without usage dates, scroll-down-zooms-out Canvas behavior, 100% Canvas baseline, Single-use Connect on, balanced link animation and zoom save timing, Workspace Canvas task panel off, Done column off, and a 50/50 task split. \(obsoleteKeySummary) \(protectedDataSummary)"
    }

    public static let obsoleteKeysCleared = AppPreferenceDefaults.obsoleteKeys

    public static let resetItems: [AppSettingsResetItem] = [
        AppSettingsResetItem(
            key: AppPreferenceKeys.appearanceMode,
            category: .appearance,
            title: "Appearance",
            defaultStoredValue: .string(AppPreferenceDefaults.appearanceMode),
            defaultValueDescription: "System"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.interfaceTextScale,
            category: .appearance,
            title: "Text Scale",
            defaultStoredValue: .string(AppPreferenceDefaults.interfaceTextScale),
            defaultValueDescription: "Follow macOS"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.interfaceDensity,
            category: .appearance,
            title: "Control Density",
            defaultStoredValue: .string(AppPreferenceDefaults.interfaceDensity),
            defaultValueDescription: "Balanced"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.startupDestination,
            category: .general,
            title: "Launch Destination",
            defaultStoredValue: .string(AppPreferenceDefaults.startupDestination),
            defaultValueDescription: "Home"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.workspaceOpenDestination,
            category: .general,
            title: "Workspace Open Destination",
            defaultStoredValue: .string(AppPreferenceDefaults.workspaceOpenDestination),
            defaultValueDescription: "Canvas"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.manifestExportScope,
            category: .data,
            title: "Default Export Preset",
            defaultStoredValue: .string(AppPreferenceDefaults.manifestExportScope),
            defaultValueDescription: "Complete Workspace Map"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.manifestExportIncludesUsageDates,
            category: .data,
            title: "Include Usage Dates",
            defaultStoredValue: .bool(AppPreferenceDefaults.manifestExportIncludesUsageDates),
            defaultValueDescription: "Off"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.agentReviewCustomPromptGuidance,
            category: .data,
            title: "Custom Agent Review Guidance",
            defaultStoredValue: .string(AppPreferenceDefaults.agentReviewCustomPromptGuidance),
            defaultValueDescription: "Cleared"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.canvasScrollZoomDirection,
            category: .canvas,
            title: "Scroll Zoom Direction",
            defaultStoredValue: .string(AppPreferenceDefaults.canvasScrollZoomDirection),
            defaultValueDescription: "Scroll down zooms out"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.canvasDefaultZoomPercent,
            category: .canvas,
            title: "Canvas 100% Baseline",
            defaultStoredValue: .double(AppPreferenceDefaults.canvasDefaultZoomPercent),
            defaultValueDescription: "\(Int(CanvasZoomBaseline.defaultPercent.rounded()))%"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.canvasConnectSingleShot,
            category: .canvas,
            title: "Single-use Connect",
            defaultStoredValue: .bool(AppPreferenceDefaults.canvasConnectSingleShot),
            defaultValueDescription: "On"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.canvasAnimationFrameRate,
            category: .canvas,
            title: "Link Animation Smoothness",
            defaultStoredValue: .string(AppPreferenceDefaults.canvasAnimationFrameRate),
            defaultValueDescription: "Balanced"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.canvasZoomCommitCadence,
            category: .canvas,
            title: "Zoom Save Timing",
            defaultStoredValue: .string(AppPreferenceDefaults.canvasZoomCommitCadence),
            defaultValueDescription: "Balanced"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen,
            category: .workspaceTasks,
            title: "Open Task Panel By Default",
            defaultStoredValue: .bool(AppPreferenceDefaults.workspaceCanvasTodoPanelDefaultOpen),
            defaultValueDescription: "Off"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen,
            category: .workspaceTasks,
            title: "Show Done Column By Default",
            defaultStoredValue: .bool(AppPreferenceDefaults.workspaceCanvasTodoDoneColumnDefaultOpen),
            defaultValueDescription: "Off"
        ),
        AppSettingsResetItem(
            key: AppPreferenceKeys.workspaceCanvasTodoColumnRatio,
            category: .workspaceTasks,
            title: "Task Column Split",
            defaultStoredValue: .double(AppPreferenceDefaults.workspaceCanvasTodoColumnRatio),
            defaultValueDescription: "50/50 split"
        )
    ]
}

public enum AppSettingsResetFlow {
    @discardableResult
    public static func resetAllSettings(
        in defaults: UserDefaults = .standard,
        confirmReset: (AppSettingsResetDescriptor.Type) -> Bool
    ) -> Bool {
        guard confirmReset(AppSettingsResetDescriptor.self) else {
            return false
        }
        AppPreferenceDefaults.restore(in: defaults)
        return true
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

public enum AppWorkspaceOpenDestination: String, CaseIterable, Identifiable, Sendable {
    case overview
    case tasks
    case canvas
    case resources
    case snippets

    public var id: String { rawValue }

    public static func resolved(_ rawValue: String) -> AppWorkspaceOpenDestination {
        AppWorkspaceOpenDestination(rawValue: rawValue) ?? .canvas
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

public enum CanvasAnimationFrameRate: String, CaseIterable, Identifiable, Sendable {
    case reduced
    case balanced
    case smooth

    public var id: String { rawValue }

    public static func resolved(_ rawValue: String) -> CanvasAnimationFrameRate {
        CanvasAnimationFrameRate(rawValue: rawValue) ?? .balanced
    }
}

public enum CanvasAnimationFrameRateSettingsDescriptor {
    public static let preferenceKey = AppPreferenceKeys.canvasAnimationFrameRate
    public static let defaultRawValue = AppPreferenceDefaults.canvasAnimationFrameRate
    public static let title = "Link Animation Smoothness"
    public static let helpText = "Link Animation Smoothness sets the maximum target for animated glow smoothness, not a guaranteed constant frame rate. Reduce Motion, active interactions, zoomed out below the baseline, dense canvas safeguards, and other performance limits can degrade or pause animation to keep input responsive."
    public static let optionRawValues = CanvasAnimationFrameRate.allCases.map(\.rawValue)
}

public enum CanvasZoomCommitCadence: String, CaseIterable, Identifiable, Sendable {
    case responsive
    case balanced
    case relaxed

    public var id: String { rawValue }

    public static func resolved(_ rawValue: String) -> CanvasZoomCommitCadence {
        CanvasZoomCommitCadence(rawValue: rawValue) ?? .balanced
    }
}

public enum CanvasZoomCommitCadenceSettingsDescriptor {
    public static let preferenceKey = AppPreferenceKeys.canvasZoomCommitCadence
    public static let defaultRawValue = AppPreferenceDefaults.canvasZoomCommitCadence
    public static let title = "Zoom Save Timing"
    public static let helpText = "Zoom Save Timing only controls how quickly scroll zoom values are saved after the gesture settles. It does not change visual zoom smoothness, rendering frame rate, or live scroll/pinch zoom responsiveness."
    public static let optionRawValues = CanvasZoomCommitCadence.allCases.map(\.rawValue)
}
