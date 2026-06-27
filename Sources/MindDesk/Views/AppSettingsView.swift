import AppKit
import MindDeskCore
import SwiftUI

struct AppSettingsDisclosureRow: Identifiable, Sendable {
    let id: String
    let title: String
    let value: String
    let description: String
}

struct AppSettingsView: View {
    nonisolated static let resetAllSettingsButtonTitle = AppSettingsResetDescriptor.settingsPaneButtonTitle
    nonisolated static let resetAllSettingsHelpText = AppSettingsResetDescriptor.settingsPaneHelpText
    nonisolated static let resetAllSettingsAlertTitle = AppSettingsResetDescriptor.alertTitle
    nonisolated static let resetAllSettingsAlertInformativeText = AppSettingsResetDescriptor.alertInformativeText
    nonisolated static let resetAllSettingsConfirmButtonTitle = AppSettingsResetDescriptor.confirmButtonTitle
    nonisolated static let resetAllSettingsCancelButtonTitle = AppSettingsResetDescriptor.cancelButtonTitle
    nonisolated static let portableJSONHelpText = ImportExportService.manifestExportOptionsHelpText
    nonisolated static let canvasScrollZoomDirectionTitle = CanvasScrollZoomDirectionSettingsDescriptor.title
    nonisolated static let canvasScrollZoomDirectionHelpText = CanvasScrollZoomDirectionSettingsDescriptor.helpText
    nonisolated static let canvasAnimationFrameRateTitle = CanvasAnimationFrameRateSettingsDescriptor.title
    nonisolated static let canvasAnimationFrameRateHelpText = CanvasAnimationFrameRateSettingsDescriptor.helpText
    nonisolated static let canvasZoomCommitCadenceTitle = CanvasZoomCommitCadenceSettingsDescriptor.title
    nonisolated static let canvasZoomCommitCadenceHelpText = CanvasZoomCommitCadenceSettingsDescriptor.helpText
    nonisolated static let agentReviewPackageDescription = "In the main MindDesk window, use Workbench > Export Agent Review Package to create a read-only .mip.json package for Codex or another agent. It includes validationReport, agentIntegrationContract, extensionCapabilities, curated helpTopics for non-authoritative retrieval help, privacy notes, manifest metadata, and proposal contract details. It may include task group titles and task text when those records are in the selected export scope. payloadFieldSchemas document payload field schema/help only; accepted proposal JSON fields are review-only schema help. They are not authorization, not policy, not validation output, not capability grants, not an allowlist, and not payload allowlists; any file, Finder, URL, clipboard, Terminal, command, alias, import/export, or apply action requires Proposal Review and explicit immediate in-app confirmation outside the proposal review sheet before execution. helpTopics are not authorization and do not override validationReport, agentIntegrationContract, extensionCapabilities, agentPolicy, externalActionPolicy, the Proposal Review gate, or in-app confirmation. Proposal Review checks raw source-package authority mirrors and serialized validationReport before pending review: missing or drifted validationReport reports package.validation-report.* diagnostics, extensionCapabilities drift reports extensionCapabilityCatalog diagnostics, agentIntegrationContract drift reports contract.*.mismatch diagnostics, and forged top-level agentPolicy or externalActionPolicy reports package policy diagnostics. Missing raw authority mirrors also block before pending review: missing agentIntegrationContract reports contract.raw.missing, missing agentPolicy reports package.agent-policy.missing, missing externalActionPolicy reports package.external-action-policy.missing, and missing extensionCapabilities reports capability-catalog.raw.missing. Top-level helpTopics are ignored and replaced from the curated catalog during decode/re-encode. Top-level agentGuide defaults are regenerated; only wrapped custom guidance is preserved as untrusted text. None of these fields can change the gate or confirmation. \(ImportExportService.globalLibraryOnlyExclusionText) validationReport redaction applies only to structured diagnostics; diagnostic fields are tokenized while raw manifest metadata records remain in the package. Raw manifest records are metadata records; raw file contents are never included."
    nonisolated static let agentReviewCustomGuidanceTitle = MindDeskAgentReviewCustomGuidancePolicy.title
    nonisolated static let agentReviewCustomGuidancePlaceholder = MindDeskAgentReviewCustomGuidancePolicy.placeholder
    nonisolated static let agentReviewCustomGuidanceClearButtonTitle = "Clear"
    nonisolated static let agentReviewCustomGuidanceDescription = MindDeskAgentReviewCustomGuidancePolicy.settingsDescription
    nonisolated static let agentReviewCustomGuidancePrivacyDescription = MindDeskAgentReviewCustomGuidancePolicy.privacyDescription
    nonisolated static let agentReviewCustomGuidanceStatusPrivacyDescription = "Status and character budget show fixed labels and counts only. They do not replay custom guidance, paths, URLs, tokens, commands, or other input text."
    nonisolated static let agentReviewImportBehaviorDescription = "Agent Review packages are not backups and cannot be imported as manifests. File, Finder, URL, clipboard, Terminal, command, alias, import/export, and apply actions require Proposal Review and explicit immediate in-app confirmation outside the proposal review sheet before execution."
    nonisolated static let externalActionSafetyDescription = "Agents can read context and propose actions only. File, Finder, URL, clipboard, Terminal, command, alias, import/export, and apply actions require Proposal Review and explicit immediate in-app confirmation outside the proposal review sheet before execution."
    nonisolated static let agentReviewPackageBoundaryRows: [AppSettingsDisclosureRow] = [
        AppSettingsDisclosureRow(
            id: "agent-review-package-read-only",
            title: "Agent Review Package",
            value: "Read-only .mip.json",
            description: "Use Workbench > Export Agent Review Package to create a read-only .mip.json package for Codex or another agent."
        ),
        AppSettingsDisclosureRow(
            id: "agent-review-package-not-backup",
            title: "Backup behavior",
            value: "Not a backup",
            description: "Agent Review packages are not backups and do not replace Complete Workspace Map JSON exports or local raw SQLite backups."
        ),
        AppSettingsDisclosureRow(
            id: "agent-review-package-not-importable",
            title: "Import behavior",
            value: "Not importable",
            description: "Agent Review packages cannot be imported as manifests and do not create SwiftData objects."
        )
    ]

