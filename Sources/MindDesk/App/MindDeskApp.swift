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
    @FocusedValue(\.mindDeskCommands) private var commands

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Workspace") {
                commands?.newWorkspace()
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(commands == nil)
        }

        CommandMenu("Workbench") {
            Button("Quick Open") {
                commands?.quickOpen()
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(commands == nil)

            Divider()

            Button("Import MindDesk Manifest...") {
                commands?.importManifest()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(commands == nil)

            Button("Export MindDesk Manifest...") {
                commands?.exportManifest()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(commands == nil)
        }
    }
}

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

private struct StorageFailureView: View {
    let error: Error

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.orange)
            Text("MindDesk could not open its data store.")
                .font(.title2.weight(.semibold))
            Text(error.localizedDescription)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("Storage path: ~/Library/Application Support/\(MindDeskStoreLayout.bundleIdentifier)/Stores/MindDesk.store")
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
