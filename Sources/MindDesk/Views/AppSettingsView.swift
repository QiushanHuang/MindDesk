import AppKit
import MindDeskCore
import SwiftUI

struct AppSettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            AppearanceSettingsPane()
                .tabItem {
                    Label("Appearance", systemImage: "textformat.size")
                }
            CanvasSettingsPane()
                .tabItem {
                    Label("Canvas", systemImage: "point.3.connected.trianglepath.dotted")
                }
            WorkspaceTaskSettingsPane()
                .tabItem {
                    Label("Canvas Tasks", systemImage: "checklist")
                }
            DataSettingsPane()
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
            SettingsManualPane()
                .tabItem {
                    Label("Manual", systemImage: "book")
                }
        }
        .padding(20)
        .frame(width: 620, height: 560)
    }
}

private struct GeneralSettingsPane: View {
    @AppStorage(AppPreferenceKeys.startupDestination) private var startupDestinationRaw = AppStartupDestination.home.rawValue

    var body: some View {
        SettingsForm {
            Section {
                Picker("Open MindDesk To", selection: startupDestinationSelection) {
                    ForEach(AppStartupDestination.allCases) { destination in
                        Text(destination.settingsTitle)
                            .tag(destination.rawValue)
                    }
                }

                SettingsHelpText("Choose the first product surface shown when the main window appears. Most recent workspace falls back to Home when there is no workspace history.")
            } header: {
                Text("Launch")
            }

            Section {
                SettingsInfoRow(
                    title: "Language",
                    value: "Automatic (macOS)",
                    description: "MindDesk currently follows the app bundle and system language. A manual language switch is intentionally not exposed until runtime localization is complete."
                )
            } header: {
                Text("Localization")
            }
        }
        .onAppear {
            startupDestinationRaw = AppStartupDestination.resolved(startupDestinationRaw).rawValue
        }
    }

    private var startupDestinationSelection: Binding<String> {
        Binding(
            get: { AppStartupDestination.resolved(startupDestinationRaw).rawValue },
            set: { startupDestinationRaw = AppStartupDestination.resolved($0).rawValue }
        )
    }
}

private struct AppearanceSettingsPane: View {
    @AppStorage(AppPreferenceKeys.appearanceMode) private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @AppStorage(AppPreferenceKeys.interfaceTextScale) private var interfaceTextScaleRaw = AppInterfaceTextScale.system.rawValue
    @AppStorage(AppPreferenceKeys.interfaceDensity) private var interfaceDensityRaw = AppInterfaceDensity.balanced.rawValue

    var body: some View {
        SettingsForm {
            Section {
                Picker("Appearance", selection: appearanceSelection) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.settingsTitle)
                            .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Text Scale", selection: textScaleSelection) {
                    ForEach(AppInterfaceTextScale.allCases) { scale in
                        Text(scale.settingsTitle)
                            .tag(scale.rawValue)
                    }
                }

                Picker("Control Density", selection: densitySelection) {
                    ForEach(AppInterfaceDensity.allCases) { density in
                        Text(density.settingsTitle)
                            .tag(density.rawValue)
                    }
                }

                SettingsHelpText("Appearance, text scale, and control density are global preferences. They apply to the main app window and Settings without changing project data.")
            } header: {
                Text("Interface")
            }
        }
        .onAppear {
            appearanceModeRaw = AppAppearanceMode.resolved(appearanceModeRaw).rawValue
            interfaceTextScaleRaw = AppInterfaceTextScale.resolved(interfaceTextScaleRaw).rawValue
            interfaceDensityRaw = AppInterfaceDensity.resolved(interfaceDensityRaw).rawValue
        }
    }

    private var appearanceSelection: Binding<String> {
        Binding(
            get: { AppAppearanceMode.resolved(appearanceModeRaw).rawValue },
            set: { appearanceModeRaw = AppAppearanceMode.resolved($0).rawValue }
        )
    }

    private var textScaleSelection: Binding<String> {
        Binding(
            get: { AppInterfaceTextScale.resolved(interfaceTextScaleRaw).rawValue },
            set: { interfaceTextScaleRaw = AppInterfaceTextScale.resolved($0).rawValue }
        )
    }

    private var densitySelection: Binding<String> {
        Binding(
            get: { AppInterfaceDensity.resolved(interfaceDensityRaw).rawValue },
            set: { interfaceDensityRaw = AppInterfaceDensity.resolved($0).rawValue }
        )
    }
}