    nonisolated static func agentReviewCustomGuidancePresentation(
        for guidance: String
    ) -> MindDeskAgentReviewCustomGuidancePresentation {
        MindDeskAgentReviewCustomGuidancePresentationPolicy.presentation(for: guidance)
    }

    nonisolated static var agentFacingSideEffectSafetyDescriptions: [(label: String, text: String)] {
        [
            ("Agent Review Package settings disclosure", agentReviewPackageDescription),
            ("Custom Agent Review Guidance settings disclosure", agentReviewCustomGuidanceDescription),
            ("Agent Review import behavior settings disclosure", agentReviewImportBehaviorDescription),
            ("External action safety settings disclosure", externalActionSafetyDescription)
        ]
    }

    @AppStorage(AppSettingsPaneSelectionDescriptor.preferenceKey) private var selectedPaneRaw = AppSettingsPaneSelectionDescriptor.defaultRawValue

    var body: some View {
        TabView(selection: selectedPaneSelection) {
            GeneralSettingsPane()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(AppSettingsPaneSelection.general.rawValue)
            AppearanceSettingsPane()
                .tabItem {
                    Label("Appearance", systemImage: "textformat.size")
                }
                .tag(AppSettingsPaneSelection.appearance.rawValue)
            CanvasSettingsPane()
                .tabItem {
                    Label("Canvas", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .tag(AppSettingsPaneSelection.canvas.rawValue)
            WorkspaceTaskSettingsPane()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(AppSettingsPaneSelection.tasks.rawValue)
            DataSettingsPane()
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
                .tag(AppSettingsPaneSelection.data.rawValue)
            MindDeskHelpCenterView()
                .tabItem {
                    Label("Help", systemImage: "questionmark.circle")
                }
                .tag(AppSettingsPaneSelection.help.rawValue)
        }
        .padding(20)
        .frame(minWidth: 620, idealWidth: 720, minHeight: 560, idealHeight: 640)
        .onAppear {
            selectedPaneRaw = AppSettingsPaneSelection.resolved(selectedPaneRaw).rawValue
        }
    }

    private var selectedPaneSelection: Binding<String> {
        Binding(
            get: { AppSettingsPaneSelection.resolved(selectedPaneRaw).rawValue },
            set: { selectedPaneRaw = AppSettingsPaneSelection.resolved($0).rawValue }
        )
    }
}

private struct GeneralSettingsPane: View {
    @AppStorage(AppPreferenceKeys.startupDestination) private var startupDestinationRaw = AppPreferenceDefaults.startupDestination
    @AppStorage(AppPreferenceKeys.workspaceOpenDestination) private var workspaceOpenDestinationRaw = AppPreferenceDefaults.workspaceOpenDestination

    var body: some View {
        SettingsForm {
            Section {
                Picker("Open MindDesk To", selection: startupDestinationSelection) {
                    ForEach(AppStartupDestination.allCases) { destination in
                        Text(destination.settingsTitle)
                            .tag(destination.rawValue)
                    }
                }

                Picker("Open Workspaces To", selection: workspaceOpenDestinationSelection) {
                    ForEach(AppWorkspaceOpenDestination.allCases) { destination in
                        Text(destination.settingsTitle)
                            .tag(destination.rawValue)
                    }
                }

                SettingsHelpText("Choose the first product surface shown when the main window appears. Most Recent Workspace opens the latest opened or updated workspace; if no workspace exists, MindDesk opens Home. Open Workspaces To controls the first tab shown when a workspace is opened from the sidebar, Home, Quick Open, or startup.")
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

            Section {
                Button(AppSettingsView.resetAllSettingsButtonTitle) {
                    resetAllSettings()
                }
                SettingsHelpText(AppSettingsView.resetAllSettingsHelpText)
            } header: {
                Text("Reset")
            }
        }
        .onAppear {
            startupDestinationRaw = AppStartupDestination.resolved(startupDestinationRaw).rawValue
            workspaceOpenDestinationRaw = AppWorkspaceOpenDestination.resolved(workspaceOpenDestinationRaw).rawValue
        }
    }

    private var startupDestinationSelection: Binding<String> {
        Binding(
            get: { AppStartupDestination.resolved(startupDestinationRaw).rawValue },
            set: { startupDestinationRaw = AppStartupDestination.resolved($0).rawValue }
        )
    }

    private var workspaceOpenDestinationSelection: Binding<String> {
        Binding(
            get: { AppWorkspaceOpenDestination.resolved(workspaceOpenDestinationRaw).rawValue },
            set: { workspaceOpenDestinationRaw = AppWorkspaceOpenDestination.resolved($0).rawValue }
        )
    }

    private func resetAllSettings() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = AppSettingsView.resetAllSettingsAlertTitle
        alert.informativeText = AppSettingsView.resetAllSettingsAlertInformativeText
        alert.addButton(withTitle: AppSettingsView.resetAllSettingsConfirmButtonTitle)
        alert.addButton(withTitle: AppSettingsView.resetAllSettingsCancelButtonTitle)

        AppSettingsResetFlow.resetAllSettings { _ in
            alert.runModal() == .alertFirstButtonReturn
        }
    }
}

private struct AppearanceSettingsPane: View {
    @AppStorage(AppPreferenceKeys.appearanceMode) private var appearanceModeRaw = AppPreferenceDefaults.appearanceMode
    @AppStorage(AppPreferenceKeys.interfaceTextScale) private var interfaceTextScaleRaw = AppPreferenceDefaults.interfaceTextScale
    @AppStorage(AppPreferenceKeys.interfaceDensity) private var interfaceDensityRaw = AppPreferenceDefaults.interfaceDensity

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
    @AppStorage(CanvasScrollZoomDirectionSettingsDescriptor.preferenceKey) private var scrollZoomDirectionRaw = AppPreferenceDefaults.canvasScrollZoomDirection
    @AppStorage(AppPreferenceKeys.canvasDefaultZoomPercent) private var canvasDefaultZoomPercent = AppPreferenceDefaults.canvasDefaultZoomPercent
    @AppStorage(AppPreferenceKeys.canvasConnectSingleShot) private var canvasConnectSingleShot = AppPreferenceDefaults.canvasConnectSingleShot
    @AppStorage(CanvasAnimationFrameRateSettingsDescriptor.preferenceKey) private var canvasAnimationFrameRateRaw = AppPreferenceDefaults.canvasAnimationFrameRate
    @AppStorage(CanvasZoomCommitCadenceSettingsDescriptor.preferenceKey) private var canvasZoomCommitCadenceRaw = AppPreferenceDefaults.canvasZoomCommitCadence

    var body: some View {
        SettingsForm {
            Section {
                Picker(AppSettingsView.canvasScrollZoomDirectionTitle, selection: scrollZoomDirectionSelection) {
                    ForEach(CanvasScrollZoomDirection.allCases) { direction in
                        Text(direction.title)
                            .tag(direction.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                SettingsHelpText(AppSettingsView.canvasScrollZoomDirectionHelpText)

                Stepper(value: $canvasDefaultZoomPercent, in: 35...500, step: 25) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Canvas 100% Baseline")
                        Text("\(Int(canvasDefaultZoomPercent.rounded()))% actual zoom is shown as 100% in Canvas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Single-use Connect", isOn: $canvasConnectSingleShot)

                Picker(AppSettingsView.canvasAnimationFrameRateTitle, selection: animationFrameRateSelection) {
                    ForEach(CanvasAnimationFrameRate.allCases) { frameRate in
                        Text(frameRate.settingsTitle)
                            .tag(frameRate.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Picker(AppSettingsView.canvasZoomCommitCadenceTitle, selection: zoomCommitCadenceSelection) {
                    ForEach(CanvasZoomCommitCadence.allCases) { cadence in
                        Text(cadence.settingsTitle)
                            .tag(cadence.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                SettingsHelpText("The Canvas baseline applies to every scale label, Reset to 100%, new Canvas initial zoom, and density-aware rendering thresholds. Single-use Connect returns to Select after one link; turn it off to keep building links.")
                SettingsHelpText(AppSettingsView.canvasAnimationFrameRateHelpText)
                SettingsHelpText(AppSettingsView.canvasZoomCommitCadenceHelpText)
            } header: {
                Text("Canvas Interaction")
            }
        }
        .onAppear {
            scrollZoomDirectionRaw = CanvasScrollZoomDirection.resolved(scrollZoomDirectionRaw).rawValue
            canvasAnimationFrameRateRaw = CanvasAnimationFrameRate.resolved(canvasAnimationFrameRateRaw).rawValue
            canvasZoomCommitCadenceRaw = CanvasZoomCommitCadence.resolved(canvasZoomCommitCadenceRaw).rawValue
            canvasDefaultZoomPercent = canvasDefaultZoomPercent.isFinite
                ? min(max(canvasDefaultZoomPercent, 35), 500)
                : AppPreferenceDefaults.canvasDefaultZoomPercent
        }
    }

    private var scrollZoomDirectionSelection: Binding<String> {
        Binding(
            get: { CanvasScrollZoomDirection.resolved(scrollZoomDirectionRaw).rawValue },
            set: { scrollZoomDirectionRaw = CanvasScrollZoomDirection.resolved($0).rawValue }
        )
    }

    private var animationFrameRateSelection: Binding<String> {
        Binding(
            get: { CanvasAnimationFrameRate.resolved(canvasAnimationFrameRateRaw).rawValue },
            set: { canvasAnimationFrameRateRaw = CanvasAnimationFrameRate.resolved($0).rawValue }
        )
    }

    private var zoomCommitCadenceSelection: Binding<String> {
        Binding(
            get: { CanvasZoomCommitCadence.resolved(canvasZoomCommitCadenceRaw).rawValue },
            set: { canvasZoomCommitCadenceRaw = CanvasZoomCommitCadence.resolved($0).rawValue }
        )
    }
}

private struct WorkspaceTaskSettingsPane: View {
    @AppStorage(AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen) private var workspaceCanvasTodoPanelDefaultOpen = AppPreferenceDefaults.workspaceCanvasTodoPanelDefaultOpen
    @AppStorage(AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen) private var workspaceCanvasTodoDoneColumnDefaultOpen = AppPreferenceDefaults.workspaceCanvasTodoDoneColumnDefaultOpen

    var body: some View {
        SettingsForm {
            Section {
                Toggle("Open Task Panel By Default", isOn: $workspaceCanvasTodoPanelDefaultOpen)
                Toggle("Show Done Column By Default", isOn: $workspaceCanvasTodoDoneColumnDefaultOpen)

                SettingsHelpText("These options control the initial state each time a Workspace Canvas opens. Task controls can still open or close the panel and Done column temporarily for the current view.")
            } header: {
                Text("Task Defaults")
            }
        }
    }
}

private struct DataSettingsPane: View {
    @AppStorage(AppPreferenceKeys.manifestExportScope) private var manifestExportScopeRaw = AppPreferenceDefaults.manifestExportScope
    @AppStorage(AppPreferenceKeys.manifestExportIncludesUsageDates) private var manifestExportIncludesUsageDates = AppPreferenceDefaults.manifestExportIncludesUsageDates
    @AppStorage(AppPreferenceKeys.agentReviewCustomPromptGuidance) private var agentReviewCustomPromptGuidance = AppPreferenceDefaults.agentReviewCustomPromptGuidance

    private let layout = (try? PersistentStoreBootstrap.resolvedLayout()) ?? MindDeskStoreLayout(
        applicationSupportDirectory: URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support", isDirectory: true)
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

                SettingsHelpText("The Export command confirms these options before writing. Complete Workspace Map is the only backup-style JSON export; \(AppSettingsView.portableJSONHelpText) Usage dates only cover behavior dates such as last opened or last run.")
            } header: {
                Text("Portable JSON")
            }

            Section {
                ForEach(AppSettingsView.agentReviewPackageBoundaryRows) { row in
                    SettingsInfoRow(
                        title: row.title,
                        value: row.value,
                        description: row.description
                    )
                }

                SettingsHelpText(AppSettingsView.agentReviewPackageDescription)
                SettingsHelpText(AppSettingsView.agentReviewImportBehaviorDescription)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(AppSettingsView.agentReviewCustomGuidanceTitle)
                        Spacer()
                        Button(AppSettingsView.agentReviewCustomGuidanceClearButtonTitle) {
                            agentReviewCustomPromptGuidance = ""
                        }
                        .disabled(!customGuidancePresentation.isClearEnabled)
                    }

                    TextField(
                        AppSettingsView.agentReviewCustomGuidancePlaceholder,
                        text: boundedAgentReviewCustomPromptGuidance,
                        axis: .vertical
                    )
                    .lineLimit(3...6)

                    SettingsInfoRow(
                        title: customGuidancePresentation.statusTitle,
                        value: customGuidancePresentation.statusValue,
                        description: AppSettingsView.agentReviewCustomGuidanceStatusPrivacyDescription
                    )

                    SettingsInfoRow(
                        title: "Custom guidance budget",
                        value: customGuidancePresentation.characterBudgetText,
                        description: customGuidancePresentation.statusDescription
                    )

                    SettingsHelpText(AppSettingsView.agentReviewCustomGuidanceDescription)
                    SettingsHelpText(AppSettingsView.agentReviewCustomGuidancePrivacyDescription)
                }
            } header: {
                Text("Agent Review")
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
                SettingsInfoRow(title: "External action safety", value: "Confirm side effects", description: AppSettingsView.externalActionSafetyDescription)
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

    private var customGuidancePresentation: MindDeskAgentReviewCustomGuidancePresentation {
        AppSettingsView.agentReviewCustomGuidancePresentation(for: agentReviewCustomPromptGuidance)
    }

    private var boundedAgentReviewCustomPromptGuidance: Binding<String> {
        Binding(
            get: { agentReviewCustomPromptGuidance },
            set: { newValue in
                agentReviewCustomPromptGuidance = MindDeskAgentReviewCustomGuidancePolicy.boundedForStorage(newValue)
            }
        )
    }
}

enum MindDeskHelpCenterWindow {
    nonisolated static let windowID = "minddesk-help"
    nonisolated static let commandTitle = "MindDesk Help"
    nonisolated static let searchPlaceholder = "Search Help"
    nonisolated static let defaultTopicID = MindDeskHelpCatalog.defaultTopics.first?.id ?? ""
    nonisolated static let topicIDs = MindDeskHelpCatalog.defaultTopics.map(\.id)

    nonisolated static func readerSections(for topic: MindDeskHelpTopic) -> [MindDeskHelpTopicReaderSection] {
        MindDeskHelpTopicReaderPolicy.sections(for: topic)
    }
}

enum MindDeskHelpCenterSelectionPolicy {
    nonisolated static func normalizedSelection(
        _ selectedTopicID: String,
        visibleTopics: [MindDeskHelpTopic]
    ) -> String {
        guard !visibleTopics.isEmpty else {
            return ""
        }
        if visibleTopics.contains(where: { $0.id == selectedTopicID }) {
            return selectedTopicID
        }
        return visibleTopics[0].id
    }

    nonisolated static func selectedTopic(
        selectedTopicID: String,
        visibleTopics: [MindDeskHelpTopic]
    ) -> MindDeskHelpTopic? {
        let normalizedTopicID = normalizedSelection(selectedTopicID, visibleTopics: visibleTopics)
        return visibleTopics.first { $0.id == normalizedTopicID }
    }

    nonisolated static func rowSelectionTag(for topic: MindDeskHelpTopic) -> String {
        topic.id
    }
}

struct MindDeskHelpCenterView: View {
    @SceneStorage("minddesk.help.searchText") private var searchText = ""
    @SceneStorage("minddesk.help.selectedTopicID") private var selectedTopicID = MindDeskHelpCenterWindow.defaultTopicID

    private var topics: [MindDeskHelpTopic] {
        MindDeskHelpSearch.results(for: searchText, in: MindDeskHelpCatalog.defaultTopics, limit: 24)
    }

    private var selectedTopic: MindDeskHelpTopic? {
        MindDeskHelpCenterSelectionPolicy.selectedTopic(
            selectedTopicID: selectedTopicID,
            visibleTopics: topics
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(MindDeskHelpCenterWindow.searchPlaceholder, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(MindDeskHelpCenterWindow.searchPlaceholder)

            HStack(spacing: 12) {
                List(selection: $selectedTopicID) {
                    ForEach(topics) { topic in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(topic.title)
                                .font(.body)
                            Text(topic.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 3)
                        .tag(MindDeskHelpCenterSelectionPolicy.rowSelectionTag(for: topic))
                    }
                }
                .frame(minWidth: 230, idealWidth: 260, maxWidth: 300)

                Divider()

                ScrollView {
                    if let selectedTopic {
                        HelpTopicDetail(topic: selectedTopic)
                    } else {
                        Text("No help topics match this search.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: normalizeSelection)
        .onChange(of: searchText) { _, _ in
            normalizeSelection()
        }
    }

    private func normalizeSelection() {
        selectedTopicID = MindDeskHelpCenterSelectionPolicy.normalizedSelection(
            selectedTopicID,
            visibleTopics: topics
        )
    }
}

private struct SettingsForm<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            Form {
                content
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, alignment: .top)
        }
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

private struct HelpTopicDetail: View {
    let topic: MindDeskHelpTopic
    let readerSections: [MindDeskHelpTopicReaderSection]

    init(topic: MindDeskHelpTopic) {
        self.topic = topic
        readerSections = MindDeskHelpCenterWindow.readerSections(for: topic)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(topic.title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            Text(topic.category.settingsTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(topic.summary)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(readerSections) { section in
                VStack(alignment: .leading, spacing: 4) {
                    if readerSections.count > 1 {
                        Text(section.title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                    }

                    Text(verbatim: section.bodyMarkdown)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 8)
    }
}

private extension MindDeskHelpCategory {
    var settingsTitle: String {
        switch self {
        case .settings:
            "Settings"
        case .canvas:
            "Canvas"
        case .data:
            "Data"
        case .agent:
            "Agent"
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

private extension AppWorkspaceOpenDestination {
    var settingsTitle: String {
        switch self {
        case .overview:
            "Overview"
        case .tasks:
            "Tasks"
        case .canvas:
            "Canvas"
        case .resources:
            "Resources"
        case .snippets:
            "Snippets"
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

private extension CanvasAnimationFrameRate {
    var settingsTitle: String {
        switch self {
        case .reduced:
            "Reduced"
        case .balanced:
            "Balanced"
        case .smooth:
            "Smooth"
        }
    }
}

private extension CanvasZoomCommitCadence {
    var settingsTitle: String {
        switch self {
        case .responsive:
            "Responsive"
        case .balanced:
            "Balanced"
        case .relaxed:
            "Relaxed"
        }
    }
}
