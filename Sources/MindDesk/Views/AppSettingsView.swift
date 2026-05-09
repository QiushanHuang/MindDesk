import MindDeskCore
import SwiftUI

struct AppSettingsView: View {
    @AppStorage(AppPreferenceKeys.canvasScrollZoomDirection) private var scrollZoomDirectionRaw = CanvasScrollZoomDirection.scrollDownZoomsOut.rawValue
    @AppStorage(AppPreferenceKeys.canvasDefaultZoomPercent) private var canvasDefaultZoomPercent = CanvasZoomBaseline.defaultPercent
    @AppStorage(AppPreferenceKeys.canvasConnectSingleShot) private var canvasConnectSingleShot = true
    @AppStorage(AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen) private var workspaceCanvasTodoPanelDefaultOpen = true
    @AppStorage(AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen) private var workspaceCanvasTodoDoneColumnDefaultOpen = false

    var body: some View {
        Form {
            Section {
                Picker("Scroll Zoom Direction", selection: $scrollZoomDirectionRaw) {
                    ForEach(CanvasScrollZoomDirection.allCases) { direction in
                        Text(direction.title)
                            .tag(direction.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("Controls the canvas zoom direction for mouse wheels and vertical trackpad scrolling. Pinch zoom keeps the system gesture behavior.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Stepper(value: $canvasDefaultZoomPercent, in: 25...500, step: 25) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default 100% Display Baseline")
                        Text("\(Int(canvasDefaultZoomPercent.rounded()))% actual zoom is shown as 100% in Canvas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Single-use Connect", isOn: $canvasConnectSingleShot)

                Text("When enabled, Connect mode returns to Select after one link is created. Turn it off to keep building links without leaving Connect mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Canvas")
            }

            Section {
                Toggle("Open Task Panel By Default", isOn: $workspaceCanvasTodoPanelDefaultOpen)
                Toggle("Show Done Column By Default", isOn: $workspaceCanvasTodoDoneColumnDefaultOpen)

                Text("These options control the initial state of the bottom task panel and Done column when opening a Workspace Canvas. Canvas controls can still open or close them temporarily.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Workspace Tasks")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }
}
