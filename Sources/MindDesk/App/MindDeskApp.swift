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

@main
struct MindDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let modelContainerResult = Result { try PersistentStoreBootstrap.makeModelContainer() }

    var body: some Scene {
        WindowGroup {
            switch modelContainerResult {
            case .success(let modelContainer):
                ContentView()
                    .frame(minWidth: 1120, minHeight: 720)
                    .modelContainer(modelContainer)
            case .failure(let error):
                StorageFailureView(error: error)
                    .frame(minWidth: 720, minHeight: 420)
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
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