private struct CanvasSettingsPane: View {
    @AppStorage(AppPreferenceKeys.canvasScrollZoomDirection) private var scrollZoomDirectionRaw = CanvasScrollZoomDirection.scrollDownZoomsOut.rawValue
    @AppStorage(AppPreferenceKeys.canvasDefaultZoomPercent) private var canvasDefaultZoomPercent = CanvasZoomBaseline.defaultPercent
    @AppStorage(AppPreferenceKeys.canvasConnectSingleShot) private var canvasConnectSingleShot = true

    var body: some View {
        SettingsForm {
            Section {
                Picker("Scroll Zoom Direction", selection: scrollZoomDirectionSelection) {
                    ForEach(CanvasScrollZoomDirection.allCases) { direction in
                        Text(direction.title)
                            .tag(direction.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                SettingsHelpText("Controls canvas zoom direction for mouse wheels and vertical trackpad scrolling. Pinch zoom keeps the system gesture behavior.")

                Stepper(value: $canvasDefaultZoomPercent, in: 35...500, step: 25) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("100% Display Calibration")
                        Text("\(Int(canvasDefaultZoomPercent.rounded()))% actual zoom is shown as 100% in Canvas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Single-use Connect", isOn: $canvasConnectSingleShot)

                SettingsHelpText("Display calibration applies to every Canvas scale label, Reset to 100%, and density-aware rendering thresholds. Single-use Connect returns to Select after one link; turn it off to keep building links.")
            } header: {
                Text("Canvas Interaction")
            }
        }
        .onAppear {
            scrollZoomDirectionRaw = CanvasScrollZoomDirection.resolved(scrollZoomDirectionRaw).rawValue
            canvasDefaultZoomPercent = canvasDefaultZoomPercent.isFinite
                ? min(max(canvasDefaultZoomPercent, 35), 500)
                : CanvasZoomBaseline.defaultPercent
        }
    }

    private var scrollZoomDirectionSelection: Binding<String> {
        Binding(
            get: { CanvasScrollZoomDirection.resolved(scrollZoomDirectionRaw).rawValue },
            set: { scrollZoomDirectionRaw = CanvasScrollZoomDirection.resolved($0).rawValue }
        )
    }
}

private struct WorkspaceTaskSettingsPane: View {
    @AppStorage(AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen) private var workspaceCanvasTodoPanelDefaultOpen = true
    @AppStorage(AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen) private var workspaceCanvasTodoDoneColumnDefaultOpen = false

    var body: some View {
        SettingsForm {
            Section {
                Toggle("Open Task Panel By Default", isOn: $workspaceCanvasTodoPanelDefaultOpen)
                Toggle("Show Done Column By Default", isOn: $workspaceCanvasTodoDoneColumnDefaultOpen)

                SettingsHelpText("These options control the initial state each time a Workspace Canvas opens. Canvas task controls can still open or close the panel and Done column temporarily for the current view.")
            } header: {
                Text("Canvas Task Defaults")
            }
        }
    }
}

private struct DataSettingsPane: View {
    @AppStorage(AppPreferenceKeys.manifestExportScope) private var manifestExportScopeRaw = ManifestExportScope.completeWorkspaceMap.rawValue
    @AppStorage(AppPreferenceKeys.manifestExportIncludesUsageDates) private var manifestExportIncludesUsageDates = false

    private let layout = MindDeskStoreLayout(
        applicationSupportDirectory: FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
    )

    var body: some View {
        SettingsForm {
            Section {
                Picker("Default Export Preset", selection: exportScopeSelection) {
                    ForEach(ManifestExportScope.allCases) { scope in
                        Text(scope.settingsTitle)
                            .tag(scope.rawValue)
                    }
                }

                Toggle("Include usage dates in JSON export", isOn: $manifestExportIncludesUsageDates)

                SettingsHelpText("The Export command confirms these options before writing. Complete Workspace Map is the only backup-style JSON export; Global Library Only excludes workspaces, canvases, cards, links, and aliases. Usage dates only cover behavior dates such as last opened or last run.")
            } header: {
                Text("Portable JSON")
            }

            Section {
                SettingsPathRow(title: "Store", url: layout.storeDirectory)
                SettingsPathRow(title: "Raw Backups", url: layout.backupDirectory)
                SettingsPathRow(title: "Quarantine", url: layout.quarantineDirectory)

                SettingsHelpText("Raw SQLite backups are local recovery data, not shareable project exports. They may include private paths, snippets, notes, aliases, and bookmark blobs.")
            } header: {
                Text("Local Storage")
            }

            Section {
                SettingsInfoRow(title: "Raw backup retention", value: "\(MindDeskStoreLayout.backupRetentionCount) newest folders", description: "Older raw backup folders are pruned after successful startup or migration backup housekeeping.")
                SettingsInfoRow(title: "Startup backup throttle", value: "30 minutes", description: "MindDesk avoids copying the raw store on every launch.")
                SettingsInfoRow(title: "Command safety", value: "Always confirm", description: "Command snippets remain confirmation-gated. Settings does not expose a switch to run shell commands silently.")
            } header: {
                Text("Safety Policy")
            }
        }
        .onAppear {
            manifestExportScopeRaw = ManifestExportScope.resolved(manifestExportScopeRaw).rawValue
        }
    }

    private var exportScopeSelection: Binding<String> {
        Binding(
            get: { ManifestExportScope.resolved(manifestExportScopeRaw).rawValue },
            set: { manifestExportScopeRaw = ManifestExportScope.resolved($0).rawValue }
        )
    }
}

private struct SettingsManualPane: View {
    var body: some View {
        SettingsForm {
            ManualSection(
                title: "What Belongs In Settings",
                text: "Use Settings for defaults that affect every workspace or canvas: launch destination, interface scale, canvas zoom behavior, task panel defaults, and export privacy. Edit individual workspaces, snippets, resources, and canvas cards in their own views."
            )
            ManualSection(
                title: "Canvas Defaults",
                text: "Scroll zoom direction changes the wheel or vertical trackpad zoom feel. 100% Display Calibration changes the scale label, Reset to 100%, and density-aware Canvas rendering thresholds for all canvases without rewriting canvas data. Single-use Connect decides whether linking stops after one edge or continues from the target card."
            )
            ManualSection(
                title: "Canvas Tasks",
                text: "Canvas Task settings only define the initial panel and Done-column state when opening a Workspace Canvas. The task board's dragged column split is layout memory, not a Settings preference."
            )
            ManualSection(
                title: "Import And Export",
                text: "Export creates a portable metadata JSON file and asks you to confirm scope and usage-date options each time. Complete Workspace Map keeps workspaces, resources, snippets, canvases, cards, links, and aliases. Global Library Only is not a complete backup; it exports reusable global resources and snippets without workspace maps. Import adds new MindDesk metadata and marks imported resources for reauthorization."
            )
            ManualSection(
                title: "Local Recovery Data",
                text: "The Store, Raw Backups, and Quarantine folders are local application support data. Use portable JSON for migration or sharing. Do not treat raw SQLite backups as share-safe files."
            )
        }
    }
}

private struct SettingsForm<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct SettingsHelpText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let value: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsPathRow: View {
    let title: String
    let url: URL

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer()
            Button("Reveal") {
                reveal(url)
            }
        }
    }

    private func reveal(_ url: URL) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }
        var parent = url.deletingLastPathComponent()
        while !fileManager.fileExists(atPath: parent.path), parent.path != "/" {
            parent.deleteLastPathComponent()
        }
        NSWorkspace.shared.open(parent)
    }
}

