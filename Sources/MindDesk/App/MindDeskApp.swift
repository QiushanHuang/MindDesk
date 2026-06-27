import AppKit
import MindDeskCore
import SwiftData
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct MindDeskMenuCommands: Commands {
    struct WorkbenchMenuDescriptor {
        static let menuTitle = "Workbench"
        static let newWorkspaceTitle = "New Workspace"
        static let newWorkspaceShortcutKey = "n"
        static let newWorkspaceShortcutModifiers = "command"
        static let quickOpenTitle = "Quick Open"
        static let quickOpenShortcutKey = "k"
        static let quickOpenShortcutModifiers = "command"
        static let importManifestTitle = "Import MindDesk Manifest..."
        static let importManifestShortcutKey = "i"
        static let importManifestShortcutModifiers = "command+shift"
        static let exportManifestTitle = "Export MindDesk Manifest..."
        static let exportManifestShortcutKey = "e"
        static let exportManifestShortcutModifiers = "command+shift"
        static let exportAgentReviewPackageTitle = "Export Agent Review Package..."
        static let exportAgentReviewPackageDefaultFilename = ImportExportService.agentReviewPackageDefaultFilename
        static let requiresFocusedMindDeskWindow = true
    }

    @FocusedValue(\.mindDeskCommands) private var commands

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(WorkbenchMenuDescriptor.newWorkspaceTitle) {
                commands?.newWorkspace()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(commands == nil)
        }

        CommandMenu(WorkbenchMenuDescriptor.menuTitle) {
            Button(WorkbenchMenuDescriptor.quickOpenTitle) {
                commands?.quickOpen()
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(commands == nil)

            Divider()

            Button(WorkbenchMenuDescriptor.exportManifestTitle) {
                commands?.exportManifest()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(commands == nil)

            Button(WorkbenchMenuDescriptor.exportAgentReviewPackageTitle) {
                commands?.exportAgentReviewPackage()
            }
            .disabled(commands == nil)

            Divider()

            Button(WorkbenchMenuDescriptor.importManifestTitle) {
                commands?.importManifest()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(commands == nil)

            Button("Review Agent Proposal...") {
                commands?.importProposalReview()
            }
            .disabled(commands == nil)
        }
    }
}

typealias MindDeskWorkbenchMenuDescriptor = MindDeskMenuCommands.WorkbenchMenuDescriptor

struct MindDeskSettingsCommands: Commands {
    struct SettingsCommandDescriptor {
        static let title = "MindDesk Settings..."
        static let shortcutKey = ","
        static let shortcutModifiers = "command"
        static let opensSettingsScene = true
    }

    @Environment(\.openSettings) private var openSettings

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(SettingsCommandDescriptor.title) {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

typealias MindDeskSettingsCommandDescriptor = MindDeskSettingsCommands.SettingsCommandDescriptor

struct MindDeskHelpCommands: Commands {
    struct HelpCommandDescriptor {
        static let title = MindDeskHelpCenterWindow.commandTitle
        static let windowID = MindDeskHelpCenterWindow.windowID
        static let shortcutKey = "?"
        static let shortcutKeyEquivalent: KeyEquivalent = "?"
        static let shortcutModifiers = "command+shift"
        static let topicIDs = MindDeskHelpCenterWindow.topicIDs
    }

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button(MindDeskHelpCommandDescriptor.title) {
                openWindow(id: MindDeskHelpCommandDescriptor.windowID)
            }
            .keyboardShortcut(MindDeskHelpCommandDescriptor.shortcutKeyEquivalent, modifiers: [.command, .shift])
        }
    }
}

typealias MindDeskHelpCommandDescriptor = MindDeskHelpCommands.HelpCommandDescriptor

@main
struct MindDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppPreferenceKeys.appearanceMode) private var appearanceModeRaw = AppPreferenceDefaults.appearanceMode
    @AppStorage(AppPreferenceKeys.interfaceTextScale) private var interfaceTextScaleRaw = AppPreferenceDefaults.interfaceTextScale
    @AppStorage(AppPreferenceKeys.interfaceDensity) private var interfaceDensityRaw = AppPreferenceDefaults.interfaceDensity
    private let modelContainerResult = Result { try PersistentStoreBootstrap.makeModelContainer() }

    var body: some Scene {
        WindowGroup {
            switch modelContainerResult {
            case .success(let modelContainer):
                ContentView()
                    .frame(minWidth: 1120, minHeight: 720)
                    .modelContainer(modelContainer)
                    .preferredColorScheme(preferredColorScheme)
                    .mindDeskDynamicTypeOverride(dynamicTypeOverride)
                    .controlSize(controlSize)
            case .failure(let error):
                StorageFailureView(error: error)
                    .frame(minWidth: 720, minHeight: 420)
                    .preferredColorScheme(preferredColorScheme)
                    .mindDeskDynamicTypeOverride(dynamicTypeOverride)
                    .controlSize(controlSize)
            }
        }
        .commands {
            MindDeskMenuCommands()
            MindDeskSettingsCommands()
            MindDeskHelpCommands()
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }

        Settings {
            AppSettingsView()
                .preferredColorScheme(preferredColorScheme)
                .mindDeskDynamicTypeOverride(dynamicTypeOverride)
                .controlSize(controlSize)
        }

        Window(MindDeskHelpCommandDescriptor.title, id: MindDeskHelpCommandDescriptor.windowID) {
            MindDeskHelpCenterView()
                .padding(20)
                .frame(minWidth: 720, minHeight: 560)
                .preferredColorScheme(preferredColorScheme)
                .mindDeskDynamicTypeOverride(dynamicTypeOverride)
                .controlSize(controlSize)
        }
        .defaultSize(width: 760, height: 620)
    }

    private var preferredColorScheme: ColorScheme? {
        switch AppAppearanceMode.resolved(appearanceModeRaw) {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    private var dynamicTypeOverride: DynamicTypeSize? {
        switch AppInterfaceTextScale.resolved(interfaceTextScaleRaw) {
        case .system:
            nil
        case .compact:
            .small
        case .standard:
            .medium
        case .large:
            .large
        case .extraLarge:
            .xLarge
        }
    }

    private var controlSize: ControlSize {
        switch AppInterfaceDensity.resolved(interfaceDensityRaw) {
        case .compact:
            .small
        case .balanced:
            .regular
        case .spacious:
            .large
        }
    }
}

private extension View {
    @ViewBuilder
    func mindDeskDynamicTypeOverride(_ size: DynamicTypeSize?) -> some View {
        if let size {
            dynamicTypeSize(size)
        } else {
            self
        }
    }
}

struct StorageFailurePresentation: Equatable {
    let iconSystemName: String
    let title: String
    let detail: String
    let storagePath: String
    let isDetailSelectable: Bool
    let isStoragePathSelectable: Bool
}

enum StorageFailurePresentationPolicy {
    static func presentation(for error: Error) -> StorageFailurePresentation {
        StorageFailurePresentation(
            iconSystemName: "externaldrive.badge.exclamationmark",
            title: "MindDesk could not open its data store.",
            detail: error.localizedDescription,
            storagePath: "Storage path: ~/Library/Application Support/\(MindDeskStoreLayout.bundleIdentifier)/Stores/MindDesk.store",
            isDetailSelectable: true,
            isStoragePathSelectable: true
        )
    }
}

private struct StorageFailureView: View {
    let error: Error

    private var presentation: StorageFailurePresentation {
        StorageFailurePresentationPolicy.presentation(for: error)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: presentation.iconSystemName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.orange)
            Text(presentation.title)
                .font(.title2.weight(.semibold))
            Text(presentation.detail)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text(presentation.storagePath)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