private struct ManualSection: View {
    let title: String
    let text: String

    var body: some View {
        Section {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        } header: {
            Text(title)
        }
    }
}

private extension AppAppearanceMode {
    var settingsTitle: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }
}

private extension AppInterfaceTextScale {
    var settingsTitle: String {
        switch self {
        case .system:
            "Follow macOS"
        case .compact:
            "Compact"
        case .standard:
            "Standard"
        case .large:
            "Large"
        case .extraLarge:
            "Extra Large"
        }
    }
}

private extension AppInterfaceDensity {
    var settingsTitle: String {
        switch self {
        case .compact:
            "Compact"
        case .balanced:
            "Balanced"
        case .spacious:
            "Spacious"
        }
    }
}

private extension AppStartupDestination {
    var settingsTitle: String {
        switch self {
        case .home:
            "Home"
        case .mostRecentWorkspace:
            "Most Recent Workspace"
        case .globalLibrary:
            "Global Library"
        case .pinnedFolders:
            "Pinned Folders"
        case .pinnedFiles:
            "Pinned Files"
        case .snippets:
            "Snippet Library"
        }
    }
}

private extension ManifestExportScope {
    var settingsTitle: String {
        switch self {
        case .completeWorkspaceMap:
            "Complete Workspace Map"
        case .globalLibraryOnly:
            "Global Library Only"
        }
    }
}
