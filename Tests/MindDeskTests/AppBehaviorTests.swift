import XCTest
import MindDeskCore
import SwiftData
@testable import MindDesk

final class AppBehaviorTests: XCTestCase {
    @MainActor
    func testCanvasInteractionFrameDriverKeepsOnlyLatestUpdateForAChannelUntilManualTick() {
        let driver = CanvasInteractionFrameDriver(automaticallySchedulesDisplayLink: false)
        var values: [Int] = []

        driver.submitLatest(channel: .viewport) { values.append(1) }
        driver.submitLatest(channel: .viewport) { values.append(2) }

        XCTAssertEqual(driver.pendingChannelCount, 1)
        XCTAssertTrue(values.isEmpty)

        driver.fireForTesting()

        XCTAssertEqual(values, [2])
        XCTAssertEqual(driver.pendingChannelCount, 0)
    }

    @MainActor
    func testCanvasInteractionFrameDriverDrainsDifferentChannelsOnceEach() {
        let driver = CanvasInteractionFrameDriver(automaticallySchedulesDisplayLink: false)
        var viewportRuns = 0
        var magnifyRuns = 0
        var nodeDragRuns = 0
        var edgeControlRuns = 0

        driver.submitLatest(channel: .viewport) { viewportRuns += 1 }
        driver.submitLatest(channel: .magnify) { magnifyRuns += 1 }
        driver.submitLatest(channel: .nodeDrag) { nodeDragRuns += 1 }
        driver.submitLatest(channel: .edgeControl) { edgeControlRuns += 1 }

        XCTAssertEqual(driver.pendingChannelCount, 4)
        driver.fireForTesting()
        driver.fireForTesting()

        XCTAssertEqual(viewportRuns, 1)
        XCTAssertEqual(magnifyRuns, 1)
        XCTAssertEqual(nodeDragRuns, 1)
        XCTAssertEqual(edgeControlRuns, 1)
        XCTAssertEqual(driver.pendingChannelCount, 0)
    }

    @MainActor
    func testCanvasInteractionFrameDriverFlushExecutesLatestUpdateAndRemovesIt() {
        let driver = CanvasInteractionFrameDriver(automaticallySchedulesDisplayLink: false)
        var values: [Int] = []

        driver.submitLatest(channel: .viewport) { values.append(1) }
        driver.submitLatest(channel: .viewport) { values.append(2) }

        driver.flush(.viewport)

        XCTAssertEqual(values, [2])
        XCTAssertEqual(driver.pendingChannelCount, 0)

        driver.fireForTesting()
        XCTAssertEqual(values, [2])
    }

    @MainActor
    func testCanvasInteractionFrameDriverAccumulatesFiniteScrollDeltasAtLatestLocationOnce() {
        let driver = CanvasInteractionFrameDriver(automaticallySchedulesDisplayLink: false)
        var samples: [CanvasScrollFrameSample] = []

        driver.submitScroll(
            CanvasScrollFrameSample(deltaY: 1.25, location: CanvasEdgePoint(x: 10, y: 20))
        ) { samples.append($0) }
        driver.submitScroll(
            CanvasScrollFrameSample(deltaY: .nan, location: CanvasEdgePoint(x: 30, y: 40))
        ) { samples.append($0) }
        driver.submitScroll(
            CanvasScrollFrameSample(deltaY: 2.75, location: CanvasEdgePoint(x: 50, y: 60))
        ) { samples.append($0) }

        XCTAssertTrue(samples.isEmpty)
        driver.fireForTesting()
        driver.fireForTesting()

        XCTAssertEqual(
            samples,
            [CanvasScrollFrameSample(deltaY: 4, location: CanvasEdgePoint(x: 50, y: 60))]
        )
    }

    @MainActor
    func testCanvasInteractionFrameDriverCancelAllDropsWorkAndReleasesCapturedOwner() {
        let driver = CanvasInteractionFrameDriver(automaticallySchedulesDisplayLink: false)
        var executionCount = 0
        var owner: NSObject? = NSObject()
        weak let weakOwner: NSObject? = owner

        driver.submitLatest(channel: .viewport) { [owner] in
            XCTAssertNotNil(owner)
            executionCount += 1
        }
        owner = nil

        XCTAssertNotNil(weakOwner)
        driver.cancelAll()

        XCTAssertNil(weakOwner)
        driver.fireForTesting()
        XCTAssertEqual(executionCount, 0)
        XCTAssertEqual(driver.pendingChannelCount, 0)
    }

    @MainActor
    func testCanvasInteractionFrameDriverDefersReentrantSubmissionUntilNextTick() {
        let driver = CanvasInteractionFrameDriver(automaticallySchedulesDisplayLink: false)
        var values: [Int] = []

        driver.submitLatest(channel: .viewport) {
            values.append(1)
            driver.submitLatest(channel: .viewport) { values.append(2) }
        }

        driver.fireForTesting()

        XCTAssertEqual(values, [1])
        XCTAssertEqual(driver.pendingChannelCount, 1)

        driver.fireForTesting()

        XCTAssertEqual(values, [1, 2])
        XCTAssertEqual(driver.pendingChannelCount, 0)
    }

    @MainActor
    func testFirstLaunchSeedDataCreatesDefaultWorkspaceAndSnippetsWithoutCanvasAndIsIdempotent() throws {
        let schema = Schema([
            WorkspaceModel.self,
            ResourcePinModel.self,
            SnippetModel.self,
            WorkspaceTodoModel.self,
            WorkspaceTodoGroupModel.self,
            CanvasModel.self,
            CanvasNodeModel.self,
            CanvasEdgeModel.self,
            FinderAliasRecordModel.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        try SeedData.seedIfNeeded(context: context)
        try SeedData.seedIfNeeded(context: context)

        let workspaces = try context.fetch(FetchDescriptor<WorkspaceModel>())
        let snippets = try context.fetch(FetchDescriptor<SnippetModel>())
        let canvases = try context.fetch(FetchDescriptor<CanvasModel>())
        let nodes = try context.fetch(FetchDescriptor<CanvasNodeModel>())

        XCTAssertEqual(workspaces.map(\.title), ["Qiushan Studio"])
        XCTAssertTrue(canvases.isEmpty)
        XCTAssertTrue(nodes.isEmpty)
        XCTAssertEqual(Set(snippets.map(\.title)), ["Summarize Notes", "List Current Folder"])
        XCTAssertTrue(snippets.contains { $0.kind == .prompt && $0.scope == .global })
        XCTAssertTrue(snippets.contains { $0.kind == .command && $0.requiresConfirmation })
    }


    func testStorageFailurePresentationShowsReadableErrorPageInsteadOfCrashing() throws {
        let error = NSError(
            domain: "MindDeskStoreOpen",
            code: 259,
            userInfo: [NSLocalizedDescriptionKey: "The store could not be opened because it is damaged."]
        )
        let presentation = StorageFailurePresentationPolicy.presentation(for: error)

        XCTAssertEqual(presentation.iconSystemName, "externaldrive.badge.exclamationmark")
        XCTAssertEqual(presentation.title, "MindDesk could not open its data store.")
        XCTAssertEqual(presentation.detail, "The store could not be opened because it is damaged.")
        XCTAssertEqual(
            presentation.storagePath,
            "Storage path: ~/Library/Application Support/\(MindDeskStoreLayout.bundleIdentifier)/Stores/MindDesk.store"
        )
        XCTAssertTrue(presentation.isDetailSelectable)
        XCTAssertTrue(presentation.isStoragePathSelectable)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/App/MindDeskApp.swift"),
            encoding: .utf8
        )
        guard let failureBranchStart = appSource.range(of: "case .failure(let error):")?.lowerBound,
              let sceneEnd = appSource.range(of: "        }\n        .commands", range: failureBranchStart..<appSource.endIndex)?.lowerBound else {
            return XCTFail("Could not locate modelContainerResult failure branch.")
        }
        let failureBranch = String(appSource[failureBranchStart..<sceneEnd])

        XCTAssertTrue(failureBranch.contains("StorageFailureView(error: error)"))
        XCTAssertTrue(appSource.contains("StorageFailurePresentationPolicy.presentation(for: error)"))
        XCTAssertFalse(failureBranch.contains("fatalError"))
        XCTAssertFalse(failureBranch.contains("try!"))
    }

    func testQuickOpenCommandKIsRegisteredOnlyThroughFocusedWorkbenchMenu() throws {
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.quickOpenTitle, "Quick Open")
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.quickOpenShortcutKey, "k")
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.quickOpenShortcutModifiers, "command")
        XCTAssertTrue(MindDeskWorkbenchMenuDescriptor.requiresFocusedMindDeskWindow)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )
        guard let toolbarStart = contentViewSource.range(of: "            .toolbar {")?.lowerBound,
              let toolbarEnd = contentViewSource.range(of: "            .navigationTitle", range: toolbarStart..<contentViewSource.endIndex)?.lowerBound else {
            return XCTFail("Could not locate ContentView toolbar implementation.")
        }
        let toolbarBody = String(contentViewSource[toolbarStart..<toolbarEnd])

        XCTAssertTrue(toolbarBody.contains("Label(\"Quick Open\", systemImage: \"magnifyingglass\")"))
        XCTAssertFalse(
            toolbarBody.contains(".keyboardShortcut(\"k\", modifiers: .command)"),
            "Command+K should be registered through the focused Workbench menu command only."
        )
        XCTAssertTrue(contentViewSource.contains("quickOpenRecordsSnapshot = quickOpenRecords"))
        XCTAssertTrue(contentViewSource.contains("QuickOpenPanel(\n                records: quickOpenRecordsSnapshot,"))
        XCTAssertTrue(contentViewSource.contains("@State private var query = \"\""))
        XCTAssertTrue(contentViewSource.contains("QuickOpenIndex.results(for: query, in: records, limit: 20)"))
    }

    func testQuickOpenCatalogSearchesWorkspaceResourceSnippetAndWebCardRecords() throws {
        XCTAssertEqual(
            QuickOpenCatalogDescriptor.searchableKinds,
            [.workspace, .resource, .snippet, .webCard]
        )
        XCTAssertEqual(
            QuickOpenCatalogDescriptor.searchHelpText,
            "Search workspaces, resources, snippets, and web page cards."
        )

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )
        guard let catalogStart = contentViewSource.range(of: "    private var quickOpenRecords: [QuickOpenRecord] {")?.lowerBound,
              let catalogEnd = contentViewSource.range(of: "    private func applyStartupDestinationIfNeeded()", range: catalogStart..<contentViewSource.endIndex)?.lowerBound else {
            return XCTFail("Could not locate ContentView Quick Open catalog implementation.")
        }
        let catalogBody = String(contentViewSource[catalogStart..<catalogEnd])

        XCTAssertTrue(contentViewSource.contains("QuickOpenCatalogDescriptor.searchableKinds"))
        XCTAssertTrue(catalogBody.contains("kind: .workspace"))
        XCTAssertTrue(catalogBody.contains("kind: .resource"))
        XCTAssertTrue(catalogBody.contains("kind: .snippet"))
        XCTAssertTrue(catalogBody.contains("QuickOpenWebCardRecordPolicy.records("))
    }

    func testQuickOpenResultRowPresentationShowsKindSubtitleAndDisplayLocation() {
        let presentation = QuickOpenResultRowPresentation(record: QuickOpenRecord(
            id: "webCard:node-docs",
            kind: .webCard,
            title: "Docs",
            subtitle: "https://docs.example.com",
            location: "Canvas: Research / Sources"
        ))

        XCTAssertEqual(presentation.systemImage, "globe")
        XCTAssertEqual(presentation.titleText, "Docs")
        XCTAssertEqual(presentation.kindText, "Web Page Card")
        XCTAssertEqual(presentation.subtitleText, "https://docs.example.com")
        XCTAssertEqual(presentation.locationText, "Canvas: Research / Sources")
        XCTAssertEqual(
            presentation.accessibilityLabel,
            "Web Page Card, Docs, https://docs.example.com, Canvas: Research / Sources"
        )
    }

    func testQuickOpenCatalogOrderingKeepsEmptyQueryAndEqualScoreResultsStable() {
        let workspace = QuickOpenRecord(id: "workspace:pinned", kind: .workspace, title: "Docs Workspace", subtitle: "")
        let resource = QuickOpenRecord(id: "resource:recent", kind: .resource, title: "Docs Resource", subtitle: "")
        let snippet = QuickOpenRecord(id: "snippet:recent", kind: .snippet, title: "Docs Snippet", subtitle: "")
        let webCard = QuickOpenRecord(id: "webCard:alpha", kind: .webCard, title: "Docs Web", subtitle: "https://docs.example.com")

        let records = QuickOpenCatalogOrdering.emptyQueryRecords(
            workspaces: [workspace],
            resources: [resource],
            snippets: [snippet],
            webCards: [webCard]
        )

        XCTAssertEqual(QuickOpenCatalogOrdering.emptyQueryKindOrder, [.workspace, .resource, .snippet, .webCard])
        XCTAssertEqual(records.map(\.id), ["workspace:pinned", "resource:recent", "snippet:recent", "webCard:alpha"])
        XCTAssertEqual(QuickOpenIndex.results(for: "", in: records).map(\.id), records.map(\.id))
        XCTAssertEqual(QuickOpenIndex.results(for: "docs", in: records).map(\.id), records.map(\.id))
    }

    func testQuickOpenKeyboardNavigationContinuouslyMovesAndScrollsSelectedResult() throws {
        let records = (0..<5).map {
            QuickOpenRecord(id: "result:\($0)", kind: .workspace, title: "Result \($0)", subtitle: "")
        }
        var selectedIndex = 0
        let visitedIndexes = [1, 1, 1, 1, 1, -1].map { delta in
            selectedIndex = QuickOpenSelectionPolicy.movedIndex(
                current: selectedIndex,
                delta: delta,
                resultCount: records.count
            )
            return selectedIndex
        }

        XCTAssertEqual(visitedIndexes, [1, 2, 3, 4, 0, 4])
        XCTAssertEqual(
            QuickOpenScrollFollowPolicy.target(selectedIndex: selectedIndex, results: records),
            QuickOpenScrollTarget(id: "result:4", anchor: .center)
        )
        XCTAssertEqual(
            QuickOpenScrollFollowPolicy.target(selectedIndex: 12, results: records),
            QuickOpenScrollTarget(id: "result:4", anchor: .center)
        )
        XCTAssertNil(QuickOpenScrollFollowPolicy.target(selectedIndex: 0, results: []))

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(contentViewSource.contains(".onMoveCommand"))
        XCTAssertTrue(contentViewSource.contains("QuickOpenScrollFollowPolicy.target(selectedIndex: selectedIndex, results: results)"))
    }

    func testQuickOpenEnterEscapeAndDismissLifecycleDoNotRetainSnapshots() throws {
        let records = [
            QuickOpenRecord(id: "result:first", kind: .workspace, title: "First", subtitle: ""),
            QuickOpenRecord(id: "result:second", kind: .resource, title: "Second", subtitle: "")
        ]

        XCTAssertEqual(QuickOpenKeyCommandPolicy.action(forKeyCode: 36), .openSelected)
        XCTAssertEqual(QuickOpenKeyCommandPolicy.action(forKeyCode: 76), .openSelected)
        XCTAssertEqual(QuickOpenKeyCommandPolicy.action(forKeyCode: 53), .dismiss)
        XCTAssertEqual(QuickOpenKeyCommandPolicy.action(forKeyCode: 125), .moveSelection(delta: 1))
        XCTAssertEqual(QuickOpenKeyCommandPolicy.action(forKeyCode: 126), .moveSelection(delta: -1))
        XCTAssertEqual(QuickOpenKeyCommandPolicy.action(forKeyCode: 0), .ignore)
        XCTAssertEqual(
            QuickOpenSelectedRecordPolicy.selectedRecord(in: records, selectedIndex: 9),
            records[1]
        )
        XCTAssertNil(QuickOpenSelectedRecordPolicy.selectedRecord(in: [], selectedIndex: 0))
        XCTAssertTrue(QuickOpenSnapshotLifecyclePolicy.recordsAfterDismiss().isEmpty)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(contentViewSource.contains("QuickOpenKeyCommandPolicy.action(forKeyCode: event.keyCode)"))
        XCTAssertTrue(contentViewSource.contains("QuickOpenSelectedRecordPolicy.selectedRecord(in: results, selectedIndex: selectedIndex)"))
        XCTAssertTrue(contentViewSource.contains("quickOpenRecordsSnapshot = QuickOpenSnapshotLifecyclePolicy.recordsAfterDismiss()"))
    }

    func testQuickOpenDirectOpenActionRoutesWorkspaceResourceAndSnippetByObjectType() throws {
        assertOrdinaryQuickOpenSurfaceAvailable()
        XCTAssertEqual(
            QuickOpenDirectOpenActionPolicy.action(for: QuickOpenRecord(
                id: "workspace:workspace-a",
                kind: .workspace,
                title: "Workspace A",
                subtitle: ""
            )),
            QuickOpenDirectOpenAction(
                selection: .workspace("workspace-a"),
                inspectorSelection: nil,
                statusMessage: "Opened workspace: Workspace A"
            )
        )
        XCTAssertEqual(
            QuickOpenDirectOpenActionPolicy.action(for: QuickOpenRecord(
                id: "resource:resource-a",
                kind: .resource,
                title: "Resource A",
                subtitle: ""
            )),
            QuickOpenDirectOpenAction(
                selection: .resource("resource-a"),
                inspectorSelection: nil,
                statusMessage: "Opened resource record: Resource A"
            )
        )
        XCTAssertEqual(
            QuickOpenDirectOpenActionPolicy.action(for: QuickOpenRecord(
                id: "snippet:snippet-a",
                kind: .snippet,
                title: "Snippet A",
                subtitle: ""
            )),
            QuickOpenDirectOpenAction(
                selection: .snippets,
                inspectorSelection: .snippet("snippet-a"),
                statusMessage: "Showing snippet: Snippet A"
            )
        )
        XCTAssertNil(QuickOpenDirectOpenActionPolicy.action(for: QuickOpenRecord(
            id: "webCard:web-a",
            kind: .webCard,
            title: "Docs",
            subtitle: "https://docs.example.com"
        )))

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(contentViewSource.contains("QuickOpenDirectOpenActionPolicy.action(for: record)"))
        XCTAssertTrue(contentViewSource.contains("QuickOpenWebCardOpenActionPolicy.action("))
    }

    func testWorkbenchQuickOpenImportExportCommandsRouteThroughFocusedWindow() throws {
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.quickOpenTitle, "Quick Open")
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.importManifestTitle, "Import MindDesk Manifest...")
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.importManifestShortcutKey, "i")
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.importManifestShortcutModifiers, "command+shift")
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.exportManifestTitle, "Export MindDesk Manifest...")
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.exportManifestShortcutKey, "e")
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.exportManifestShortcutModifiers, "command+shift")
        XCTAssertTrue(MindDeskWorkbenchMenuDescriptor.requiresFocusedMindDeskWindow)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/App/MindDeskApp.swift"),
            encoding: .utf8
        )
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )

        for routedAction in [
            "commands?.quickOpen()",
            "commands?.importManifest()",
            "commands?.exportManifest()"
        ] {
            XCTAssertTrue(appSource.contains(routedAction), "Workbench menu must route \(routedAction) through focused commands.")
        }
        for focusedValue in [
            "quickOpen: openQuickOpen",
            "importManifest: importManifest",
            "exportManifest: exportManifest"
        ] {
            XCTAssertTrue(contentViewSource.contains(focusedValue), "ContentView must publish current-window action \(focusedValue).")
        }
        XCTAssertFalse(appSource.contains("ImportExportService().importRecords"))
        XCTAssertFalse(appSource.contains("FileDialogs.openJSON()"))
        XCTAssertFalse(appSource.contains("FileDialogs.saveJSON()"))
    }

    func testFileNewWorkspaceCommandRoutesThroughSameFocusedActionAsSidebarPlus() throws {
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.newWorkspaceTitle, "New Workspace")
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.newWorkspaceShortcutKey, "n")
        XCTAssertEqual(MindDeskWorkbenchMenuDescriptor.newWorkspaceShortcutModifiers, "command")
        XCTAssertTrue(MindDeskWorkbenchMenuDescriptor.requiresFocusedMindDeskWindow)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/App/MindDeskApp.swift"),
            encoding: .utf8
        )
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(appSource.contains("CommandGroup(replacing: .newItem)"))
        XCTAssertTrue(appSource.contains("Button(WorkbenchMenuDescriptor.newWorkspaceTitle)"))
        XCTAssertTrue(appSource.contains("commands?.newWorkspace()"))
        XCTAssertTrue(appSource.contains(".keyboardShortcut(\"n\", modifiers: .command)"))
        XCTAssertTrue(contentViewSource.contains("newWorkspace: addWorkspace"))
        XCTAssertTrue(contentViewSource.contains("Button {\n                    addWorkspace()\n                } label: {\n                    Label(\"New Workspace\", systemImage: \"plus\")"))
    }

    func testCommandCommaOpensMindDeskSettingsThroughSceneSettingsCommand() throws {
        XCTAssertEqual(MindDeskSettingsCommandDescriptor.title, "MindDesk Settings...")
        XCTAssertEqual(MindDeskSettingsCommandDescriptor.shortcutKey, ",")
        XCTAssertEqual(MindDeskSettingsCommandDescriptor.shortcutModifiers, "command")
        XCTAssertTrue(MindDeskSettingsCommandDescriptor.opensSettingsScene)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/App/MindDeskApp.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(appSource.contains("@Environment(\\.openSettings)"))
        XCTAssertTrue(appSource.contains("openSettings()"))
        XCTAssertTrue(appSource.contains(".keyboardShortcut(\",\", modifiers: .command)"))
        XCTAssertTrue(appSource.contains("MindDeskSettingsCommands()"))
    }


    func testHelpCenterWindowDescriptorPublishesMainMenuHelpEntry() {
        XCTAssertEqual(MindDeskHelpCenterWindow.windowID, "minddesk-help")
        XCTAssertEqual(MindDeskHelpCenterWindow.commandTitle, "MindDesk Help")
        XCTAssertEqual(MindDeskHelpCenterWindow.searchPlaceholder, "Search Help")
        XCTAssertEqual(MindDeskHelpCenterWindow.defaultTopicID, "settings-defaults")
        XCTAssertEqual(
            MindDeskHelpCenterWindow.topicIDs,
            ["settings-defaults", "canvas-performance", "import-export"]
        )
    }

    func testMacOSHelpMenuOpensStandaloneHelpCenterAndSettingsReusesTopics() throws {
        XCTAssertEqual(MindDeskHelpCommandDescriptor.title, MindDeskHelpCenterWindow.commandTitle)
        XCTAssertEqual(MindDeskHelpCommandDescriptor.windowID, MindDeskHelpCenterWindow.windowID)
        XCTAssertEqual(MindDeskHelpCommandDescriptor.shortcutKey, "?")
        XCTAssertEqual(MindDeskHelpCommandDescriptor.shortcutModifiers, "command+shift")
        XCTAssertEqual(MindDeskHelpCommandDescriptor.topicIDs, MindDeskHelpCatalog.defaultTopics.map(\.id))
        XCTAssertEqual(MindDeskHelpCommandDescriptor.topicIDs, ["settings-defaults", "canvas-performance", "import-export"])

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/App/MindDeskApp.swift"),
            encoding: .utf8
        )
        let settingsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/AppSettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(appSource.contains("MindDeskHelpCommands()"))
        XCTAssertTrue(appSource.contains("CommandGroup(replacing: .help)"))
        XCTAssertTrue(appSource.contains("Button(MindDeskHelpCommandDescriptor.title)"))
        XCTAssertTrue(appSource.contains("openWindow(id: MindDeskHelpCommandDescriptor.windowID)"))
        XCTAssertTrue(appSource.contains("Window(MindDeskHelpCommandDescriptor.title, id: MindDeskHelpCommandDescriptor.windowID)"))
        XCTAssertTrue(appSource.contains("MindDeskHelpCenterView()"))
        XCTAssertTrue(settingsSource.contains("MindDeskHelpCenterView()"))
        XCTAssertTrue(settingsSource.contains(".tag(AppSettingsPaneSelection.help.rawValue)"))
        XCTAssertTrue(settingsSource.contains("MindDeskHelpSearch.results(for: searchText, in: MindDeskHelpCatalog.defaultTopics"))
    }



    func testHelpCenterSelectionNormalizesUnknownSelectionToFirstVisibleTopic() {
        let visibleTopics = MindDeskHelpSearch.results(
            for: "canvas performance",
            in: MindDeskHelpCatalog.defaultTopics,
            limit: 24
        )

        XCTAssertEqual(visibleTopics.first?.id, "canvas-performance")
        XCTAssertEqual(
            MindDeskHelpCenterSelectionPolicy.normalizedSelection(
                "missing-topic",
                visibleTopics: visibleTopics
            ),
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpCenterSelectionPolicy.selectedTopic(
                selectedTopicID: "missing-topic",
                visibleTopics: visibleTopics
            )?.id,
            "canvas-performance"
        )
    }

    func testHelpCenterSelectionPreservesSelectionWhenStillVisible() throws {
        let visibleTopics = MindDeskHelpSearch.results(
            for: "import export",
            in: MindDeskHelpCatalog.defaultTopics,
            limit: 24
        )
        let selectedTopic = try XCTUnwrap(visibleTopics.first { $0.id == "import-export" })

        XCTAssertEqual(
            MindDeskHelpCenterSelectionPolicy.normalizedSelection(
                selectedTopic.id,
                visibleTopics: visibleTopics
            ),
            selectedTopic.id
        )
        XCTAssertEqual(
            MindDeskHelpCenterSelectionPolicy.selectedTopic(
                selectedTopicID: selectedTopic.id,
                visibleTopics: visibleTopics
            )?.id,
            selectedTopic.id
        )
    }

    func testHelpCenterSelectionClearsWhenSearchHasNoVisibleTopics() {
        assertOrdinaryHelpSurfaceAvailable()
        XCTAssertEqual(
            MindDeskHelpCenterSelectionPolicy.normalizedSelection(
                "settings-defaults",
                visibleTopics: []
            ),
            ""
        )
        XCTAssertNil(
            MindDeskHelpCenterSelectionPolicy.selectedTopic(
                selectedTopicID: "settings-defaults",
                visibleTopics: []
            )
        )
    }

    func testHelpCenterRowSelectionTagUsesStringTopicID() throws {
        assertOrdinaryHelpSurfaceAvailable()
        let topic = try XCTUnwrap(MindDeskHelpCatalog.defaultTopics.first)
        let tag: String = MindDeskHelpCenterSelectionPolicy.rowSelectionTag(for: topic)

        XCTAssertEqual(tag, topic.id)
    }

    func testHelpCenterReaderSectionsUseCorePresentationPolicy() throws {
        assertOrdinaryHelpSurfaceAvailable()
        let topic = try XCTUnwrap(
            MindDeskHelpCatalog.defaultTopics.first { $0.id == "canvas-performance" }
        )

        XCTAssertEqual(
            MindDeskHelpCenterWindow.readerSections(for: topic),
            MindDeskHelpTopicReaderPolicy.sections(for: topic)
        )
        XCTAssertGreaterThan(MindDeskHelpCenterWindow.readerSections(for: topic).count, 1)
    }

    func testPersistentStorePostOpenMaintenancePlannerDefersStartupBackupCopy() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let now = Date(timeIntervalSince1970: 1_800_000)
        let staleBackup = backupRoot.appendingPathComponent(
            MindDeskStoreLayout.backupFolderName(
                for: now.addingTimeInterval(-31 * 60),
                reason: .startup
            ),
            isDirectory: true
        )

        let plan = PersistentStorePostOpenMaintenancePlan.plan(
            didMigrateStore: false,
            didRestoreStore: false,
            storeExists: true,
            backupFolders: [staleBackup],
            now: now
        )

        XCTAssertTrue(plan.immediateWork.isEmpty)
        XCTAssertEqual(plan.deferredWork, [.backup(.startup), .pruneOldBackups])
    }

    func testPersistentStorePostOpenMaintenancePlannerKeepsMigrationBackupSynchronous() {
        let plan = PersistentStorePostOpenMaintenancePlan.plan(
            didMigrateStore: true,
            didRestoreStore: false,
            storeExists: true,
            backupFolders: [],
            now: Date(timeIntervalSince1970: 1_800_000)
        )

        XCTAssertEqual(plan.immediateWork, [.backup(.migration), .pruneOldBackups])
        XCTAssertTrue(plan.deferredWork.isEmpty)
    }

    func testPersistentStorePostOpenMaintenancePlannerCreatesRestoreBackupBeforePruning() {
        let plan = PersistentStorePostOpenMaintenancePlan.plan(
            didMigrateStore: false,
            didRestoreStore: true,
            storeExists: true,
            backupFolders: [],
            now: Date(timeIntervalSince1970: 1_800_000)
        )

        XCTAssertEqual(plan.immediateWork, [.backup(.restore), .pruneOldBackups])
        XCTAssertTrue(plan.deferredWork.isEmpty)
    }

    func testPersistentStorePostOpenMaintenanceRunnerSchedulesDeferredStartupWorkWithoutRunningItInline() {
        let recorder = PostOpenMaintenanceRunnerRecorder()
        let plan = PersistentStorePostOpenMaintenancePlan(
            immediateWork: [],
            deferredWork: [.backup(.startup), .pruneOldBackups]
        )

        PersistentStorePostOpenMaintenanceRunner.run(
            plan: plan,
            runImmediate: { recorder.immediateRuns.append($0) },
            runDeferred: { recorder.deferredRuns.append($0) },
            scheduleDeferred: { recorder.scheduledDeferredWork.append($0) }
        )

        XCTAssertTrue(recorder.immediateRuns.isEmpty)
        XCTAssertTrue(recorder.deferredRuns.isEmpty)
        XCTAssertEqual(recorder.scheduledDeferredWork.count, 1)

        recorder.scheduledDeferredWork[0]()

        XCTAssertEqual(recorder.deferredRuns, [[.backup(.startup), .pruneOldBackups]])
    }

    func testPersistentStorePostOpenMaintenanceRunnerKeepsMigrationWorkInline() {
        let recorder = PostOpenMaintenanceRunnerRecorder()
        let plan = PersistentStorePostOpenMaintenancePlan(
            immediateWork: [.backup(.migration), .pruneOldBackups],
            deferredWork: []
        )

        PersistentStorePostOpenMaintenanceRunner.run(
            plan: plan,
            runImmediate: { recorder.immediateRuns.append($0) },
            runDeferred: { recorder.deferredRuns.append($0) },
            scheduleDeferred: { recorder.scheduledDeferredWork.append($0) }
        )

        XCTAssertEqual(recorder.immediateRuns, [[.backup(.migration), .pruneOldBackups]])
        XCTAssertTrue(recorder.deferredRuns.isEmpty)
        XCTAssertTrue(recorder.scheduledDeferredWork.isEmpty)
    }









    func testSettingsDirectUserSideEffectCopyRequiresExplicitImmediateConfirmation() {
        let sideEffects: [WorkbenchExternalAction] = [
            .applyAgentAction,
            .runCommand,
            .openTerminal,
            .openFileSystemItem,
            .revealInFinder,
            .createFinderAlias,
            .openURL,
            .copyPathToClipboard
        ]

        XCTAssertTrue(sideEffects.allSatisfy(WorkbenchExternalActionPolicy.requiresUserConfirmation))
        XCTAssertFalse(WorkbenchExternalActionPolicy.requiresUserConfirmation(.readAgentContext))
        XCTAssertFalse(WorkbenchExternalActionPolicy.requiresUserConfirmation(.proposeAgentAction))
    }

    func testSettingsResetAllCopyUsesSharedDescriptorForReviewableSummary() {
        XCTAssertEqual(AppSettingsView.resetAllSettingsButtonTitle, AppSettingsResetDescriptor.settingsPaneButtonTitle)
        XCTAssertEqual(AppSettingsView.resetAllSettingsHelpText, AppSettingsResetDescriptor.settingsPaneHelpText)
        XCTAssertEqual(AppSettingsView.resetAllSettingsAlertTitle, AppSettingsResetDescriptor.alertTitle)
        XCTAssertEqual(AppSettingsView.resetAllSettingsAlertInformativeText, AppSettingsResetDescriptor.alertInformativeText)
        XCTAssertEqual(AppSettingsView.resetAllSettingsConfirmButtonTitle, AppSettingsResetDescriptor.confirmButtonTitle)
        XCTAssertEqual(AppSettingsView.resetAllSettingsCancelButtonTitle, AppSettingsResetDescriptor.cancelButtonTitle)

        let combined = [
            AppSettingsView.resetAllSettingsHelpText,
            AppSettingsView.resetAllSettingsAlertInformativeText
        ]
            .joined(separator: " ")
            .lowercased()

        for required in [
            "reset all settings",
            "obsolete settings keys",
            "does not delete",
            "workspaces",
            "resources",
            "snippets",
            "tasks",
            "canvases",
            "exports",
            "raw backups",
            "quarantine"
        ] {
            XCTAssertTrue(combined.contains(required), "Missing Settings reset UI copy term: \(required)")
        }
    }

    func testSettingsResetAllFlowConfirmsBeforeRestoringDefaults() throws {
        let suiteName = "MindDeskTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let obsoleteGuidanceKey = "agentReviewCustomPromptGuidance"
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(AppAppearanceMode.dark.rawValue, forKey: AppPreferenceKeys.appearanceMode)
        defaults.set("Keep until confirmed", forKey: obsoleteGuidanceKey)

        let canceled = AppSettingsResetFlow.resetAllSettings(
            in: defaults,
            confirmReset: { _ in false }
        )

        XCTAssertFalse(canceled)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.appearanceMode), AppAppearanceMode.dark.rawValue)
        XCTAssertEqual(defaults.string(forKey: obsoleteGuidanceKey), "Keep until confirmed")

        let confirmed = AppSettingsResetFlow.resetAllSettings(
            in: defaults,
            confirmReset: { descriptor in
                descriptor.alertInformativeText.contains("Reset All Settings") &&
                    descriptor.obsoleteKeysCleared.contains(obsoleteGuidanceKey)
            }
        )

        XCTAssertTrue(confirmed)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.appearanceMode), AppPreferenceDefaults.appearanceMode)
        XCTAssertNil(defaults.object(forKey: obsoleteGuidanceKey))
    }

    func testCanvasScrollZoomDirectionSettingsUsesSharedSwitchableDescriptor() throws {
        XCTAssertEqual(AppSettingsView.canvasScrollZoomDirectionTitle, CanvasScrollZoomDirectionSettingsDescriptor.title)
        XCTAssertEqual(AppSettingsView.canvasScrollZoomDirectionHelpText, CanvasScrollZoomDirectionSettingsDescriptor.helpText)
        XCTAssertEqual(CanvasScrollZoomDirectionSettingsDescriptor.preferenceKey, AppPreferenceKeys.canvasScrollZoomDirection)
        XCTAssertEqual(CanvasScrollZoomDirectionSettingsDescriptor.defaultRawValue, AppPreferenceDefaults.canvasScrollZoomDirection)
        XCTAssertEqual(
            CanvasScrollZoomDirectionSettingsDescriptor.optionRawValues,
            CanvasScrollZoomDirection.allCases.map(\.rawValue)
        )

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settingsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/AppSettingsView.swift"),
            encoding: .utf8
        )
        let canvasSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Canvas/WorkspaceCanvasView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(settingsSource.contains("@AppStorage(CanvasScrollZoomDirectionSettingsDescriptor.preferenceKey)"))
        XCTAssertTrue(settingsSource.contains("Picker(AppSettingsView.canvasScrollZoomDirectionTitle"))
        XCTAssertTrue(settingsSource.contains("SettingsHelpText(AppSettingsView.canvasScrollZoomDirectionHelpText)"))
        XCTAssertTrue(canvasSource.contains("@AppStorage(CanvasScrollZoomDirectionSettingsDescriptor.preferenceKey)"))
        XCTAssertTrue(canvasSource.contains("CanvasScrollZoomRuntimePolicy.zoom"))
        XCTAssertTrue(canvasSource.contains("directionRawValue: scrollZoomDirectionRaw"))
    }

    func testCanvasScrollZoomDirectionChangesApplyWithoutRestart() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let canvasSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Canvas/WorkspaceCanvasView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(canvasSource.contains("@AppStorage(CanvasScrollZoomDirectionSettingsDescriptor.preferenceKey)"))
        XCTAssertTrue(canvasSource.contains("CanvasScrollZoomRuntimePolicy.zoom"))
        XCTAssertTrue(canvasSource.contains("directionRawValue: scrollZoomDirectionRaw"))
    }

    func testCanvasAnimationSmoothnessSettingsUsesSharedAdaptiveLimitCopy() throws {
        XCTAssertEqual(AppSettingsView.canvasAnimationFrameRateTitle, CanvasAnimationFrameRateSettingsDescriptor.title)
        XCTAssertEqual(AppSettingsView.canvasAnimationFrameRateHelpText, CanvasAnimationFrameRateSettingsDescriptor.helpText)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settingsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/AppSettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(settingsSource.contains("@AppStorage(CanvasAnimationFrameRateSettingsDescriptor.preferenceKey)"))
        XCTAssertTrue(settingsSource.contains("Picker(AppSettingsView.canvasAnimationFrameRateTitle"))
        XCTAssertTrue(settingsSource.contains("SettingsHelpText(AppSettingsView.canvasAnimationFrameRateHelpText)"))
    }

    func testWorkspaceCanvasUsesAnimationTimelinePlanForBlueFlowCPUThrottle() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let canvasSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Canvas/WorkspaceCanvasView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(canvasSource.contains("CanvasEdgeAnimationPolicy.effectiveTimelinePlan"))
        XCTAssertTrue(canvasSource.contains("edgeAnimationTimelinePlan.minimumInterval"))
        XCTAssertTrue(canvasSource.contains("edgeAnimationTimelinePlan.shouldAnimate"))
    }

    func testCanvasZoomSaveTimingSettingsUsesSharedSaveOnlyCopy() throws {
        XCTAssertEqual(AppSettingsView.canvasZoomCommitCadenceTitle, CanvasZoomCommitCadenceSettingsDescriptor.title)
        XCTAssertEqual(AppSettingsView.canvasZoomCommitCadenceHelpText, CanvasZoomCommitCadenceSettingsDescriptor.helpText)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settingsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/AppSettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(settingsSource.contains("@AppStorage(CanvasZoomCommitCadenceSettingsDescriptor.preferenceKey)"))
        XCTAssertTrue(settingsSource.contains("Picker(AppSettingsView.canvasZoomCommitCadenceTitle"))
        XCTAssertTrue(settingsSource.contains("SettingsHelpText(AppSettingsView.canvasZoomCommitCadenceHelpText)"))
    }

    func testAppSettingsPaneSelectionUsesAppStorageBackedTabSelection() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settingsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/AppSettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(settingsSource.contains("@AppStorage(AppSettingsPaneSelectionDescriptor.preferenceKey) private var selectedPaneRaw"))
        XCTAssertTrue(settingsSource.contains("TabView(selection: selectedPaneSelection)"))
        XCTAssertTrue(settingsSource.contains("selectedPaneRaw = AppSettingsPaneSelection.resolved(selectedPaneRaw).rawValue"))
        XCTAssertTrue(settingsSource.contains(".tag(AppSettingsPaneSelection.general.rawValue)"))
        XCTAssertTrue(settingsSource.contains(".tag(AppSettingsPaneSelection.appearance.rawValue)"))
        XCTAssertTrue(settingsSource.contains(".tag(AppSettingsPaneSelection.canvas.rawValue)"))
        XCTAssertTrue(settingsSource.contains(".tag(AppSettingsPaneSelection.tasks.rawValue)"))
        XCTAssertTrue(settingsSource.contains(".tag(AppSettingsPaneSelection.data.rawValue)"))
        XCTAssertTrue(settingsSource.contains(".tag(AppSettingsPaneSelection.help.rawValue)"))
    }

    func testAppSettingsLayoutAllowsWindowExpansionAndScrollableLongText() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let settingsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/AppSettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(settingsSource.contains(".frame(minWidth: 620, idealWidth: 720, minHeight: 560, idealHeight: 640)"))
        XCTAssertFalse(settingsSource.contains(".frame(width: 720"))
        XCTAssertFalse(settingsSource.contains(".frame(height: 640"))
        func sourceSlice(from startMarker: String, to endMarker: String) -> String? {
            guard let start = settingsSource.range(of: startMarker)?.lowerBound,
                  let end = settingsSource.range(of: endMarker, range: start..<settingsSource.endIndex)?.lowerBound else {
                return nil
            }
            return String(settingsSource[start..<end])
        }
        let settingsFormSource = try XCTUnwrap(sourceSlice(from: "private struct SettingsForm", to: "private struct SettingsHelpText"))
        let helpTextSource = try XCTUnwrap(sourceSlice(from: "private struct SettingsHelpText", to: "private struct SettingsInfoRow"))
        let infoRowSource = try XCTUnwrap(sourceSlice(from: "private struct SettingsInfoRow", to: "private struct SettingsPathRow"))

        XCTAssertTrue(settingsFormSource.contains("ScrollView {"))
        XCTAssertTrue(settingsFormSource.contains("Form {"))
        XCTAssertTrue(settingsFormSource.contains(".frame(maxWidth: .infinity, alignment: .top)"))
        XCTAssertTrue(settingsFormSource.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)"))
        XCTAssertTrue(helpTextSource.contains(".fixedSize(horizontal: false, vertical: true)"))
        XCTAssertFalse(helpTextSource.contains(".lineLimit"))
        XCTAssertTrue(infoRowSource.contains(".fixedSize(horizontal: false, vertical: true)"))
        XCTAssertFalse(infoRowSource.contains(".lineLimit"))
    }

    func testWorkspaceCanvasTodoStartupUsesSharedNoAutoGroupPolicy() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let canvasSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Canvas/WorkspaceCanvasView.swift"),
            encoding: .utf8
        )
        let todoBoardSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/WorkspaceTodoBoardView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(canvasSource.contains("TodoBoardStartupPolicy.initialState"))
        XCTAssertTrue(todoBoardSource.contains("TodoBoardDefaultGroupCreationPolicy.shouldCreateDefaultGroup"))
        XCTAssertTrue(todoBoardSource.contains("trigger: .addTask"))
        XCTAssertTrue(todoBoardSource.contains("trigger: .deleteGroupFallback"))
        XCTAssertFalse(todoBoardSource.contains("ensureDefaultGroup()"))
    }

    func testPinnedSidebarSectionsExpandAndRouteToListsAndResourcePreview() throws {
        XCTAssertEqual(
            PinnedSidebarNavigationPolicy.sectionSelection(for: .folders),
            .pinnedFolders
        )
        XCTAssertEqual(
            PinnedSidebarNavigationPolicy.sectionSelection(for: .files),
            .pinnedFiles
        )
        XCTAssertEqual(
            PinnedSidebarNavigationPolicy.resourceSelection(resourceID: "resource-a"),
            .resource("resource-a")
        )

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(contentViewSource.contains("DisclosureGroup(isExpanded: $pinnedFoldersExpanded)"))
        XCTAssertTrue(contentViewSource.contains("DisclosureGroup(isExpanded: $pinnedFilesExpanded)"))
        XCTAssertTrue(contentViewSource.contains("selection = PinnedSidebarNavigationPolicy.sectionSelection(for: .folders)"))
        XCTAssertTrue(contentViewSource.contains("selection = PinnedSidebarNavigationPolicy.sectionSelection(for: .files)"))
        XCTAssertTrue(contentViewSource.contains(".tag(PinnedSidebarNavigationPolicy.resourceSelection(resourceID: resource.id))"))
        XCTAssertTrue(contentViewSource.contains("case .pinnedFolders:"))
        XCTAssertTrue(contentViewSource.contains("title: \"Pinned Folders\""))
        XCTAssertTrue(contentViewSource.contains("case .pinnedFiles:"))
        XCTAssertTrue(contentViewSource.contains("title: \"Pinned Files\""))
        XCTAssertTrue(contentViewSource.contains("case .resource(let id):"))
        XCTAssertTrue(contentViewSource.contains("ResourcePreviewView("))
    }

    func testWorkspaceSidebarSelectionPolicyKeepsSelectionStableAfterDeletion() {
        XCTAssertEqual(
            WorkspaceSidebarSelectionPolicy.selectionAfterDeletingWorkspace(
                currentSelection: .home,
                deletedWorkspaceID: "workspace-a",
                orderedWorkspaceIDs: ["workspace-b", "workspace-c"]
            ),
            .home
        )
        XCTAssertEqual(
            WorkspaceSidebarSelectionPolicy.selectionAfterDeletingWorkspace(
                currentSelection: .workspace("workspace-b"),
                deletedWorkspaceID: "workspace-a",
                orderedWorkspaceIDs: ["workspace-b", "workspace-c"]
            ),
            .workspace("workspace-b")
        )
        XCTAssertEqual(
            WorkspaceSidebarSelectionPolicy.selectionAfterDeletingWorkspace(
                currentSelection: .workspace("workspace-a"),
                deletedWorkspaceID: "workspace-a",
                orderedWorkspaceIDs: ["workspace-a", "workspace-b", "workspace-c"]
            ),
            .workspace("workspace-b")
        )
        XCTAssertEqual(
            WorkspaceSidebarSelectionPolicy.selectionAfterDeletingWorkspace(
                currentSelection: .workspace("workspace-a"),
                deletedWorkspaceID: "workspace-a",
                orderedWorkspaceIDs: ["workspace-a"]
            ),
            .home
        )
    }

    func testWorkspaceContextMenuPresentationUsesMetadataOnlyActions() throws {
        XCTAssertEqual(
            WorkspaceContextMenuPresentationPolicy.menuTitles(isPinned: false),
            ["Rename", "Pin to Top", "Move Up", "Move Down", "Delete MindDesk Metadata"]
        )
        XCTAssertEqual(
            WorkspaceContextMenuPresentationPolicy.menuTitles(isPinned: true),
            ["Rename", "Unpin from Top", "Move Up", "Move Down", "Delete MindDesk Metadata"]
        )

        for title in WorkspaceContextMenuPresentationPolicy.menuTitles(isPinned: false) {
            XCTAssertFalse(title.localizedCaseInsensitiveContains("finder"), "Workspace menu action should stay metadata-scoped: \(title)")
            XCTAssertFalse(title.localizedCaseInsensitiveContains("trash"), "Workspace menu action should not imply Finder deletion: \(title)")
            XCTAssertFalse(title.localizedCaseInsensitiveContains("disk"), "Workspace menu action should not imply disk deletion: \(title)")
        }

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(contentViewSource.contains("WorkspaceRenameSheet(workspace: workspace)"))
        XCTAssertTrue(contentViewSource.contains("saveWorkspaceRename(workspace)"))
        XCTAssertTrue(contentViewSource.contains(".alert(\"Delete workspace metadata?\""))
        XCTAssertTrue(contentViewSource.contains("modelContext.delete(workspace)"))
        XCTAssertTrue(contentViewSource.contains("Button(WorkspaceContextMenuPresentationPolicy.deleteMetadataTitle, role: .destructive)"))
    }

    func testWorkspaceDeletionImpactMessageNamesMetadataCleanupAndFinderSafety() {
        let plan = WorkspaceDeletionPlan(
            nodeIds: ["node-a", "node-b"],
            edgeIds: ["edge-a"],
            snippetIdsClearingWorkingDirectory: ["snippet-a"]
        )
        let message = WorkspaceDeletionImpactMessagePolicy.message(
            workspaceTitle: "Research",
            workspacePinCount: 2,
            workspaceSnippetCount: 1,
            canvasMapCount: 3,
            deletionPlan: plan,
            aliasRecordCount: 4,
            todoGroupCount: 5,
            todoCount: 6
        )

        for required in [
            "Research",
            "MindDesk metadata only",
            "Workspace pins: 2",
            "Workspace snippets: 1",
            "Canvas maps: 3",
            "Canvas cards/references: 2",
            "Links: 1",
            "Command working directories cleared: 1",
            "Alias records marked missing: 4",
            "Todo groups/tasks: 5/6",
            "Finder items affected: 0"
        ] {
            XCTAssertTrue(message.contains(required), "Missing workspace deletion warning term: \(required)")
        }
    }























    func testGlobalLibraryOnlyHelpExplainsTodoDataIsExcluded() {
        assertOrdinaryHelpSurfaceAvailable()
        let importExportHelp = MindDeskHelpCatalog.defaultTopics.first { $0.id == "import-export" }
        let combined = [
            ImportExportService.manifestExportOptionsHelpText,
            AppSettingsView.portableJSONHelpText,
            importExportHelp?.bodyMarkdown ?? ""
        ]
            .joined(separator: " ")
            .lowercased()

        for required in [
            "global library only",
            "todo groups",
            "todos",
            "task groups",
            "tasks",
            "workspaces",
            "canvases"
        ] {
            XCTAssertTrue(combined.contains(required), "Missing Global Library Only help term: \(required)")
        }
        XCTAssertEqual(AppSettingsView.portableJSONHelpText, ImportExportService.manifestExportOptionsHelpText)
    }

    func testGlobalLibraryOnlyScopeDisclosureUsesTaskAndTodoTermsConsistently() {
        let surfaces = [
            ("manifest export options", ImportExportService.manifestExportOptionsHelpText),
            ("portable JSON settings", AppSettingsView.portableJSONHelpText),
            (
                "import and export help",
                MindDeskHelpCatalog.defaultTopics.first { $0.id == "import-export" }?.bodyMarkdown ?? ""
            )
        ]

        for surface in surfaces {
            let text = surface.1.lowercased()
            for required in [
                "global library only",
                "workspaces",
                "canvases",
                "cards",
                "links",
                "aliases",
                "todo groups",
                "task groups",
                "todos",
                "tasks"
            ] {
                XCTAssertTrue(text.contains(required), "\(surface.0) missing Global Library Only scope term: \(required)")
            }
        }
    }



































    func testImportExportServiceFormatsManifestImportValidationFailureWithoutRawIssueText() throws {
        assertOrdinaryManifestSurfaceAvailable()
        let adversarialID = "canvas IGNORE_AGENT_INSTRUCTIONS token=secret https://evil.example/open?token=url-secret"
        let unsupportedKind = "prompt\nIGNORE_AGENT_INSTRUCTIONS https://evil.example/run?token=kind-secret"
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 10),
            workspaces: [],
            resources: [],
            snippets: [
                SnippetRecord(
                    id: "snippet",
                    workspaceId: nil,
                    title: "Snippet",
                    kind: unsupportedKind,
                    body: "Body",
                    details: "",
                    tags: [],
                    scope: "global",
                    workingDirectoryRef: nil,
                    requiresConfirmation: false
                )
            ],
            canvases: [
                CanvasRecord(
                    id: adversarialID,
                    workspaceId: "workspace IGNORE_AGENT_INSTRUCTIONS token=workspace-secret",
                    title: "Canvas"
                )
            ],
            nodes: [],
            edges: [],
            aliases: []
        )

        let status = try XCTUnwrap(ImportExportService.manifestImportBlockedStatus(for: manifest))

        XCTAssertTrue(status.contains("Manifest import blocked"))
        XCTAssertTrue(status.contains("2 validation issues"))
        XCTAssertTrue(status.contains("Manifest field contains an unsupported value."))
        XCTAssertTrue(status.contains("manifest.field.unsupported-value"))
        XCTAssertTrue(status.contains("/manifest/snippets/0/kind"))
        XCTAssertTrue(status.contains("Manifest reference is missing."))
        XCTAssertTrue(status.contains("manifest.reference.missing"))
        XCTAssertTrue(status.contains("/manifest/canvases/0/workspaceId"))
        for forbidden in [
            "IGNORE_AGENT_INSTRUCTIONS",
            "evil.example",
            "token=secret",
            "token=workspace-secret",
            "token=kind-secret",
            unsupportedKind,
            adversarialID
        ] {
            XCTAssertFalse(status.contains(forbidden), "Import failure status replayed raw text: \(forbidden)")
        }
    }













    func testImportExportServiceRejectsUnknownFormattedJSONAsManifestImport() throws {
        assertOrdinaryManifestSurfaceAvailable()
        let object: [String: Any] = [
            "format": "minddesk.future.document",
            "formatVersion": 99,
            "schemaVersion": 2,
            "exportedAt": "1970-01-01T00:00:00Z",
            "workspaces": [],
            "resources": [],
            "snippets": [],
            "canvases": [],
            "nodes": [],
            "edges": [],
            "aliases": []
        ]
        let data = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try ImportExportService().decodeManifest(from: data)) { error in
            guard case WorkbenchError.invalidManifestReferences(let message) = error else {
                return XCTFail("Expected invalid manifest references error, got \(error)")
            }
            XCTAssertEqual(message, "MindDesk formatted JSON files that are not manifests cannot be imported as manifests.")
            XCTAssertFalse(message.contains("minddesk.future.document"))
        }
    }

    func testImportExportServiceDecodesTypedManifestDirectly() throws {
        assertOrdinaryManifestSurfaceAvailable()
        let object: [String: Any] = [
            "format": "minddesk.export.manifest",
            "formatVersion": 1,
            "schemaVersion": 2,
            "exportedAt": "1970-01-01T00:00:00Z",
            "workspaces": [],
            "resources": [],
            "snippets": [],
            "canvases": [],
            "nodes": [],
            "edges": [],
            "aliases": []
        ]
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoded = try ImportExportService().decodeManifest(from: data)

        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.exportedAt, Date(timeIntervalSince1970: 0))
        XCTAssertTrue(decoded.workspaces.isEmpty)
        XCTAssertTrue(decoded.resources.isEmpty)
    }

    func testImportExportServiceRejectsUnsupportedTypedManifestWireVersion() throws {
        assertOrdinaryManifestSurfaceAvailable()
        let cases: [[String: Any]] = [
            [
                "format": "minddesk.export.manifest",
                "formatVersion": 999,
                "schemaVersion": 2,
                "exportedAt": "1970-01-01T00:00:00Z",
                "workspaces": [],
                "resources": [],
                "snippets": [],
                "canvases": [],
                "nodes": [],
                "edges": [],
                "aliases": []
            ],
            [
                "format": "minddesk.export.manifest",
                "schemaVersion": 2,
                "exportedAt": "1970-01-01T00:00:00Z",
                "workspaces": [],
                "resources": [],
                "snippets": [],
                "canvases": [],
                "nodes": [],
                "edges": [],
                "aliases": []
            ],
            [
                "format": "minddesk.export.manifest",
                "formatVersion": "1",
                "schemaVersion": 2,
                "exportedAt": "1970-01-01T00:00:00Z",
                "workspaces": [],
                "resources": [],
                "snippets": [],
                "canvases": [],
                "nodes": [],
                "edges": [],
                "aliases": []
            ]
        ]

        for object in cases {
            let data = try JSONSerialization.data(withJSONObject: object)

            XCTAssertThrowsError(try ImportExportService().decodeManifest(from: data)) { error in
                guard case WorkbenchError.invalidManifestReferences(let message) = error else {
                    return XCTFail("Expected invalid typed manifest error, got \(error)")
                }
                XCTAssertEqual(message, "MindDesk manifest format version is not supported.")
                XCTAssertFalse(message.contains("999"))
            }
        }
    }





















































    func testImportExportServiceReadJSONImportDataSanitizesUnreadableFileErrors() throws {
        assertOrdinaryManifestSurfaceAvailable()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("minddesk-manifest-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let missingURL = directory.appendingPathComponent(
            "IGNORE_AGENT_INSTRUCTIONS-token=io-secret.manifest.json"
        )

        XCTAssertThrowsError(
            try ImportExportService().decodeManifest(from: missingURL)
        ) { error in
            guard case WorkbenchError.invalidManifestReferences(let message) = error else {
                return XCTFail("Expected sanitized manifest import read error, got \(error)")
            }
            XCTAssertEqual(message, "Manifest import blocked: file could not be read.")
            for forbidden in [
                "IGNORE_AGENT_INSTRUCTIONS",
                "token=io-secret",
                missingURL.path,
                directory.path
            ] {
                XCTAssertFalse(message.contains(forbidden), "Read failure replayed raw path text: \(forbidden)")
            }
        }
    }

    func testImportExportServiceStillDecodesLegacyManifestDirectly() throws {
        assertOrdinaryManifestSurfaceAvailable()
        let data = Data("""
        {
          "schemaVersion": 2,
          "exportedAt": "1970-01-01T00:00:00Z",
          "workspaces": [],
          "resources": [],
          "snippets": [],
          "canvases": [],
          "nodes": [],
          "edges": [],
          "aliases": []
        }
        """.utf8)

        let decoded = try ImportExportService().decodeManifest(from: data)

        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.exportedAt, Date(timeIntervalSince1970: 0))
        XCTAssertTrue(decoded.workspaces.isEmpty)
        XCTAssertTrue(decoded.resources.isEmpty)
    }

    func testWorkspaceReentryMapperBuildsBriefFromAppModels() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let workspace = WorkspaceModel(id: "workspace-a", title: "Workspace A", updatedAt: now)
        let alphaResource = ResourcePinModel(
            id: "resource-alpha",
            workspaceId: workspace.id,
            title: "Zulu Title",
            targetType: .file,
            displayPath: "/tmp/alpha.md",
            lastResolvedPath: "/tmp/alpha.md",
            scope: .workspace,
            originalName: "Alpha.md",
            status: .missingVolume,
            updatedAt: now.addingTimeInterval(-10)
        )
        let zuluResource = ResourcePinModel(
            id: "resource-zulu",
            workspaceId: workspace.id,
            title: "Alpha Title",
            targetType: .file,
            displayPath: "/tmp/zulu.md",
            lastResolvedPath: "/tmp/zulu.md",
            scope: .workspace,
            originalName: "Zulu.md",
            status: .staleAuthorization,
            updatedAt: now.addingTimeInterval(-10)
        )
        let todo = WorkspaceTodoModel(
            id: "todo-linked-resource",
            workspaceId: workspace.id,
            title: "Review linked resource",
            isPinned: true,
            sortIndex: 4,
            updatedAt: now.addingTimeInterval(-20),
            dueAt: now.addingTimeInterval(60 * 60),
            linkedResourceId: alphaResource.id
        )
        let snippet = SnippetModel(
            id: "snippet-workspace",
            workspaceId: workspace.id,
            title: "Workspace prompt",
            kind: .prompt,
            body: "Summarize",
            scope: .workspace,
            lastCopiedAt: now.addingTimeInterval(-100),
            lastUsedAt: now.addingTimeInterval(-50),
            updatedAt: now.addingTimeInterval(-200)
        )
        let canvas = CanvasModel(
            id: "canvas-a",
            workspaceId: workspace.id,
            updatedAt: now.addingTimeInterval(-30)
        )
        let node = CanvasNodeModel(
            id: "node-a",
            canvasId: canvas.id,
            title: "Resource",
            nodeType: .resource,
            objectType: "resourcePin",
            objectId: alphaResource.id,
            x: 0,
            y: 0,
            updatedAt: now.addingTimeInterval(-25)
        )
        let edge = CanvasEdgeModel(
            id: "edge-self",
            canvasId: canvas.id,
            sourceNodeId: node.id,
            targetNodeId: node.id,
            updatedAt: now.addingTimeInterval(-15)
        )

        let brief = WorkspaceReentryBriefMapper.brief(
            for: workspace,
            resources: [zuluResource, alphaResource],
            snippets: [snippet],
            todos: [todo],
            canvases: [canvas],
            nodes: [node],
            edges: [edge],
            now: now
        )

        XCTAssertEqual(brief.workspaceId, workspace.id)
        XCTAssertEqual(brief.nextTaskIds, [todo.id])
        XCTAssertEqual(brief.resourceIssueIds, [alphaResource.id, zuluResource.id])
        XCTAssertEqual(brief.recentSnippetIds, [snippet.id])
        XCTAssertEqual(brief.canvasSummary.canvasCount, 1)
        XCTAssertEqual(brief.canvasSummary.cardCount, 1)
        XCTAssertEqual(brief.canvasSummary.validLinkCount, 1)
        XCTAssertEqual(brief.unresolvedReferenceCount, 0)
    }

    func testWorkspaceReentryMapperDoesNotLeakWorkspaceScopedPrivateRecords() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let selectedWorkspace = WorkspaceModel(id: "workspace-a", title: "Workspace A", updatedAt: now)
        let otherWorkspace = WorkspaceModel(id: "workspace-b", title: "Workspace B", updatedAt: now)
        let privateResource = ResourcePinModel(
            id: "resource-private-b",
            workspaceId: otherWorkspace.id,
            title: "Private B",
            targetType: .file,
            displayPath: "/tmp/private-b.md",
            lastResolvedPath: "/tmp/private-b.md",
            scope: .workspace,
            status: .missingVolume,
            updatedAt: now.addingTimeInterval(-10)
        )
        let privateSnippet = SnippetModel(
            id: "snippet-private-b",
            workspaceId: otherWorkspace.id,
            title: "Private B Prompt",
            kind: .prompt,
            body: "Private",
            scope: .workspace,
            lastUsedAt: now.addingTimeInterval(-20),
            updatedAt: now.addingTimeInterval(-30)
        )
        let todo = WorkspaceTodoModel(
            id: "todo-a-links-private-b",
            workspaceId: selectedWorkspace.id,
            title: "Check missing link",
            updatedAt: now.addingTimeInterval(-40),
            linkedResourceId: privateResource.id
        )
        let canvas = CanvasModel(id: "canvas-a", workspaceId: selectedWorkspace.id, updatedAt: now)
        let snippetNode = CanvasNodeModel(
            id: "node-private-snippet",
            canvasId: canvas.id,
            title: "Private snippet",
            nodeType: .snippet,
            objectType: "snippet",
            objectId: privateSnippet.id,
            x: 0,
            y: 0,
            updatedAt: now
        )

        let brief = WorkspaceReentryBriefMapper.brief(
            for: selectedWorkspace,
            resources: [privateResource],
            snippets: [privateSnippet],
            todos: [todo],
            canvases: [canvas],
            nodes: [snippetNode],
            edges: [],
            now: now
        )

        XCTAssertEqual(brief.resourceIssueIds, [])
        XCTAssertEqual(brief.resourceIssueCount, 0)
        XCTAssertEqual(brief.recentSnippetIds, [])
        XCTAssertEqual(brief.unresolvedReferenceCount, 2)
    }

    func testWorkspaceReentryMapperScopedInputsExcludeUnrelatedRecordsBeforeCoreMapping() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let selectedWorkspace = WorkspaceModel(id: "workspace-a", title: "Workspace A", updatedAt: now)
        let otherWorkspace = WorkspaceModel(id: "workspace-b", title: "Workspace B", updatedAt: now)
        let workspaceResource = ResourcePinModel(
            id: "resource-workspace-a",
            workspaceId: selectedWorkspace.id,
            title: "Workspace A Resource",
            targetType: .file,
            displayPath: "/tmp/a.md",
            lastResolvedPath: "/tmp/a.md",
            scope: .workspace,
            updatedAt: now
        )
        let linkedGlobalResource = ResourcePinModel(
            id: "resource-global-linked",
            title: "Linked Global Resource",
            targetType: .file,
            displayPath: "/tmp/global-linked.md",
            lastResolvedPath: "/tmp/global-linked.md",
            scope: .global,
            status: .missingVolume,
            updatedAt: now
        )
        let unrelatedGlobalResource = ResourcePinModel(
            id: "resource-global-unrelated",
            title: "Unrelated Global Resource",
            targetType: .file,
            displayPath: "/tmp/global-unrelated.md",
            lastResolvedPath: "/tmp/global-unrelated.md",
            scope: .global,
            status: .missingVolume,
            updatedAt: now
        )
        let otherWorkspaceResource = ResourcePinModel(
            id: "resource-workspace-b",
            workspaceId: otherWorkspace.id,
            title: "Workspace B Resource",
            targetType: .file,
            displayPath: "/tmp/b.md",
            lastResolvedPath: "/tmp/b.md",
            scope: .workspace,
            status: .missingVolume,
            updatedAt: now
        )
        let workspaceSnippet = SnippetModel(
            id: "snippet-workspace-a",
            workspaceId: selectedWorkspace.id,
            title: "Workspace A Snippet",
            kind: .prompt,
            body: "A",
            scope: .workspace,
            updatedAt: now
        )
        let linkedGlobalSnippet = SnippetModel(
            id: "snippet-global-linked",
            title: "Linked Global Snippet",
            kind: .prompt,
            body: "Global linked",
            scope: .global,
            updatedAt: now
        )
        let unrelatedGlobalSnippet = SnippetModel(
            id: "snippet-global-unrelated",
            title: "Unrelated Global Snippet",
            kind: .prompt,
            body: "Global unrelated",
            scope: .global,
            updatedAt: now
        )
        let otherWorkspaceSnippet = SnippetModel(
            id: "snippet-workspace-b",
            workspaceId: otherWorkspace.id,
            title: "Workspace B Snippet",
            kind: .prompt,
            body: "B",
            scope: .workspace,
            updatedAt: now
        )
        let selectedTodo = WorkspaceTodoModel(
            id: "todo-a",
            workspaceId: selectedWorkspace.id,
            title: "Review linked global resource",
            updatedAt: now,
            linkedResourceId: linkedGlobalResource.id
        )
        let otherTodo = WorkspaceTodoModel(
            id: "todo-b",
            workspaceId: otherWorkspace.id,
            title: "Other workspace todo",
            updatedAt: now,
            linkedResourceId: otherWorkspaceResource.id
        )
        let selectedCanvas = CanvasModel(id: "canvas-a", workspaceId: selectedWorkspace.id, updatedAt: now)
        let otherCanvas = CanvasModel(id: "canvas-b", workspaceId: otherWorkspace.id, updatedAt: now)
        let resourceNode = CanvasNodeModel(
            id: "node-resource",
            canvasId: selectedCanvas.id,
            title: "Resource",
            nodeType: .resource,
            objectType: "resourcePin",
            objectId: linkedGlobalResource.id,
            x: 0,
            y: 0,
            updatedAt: now
        )
        let snippetNode = CanvasNodeModel(
            id: "node-snippet",
            canvasId: selectedCanvas.id,
            title: "Snippet",
            nodeType: .snippet,
            objectType: "snippet",
            objectId: linkedGlobalSnippet.id,
            x: 0,
            y: 0,
            updatedAt: now
        )
        let otherNode = CanvasNodeModel(
            id: "node-other",
            canvasId: otherCanvas.id,
            title: "Other",
            nodeType: .resource,
            objectType: "resourcePin",
            objectId: otherWorkspaceResource.id,
            x: 0,
            y: 0,
            updatedAt: now
        )
        let selectedEdge = CanvasEdgeModel(
            id: "edge-a",
            canvasId: selectedCanvas.id,
            sourceNodeId: resourceNode.id,
            targetNodeId: snippetNode.id,
            updatedAt: now
        )
        let otherEdge = CanvasEdgeModel(
            id: "edge-b",
            canvasId: otherCanvas.id,
            sourceNodeId: otherNode.id,
            targetNodeId: otherNode.id,
            updatedAt: now
        )

        let stats = WorkspaceReentryBriefMapper.scopedInputStats(
            for: selectedWorkspace,
            resources: [workspaceResource, linkedGlobalResource, unrelatedGlobalResource, otherWorkspaceResource],
            snippets: [workspaceSnippet, linkedGlobalSnippet, unrelatedGlobalSnippet, otherWorkspaceSnippet],
            todos: [selectedTodo, otherTodo],
            canvases: [selectedCanvas, otherCanvas],
            nodes: [resourceNode, snippetNode, otherNode],
            edges: [selectedEdge, otherEdge]
        )

        XCTAssertEqual(stats.resourceRecordCount, 2)
        XCTAssertEqual(stats.snippetRecordCount, 2)
        XCTAssertEqual(stats.todoRecordCount, 1)
        XCTAssertEqual(stats.canvasRecordCount, 1)
        XCTAssertEqual(stats.nodeRecordCount, 2)
        XCTAssertEqual(stats.edgeRecordCount, 1)

        let brief = WorkspaceReentryBriefMapper.brief(
            for: selectedWorkspace,
            resources: [workspaceResource, linkedGlobalResource, unrelatedGlobalResource, otherWorkspaceResource],
            snippets: [workspaceSnippet, linkedGlobalSnippet, unrelatedGlobalSnippet, otherWorkspaceSnippet],
            todos: [selectedTodo, otherTodo],
            canvases: [selectedCanvas, otherCanvas],
            nodes: [resourceNode, snippetNode, otherNode],
            edges: [selectedEdge, otherEdge],
            now: now
        )

        XCTAssertEqual(brief.resourceIssueIds, [linkedGlobalResource.id])
        XCTAssertEqual(Set(brief.recentSnippetIds), [workspaceSnippet.id, linkedGlobalSnippet.id])
        XCTAssertEqual(brief.nextTaskIds, [selectedTodo.id])
        XCTAssertEqual(brief.canvasSummary.cardCount, 2)
    }

    func testWorkspaceReentryMapperLargeScopedInputsSkipCanvasReferenceDetailCollection() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let workspace = WorkspaceModel(id: "workspace-a", title: "Workspace A", updatedAt: now)
        let workspaceResource = ResourcePinModel(
            id: "resource-workspace-a",
            workspaceId: workspace.id,
            title: "Workspace A Resource",
            targetType: .file,
            displayPath: "/tmp/a.md",
            lastResolvedPath: "/tmp/a.md",
            scope: .workspace,
            status: .missingVolume,
            updatedAt: now
        )
        let linkedGlobalResource = ResourcePinModel(
            id: "resource-global-todo-linked",
            title: "Todo Linked Global Resource",
            targetType: .file,
            displayPath: "/tmp/todo-linked.md",
            lastResolvedPath: "/tmp/todo-linked.md",
            scope: .global,
            status: .staleAuthorization,
            updatedAt: now
        )
        let canvasOnlyGlobalResource = ResourcePinModel(
            id: "resource-global-canvas-only",
            title: "Canvas Only Global Resource",
            targetType: .file,
            displayPath: "/tmp/canvas-only.md",
            lastResolvedPath: "/tmp/canvas-only.md",
            scope: .global,
            status: .missingVolume,
            updatedAt: now
        )
        let workspaceSnippet = SnippetModel(
            id: "snippet-workspace-a",
            workspaceId: workspace.id,
            title: "Workspace A Snippet",
            kind: .prompt,
            body: "A",
            scope: .workspace,
            updatedAt: now
        )
        let canvasOnlyGlobalSnippet = SnippetModel(
            id: "snippet-global-canvas-only",
            title: "Canvas Only Global Snippet",
            kind: .prompt,
            body: "Global",
            scope: .global,
            updatedAt: now
        )
        let todo = WorkspaceTodoModel(
            id: "todo-linked-global",
            workspaceId: workspace.id,
            title: "Review linked global resource",
            updatedAt: now,
            linkedResourceId: linkedGlobalResource.id
        )
        let canvas = CanvasModel(id: "canvas-a", workspaceId: workspace.id, updatedAt: now)
        let nodes = (0...WorkspaceReentryBriefPolicy.maximumDetailedNodeCount).map { index in
            if index == 0 {
                return CanvasNodeModel(
                    id: "node-resource",
                    canvasId: canvas.id,
                    title: "Resource",
                    nodeType: .resource,
                    objectType: "resourcePin",
                    objectId: canvasOnlyGlobalResource.id,
                    x: 0,
                    y: 0,
                    updatedAt: now
                )
            }
            if index == 1 {
                return CanvasNodeModel(
                    id: "node-snippet",
                    canvasId: canvas.id,
                    title: "Snippet",
                    nodeType: .snippet,
                    objectType: "snippet",
                    objectId: canvasOnlyGlobalSnippet.id,
                    x: 0,
                    y: 0,
                    updatedAt: now
                )
            }
            return CanvasNodeModel(
                id: "node-\(index)",
                canvasId: canvas.id,
                title: "Node \(index)",
                nodeType: .note,
                objectType: nil,
                objectId: nil,
                x: 0,
                y: 0,
                updatedAt: now
            )
        }

        let stats = WorkspaceReentryBriefMapper.scopedInputStats(
            for: workspace,
            resources: [workspaceResource, linkedGlobalResource, canvasOnlyGlobalResource],
            snippets: [workspaceSnippet, canvasOnlyGlobalSnippet],
            todos: [todo],
            canvases: [canvas],
            nodes: nodes,
            edges: []
        )

        XCTAssertEqual(stats.nodeRecordCount, WorkspaceReentryBriefPolicy.maximumDetailedNodeCount + 1)
        XCTAssertEqual(stats.resourceRecordCount, 2)
        XCTAssertEqual(stats.snippetRecordCount, 1)

        let brief = WorkspaceReentryBriefMapper.brief(
            for: workspace,
            resources: [workspaceResource, linkedGlobalResource, canvasOnlyGlobalResource],
            snippets: [workspaceSnippet, canvasOnlyGlobalSnippet],
            todos: [todo],
            canvases: [canvas],
            nodes: nodes,
            edges: [],
            now: now
        )

        XCTAssertTrue(brief.isLargeDataDegraded)
        XCTAssertEqual(brief.resourceIssueCount, 2)
        XCTAssertTrue(brief.recentSnippetIds.isEmpty)
        XCTAssertEqual(brief.canvasSummary.cardCount, WorkspaceReentryBriefPolicy.maximumDetailedNodeCount + 1)
    }

    func testWorkspaceReentryMapperBriefsByWorkspaceIDCapsToFirstSixWorkspaces() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let workspaces = (1...7).map { index in
            WorkspaceModel(id: "workspace-\(index)", title: "Workspace \(index)", updatedAt: now)
        }
        let cappedTodo = WorkspaceTodoModel(
            id: "todo-six",
            workspaceId: "workspace-6",
            title: "Visible capped todo",
            updatedAt: now
        )
        let omittedTodo = WorkspaceTodoModel(
            id: "todo-seven",
            workspaceId: "workspace-7",
            title: "Omitted seventh todo",
            updatedAt: now
        )

        let briefs = WorkspaceReentryBriefMapper.briefsByWorkspaceID(
            workspaces: workspaces,
            resources: [],
            snippets: [],
            todos: [cappedTodo, omittedTodo],
            canvases: [],
            nodes: [],
            edges: [],
            now: now
        )

        XCTAssertEqual(Set(briefs.keys), Set(workspaces.prefix(6).map(\.id)))
        XCTAssertNil(briefs["workspace-7"])
        XCTAssertEqual(briefs["workspace-6"]?.nextTaskIds, [cappedTodo.id])
    }

    func testWorkspaceReentryMapperBulkScopedInputsCapThenGroupRelevantRecords() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let workspaces = (1...7).map { index in
            WorkspaceModel(id: "workspace-\(index)", title: "Workspace \(index)", updatedAt: now)
        }
        let workspaceOneResource = ResourcePinModel(
            id: "resource-workspace-1",
            workspaceId: "workspace-1",
            title: "Workspace 1 Resource",
            targetType: .file,
            displayPath: "/tmp/workspace-1.md",
            lastResolvedPath: "/tmp/workspace-1.md",
            scope: .workspace,
            updatedAt: now
        )
        let workspaceSevenResource = ResourcePinModel(
            id: "resource-workspace-7",
            workspaceId: "workspace-7",
            title: "Workspace 7 Resource",
            targetType: .file,
            displayPath: "/tmp/workspace-7.md",
            lastResolvedPath: "/tmp/workspace-7.md",
            scope: .workspace,
            updatedAt: now
        )
        let linkedGlobalResource = ResourcePinModel(
            id: "resource-global-linked-1",
            title: "Linked Global Resource",
            targetType: .file,
            displayPath: "/tmp/global-linked-1.md",
            lastResolvedPath: "/tmp/global-linked-1.md",
            scope: .global,
            updatedAt: now
        )
        let unrelatedGlobalResource = ResourcePinModel(
            id: "resource-global-unrelated",
            title: "Unrelated Global Resource",
            targetType: .file,
            displayPath: "/tmp/global-unrelated.md",
            lastResolvedPath: "/tmp/global-unrelated.md",
            scope: .global,
            updatedAt: now
        )
        let linkedTodo = WorkspaceTodoModel(
            id: "todo-workspace-1",
            workspaceId: "workspace-1",
            title: "Review linked global resource",
            updatedAt: now,
            linkedResourceId: linkedGlobalResource.id
        )
        let omittedTodo = WorkspaceTodoModel(
            id: "todo-workspace-7",
            workspaceId: "workspace-7",
            title: "Omitted workspace todo",
            updatedAt: now,
            linkedResourceId: workspaceSevenResource.id
        )

        let statsByWorkspaceID = WorkspaceReentryBriefMapper.scopedInputStatsByWorkspaceID(
            workspaces: workspaces,
            resources: [
                workspaceOneResource,
                workspaceSevenResource,
                linkedGlobalResource,
                unrelatedGlobalResource
            ],
            snippets: [],
            todos: [linkedTodo, omittedTodo],
            canvases: [],
            nodes: [],
            edges: []
        )

        XCTAssertEqual(Set(statsByWorkspaceID.keys), Set(workspaces.prefix(6).map(\.id)))
        XCTAssertNil(statsByWorkspaceID["workspace-7"])
        XCTAssertEqual(statsByWorkspaceID["workspace-1"]?.resourceRecordCount, 2)
        XCTAssertEqual(statsByWorkspaceID["workspace-1"]?.todoRecordCount, 1)
        XCTAssertEqual(statsByWorkspaceID["workspace-2"]?.resourceRecordCount, 0)

        let bulkBriefs = WorkspaceReentryBriefMapper.briefsByWorkspaceID(
            workspaces: workspaces,
            resources: [
                workspaceOneResource,
                workspaceSevenResource,
                linkedGlobalResource,
                unrelatedGlobalResource
            ],
            snippets: [],
            todos: [linkedTodo, omittedTodo],
            canvases: [],
            nodes: [],
            edges: [],
            now: now
        )
        let singleBrief = WorkspaceReentryBriefMapper.brief(
            for: workspaces[0],
            resources: [
                workspaceOneResource,
                workspaceSevenResource,
                linkedGlobalResource,
                unrelatedGlobalResource
            ],
            snippets: [],
            todos: [linkedTodo, omittedTodo],
            canvases: [],
            nodes: [],
            edges: [],
            now: now
        )

        XCTAssertEqual(bulkBriefs["workspace-1"], singleBrief)
    }

    func testWorkspaceResourceDisplayIncludesWorkspaceOwnedAndUsedGlobalResources() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let workspaceID = "workspace-a"
        let workspaceResource = ResourcePinModel(
            id: "workspace-resource",
            workspaceId: workspaceID,
            title: "Workspace Resource",
            targetType: .file,
            displayPath: "/tmp/workspace.md",
            lastResolvedPath: "/tmp/workspace.md",
            scope: .workspace,
            updatedAt: now
        )
        let globalCanvasResource = ResourcePinModel(
            id: "global-canvas",
            title: "Global Canvas",
            targetType: .folder,
            displayPath: "/tmp/global-canvas",
            lastResolvedPath: "/tmp/global-canvas",
            scope: .global,
            updatedAt: now
        )
        let globalTaskResource = ResourcePinModel(
            id: "global-task",
            title: "Global Task",
            targetType: .file,
            displayPath: "/tmp/global-task.md",
            lastResolvedPath: "/tmp/global-task.md",
            scope: .global,
            updatedAt: now
        )
        let unusedGlobalResource = ResourcePinModel(
            id: "unused-global",
            title: "Unused Global",
            targetType: .file,
            displayPath: "/tmp/unused.md",
            lastResolvedPath: "/tmp/unused.md",
            scope: .global,
            updatedAt: now
        )
        let privateOtherResource = ResourcePinModel(
            id: "private-other",
            workspaceId: "workspace-b",
            title: "Other Workspace",
            targetType: .file,
            displayPath: "/tmp/private.md",
            lastResolvedPath: "/tmp/private.md",
            scope: .workspace,
            updatedAt: now
        )
        let canvas = CanvasModel(id: "canvas-a", workspaceId: workspaceID, updatedAt: now)
        let otherCanvas = CanvasModel(id: "canvas-b", workspaceId: "workspace-b", updatedAt: now)
        let canvasNode = CanvasNodeModel(
            id: "node-global-canvas",
            canvasId: canvas.id,
            title: "Global Canvas",
            nodeType: .resource,
            objectType: "resourcePin",
            objectId: globalCanvasResource.id,
            x: 0,
            y: 0,
            updatedAt: now
        )
        let otherNode = CanvasNodeModel(
            id: "node-other-global",
            canvasId: otherCanvas.id,
            title: "Other Global",
            nodeType: .resource,
            objectType: "resourcePin",
            objectId: unusedGlobalResource.id,
            x: 0,
            y: 0,
            updatedAt: now
        )
        let linkedTodo = WorkspaceTodoModel(
            id: "todo-global-task",
            workspaceId: workspaceID,
            title: "Review global resource",
            updatedAt: now,
            linkedResourceId: globalTaskResource.id
        )

        let displayedResources = WorkspaceResourceDisplayPolicy.resources(
            forWorkspaceID: workspaceID,
            resources: [
                unusedGlobalResource,
                globalTaskResource,
                privateOtherResource,
                globalCanvasResource,
                workspaceResource
            ],
            todos: [linkedTodo],
            canvases: [canvas, otherCanvas],
            nodes: [canvasNode, otherNode]
        )

        XCTAssertEqual(
            Set(displayedResources.map(\.id)),
            Set([workspaceResource.id, globalCanvasResource.id, globalTaskResource.id])
        )
    }

    func testWorkspaceResourceDisplayDoesNotLeakOtherWorkspaceOrUnknownScopeResources() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let workspaceID = "workspace-a"
        let workspaceResource = ResourcePinModel(
            id: "workspace-resource",
            workspaceId: workspaceID,
            title: "Workspace Resource",
            targetType: .file,
            displayPath: "/tmp/workspace.md",
            lastResolvedPath: "/tmp/workspace.md",
            scope: .workspace,
            updatedAt: now
        )
        let privateOtherResource = ResourcePinModel(
            id: "private-other",
            workspaceId: "workspace-b",
            title: "Other Workspace",
            targetType: .file,
            displayPath: "/tmp/private.md",
            lastResolvedPath: "/tmp/private.md",
            scope: .workspace,
            updatedAt: now
        )
        let unknownScopeResource = ResourcePinModel(
            id: "unknown-scope",
            title: "Unknown Scope",
            targetType: .file,
            displayPath: "/tmp/unknown.md",
            lastResolvedPath: "/tmp/unknown.md",
            scope: .global,
            updatedAt: now
        )
        unknownScopeResource.scopeRaw = "shared"
        let canvas = CanvasModel(id: "canvas-a", workspaceId: workspaceID, updatedAt: now)
        let privateNode = CanvasNodeModel(
            id: "node-private",
            canvasId: canvas.id,
            title: "Private",
            nodeType: .resource,
            objectType: "resourcePin",
            objectId: privateOtherResource.id,
            x: 0,
            y: 0,
            updatedAt: now
        )
        let unknownNode = CanvasNodeModel(
            id: "node-unknown",
            canvasId: canvas.id,
            title: "Unknown",
            nodeType: .resource,
            objectType: "resourcePin",
            objectId: unknownScopeResource.id,
            x: 0,
            y: 0,
            updatedAt: now
        )
        let privateLinkedTodo = WorkspaceTodoModel(
            id: "todo-private",
            workspaceId: workspaceID,
            title: "Check private link",
            updatedAt: now,
            linkedResourceId: privateOtherResource.id
        )
        let unknownLinkedTodo = WorkspaceTodoModel(
            id: "todo-unknown",
            workspaceId: workspaceID,
            title: "Check unknown link",
            updatedAt: now,
            linkedResourceId: unknownScopeResource.id
        )

        let displayedResources = WorkspaceResourceDisplayPolicy.resources(
            forWorkspaceID: workspaceID,
            resources: [privateOtherResource, unknownScopeResource, workspaceResource],
            todos: [privateLinkedTodo, unknownLinkedTodo],
            canvases: [canvas],
            nodes: [privateNode, unknownNode]
        )

        XCTAssertEqual(displayedResources.map(\.id), [workspaceResource.id])
    }

    func testWorkspaceResourceRemovalPolicyAllowsOnlyWorkspaceScopedRows() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let workspaceResource = ResourcePinModel(
            id: "workspace-resource",
            workspaceId: "workspace-a",
            title: "Workspace Resource",
            targetType: .file,
            displayPath: "/tmp/workspace.md",
            lastResolvedPath: "/tmp/workspace.md",
            scope: .workspace,
            updatedAt: now
        )
        let globalResource = ResourcePinModel(
            id: "global-resource",
            title: "Global Resource",
            targetType: .file,
            displayPath: "/tmp/global.md",
            lastResolvedPath: "/tmp/global.md",
            scope: .global,
            updatedAt: now
        )
        let unknownScopeResource = ResourcePinModel(
            id: "unknown-resource",
            title: "Unknown Resource",
            targetType: .file,
            displayPath: "/tmp/unknown.md",
            lastResolvedPath: "/tmp/unknown.md",
            scope: .workspace,
            updatedAt: now
        )
        unknownScopeResource.scopeRaw = "shared"

        XCTAssertTrue(WorkspaceResourceRemovalPolicy.canRemoveFromWorkspaceResources(workspaceResource))
        XCTAssertFalse(WorkspaceResourceRemovalPolicy.canRemoveFromWorkspaceResources(globalResource))
        XCTAssertFalse(WorkspaceResourceRemovalPolicy.canRemoveFromWorkspaceResources(unknownScopeResource))
        XCTAssertTrue(
            WorkspaceResourceRemovalPolicy.blockedStatus(for: globalResource).contains("Global Library")
        )
    }

    func testResourceRemovalImpactMessageListsAllCleanupPlanEffects() {
        let cleanup = CleanupPlan(
            canvasNodeIdsToDelete: ["node-a", "node-b"],
            canvasEdgeIdsToDelete: ["edge-a"],
            todoIdsClearingLinkedResource: ["todo-a", "todo-b", "todo-c"],
            snippetIdsClearingWorkingDirectory: ["snippet-a"],
            aliasIdsMarkingMissing: ["alias-a", "alias-b"]
        )
        let message = ResourceRemovalImpactMessage.text(displayName: "Project Docs", cleanup: cleanup)

        XCTAssertEqual(message, expectedResourceRemovalMessage(displayName: "Project Docs", cleanup: cleanup))
    }

    func testResourceRemovalRequestSnapshotsCleanupAndMessage() {
        let resource = ResourcePinModel(
            id: "resource",
            title: "Docs",
            targetType: .folder,
            displayPath: "/tmp/Docs",
            lastResolvedPath: "/tmp/Docs",
            scope: .global,
            customName: "Project Docs"
        )
        let cleanup = CleanupPlan(
            canvasNodeIdsToDelete: ["node"],
            canvasEdgeIdsToDelete: ["edge"],
            todoIdsClearingLinkedResource: ["todo"],
            snippetIdsClearingWorkingDirectory: ["snippet"],
            aliasIdsMarkingMissing: ["alias"]
        )
        let displayName = resource.displayName

        let request = ResourceRemovalRequest(resource: resource, cleanup: cleanup)
        resource.customName = "Renamed After Alert"

        XCTAssertEqual(request.id, "resource")
        XCTAssertEqual(request.displayName, displayName)
        XCTAssertEqual(request.cleanup, cleanup)
        XCTAssertEqual(request.message, expectedResourceRemovalMessage(displayName: displayName, cleanup: cleanup))
    }

    func testWorkspaceDetailTabDefaultsToCanvasAndFollowsWorkspaceOpenPreference() {
        assertOrdinaryWorkspaceSurfaceAvailable()
        XCTAssertEqual(WorkspaceDetailTab.defaultTab, .canvas)
        XCTAssertEqual(WorkspaceDetailTab.defaultTab(for: AppWorkspaceOpenDestination.canvas.rawValue), .canvas)
        XCTAssertEqual(WorkspaceDetailTab.defaultTab(for: AppWorkspaceOpenDestination.overview.rawValue), .overview)
        XCTAssertEqual(WorkspaceDetailTab.defaultTab(for: AppWorkspaceOpenDestination.tasks.rawValue), .tasks)
        XCTAssertEqual(WorkspaceDetailTab.defaultTab(for: AppWorkspaceOpenDestination.resources.rawValue), .resources)
        XCTAssertEqual(WorkspaceDetailTab.defaultTab(for: AppWorkspaceOpenDestination.snippets.rawValue), .snippets)
        XCTAssertEqual(WorkspaceDetailTab.defaultTab(for: "missing"), .canvas)
        XCTAssertEqual(WorkspaceDetailTab.allCases.map(\.title), ["Overview", "Tasks", "Canvas", "Resources", "Snippets"])
        XCTAssertEqual(WorkspaceDetailTab.tabAfterWorkspaceChange(from: .overview, openDestinationRaw: AppWorkspaceOpenDestination.canvas.rawValue), .canvas)
        XCTAssertEqual(WorkspaceDetailTab.tabAfterWorkspaceChange(from: .canvas, openDestinationRaw: AppWorkspaceOpenDestination.overview.rawValue), .overview)
        XCTAssertFalse(WorkspaceDetailTab.overview.activatesCanvas)
        XCTAssertFalse(WorkspaceDetailTab.tasks.activatesCanvas)
        XCTAssertTrue(WorkspaceDetailTab.canvas.activatesCanvas)
    }

    func testWorkspaceOverviewRouteRendersCurrentOverviewWhenCanvasIsUnavailable() throws {
        XCTAssertFalse(WorkspaceDetailTab.overview.activatesCanvas)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )
        let overviewStart = try XCTUnwrap(contentViewSource.range(of: "            case .overview:"))
        let tasksStart = try XCTUnwrap(
            contentViewSource.range(of: "            case .tasks:", range: overviewStart.upperBound..<contentViewSource.endIndex)
        )
        let canvasStart = try XCTUnwrap(
            contentViewSource.range(of: "            case .canvas:", range: tasksStart.upperBound..<contentViewSource.endIndex)
        )
        let overviewRoute = String(contentViewSource[overviewStart.lowerBound..<tasksStart.lowerBound])
        let canvasRoute = String(contentViewSource[canvasStart.lowerBound...])

        XCTAssertTrue(overviewRoute.contains("WorkspaceResumeBriefView("))
        XCTAssertFalse(overviewRoute.contains("primaryCanvasAvailability"))
        XCTAssertFalse(overviewRoute.contains("primaryCanvasUnavailableView"))
        XCTAssertTrue(canvasRoute.contains("primaryCanvasUnavailableView"))
    }

    func testWorkspaceTodoBoardPresentationSeparatesCanvasPanelFromFullHeightTab() {
        XCTAssertTrue(WorkspaceTodoBoardPresentation.canvasPanel.usesFixedHeight)
        XCTAssertTrue(WorkspaceTodoBoardPresentation.canvasPanel.showsCollapseControl)
        XCTAssertTrue(WorkspaceTodoBoardPresentation.canvasPanel.usesPanelChrome)

        XCTAssertFalse(WorkspaceTodoBoardPresentation.fullHeightTab.usesFixedHeight)
        XCTAssertFalse(WorkspaceTodoBoardPresentation.fullHeightTab.showsCollapseControl)
        XCTAssertFalse(WorkspaceTodoBoardPresentation.fullHeightTab.usesPanelChrome)
    }

    private func expectedResourceRemovalMessage(displayName: String, cleanup: CleanupPlan) -> String {
        """
        This removes \(displayName) from MindDesk metadata only.

        Canvas cards removed: \(cleanup.canvasNodeIdsToDelete.count)
        Canvas links removed: \(cleanup.canvasEdgeIdsToDelete.count)
        Todo linked resources cleared: \(cleanup.todoIdsClearingLinkedResource.count)
        Command working directories cleared: \(cleanup.snippetIdsClearingWorkingDirectory.count)
        Alias records marked missing: \(cleanup.aliasIdsMarkingMissing.count)
        Finder items affected: 0
        """
    }

    func testResourceListOrderingUsesIDTieBreakForStableRows() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let beta = ResourcePinModel(
            id: "resource-b",
            title: "Plan",
            targetType: .file,
            displayPath: "/tmp/plan-b.md",
            lastResolvedPath: "/tmp/plan-b.md",
            scope: .workspace,
            updatedAt: now
        )
        let alpha = ResourcePinModel(
            id: "resource-a",
            title: "Plan",
            targetType: .file,
            displayPath: "/tmp/plan-a.md",
            lastResolvedPath: "/tmp/plan-a.md",
            scope: .workspace,
            updatedAt: now
        )
        beta.sortIndex = 7
        alpha.sortIndex = 7

        XCTAssertEqual(
            ResourceListOrderingPolicy.ordered([beta, alpha]).map(\.id),
            [alpha.id, beta.id]
        )
    }

    func testResourceRowActionPresentationExposesCommonResourceActions() throws {
        let unpinnedPrimary = ResourceRowActionPresentationPolicy.primaryActions(isPinned: false)
        let pinnedPrimary = ResourceRowActionPresentationPolicy.primaryActions(isPinned: true)

        XCTAssertEqual(unpinnedPrimary.map(\.id), [.open, .reveal, .copyPath, .pinToggle, .details])
        XCTAssertEqual(
            unpinnedPrimary.map(\.systemImage),
            ["arrow.up.forward.app", "arrow.right.square", "doc.on.doc", "pin", "info.circle"]
        )
        XCTAssertEqual(unpinnedPrimary.map(\.helpText), ["Open", "Reveal", "Copy full path", "Pin", "Details"])
        XCTAssertEqual(pinnedPrimary.first { $0.id == .pinToggle }?.systemImage, "pin.slash")
        XCTAssertEqual(pinnedPrimary.first { $0.id == .pinToggle }?.helpText, "Unpin")

        XCTAssertEqual(
            ResourceRowActionPresentationPolicy.moreMenuTitles(canRemove: true),
            ["Rename in MindDesk", "Create Finder Alias", "Reauthorize", "Remove from MindDesk"]
        )
        XCTAssertEqual(
            ResourceRowActionPresentationPolicy.contextMenuTitles(isPinned: false, canRemove: true),
            [
                "Open in Finder",
                "Reveal in Finder",
                "Copy Full Path",
                "Pin",
                "Details",
                "Rename in MindDesk",
                "Create Finder Alias",
                "Reauthorize",
                "Remove from MindDesk"
            ]
        )
        XCTAssertEqual(
            ResourceRowActionPresentationPolicy.contextMenuTitles(isPinned: true, canRemove: false),
            [
                "Open in Finder",
                "Reveal in Finder",
                "Copy Full Path",
                "Unpin",
                "Details",
                "Rename in MindDesk",
                "Create Finder Alias",
                "Reauthorize"
            ]
        )

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourceViewsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ResourceSnippetViews.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(resourceViewsSource.contains("ResourceRowActionPresentationPolicy.primaryActions(isPinned: resource.isPinned)"))
        XCTAssertTrue(resourceViewsSource.contains("ResourceRowActionPresentationPolicy.moreMenuActions(canRemove: canRemove)"))
        XCTAssertTrue(resourceViewsSource.contains("ResourceRowActionPresentationPolicy.contextMenuActions(isPinned: resource.isPinned, canRemove: canRemove)"))
    }

    func testSnippetCreationPresentationExposesPromptAndCommandEntrypoints() {
        let actions = SnippetCreationPresentationPolicy.creationActions

        XCTAssertEqual(actions.map(\.id), [.prompt, .command])
        XCTAssertEqual(actions.map(\.title), ["New Prompt", "New Command"])
        XCTAssertEqual(actions.map(\.systemImage), ["text.quote", "terminal"])
        XCTAssertEqual(actions.map(\.helpText), ["Create prompt snippet", "Create command snippet"])
        XCTAssertEqual(SnippetCreationPresentationPolicy.initialKind(for: .prompt), .prompt)
        XCTAssertEqual(SnippetCreationPresentationPolicy.initialKind(for: .command), .command)
    }

    func testSnippetActionPresentationExposesCopyEditAndDeleteManagementActions() throws {
        let actions = SnippetActionPresentationPolicy.managementActions

        XCTAssertEqual(actions.map(\.id), [.copy, .edit, .delete])
        XCTAssertEqual(actions.map(\.title), ["Copy", "Edit", "Delete Snippet"])
        XCTAssertEqual(actions.map(\.systemImage), ["doc.on.doc", "pencil", "trash"])
        XCTAssertEqual(actions.map(\.helpText), ["Copy snippet", "Edit snippet", "Delete snippet"])

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourceViewsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ResourceSnippetViews.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(resourceViewsSource.contains("SnippetActionPresentationPolicy.managementActions"))
        XCTAssertTrue(resourceViewsSource.contains("performSnippetManagementAction(action.id)"))
    }

    func testSnippetExpansionPresentationPreservesFullBodyAndProvidesEditEntrypoint() throws {
        let longBody = "Line 1\nLine 2 with details\nLine 3 with command text"
        let editAction = SnippetExpansionPresentationPolicy.expandedEditAction

        XCTAssertEqual(SnippetExpansionPresentationPolicy.doubleClickActionID, .toggleExpanded)
        XCTAssertEqual(SnippetExpansionPresentationPolicy.bodyText(for: longBody), longBody)
        XCTAssertEqual(SnippetExpansionPresentationPolicy.bodyText(for: ""), "No snippet body.")
        XCTAssertEqual(editAction.title, "Edit")
        XCTAssertEqual(editAction.systemImage, "pencil")
        XCTAssertEqual(editAction.helpText, "Edit full snippet")

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourceViewsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ResourceSnippetViews.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(resourceViewsSource.contains("performExpansionGestureAction(SnippetExpansionPresentationPolicy.doubleClickActionID)"))
        XCTAssertTrue(resourceViewsSource.contains("SnippetExpansionPresentationPolicy.bodyText(for: snippet.body)"))
        XCTAssertTrue(resourceViewsSource.contains("SnippetExpansionPresentationPolicy.expandedEditAction"))
    }

    @MainActor
    func testClipboardServiceUsesPerInstanceWriterWithoutGlobalTestOverride() throws {
        var firstWrites: [String] = []
        var secondWrites: [String] = []
        let firstService = ClipboardService(writer: { firstWrites.append($0) })
        let secondService = ClipboardService(writer: { secondWrites.append($0) })

        XCTAssertTrue(firstWrites.isEmpty)
        XCTAssertTrue(secondWrites.isEmpty)

        firstService.copy("first payload")
        XCTAssertEqual(firstWrites, ["first payload"])
        XCTAssertTrue(secondWrites.isEmpty)

        secondService.copy("second payload")
        XCTAssertEqual(firstWrites, ["first payload"])
        XCTAssertEqual(secondWrites, ["second payload"])

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let servicesSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Services/SystemServices.swift"),
            encoding: .utf8
        )
        guard let serviceStart = servicesSource.range(of: "struct ClipboardService {")?.lowerBound,
              let serviceEnd = servicesSource.range(of: "struct FinderService {", range: serviceStart..<servicesSource.endIndex)?.lowerBound else {
            return XCTFail("Could not locate ClipboardService source boundary.")
        }
        let serviceSource = String(servicesSource[serviceStart..<serviceEnd])

        XCTAssertTrue(serviceSource.contains("private let writer: @MainActor (String) -> Void"))
        XCTAssertTrue(serviceSource.contains("init(writer: @escaping @MainActor (String) -> Void)"))
        XCTAssertFalse(serviceSource.contains("static var"))
        XCTAssertFalse(serviceSource.contains("XCTest"))
        XCTAssertFalse(serviceSource.contains("ProcessInfo"))
    }

    @MainActor
    func testDirectUserResourceCopyPathWritesOnlyAfterExplicitAction() throws {
        let resource = ResourcePinModel(
            title: "Reference",
            targetType: .file,
            displayPath: "/tmp/reference.txt",
            lastResolvedPath: "/tmp/reference.txt",
            scope: .global
        )
        var writes: [String] = []
        var statuses: [String] = []
        let clipboardService = ClipboardService(writer: { writes.append($0) })
        let view = ResourceListView(
            title: "Resources",
            resources: [resource],
            knownResources: [resource],
            scope: .global,
            workspaceId: nil,
            targetFilter: nil,
            pinImported: false,
            onSelect: nil,
            onStatus: { statuses.append($0) },
            onInspect: { _ in },
            onRemove: { _ in },
            clipboardService: clipboardService
        )

        XCTAssertTrue(writes.isEmpty)
        XCTAssertTrue(statuses.isEmpty)

        view.performResourceAction(resource, action: .copy)

        XCTAssertEqual(writes, ["/tmp/reference.txt"])
        XCTAssertEqual(statuses, ["Copied path: /tmp/reference.txt"])

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )
        let resourceSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ResourceSnippetViews.swift"),
            encoding: .utf8
        )
        let canvasSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Canvas/WorkspaceCanvasView.swift"),
            encoding: .utf8
        )

        func declaration(_ source: String, from startMarker: String, to endMarker: String) throws -> String {
            let start = try XCTUnwrap(source.range(of: startMarker)?.lowerBound, "Missing declaration: \(startMarker)")
            let end = try XCTUnwrap(
                source.range(of: endMarker, range: start..<source.endIndex)?.lowerBound,
                "Missing declaration terminator: \(endMarker)"
            )
            return String(source[start..<end])
        }

        func occurrenceCount(_ needle: String, in source: String) -> Int {
            source.components(separatedBy: needle).count - 1
        }

        let ordinaryOwners = try [
            declaration(contentSource, from: "func copySnippet(_ snippet: SnippetModel)", to: "func saveSnippet("),
            declaration(contentSource, from: "func copyResourcePath(_ resource: ResourcePinModel)", to: "func performResource("),
            declaration(resourceSource, from: "func performResourceAction(_ resource: ResourcePinModel, action: ResourceAction)", to: "func createAlias("),
            declaration(resourceSource, from: "func performResourceAction(_ action: ResourcePreviewAction)", to: "func loadFolderContents("),
            declaration(resourceSource, from: "func copyFolderPreviewItemPath(_ item: FolderPreviewItem)", to: "func performResourceAction(_ action: ResourcePreviewAction)"),
            declaration(resourceSource, from: "func copy(_ snippet: SnippetModel)", to: "func openTerminal("),
            declaration(resourceSource, from: "func run(_ request: CommandRunRequest)", to: "func resolvedWorkingDirectory("),
            declaration(canvasSource, from: "func open(_ node: CanvasNodeModel)", to: "func inspect("),
            declaration(canvasSource, from: "func copyNodePayload(_ node: CanvasNodeModel)", to: "func connectButtonTapped(")
        ]
        for owner in ordinaryOwners {
            XCTAssertTrue(owner.contains("clipboardService.copy("))
            XCTAssertFalse(owner.contains("ClipboardService().copy("))
        }

        let dependencyDeclaration = "private(set) var clipboardService: ClipboardService = ClipboardService()"
        XCTAssertEqual(occurrenceCount(dependencyDeclaration, in: contentSource), 3)
        XCTAssertEqual(occurrenceCount(dependencyDeclaration, in: resourceSource), 3)
        XCTAssertEqual(occurrenceCount(dependencyDeclaration, in: canvasSource), 1)
        XCTAssertEqual(occurrenceCount("clipboardService: clipboardService", in: contentSource), 11)
    }

    @MainActor
    func testDirectUserSnippetCopyWritesBodyOnlyAfterExplicitAction() {
        let snippet = SnippetModel(
            title: "Summary",
            kind: .prompt,
            body: "Summarize the selected notes.",
            scope: .global
        )
        var writes: [String] = []
        var statuses: [String] = []
        let clipboardService = ClipboardService(writer: { writes.append($0) })
        let view = SnippetLibraryView(
            snippets: [snippet],
            resources: [],
            scope: nil,
            workspaceId: nil,
            onStatus: { statuses.append($0) },
            onInspect: { _ in },
            onEdit: { _ in },
            onDelete: { _ in },
            clipboardService: clipboardService
        )

        XCTAssertTrue(writes.isEmpty)
        XCTAssertTrue(statuses.isEmpty)
        XCTAssertNil(snippet.lastCopiedAt)

        view.copy(snippet)

        XCTAssertEqual(writes, ["Summarize the selected notes."])
        XCTAssertEqual(statuses, ["Copied prompt: Summary"])
        XCTAssertNotNil(snippet.lastCopiedAt)
    }

    @MainActor
    func testFolderPreviewCopyUsesNamedDirectUserClipboardRoute() {
        let resource = ResourcePinModel(
            title: "Documents",
            targetType: .folder,
            displayPath: "/tmp/Documents",
            lastResolvedPath: "/tmp/Documents",
            scope: .global
        )
        let item = FolderPreviewItem(
            id: "document",
            name: "Document.txt",
            path: "/tmp/Documents/Document.txt",
            url: URL(fileURLWithPath: "/tmp/Documents/Document.txt"),
            isDirectory: false,
            size: 42
        )
        var writes: [String] = []
        var statuses: [String] = []
        let clipboardService = ClipboardService(writer: { writes.append($0) })
        let view = ResourcePreviewView(
            resource: resource,
            onStatus: { statuses.append($0) },
            onInspect: { _ in },
            onRemove: { _ in },
            clipboardService: clipboardService
        )

        XCTAssertTrue(writes.isEmpty)
        XCTAssertTrue(statuses.isEmpty)

        view.copyFolderPreviewItemPath(item)

        XCTAssertEqual(writes, ["/tmp/Documents/Document.txt"])
        XCTAssertEqual(statuses, ["Copied path: /tmp/Documents/Document.txt"])
    }

    func testTerminalPrefillAppleScriptTypesCommandWithoutRunningIt() {
        assertDirectUserTerminalSurfaceAvailable()
        let script = TerminalService.prefillAppleScript(
            command: "swift test\nswift build",
            workingDirectory: "/tmp/My Folder"
        )

        XCTAssertTrue(script.contains("do script \"\""))
        XCTAssertTrue(script.contains("keystroke \"cd -- '/tmp/My Folder' && swift test ; swift build\""))
        XCTAssertFalse(script.contains("do script \"cd -- '/tmp/My Folder' && swift test"))
    }

    func testCommandSnippetOpenTerminalRoutesThroughPrefillService() throws {
        assertDirectUserTerminalSurfaceAvailable()
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourceViewsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ResourceSnippetViews.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(resourceViewsSource.contains("TerminalService().prefill(command: snippet.body, workingDirectory: directory)"))
        XCTAssertTrue(resourceViewsSource.contains("Opened Terminal with command prefilled"))
        XCTAssertTrue(resourceViewsSource.contains("CommandRunConfirmationPolicy.shouldConfirm"))
    }

    func testCommandRunFailureFallbackCopiesCommandPrefillsTerminalAndKeepsOpenFallback() throws {
        assertDirectUserTerminalSurfaceAvailable()
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourceViewsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ResourceSnippetViews.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(resourceViewsSource.contains("clipboardService.copy(snippet.body)"))
        XCTAssertTrue(resourceViewsSource.contains("try TerminalService().prefill(command: snippet.body, workingDirectory: request.workingDirectory)"))
        XCTAssertTrue(resourceViewsSource.contains("try TerminalService().open(at: request.workingDirectory)"))
        XCTAssertTrue(resourceViewsSource.contains("Terminal run failed; copied command and opened Terminal with command prefilled"))
        XCTAssertTrue(resourceViewsSource.contains("Terminal run failed; copied command. Could not open Terminal"))
    }

    func testHomeRecentSnippetCompactCardsKeepTitlesAndExpandedBodiesReadable() throws {
        XCTAssertEqual(SnippetActionCardReadabilityPolicy.titleLineLimit(compact: true), 3)
        XCTAssertEqual(SnippetActionCardReadabilityPolicy.titleLineLimit(compact: false), 1)
        XCTAssertEqual(SnippetActionCardReadabilityPolicy.subtitleLineLimit(compact: true), 2)
        XCTAssertNil(SnippetActionCardReadabilityPolicy.expandedBodyLineLimit(compact: true))
        XCTAssertNil(SnippetActionCardReadabilityPolicy.expandedBodyLineLimit(compact: false))
        XCTAssertGreaterThanOrEqual(
            SnippetActionCardReadabilityPolicy.minimumHeight(compact: true, isExpanded: false),
            128
        )
        XCTAssertGreaterThanOrEqual(
            SnippetActionCardReadabilityPolicy.minimumHeight(compact: true, isExpanded: true),
            176
        )

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourceViewsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ResourceSnippetViews.swift"),
            encoding: .utf8
        )
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(contentViewSource.contains("DashboardSection(title: \"Recent Snippets\")"))
        XCTAssertTrue(contentViewSource.contains("compact: true"))
        XCTAssertTrue(resourceViewsSource.contains("SnippetActionCardReadabilityPolicy.titleLineLimit(compact: compact)"))
        XCTAssertTrue(resourceViewsSource.contains("SnippetActionCardReadabilityPolicy.expandedBodyLineLimit(compact: compact)"))
        XCTAssertTrue(resourceViewsSource.contains("SnippetActionCardReadabilityPolicy.minimumHeight(compact: compact, isExpanded: isExpanded)"))
    }

    func testResourceRowDoubleClickRoutesThroughOpenActionAndFinderRouting() throws {
        XCTAssertEqual(ResourceRowGestureActionPolicy.doubleClickActionID, .open)
        XCTAssertEqual(ResourceFinderRouting.doubleClickAction(forTargetType: "folder"), .open)
        XCTAssertEqual(ResourceFinderRouting.doubleClickAction(forTargetType: "file"), .reveal)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resourceViewsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ResourceSnippetViews.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(resourceViewsSource.contains(".simultaneousGesture(TapGesture(count: 2).onEnded"))
        XCTAssertTrue(resourceViewsSource.contains("perform(ResourceRowGestureActionPolicy.doubleClickActionID)"))
        XCTAssertTrue(resourceViewsSource.contains("ResourceFinderRouting.doubleClickAction(forTargetType: resource.targetTypeRaw)"))
    }

    func testGlobalLibraryResourceSectionsSeparateFoldersFilesAndAcceptMatchingDrops() throws {
        let sections = GlobalLibraryResourceSectionPolicy.sections

        XCTAssertEqual(sections.map(\.id), ["folders", "files"])
        XCTAssertEqual(sections.map(\.title), ["Folders", "Files"])
        XCTAssertEqual(sections.map(\.targetFilter), [.folder, .file])
        XCTAssertEqual(sections.map(\.pinImported), [false, false])

        XCTAssertTrue(sections[0].acceptsDrop(targetType: .folder))
        XCTAssertFalse(sections[0].acceptsDrop(targetType: .file))
        XCTAssertFalse(sections[1].acceptsDrop(targetType: .folder))
        XCTAssertTrue(sections[1].acceptsDrop(targetType: .file))
        XCTAssertEqual(
            Set(sections.flatMap { section in ResourceTargetType.allCases.filter { section.acceptsDrop(targetType: $0) } }),
            Set(ResourceTargetType.allCases)
        )

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contentViewSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/MindDesk/Views/ContentView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(contentViewSource.contains("ForEach(GlobalLibraryResourceSectionPolicy.sections)"))
        XCTAssertTrue(contentViewSource.contains("title: section.title"))
        XCTAssertTrue(contentViewSource.contains("targetFilter: section.targetFilter"))
        XCTAssertTrue(contentViewSource.contains("pinImported: section.pinImported"))
    }

    func testWorkspaceReentryNextTasksEntryOpensTaskPanelInsideCanvas() {
        let brief = WorkspaceReentryBrief(
            workspaceId: "workspace",
            badges: [WorkspaceReentryBadge(kind: .openTasks, count: 2)],
            nextTaskIds: ["todo-a", "todo-b"],
            resourceIssueIds: [],
            recentSnippetIds: [],
            canvasSummary: WorkspaceReentryCanvasSummary(
                canvasCount: 1,
                cardCount: 3,
                validLinkCount: 2,
                lastUpdatedAt: nil
            ),
            openTaskCount: 2,
            overdueTaskCount: 0,
            dueSoonTaskCount: 0,
            resourceIssueCount: 0,
            unresolvedReferenceCount: 0,
            isLargeDataDegraded: false
        )

        let action = WorkspaceReentryEntryActionPolicy.action(
            for: .nextTasks,
            brief: brief,
            visibleTaskTitles: ["Review outline", "Ship draft"]
        )

        XCTAssertTrue(action.isEnabled)
        XCTAssertEqual(action.targetTab, "Tasks")
        XCTAssertFalse(action.opensTaskPanel)
        XCTAssertEqual(action.statusMessage, "Showing 2 workspace tasks: Review outline, Ship draft")
    }

    func testHomeRecentWorkspacePresentationOrdersByRecencyAndLimitsBadges() {
        let old = Date(timeIntervalSince1970: 100)
        let middle = Date(timeIntervalSince1970: 200)
        let recent = Date(timeIntervalSince1970: 300)
        let sidebarFirst = WorkspaceModel(
            id: "sidebar-first",
            title: "Sidebar First",
            updatedAt: Date(timeIntervalSince1970: 900),
            lastOpenedAt: old,
            sortIndex: 0
        )
        let mostRecent = WorkspaceModel(
            id: "most-recent",
            title: "Most Recent",
            updatedAt: old,
            lastOpenedAt: recent,
            sortIndex: 99
        )
        let fallback = WorkspaceModel(
            id: "fallback-updated",
            title: "Fallback Updated",
            updatedAt: middle,
            lastOpenedAt: nil,
            sortIndex: 50
        )

        XCTAssertEqual(
            HomeRecentWorkspacePresentationPolicy.orderedWorkspaces(
                [sidebarFirst, mostRecent, fallback],
                limit: 3
            ).map(\.id),
            ["most-recent", "fallback-updated", "sidebar-first"]
        )

        let brief = WorkspaceReentryBrief(
            workspaceId: "most-recent",
            badges: [
                WorkspaceReentryBadge(kind: .overdueTasks, count: 2),
                WorkspaceReentryBadge(kind: .resourceIssues, count: 1),
                WorkspaceReentryBadge(kind: .openTasks, count: 4),
                WorkspaceReentryBadge(kind: .dueSoonTasks, count: 3)
            ],
            nextTaskIds: ["todo-a", "todo-b", "todo-c"],
            resourceIssueIds: ["resource-a"],
            recentSnippetIds: ["snippet-a"],
            canvasSummary: WorkspaceReentryCanvasSummary(
                canvasCount: 1,
                cardCount: 3,
                validLinkCount: 2,
                lastUpdatedAt: nil
            ),
            openTaskCount: 4,
            overdueTaskCount: 2,
            dueSoonTaskCount: 3,
            resourceIssueCount: 1,
            unresolvedReferenceCount: 0,
            isLargeDataDegraded: false
        )

        XCTAssertEqual(
            HomeRecentWorkspacePresentationPolicy.visibleBadges(for: brief).map(\.kind),
            [.overdueTasks, .resourceIssues]
        )
        XCTAssertEqual(
            HomeRecentWorkspacePresentationPolicy.taskSummary(for: brief),
            "4 open"
        )
    }

    func testWorkspaceReentryEntriesOnlyRouteInsideMindDeskViews() {
        let brief = WorkspaceReentryBrief(
            workspaceId: "workspace",
            badges: [WorkspaceReentryBadge(kind: .resourceIssues, count: 1)],
            nextTaskIds: ["todo-a"],
            resourceIssueIds: ["resource-a"],
            recentSnippetIds: ["snippet-a"],
            canvasSummary: WorkspaceReentryCanvasSummary(
                canvasCount: 1,
                cardCount: 4,
                validLinkCount: 3,
                lastUpdatedAt: nil
            ),
            openTaskCount: 1,
            overdueTaskCount: 0,
            dueSoonTaskCount: 0,
            resourceIssueCount: 1,
            unresolvedReferenceCount: 0,
            isLargeDataDegraded: false
        )

        let canvas = WorkspaceReentryEntryActionPolicy.action(for: .canvas, brief: brief)
        let nextTasks = WorkspaceReentryEntryActionPolicy.action(
            for: .nextTasks,
            brief: brief,
            visibleTaskTitles: ["Review outline"]
        )
        let resources = WorkspaceReentryEntryActionPolicy.action(for: .resources, brief: brief)
        let snippets = WorkspaceReentryEntryActionPolicy.action(for: .snippets, brief: brief)

        XCTAssertEqual(canvas.targetTab, "Canvas")
        XCTAssertEqual(nextTasks.targetTab, "Tasks")
        XCTAssertEqual(resources.targetTab, "Resources")
        XCTAssertEqual(snippets.targetTab, "Snippets")
        XCTAssertFalse(canvas.opensTaskPanel)
        XCTAssertFalse(nextTasks.opensTaskPanel)
        XCTAssertFalse(resources.opensTaskPanel)
        XCTAssertFalse(snippets.opensTaskPanel)
        XCTAssertNil(canvas.statusMessage)
        XCTAssertNil(resources.statusMessage)
        XCTAssertNil(snippets.statusMessage)
        for action in [canvas, nextTasks, resources, snippets] {
            XCTAssertTrue(action.isEnabled)
        }
    }

    func testWorkspaceReentryNextTasksEntryIsInformationalWhenNoTasksAreOpen() {
        let brief = WorkspaceReentryBrief(
            workspaceId: "workspace",
            badges: [],
            nextTaskIds: [],
            resourceIssueIds: [],
            recentSnippetIds: [],
            canvasSummary: WorkspaceReentryCanvasSummary(
                canvasCount: 0,
                cardCount: 0,
                validLinkCount: 0,
                lastUpdatedAt: nil
            ),
            openTaskCount: 0,
            overdueTaskCount: 0,
            dueSoonTaskCount: 0,
            resourceIssueCount: 0,
            unresolvedReferenceCount: 0,
            isLargeDataDegraded: false
        )

        let action = WorkspaceReentryEntryActionPolicy.action(
            for: .nextTasks,
            brief: brief,
            visibleTaskTitles: []
        )

        XCTAssertFalse(action.isEnabled)
        XCTAssertNil(action.targetTab)
        XCTAssertFalse(action.opensTaskPanel)
        XCTAssertEqual(action.statusMessage, "No open workspace tasks")
    }

    func testWorkspaceReentryDisplayPolicyUsesCountOnlyCopyWhenLargeDataDegraded() {
        let brief = WorkspaceReentryBrief(
            workspaceId: "workspace",
            badges: [WorkspaceReentryBadge(kind: .openTasks, count: 3)],
            nextTaskIds: [],
            resourceIssueIds: [],
            recentSnippetIds: [],
            canvasSummary: WorkspaceReentryCanvasSummary(
                canvasCount: 2,
                cardCount: 12_000,
                validLinkCount: 0,
                lastUpdatedAt: nil
            ),
            openTaskCount: 3,
            overdueTaskCount: 0,
            dueSoonTaskCount: 0,
            resourceIssueCount: 2,
            unresolvedReferenceCount: 0,
            isLargeDataDegraded: true
        )

        let display = WorkspaceReentryBriefDisplayPolicy.text(
            for: brief,
            taskTitles: ["Secret task title"],
            resourceIssueTitles: ["/private/path/secret.md"],
            snippetTitles: ["Command body https://example.com"]
        )
        let visibleText = [
            display.canvasValue,
            display.canvasDetail,
            display.taskValue,
            display.taskDetail,
            display.resourceValue,
            display.resourceDetail,
            display.snippetValue,
            display.snippetDetail
        ].joined(separator: " ")

        XCTAssertEqual(display.canvasValue, "Large workspace - counts only")
        XCTAssertEqual(display.canvasDetail, "Detailed checks paused")
        XCTAssertEqual(display.taskValue, "3 open tasks")
        XCTAssertEqual(display.taskDetail, "Next task ranking skipped")
        XCTAssertEqual(display.resourceValue, "2 known resource issues")
        XCTAssertEqual(display.resourceDetail, "Reference checks skipped")
        XCTAssertEqual(display.snippetValue, "Recent snippets not summarized")
        XCTAssertEqual(display.snippetDetail, "Details skipped")
        XCTAssertFalse(visibleText.contains("Secret task title"))
        XCTAssertFalse(visibleText.contains("/private/path"))
        XCTAssertFalse(visibleText.contains("https://example.com"))
    }

    func testWorkspaceReentryDisplayPolicyDoesNotShowEmptyDetailedCopyWhenLargeDataDegraded() {
        let brief = WorkspaceReentryBrief(
            workspaceId: "workspace",
            badges: [],
            nextTaskIds: [],
            resourceIssueIds: [],
            recentSnippetIds: [],
            canvasSummary: WorkspaceReentryCanvasSummary(
                canvasCount: 1,
                cardCount: 12_000,
                validLinkCount: 0,
                lastUpdatedAt: nil
            ),
            openTaskCount: 0,
            overdueTaskCount: 0,
            dueSoonTaskCount: 0,
            resourceIssueCount: 0,
            unresolvedReferenceCount: 0,
            isLargeDataDegraded: true
        )

        let display = WorkspaceReentryBriefDisplayPolicy.text(
            for: brief,
            taskTitles: [],
            resourceIssueTitles: [],
            snippetTitles: []
        )
        let visibleText = [
            display.canvasValue,
            display.canvasDetail,
            display.taskValue,
            display.taskDetail,
            display.resourceValue,
            display.resourceDetail,
            display.snippetValue,
            display.snippetDetail
        ].joined(separator: " ")

        XCTAssertFalse(visibleText.contains("No resource issues"))
        XCTAssertFalse(visibleText.contains("No recent snippets"))
        XCTAssertFalse(visibleText.contains("None"))
        XCTAssertFalse(visibleText.contains("Workspace map"))
        XCTAssertFalse(visibleText.contains("0 links"))
        XCTAssertEqual(display.resourceValue, "Reference checks skipped")
        XCTAssertEqual(display.snippetValue, "Recent snippets not summarized")
    }

    func testWorkspaceReentryDisplayPolicyKeepsDetailedCopyWhenNotDegraded() {
        let brief = WorkspaceReentryBrief(
            workspaceId: "workspace",
            badges: [WorkspaceReentryBadge(kind: .resourceIssues, count: 1)],
            nextTaskIds: ["todo-a"],
            resourceIssueIds: ["resource-a"],
            recentSnippetIds: ["snippet-a"],
            canvasSummary: WorkspaceReentryCanvasSummary(
                canvasCount: 1,
                cardCount: 4,
                validLinkCount: 3,
                lastUpdatedAt: nil
            ),
            openTaskCount: 1,
            overdueTaskCount: 0,
            dueSoonTaskCount: 0,
            resourceIssueCount: 1,
            unresolvedReferenceCount: 2,
            isLargeDataDegraded: false
        )

        let display = WorkspaceReentryBriefDisplayPolicy.text(
            for: brief,
            taskTitles: ["Review outline"],
            resourceIssueTitles: ["Missing Drive"],
            snippetTitles: ["Prompt Draft"]
        )

        XCTAssertEqual(display.canvasValue, "4 cards · 3 links")
        XCTAssertEqual(display.canvasDetail, "2 unresolved references")
        XCTAssertEqual(display.taskValue, "1 open task")
        XCTAssertEqual(display.taskDetail, "Review outline")
        XCTAssertEqual(display.resourceValue, "1 resource issue")
        XCTAssertEqual(display.resourceDetail, "Missing Drive")
        XCTAssertEqual(display.snippetValue, "1 recent snippet")
        XCTAssertEqual(display.snippetDetail, "Prompt Draft")
    }

    func testWorkspaceReentryNextTasksEntryIgnoresTitlesWhenLargeDataDegraded() {
        let brief = WorkspaceReentryBrief(
            workspaceId: "workspace",
            badges: [WorkspaceReentryBadge(kind: .openTasks, count: 3)],
            nextTaskIds: ["todo-secret"],
            resourceIssueIds: [],
            recentSnippetIds: [],
            canvasSummary: WorkspaceReentryCanvasSummary(
                canvasCount: 1,
                cardCount: 12_000,
                validLinkCount: 0,
                lastUpdatedAt: nil
            ),
            openTaskCount: 3,
            overdueTaskCount: 0,
            dueSoonTaskCount: 0,
            resourceIssueCount: 0,
            unresolvedReferenceCount: 0,
            isLargeDataDegraded: true
        )

        let action = WorkspaceReentryEntryActionPolicy.action(
            for: .nextTasks,
            brief: brief,
            visibleTaskTitles: ["Secret task https://evil.example /Users/me/key token=abc"]
        )

        XCTAssertTrue(action.isEnabled)
        XCTAssertEqual(action.targetTab, "Tasks")
        XCTAssertFalse(action.opensTaskPanel)
        XCTAssertEqual(action.statusMessage, "Showing 3 workspace tasks. Details paused for large workspace.")
        XCTAssertFalse(action.statusMessage?.contains("Secret") ?? false)
        XCTAssertFalse(action.statusMessage?.contains("https://") ?? false)
        XCTAssertFalse(action.statusMessage?.contains("/Users/") ?? false)
        XCTAssertFalse(action.statusMessage?.contains("token=") ?? false)
    }

    func testWorkspaceTodoPanelOpenRequestPolicyIgnoresOtherWorkspaceRequests() {
        let request = WorkspaceTodoPanelOpenRequest(id: 4, workspaceID: "workspace-a")

        XCTAssertFalse(
            WorkspaceTodoPanelOpenRequestPolicy.shouldHandle(
                request,
                forWorkspaceID: "workspace-b",
                handledRequestID: 0
            )
        )
    }

    func testWorkspaceTodoPanelOpenRequestPolicyHandlesOnlyNewCurrentWorkspaceRequests() {
        let currentRequest = WorkspaceTodoPanelOpenRequest(id: 5, workspaceID: "workspace-a")

        XCTAssertTrue(
            WorkspaceTodoPanelOpenRequestPolicy.shouldHandle(
                currentRequest,
                forWorkspaceID: "workspace-a",
                handledRequestID: 4
            )
        )
        XCTAssertFalse(
            WorkspaceTodoPanelOpenRequestPolicy.shouldHandle(
                currentRequest,
                forWorkspaceID: "workspace-a",
                handledRequestID: 5
            )
        )
        XCTAssertEqual(
            WorkspaceTodoPanelOpenRequestPolicy.nextRequest(
                after: currentRequest,
                workspaceID: "workspace-a"
            ),
            WorkspaceTodoPanelOpenRequest(id: 6, workspaceID: "workspace-a")
        )
        XCTAssertEqual(
            WorkspaceTodoPanelOpenRequestPolicy.nextRequest(
                after: nil,
                workspaceID: "workspace-b"
            ),
            WorkspaceTodoPanelOpenRequest(id: 1, workspaceID: "workspace-b")
        )
    }

    func testQuickOpenWebCardDeepLinkPolicyTargetsOwningCanvasNode() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        let now = Date(timeIntervalSince1970: 1_800)
        let workspace = WorkspaceModel(id: "workspace-a", title: "Workspace A", updatedAt: now)
        let canvas = CanvasModel(id: "canvas-a", workspaceId: "workspace-a", updatedAt: now)
        let webNode = CanvasNodeModel(
            id: "web-node",
            canvasId: canvas.id,
            title: "OpenAI Docs",
            body: "https://platform.openai.com/docs",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "https://platform.openai.com/docs",
            x: 80,
            y: 120,
            updatedAt: now
        )
        let record = QuickOpenRecord(
            id: "webCard:\(webNode.id)",
            kind: .webCard,
            title: webNode.title,
            subtitle: "https://display-only.example.com",
            location: "Canvas: Wrong Workspace / Wrong Canvas"
        )

        let expectedTarget = WorkspaceCanvasNodeOpenTarget(workspaceID: "workspace-a", canvasID: "canvas-a", nodeID: "web-node")
        XCTAssertEqual(
            QuickOpenWebCardDeepLinkPolicy.result(
                for: record,
                workspaces: [workspace],
                canvases: [canvas],
                nodes: [webNode]
            ),
            .ready(expectedTarget)
        )
        XCTAssertEqual(
            QuickOpenWebCardDeepLinkPolicy.target(
                for: record,
                workspaces: [workspace],
                canvases: [canvas],
                nodes: [webNode]
            ),
            expectedTarget
        )
    }

    func testQuickOpenWebCardDeepLinkPolicyRejectsMissingOrInvalidWebCards() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        let workspace = WorkspaceModel(id: "workspace-a", title: "Workspace A")
        let canvas = CanvasModel(id: "canvas-a", workspaceId: "workspace-a")
        let invalidWebNode = CanvasNodeModel(
            id: "web-node",
            canvasId: canvas.id,
            title: "Bad URL",
            body: "javascript:alert(1)",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "javascript:alert(1)",
            x: 0,
            y: 0
        )
        let wrongKindRecord = QuickOpenRecord(
            id: "webCard:\(invalidWebNode.id)",
            kind: .workspace,
            title: invalidWebNode.title,
            subtitle: invalidWebNode.body
        )
        let invalidRecord = QuickOpenRecord(
            id: "webCard:\(invalidWebNode.id)",
            kind: .webCard,
            title: invalidWebNode.title,
            subtitle: invalidWebNode.body
        )

        XCTAssertNil(QuickOpenWebCardDeepLinkPolicy.target(
            for: wrongKindRecord,
            workspaces: [workspace],
            canvases: [canvas],
            nodes: [invalidWebNode]
        ))
        XCTAssertNil(QuickOpenWebCardDeepLinkPolicy.target(
            for: invalidRecord,
            workspaces: [workspace],
            canvases: [canvas],
            nodes: [invalidWebNode]
        ))
        XCTAssertNil(QuickOpenWebCardDeepLinkPolicy.target(
            for: invalidRecord,
            workspaces: [workspace],
            canvases: [],
            nodes: [invalidWebNode]
        ))
    }

    func testQuickOpenWebCardDeepLinkPolicyReportsSpecificBlockedReasons() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        let workspace = WorkspaceModel(id: "workspace-a", title: "Workspace A")
        let canvas = CanvasModel(id: "canvas-a", workspaceId: workspace.id)
        let validRecord = QuickOpenRecord(
            id: "webCard:missing-node",
            kind: .webCard,
            title: "Missing",
            subtitle: "https://docs.example.com"
        )
        let wrongKindRecord = QuickOpenRecord(
            id: "workspace:workspace-a",
            kind: .workspace,
            title: "Workspace",
            subtitle: "Details"
        )
        let invalidURLNode = CanvasNodeModel(
            id: "invalid-url-node",
            canvasId: canvas.id,
            title: "Invalid URL",
            body: "https://safe.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "javascript:alert(1)",
            x: 0,
            y: 0
        )
        let invalidURLRecord = QuickOpenRecord(
            id: "webCard:\(invalidURLNode.id)",
            kind: .webCard,
            title: invalidURLNode.title,
            subtitle: invalidURLNode.body
        )
        let missingCanvasNode = CanvasNodeModel(
            id: "missing-canvas-node",
            canvasId: "missing-canvas",
            title: "Missing Canvas",
            body: "https://docs.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "https://docs.example.com",
            x: 0,
            y: 0
        )
        let missingWorkspaceCanvas = CanvasModel(id: "missing-workspace-canvas", workspaceId: "missing-workspace")
        let missingWorkspaceNode = CanvasNodeModel(
            id: "missing-workspace-node",
            canvasId: missingWorkspaceCanvas.id,
            title: "Missing Workspace",
            body: "https://docs.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "https://docs.example.com",
            x: 0,
            y: 0
        )
        let incompatibleNode = CanvasNodeModel(
            id: "resource-web-node",
            canvasId: canvas.id,
            title: "Wrong Type",
            body: "https://docs.example.com",
            nodeType: .resource,
            objectType: "webURL",
            objectId: "https://docs.example.com",
            x: 0,
            y: 0
        )

        XCTAssertEqual(
            QuickOpenWebCardDeepLinkPolicy.result(
                for: wrongKindRecord,
                workspaces: [workspace],
                canvases: [canvas],
                nodes: []
            ),
            .blocked(.unsupportedRecordKind)
        )
        XCTAssertEqual(
            QuickOpenWebCardDeepLinkPolicy.result(
                for: validRecord,
                workspaces: [workspace],
                canvases: [canvas],
                nodes: []
            ),
            .blocked(.missingNode)
        )
        XCTAssertEqual(
            QuickOpenWebCardDeepLinkPolicy.result(
                for: invalidURLRecord,
                workspaces: [workspace],
                canvases: [canvas],
                nodes: [invalidURLNode]
            ),
            .blocked(.invalidURL)
        )
        XCTAssertEqual(
            QuickOpenWebCardDeepLinkPolicy.result(
                for: QuickOpenRecord(id: "webCard:\(missingCanvasNode.id)", kind: .webCard, title: missingCanvasNode.title, subtitle: missingCanvasNode.body),
                workspaces: [workspace],
                canvases: [canvas],
                nodes: [missingCanvasNode]
            ),
            .blocked(.missingCanvas)
        )
        XCTAssertEqual(
            QuickOpenWebCardDeepLinkPolicy.result(
                for: QuickOpenRecord(id: "webCard:\(missingWorkspaceNode.id)", kind: .webCard, title: missingWorkspaceNode.title, subtitle: missingWorkspaceNode.body),
                workspaces: [workspace],
                canvases: [missingWorkspaceCanvas],
                nodes: [missingWorkspaceNode]
            ),
            .blocked(.missingWorkspace)
        )
        XCTAssertEqual(
            QuickOpenWebCardDeepLinkPolicy.result(
                for: QuickOpenRecord(id: "webCard:\(incompatibleNode.id)", kind: .webCard, title: incompatibleNode.title, subtitle: incompatibleNode.body),
                workspaces: [workspace],
                canvases: [canvas],
                nodes: [incompatibleNode]
            ),
            .blocked(.incompatibleNode)
        )
    }

    func testQuickOpenWebCardDeepLinkBlockedStatusDoesNotReplayRawValues() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        let blockedReasons: [QuickOpenWebCardDeepLinkBlockedReason] = [
            .unsupportedRecordKind,
            .missingNode,
            .invalidURL,
            .missingCanvas,
            .missingWorkspace,
            .incompatibleNode
        ]

        for reason in blockedReasons {
            let status = reason.statusMessage
            switch reason {
            case .unsupportedRecordKind:
                XCTAssertEqual(status, "Selected item is not a web page card.")
            case .missingNode:
                XCTAssertEqual(status, "Web page card is no longer available.")
            case .invalidURL:
                XCTAssertEqual(status, "Web page card has an invalid URL.")
            case .missingCanvas:
                XCTAssertEqual(status, "Workspace map for this web page card is no longer available.")
            case .missingWorkspace:
                XCTAssertEqual(status, "Workspace for this web page card is no longer available.")
            case .incompatibleNode:
                XCTAssertEqual(status, "This item is no longer a web page card.")
            }
            XCTAssertFalse(status.contains("webCard:"))
            XCTAssertFalse(status.contains("node-"))
            XCTAssertFalse(status.contains("canvas-"))
            XCTAssertFalse(status.contains("workspace-a"))
            XCTAssertFalse(status.contains("javascript:"))
            XCTAssertFalse(status.contains("https://"))
            XCTAssertFalse(status.localizedCaseInsensitiveContains("opened web page"))
        }
    }

    func testQuickOpenWebCardRecordPolicyKeepsOnlyNavigableWebCards() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        let workspace = WorkspaceModel(id: "workspace-a", title: "Workspace A")
        let canvas = CanvasModel(id: "canvas-a", workspaceId: workspace.id)
        let validNode = CanvasNodeModel(
            id: "node-valid",
            canvasId: canvas.id,
            title: "Docs",
            body: "https://docs.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "docs.example.com",
            x: 0,
            y: 0
        )
        let bodyFallbackNode = CanvasNodeModel(
            id: "node-body",
            canvasId: canvas.id,
            title: "API",
            body: "https://api.example.com/path",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: nil,
            x: 0,
            y: 0
        )
        let danglingCanvasNode = CanvasNodeModel(
            id: "node-dangling-canvas",
            canvasId: "missing-canvas",
            title: "Dangling Canvas",
            body: "https://dangling.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "https://dangling.example.com",
            x: 0,
            y: 0
        )
        let invalidURLNode = CanvasNodeModel(
            id: "node-invalid",
            canvasId: canvas.id,
            title: "Invalid",
            body: "javascript:alert(1)",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "javascript:alert(1)",
            x: 0,
            y: 0
        )
        let nonWebNode = CanvasNodeModel(
            id: "node-note",
            canvasId: canvas.id,
            title: "Note",
            body: "https://note.example.com",
            nodeType: .note,
            objectType: nil,
            x: 0,
            y: 0
        )

        let records = QuickOpenWebCardRecordPolicy.records(
            workspaces: [workspace],
            canvases: [canvas],
            nodes: [validNode, bodyFallbackNode, danglingCanvasNode, invalidURLNode, nonWebNode]
        )

        XCTAssertEqual(records.map(\.id), ["webCard:node-body", "webCard:node-valid"])
        XCTAssertEqual(records.map(\.kind), [.webCard, .webCard])
        XCTAssertEqual(records.map(\.subtitle), ["https://api.example.com/path", "https://docs.example.com"])
        XCTAssertEqual(records.map(\.location), [
            "Canvas: Workspace A / Map",
            "Canvas: Workspace A / Map"
        ])
    }

    func testQuickOpenWebCardRecordPolicyKeepsURLSubtitleSeparateFromLocationContext() throws {
        assertOrdinaryQuickOpenSurfaceAvailable()
        let workspace = WorkspaceModel(id: "workspace-a", title: "Research")
        let canvas = CanvasModel(id: "canvas-a", workspaceId: workspace.id, title: "Sources")
        let node = CanvasNodeModel(
            id: "node-docs",
            canvasId: canvas.id,
            title: "Docs",
            body: "https://docs.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "docs.example.com",
            x: 0,
            y: 0
        )

        let record = try XCTUnwrap(QuickOpenWebCardRecordPolicy.records(
            workspaces: [workspace],
            canvases: [canvas],
            nodes: [node]
        ).first)

        XCTAssertEqual(record.subtitle, "https://docs.example.com")
        XCTAssertEqual(record.location, "Canvas: Research / Sources")
    }

    func testQuickOpenWebCardRecordPolicyRejectsInvalidObjectIDBeforeBodyFallback() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        let workspace = WorkspaceModel(id: "workspace-a", title: "Workspace A")
        let canvas = CanvasModel(id: "canvas-a", workspaceId: workspace.id)
        let node = CanvasNodeModel(
            id: "node-invalid-object",
            canvasId: canvas.id,
            title: "Dirty URL",
            body: "https://valid.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "javascript:alert(1)",
            x: 0,
            y: 0
        )
        let record = QuickOpenRecord(
            id: "webCard:\(node.id)",
            kind: .webCard,
            title: node.title,
            subtitle: node.body
        )

        XCTAssertTrue(QuickOpenWebCardRecordPolicy.records(
            workspaces: [workspace],
            canvases: [canvas],
            nodes: [node]
        ).isEmpty)
        XCTAssertNil(QuickOpenWebCardDeepLinkPolicy.target(
            for: record,
            workspaces: [workspace],
            canvases: [canvas],
            nodes: [node]
        ))
    }

    func testQuickOpenWebCardRecordPolicyRejectsIncompatibleNodeTypes() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        let workspace = WorkspaceModel(id: "workspace-a", title: "Workspace A")
        let canvas = CanvasModel(id: "canvas-a", workspaceId: workspace.id)
        let node = CanvasNodeModel(
            id: "node-resource-web",
            canvasId: canvas.id,
            title: "Mismatched Web",
            body: "https://valid.example.com",
            nodeType: .resource,
            objectType: "webURL",
            objectId: "https://valid.example.com",
            x: 0,
            y: 0
        )
        let record = QuickOpenRecord(
            id: "webCard:\(node.id)",
            kind: .webCard,
            title: node.title,
            subtitle: node.body
        )

        XCTAssertTrue(QuickOpenWebCardRecordPolicy.records(
            workspaces: [workspace],
            canvases: [canvas],
            nodes: [node]
        ).isEmpty)
        XCTAssertNil(QuickOpenWebCardDeepLinkPolicy.target(
            for: record,
            workspaces: [workspace],
            canvases: [canvas],
            nodes: [node]
        ))
    }

    func testQuickOpenWebCardRecordPolicyPreservesDuplicateURLCardsWithStableTieBreak() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        let workspace = WorkspaceModel(id: "workspace-a", title: "Workspace A")
        let canvas = CanvasModel(id: "canvas-a", workspaceId: workspace.id)
        let first = CanvasNodeModel(
            id: "node-b",
            canvasId: canvas.id,
            title: "Same",
            body: "example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "example.com",
            x: 0,
            y: 0
        )
        let second = CanvasNodeModel(
            id: "node-a",
            canvasId: canvas.id,
            title: "Same",
            body: "example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "example.com",
            x: 0,
            y: 0
        )

        let records = QuickOpenWebCardRecordPolicy.records(
            workspaces: [workspace],
            canvases: [canvas],
            nodes: [first, second]
        )

        XCTAssertEqual(records.map(\.id), ["webCard:node-a", "webCard:node-b"])
        XCTAssertEqual(records.map(\.subtitle), ["https://example.com", "https://example.com"])
    }

    func testQuickOpenWebCardRecordPolicySortsByTitleSubtitleThenID() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        let workspace = WorkspaceModel(id: "workspace-a", title: "Workspace A")
        let canvas = CanvasModel(id: "canvas-a", workspaceId: workspace.id)
        let beta = CanvasNodeModel(
            id: "node-beta",
            canvasId: canvas.id,
            title: "Beta",
            body: "https://b.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "https://b.example.com",
            x: 0,
            y: 0
        )
        let alphaSecondURL = CanvasNodeModel(
            id: "node-alpha-b",
            canvasId: canvas.id,
            title: "Alpha",
            body: "https://b.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "https://b.example.com",
            x: 0,
            y: 0
        )
        let alphaFirstURLSecondID = CanvasNodeModel(
            id: "node-alpha-z",
            canvasId: canvas.id,
            title: "Alpha",
            body: "https://a.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "https://a.example.com",
            x: 0,
            y: 0
        )
        let alphaFirstURLFirstID = CanvasNodeModel(
            id: "node-alpha-a",
            canvasId: canvas.id,
            title: "Alpha",
            body: "https://a.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "https://a.example.com",
            x: 0,
            y: 0
        )

        let records = QuickOpenWebCardRecordPolicy.records(
            workspaces: [workspace],
            canvases: [canvas],
            nodes: [beta, alphaSecondURL, alphaFirstURLSecondID, alphaFirstURLFirstID]
        )

        XCTAssertEqual(records.map(\.id), [
            "webCard:node-alpha-a",
            "webCard:node-alpha-z",
            "webCard:node-alpha-b",
            "webCard:node-beta"
        ])
    }

    func testQuickOpenWebCardDeepLinkPolicyRejectsMissingWorkspace() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        let canvas = CanvasModel(id: "canvas-a", workspaceId: "missing-workspace")
        let webNode = CanvasNodeModel(
            id: "web-node",
            canvasId: canvas.id,
            title: "Docs",
            body: "https://docs.example.com",
            nodeType: .snippet,
            objectType: "webURL",
            objectId: "https://docs.example.com",
            x: 0,
            y: 0
        )
        let record = QuickOpenRecord(
            id: "webCard:\(webNode.id)",
            kind: .webCard,
            title: webNode.title,
            subtitle: webNode.body
        )

        XCTAssertNil(
            QuickOpenWebCardDeepLinkPolicy.target(
                for: record,
                workspaces: [],
                canvases: [canvas],
                nodes: [webNode]
            )
        )
    }

    func testCanvasCardTapSelectsNodeAndSelectionFrameShowsAccentImmediately() {
        let singleSelection = CanvasNodeTapSelectionPolicy.result(
            tappingNodeID: "node-a",
            selectedNodeIDs: [],
            selectedEdgeIDs: ["edge-a"],
            connectionSourceNodeID: "source-a"
        )

        XCTAssertEqual(singleSelection.selectedNodeIDs, ["node-a"])
        XCTAssertTrue(singleSelection.selectedEdgeIDs.isEmpty)
        XCTAssertNil(singleSelection.connectionSourceNodeID)

        let removedFromMultiSelection = CanvasNodeTapSelectionPolicy.result(
            tappingNodeID: "node-a",
            selectedNodeIDs: ["node-a", "node-b"],
            selectedEdgeIDs: ["edge-a"],
            connectionSourceNodeID: "source-a"
        )
        XCTAssertEqual(removedFromMultiSelection.selectedNodeIDs, ["node-b"])

        let replacedSelection = CanvasNodeTapSelectionPolicy.result(
            tappingNodeID: "node-c",
            selectedNodeIDs: ["node-a", "node-b"],
            selectedEdgeIDs: ["edge-a"],
            connectionSourceNodeID: "source-a"
        )
        XCTAssertEqual(replacedSelection.selectedNodeIDs, ["node-c"])

        XCTAssertEqual(
            CanvasNodeSelectionFramePolicy.style(
                isSelected: true,
                isConnectionSource: false,
                inactiveLineWidth: 1
            ),
            CanvasNodeSelectionFrameStyle(tone: .accent, lineWidth: 2)
        )
        XCTAssertEqual(
            CanvasNodeSelectionFramePolicy.style(
                isSelected: false,
                isConnectionSource: false,
                inactiveLineWidth: 1.2
            ),
            CanvasNodeSelectionFrameStyle(tone: .inactive, lineWidth: 1.2)
        )
    }

    func testCanvasEdgeTapSelectsOnlyEdgeAndClearsCardSelection() {
        let selection = CanvasEdgeTapSelectionPolicy.result(tappingEdgeID: "edge-a")

        XCTAssertTrue(selection.selectedNodeIDs.isEmpty)
        XCTAssertEqual(selection.selectedEdgeIDs, ["edge-a"])
        XCTAssertNil(selection.connectionSourceNodeID)
    }

    func testCanvasCardDragCommitPersistsReleasedModelPositions() {
        let committedPositions = CanvasNodeDragCommitPolicy.committedPositions(
            dragStarts: [
                CanvasFramePosition(id: "node-a", x: 120, y: 80),
                CanvasFramePosition(id: "node-b", x: -40, y: 15)
            ],
            deltaX: 22.5,
            deltaY: -10
        )

        XCTAssertEqual(
            committedPositions,
            [
                CanvasFramePosition(id: "node-a", x: 142.5, y: 70),
                CanvasFramePosition(id: "node-b", x: -17.5, y: 5)
            ]
        )
        XCTAssertTrue(
            CanvasNodeDragCommitPolicy.committedPositions(
                dragStarts: [],
                deltaX: 22.5,
                deltaY: -10
            ).isEmpty
        )
    }

    func testCanvasCardDragPersistencePolicyDefersSwiftDataSaveUntilGestureEnd() {
        XCTAssertEqual(
            CanvasNodeDragPersistencePolicy.action(for: .changed, hasActiveDrag: false),
            .ignore
        )
        XCTAssertEqual(
            CanvasNodeDragPersistencePolicy.action(for: .changed, hasActiveDrag: true),
            .updateTransientOffset
        )
        XCTAssertEqual(
            CanvasNodeDragPersistencePolicy.action(for: .ended, hasActiveDrag: true),
            .commitModelAndSave
        )
        XCTAssertNotEqual(
            CanvasNodeDragPersistencePolicy.action(for: .changed, hasActiveDrag: true),
            .commitModelAndSave
        )
    }

    func testCanvasCardInteractionSurfaceCoversTopBlankEdgeAndBlocksBackgroundPan() {
        let card = CanvasFrameRect(id: "folder-card", x: 150, y: 300, width: 316, height: 226)

        XCTAssertEqual(
            CanvasNodeInteractionHitPolicy.backgroundDragTarget(
                at: CanvasEdgePoint(x: 158, y: 306),
                nodeRects: [card],
                hitSlop: 0
            ),
            .node("folder-card")
        )
        XCTAssertEqual(
            CanvasNodeInteractionHitPolicy.backgroundDragTarget(
                at: CanvasEdgePoint(x: 158, y: 296),
                nodeRects: [card],
                hitSlop: 8
            ),
            .node("folder-card")
        )
        XCTAssertEqual(
            CanvasNodeInteractionHitPolicy.backgroundDragTarget(
                at: CanvasEdgePoint(x: 158, y: 291),
                nodeRects: [card],
                hitSlop: 8
            ),
            .background
        )
        XCTAssertEqual(
            CanvasNodeInteractionHitPolicy.contentShapePadding(hitSlop: 8),
            0
        )
        XCTAssertEqual(
            CanvasNodeInteractionHitPolicy.contentShapePadding(hitSlop: -3),
            0
        )
    }

    func testCanvasBackgroundPanCommitMovesViewportOnlyForBackgroundDrag() {
        let commit = CanvasBackgroundPanCommitPolicy.commit(
            viewportX: 18,
            viewportY: -12,
            transientOffset: CGSize(width: 42, height: -9),
            startsOnNode: false
        )

        XCTAssertEqual(commit?.viewportX, 60)
        XCTAssertEqual(commit?.viewportY, -21)
        XCTAssertNil(
            CanvasBackgroundPanCommitPolicy.commit(
                viewportX: 18,
                viewportY: -12,
                transientOffset: CGSize(width: 42, height: -9),
                startsOnNode: true
            )
        )
        XCTAssertNil(
            CanvasBackgroundPanCommitPolicy.commit(
                viewportX: 18,
                viewportY: -12,
                transientOffset: CGSize.zero,
                startsOnNode: false
            )
        )
    }

    func testCanvasViewportPersistencePolicyRejectsNonFiniteZoomAndPanCommits() {
        XCTAssertEqual(
            CanvasViewportPersistencePolicy.commit(
                zoom: 0.7,
                viewportX: 42,
                viewportY: -12,
                minimumZoom: 0.12,
                maximumZoom: 2.4
            ),
            CanvasViewportPersistenceCommit(zoom: 0.7, viewportX: 42, viewportY: -12)
        )
        XCTAssertEqual(
            CanvasViewportPersistencePolicy.commit(
                zoom: 9,
                viewportX: 42,
                viewportY: -12,
                minimumZoom: 0.12,
                maximumZoom: 2.4
            )?.zoom,
            2.4
        )
        XCTAssertNil(
            CanvasViewportPersistencePolicy.commit(
                zoom: .nan,
                viewportX: 42,
                viewportY: -12,
                minimumZoom: 0.12,
                maximumZoom: 2.4
            )
        )
        XCTAssertNil(
            CanvasViewportPersistencePolicy.commit(
                zoom: 0.7,
                viewportX: .infinity,
                viewportY: -12,
                minimumZoom: 0.12,
                maximumZoom: 2.4
            )
        )
        XCTAssertNil(
            CanvasViewportPersistencePolicy.commit(
                zoom: 0.7,
                viewportX: 42,
                viewportY: .nan,
                minimumZoom: 0.12,
                maximumZoom: 2.4
            )
        )
    }

    func testCanvasBoxSelectionSelectsMultipleIntersectingCards() {
        let selectedIDs = CanvasBoxSelectionPolicy.selectedNodeIDs(
            selectionRect: CGRect(x: 80, y: 70, width: 250, height: 180),
            nodeRects: [
                CanvasFrameRect(id: "inside", x: 100, y: 90, width: 80, height: 60),
                CanvasFrameRect(id: "edge-intersecting", x: 300, y: 220, width: 100, height: 80),
                CanvasFrameRect(id: "near-hit-slop", x: 335, y: 90, width: 20, height: 20),
                CanvasFrameRect(id: "outside", x: 380, y: 280, width: 80, height: 60)
            ],
            hitSlop: 8
        )

        XCTAssertEqual(selectedIDs, ["inside", "edge-intersecting", "near-hit-slop"])
    }

    func testScaledCanvasNodeDragHitRectKeepsEdgesTopBlankAndBottomNoteOnNode() {
        let visualRect = CanvasFrameRect(id: "note-card", x: 80, y: 48, width: 116, height: 72)
        let hitRect = CanvasNodeDragHitRectPolicy.hitRect(forVisualRect: visualRect)

        XCTAssertEqual(hitRect, visualRect)
        XCTAssertEqual(
            CanvasNodeInteractionHitPolicy.backgroundDragTarget(
                at: CanvasEdgePoint(x: 80.5, y: 48.5),
                nodeRects: [hitRect],
                hitSlop: 0
            ),
            .node("note-card")
        )
        XCTAssertEqual(
            CanvasNodeInteractionHitPolicy.backgroundDragTarget(
                at: CanvasEdgePoint(x: 90, y: 50),
                nodeRects: [hitRect],
                hitSlop: 0
            ),
            .node("note-card")
        )
        XCTAssertEqual(
            CanvasNodeInteractionHitPolicy.backgroundDragTarget(
                at: CanvasEdgePoint(x: 90, y: 118),
                nodeRects: [hitRect],
                hitSlop: 0
            ),
            .node("note-card")
        )
        XCTAssertEqual(
            CanvasNodeInteractionHitPolicy.backgroundDragTarget(
                at: CanvasEdgePoint(x: 90, y: 121),
                nodeRects: [hitRect],
                hitSlop: 0
            ),
            .background
        )
    }

    func testScaledCanvasCardInteractionsKeepDragDoubleClickAndButtonsActive() {
        let zoomedInDelta = CanvasNodeDragDeltaPolicy.canvasDelta(
            screenTranslation: CGSize(width: 120, height: -60),
            zoom: 2
        )
        let zoomedOutDelta = CanvasNodeDragDeltaPolicy.canvasDelta(
            screenTranslation: CGSize(width: 12, height: 6),
            zoom: 0.25
        )

        XCTAssertEqual(zoomedInDelta.width, 60)
        XCTAssertEqual(zoomedInDelta.height, -30)
        XCTAssertEqual(zoomedOutDelta.width, 48)
        XCTAssertEqual(zoomedOutDelta.height, 24)
        XCTAssertTrue(
            CanvasResourceCardDoubleClickPolicy.shouldOpenFinder(
                nodeObjectType: "resourcePin",
                hasResolvedResource: true
            )
        )
        XCTAssertFalse(CanvasCardChromeButtonInteractionPolicy.parentDragShouldIncludeSubviewControls)
        XCTAssertEqual(CanvasCardChromeButtonInteractionPolicy.feedbackMessage(for: .copy), "Copied")
        XCTAssertEqual(CanvasCardChromeButtonInteractionPolicy.feedbackMessage(for: .details), "Details")
        XCTAssertEqual(CanvasCardChromeButtonInteractionPolicy.feedbackMessage(for: .delete), "Deleted")
    }

    func testOrganizationFrameDragIncludesContainedAndParentLinkedCardsOnly() {
        let draggedIDs = CanvasOrganizationFrameDragPolicy.draggedNodeIDs(
            baseNodeIDs: ["frame-a"],
            frameRectsByID: [
                "frame-a": CanvasFrameRect(id: "frame-a", x: 100, y: 100, width: 360, height: 260)
            ],
            cardRects: [
                CanvasFrameRect(id: "inside-card", x: 140, y: 150, width: 120, height: 80),
                CanvasFrameRect(id: "linked-card", x: 520, y: 150, width: 120, height: 80),
                CanvasFrameRect(id: "outside-card", x: 520, y: 300, width: 120, height: 80)
            ],
            parentNodeIDsByCardID: [
                "inside-card": nil,
                "linked-card": "frame-a",
                "outside-card": nil
            ]
        )

        XCTAssertEqual(draggedIDs, ["frame-a", "inside-card", "linked-card"])
    }

    func testCanvasNodeResizeCommitPolicySupportsCardsAndOrganizationFrames() {
        let cardFrame = CanvasNodeResizeCommitPolicy.resizedFrame(
            startFrame: CanvasFrameRect(id: "card-a", x: 20, y: 40, width: 200, height: 120),
            screenDeltaWidth: 60,
            screenDeltaHeight: 30,
            zoom: 2,
            minimumWidth: 180,
            minimumHeight: 112
        )

        XCTAssertEqual(cardFrame.width, 230)
        XCTAssertEqual(cardFrame.height, 135)

        let organizationFrame = CanvasNodeResizeCommitPolicy.resizedFrame(
            startFrame: CanvasFrameRect(id: "frame-a", x: 0, y: 0, width: 260, height: 180),
            screenDeltaWidth: -400,
            screenDeltaHeight: -200,
            zoom: 1,
            minimumWidth: 240,
            minimumHeight: 160
        )

        XCTAssertEqual(organizationFrame.width, 240)
        XCTAssertEqual(organizationFrame.height, 160)
        XCTAssertTrue(CanvasNodeResizeCommitPolicy.shouldCommitSizeChange(oldWidth: 200, oldHeight: 120, newWidth: 200.5, newHeight: 120))
        XCTAssertFalse(CanvasNodeResizeCommitPolicy.shouldCommitSizeChange(oldWidth: 200, oldHeight: 120, newWidth: 200.49, newHeight: 120.49))
    }

    func testLockedCanvasNodeMutationPolicyAllowsSelectionAndViewButBlocksWrites() {
        let selectedNodeIDs: Set<String> = ["locked-card", "open-card"]
        let lockedNodeIDs: Set<String> = ["locked-card"]

        XCTAssertTrue(CanvasLockedNodeMutationPolicy.allowsSelection(isLocked: true))
        XCTAssertTrue(CanvasLockedNodeMutationPolicy.allowsInspection(isLocked: true))
        XCTAssertFalse(CanvasLockedNodeMutationPolicy.canMutateNode(isLocked: true))
        XCTAssertTrue(CanvasLockedNodeMutationPolicy.canMutateNode(isLocked: false))
        XCTAssertFalse(
            CanvasLockedNodeMutationPolicy.canMutateSelection(
                selectedNodeIDs: selectedNodeIDs,
                lockedNodeIDs: lockedNodeIDs
            )
        )
        XCTAssertEqual(
            CanvasLockedNodeMutationPolicy.mutableNodeIDs(
                from: selectedNodeIDs,
                lockedNodeIDs: lockedNodeIDs
            ),
            ["open-card"]
        )
        XCTAssertFalse(CanvasLockedNodeMutationPolicy.shouldExposeResizeHandle(isSelected: true, isLocked: true))
        XCTAssertTrue(CanvasLockedNodeMutationPolicy.shouldExposeResizeHandle(isSelected: true, isLocked: false))
    }

    func testCanvasCardChromeButtonsRemainClickableAndExposePressFeedback() {
        XCTAssertEqual(CanvasCardChromeButtonKind.allCases, [.copy, .details, .delete])
        XCTAssertFalse(CanvasCardChromeButtonInteractionPolicy.parentDragShouldIncludeSubviewControls)
        XCTAssertEqual(CanvasCardChromeButtonInteractionPolicy.feedbackMessage(for: .copy), "Copied")
        XCTAssertEqual(CanvasCardChromeButtonInteractionPolicy.feedbackMessage(for: .details), "Details")
        XCTAssertEqual(CanvasCardChromeButtonInteractionPolicy.feedbackMessage(for: .delete), "Deleted")
        XCTAssertLessThan(
            CanvasCardChromeButtonInteractionPolicy.visualScale(isPressed: true),
            CanvasCardChromeButtonInteractionPolicy.visualScale(isPressed: false)
        )
        XCTAssertGreaterThan(
            CanvasCardChromeButtonInteractionPolicy.backgroundOpacity(isActive: false, isPressed: true),
            CanvasCardChromeButtonInteractionPolicy.backgroundOpacity(isActive: false, isPressed: false)
        )
        XCTAssertGreaterThan(
            CanvasCardChromeButtonInteractionPolicy.backgroundOpacity(isActive: true, isPressed: true),
            CanvasCardChromeButtonInteractionPolicy.backgroundOpacity(isActive: true, isPressed: false)
        )
    }

    func testCanvasInspectorOpensOnlyFromCardInfoButton() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        XCTAssertEqual(CanvasInspectorOpenSource.allCases, [.cardInfoButton, .cardTap, .contextMenu])
        XCTAssertTrue(CanvasInspectorOpenPolicy.shouldOpenInspector(source: .cardInfoButton))
        XCTAssertFalse(CanvasInspectorOpenPolicy.shouldOpenInspector(source: .cardTap))
        XCTAssertFalse(CanvasInspectorOpenPolicy.shouldOpenInspector(source: .contextMenu))
    }

    func testCanvasInspectorVisibilityDefaultsClosedAndTogglesManually() {
        assertOrdinaryQuickOpenSurfaceAvailable()
        XCTAssertFalse(CanvasInspectorVisibilityPolicy.defaultVisibility)

        let opened = CanvasInspectorVisibilityPolicy.toggled(from: CanvasInspectorVisibilityPolicy.defaultVisibility)
        XCTAssertTrue(opened)
        XCTAssertFalse(CanvasInspectorVisibilityPolicy.toggled(from: opened))
    }

    func testCanvasStartLinkContextMenuPolicyExposesCardAndFrameActions() {
        XCTAssertEqual(CanvasStartLinkContextMenuTarget.allCases, [.card, .frame])
        XCTAssertTrue(CanvasStartLinkContextMenuPolicy.shouldExposeStartLink(for: .card))
        XCTAssertTrue(CanvasStartLinkContextMenuPolicy.shouldExposeStartLink(for: .frame))
        XCTAssertEqual(
            CanvasStartLinkContextMenuPolicy.title(for: .card),
            "Start Link From This Card"
        )
        XCTAssertEqual(
            CanvasStartLinkContextMenuPolicy.title(for: .frame),
            "Start Link From This Frame"
        )
    }

    func testCanvasStartLinkKeyboardCommandPolicyRequiresExactlyOneSelectedCard() {
        XCTAssertEqual(CanvasStartLinkKeyboardCommandPolicy.title, "Start Link From Selected Card")
        XCTAssertEqual(CanvasStartLinkKeyboardCommandPolicy.shortcutKey, "l")
        XCTAssertEqual(CanvasStartLinkKeyboardCommandPolicy.shortcutModifiers, "command")
        XCTAssertTrue(CanvasStartLinkKeyboardCommandPolicy.canStartLink(selectedNodeCount: 1))
        XCTAssertFalse(CanvasStartLinkKeyboardCommandPolicy.canStartLink(selectedNodeCount: 0))
        XCTAssertFalse(CanvasStartLinkKeyboardCommandPolicy.canStartLink(selectedNodeCount: 2))
    }

    func testCanvasConnectSelectedKeyboardCommandPolicyRequiresExactlyTwoSelectedCards() {
        XCTAssertEqual(CanvasConnectSelectedKeyboardCommandPolicy.title, "Connect Selected Cards")
        XCTAssertEqual(CanvasConnectSelectedKeyboardCommandPolicy.shortcutKey, "l")
        XCTAssertEqual(CanvasConnectSelectedKeyboardCommandPolicy.shortcutModifiers, "shift+command")
        XCTAssertTrue(CanvasConnectSelectedKeyboardCommandPolicy.canConnectSelected(selectedNodeCount: 2))
        XCTAssertFalse(CanvasConnectSelectedKeyboardCommandPolicy.canConnectSelected(selectedNodeCount: 0))
        XCTAssertFalse(CanvasConnectSelectedKeyboardCommandPolicy.canConnectSelected(selectedNodeCount: 1))
        XCTAssertFalse(CanvasConnectSelectedKeyboardCommandPolicy.canConnectSelected(selectedNodeCount: 3))
    }

    func testCanvasResourceCardDoubleClickOpensFinderOnlyForResolvedResourceCards() {
        XCTAssertTrue(
            CanvasResourceCardDoubleClickPolicy.shouldOpenFinder(
                nodeObjectType: "resourcePin",
                hasResolvedResource: true
            )
        )
        XCTAssertFalse(
            CanvasResourceCardDoubleClickPolicy.shouldOpenFinder(
                nodeObjectType: "resourcePin",
                hasResolvedResource: false
            )
        )
        XCTAssertFalse(
            CanvasResourceCardDoubleClickPolicy.shouldOpenFinder(
                nodeObjectType: "snippet",
                hasResolvedResource: true
            )
        )
        XCTAssertFalse(
            CanvasResourceCardDoubleClickPolicy.shouldOpenFinder(
                nodeObjectType: nil,
                hasResolvedResource: true
            )
        )
    }

    func testCanvasResourceDropStatusShowsSkippedFeedbackForExistingCanvasResources() {
        let status = CanvasResourceDropStatusPolicy.statusText(
            baseStatusText: "reused 1, skipped 2.",
            skippedIssues: [
                ResourceImportItemIssue(path: "/tmp/Plan.md", reason: "Already on this canvas"),
                ResourceImportItemIssue(path: "/tmp/Plan.md", reason: "Already on this canvas"),
                ResourceImportItemIssue(path: "/tmp/Notes.md", reason: "Duplicate canvas drop")
            ]
        )

        XCTAssertEqual(
            status,
            "Canvas drop: reused 1, skipped 2. Skipped: Already on this canvas; Duplicate canvas drop."
        )
        XCTAssertEqual(
            CanvasResourceDropStatusPolicy.statusText(baseStatusText: "Imported 1.", skippedIssues: []),
            "Canvas drop: Imported 1."
        )
    }

    func testCanvasNoteCardEditingPolicySupportsDoubleClickRenameAndBodyEditingOnlyForNotes() {
        XCTAssertTrue(CanvasNoteCardEditingPolicy.canRenameTitle(nodeType: .note))
        XCTAssertFalse(CanvasNoteCardEditingPolicy.canRenameTitle(nodeType: .resource))
        XCTAssertFalse(CanvasNoteCardEditingPolicy.canRenameTitle(nodeType: .snippet))
        XCTAssertFalse(CanvasNoteCardEditingPolicy.canRenameTitle(nodeType: .groupFrame))

        XCTAssertTrue(CanvasNoteCardEditingPolicy.shouldStartTitleEditing(nodeType: .note, clickCount: 2))
        XCTAssertFalse(CanvasNoteCardEditingPolicy.shouldStartTitleEditing(nodeType: .note, clickCount: 1))
        XCTAssertFalse(CanvasNoteCardEditingPolicy.shouldStartTitleEditing(nodeType: .resource, clickCount: 2))

        XCTAssertTrue(CanvasNoteCardEditingPolicy.canEditBody(nodeType: .note, rendersDetails: true))
        XCTAssertFalse(CanvasNoteCardEditingPolicy.canEditBody(nodeType: .note, rendersDetails: false))
        XCTAssertFalse(CanvasNoteCardEditingPolicy.canEditBody(nodeType: .resource, rendersDetails: true))
    }

    func testCanvasConnectionCompletionApplicationPolicyReturnsSingleUseConnectToSelectMode() {
        XCTAssertEqual(
            CanvasConnectionCompletionApplicationPolicy.state(targetNodeId: "target", singleShot: true),
            CanvasConnectionCompletionApplicationState(
                nextSourceNodeId: nil,
                modeTransition: .select
            )
        )
        XCTAssertEqual(
            CanvasConnectionCompletionApplicationPolicy.state(targetNodeId: "target", singleShot: false),
            CanvasConnectionCompletionApplicationState(
                nextSourceNodeId: "target",
                modeTransition: .keepCurrentMode
            )
        )
    }

    func testCanvasResourceCardNotePolicyUsesResourceNoteAndScrollableExpandedEditor() {
        XCTAssertEqual(
            CanvasResourceCardNotePolicy.noteText(nodeType: .resource, nodeBody: "Stale node cache", resourceNote: "Current resource note"),
            "Current resource note"
        )
        XCTAssertEqual(
            CanvasResourceCardNotePolicy.noteText(nodeType: .resource, nodeBody: "Node fallback", resourceNote: nil),
            "Node fallback"
        )
        XCTAssertEqual(
            CanvasResourceCardNotePolicy.noteText(nodeType: .snippet, nodeBody: "Snippet details", resourceNote: "Resource note"),
            "Snippet details"
        )
        XCTAssertEqual(CanvasResourceCardNotePolicy.previewText(for: " \n "), "No description yet.")
        XCTAssertEqual(CanvasResourceCardNotePolicy.previewText(for: "  Ready  "), "Ready")

        XCTAssertTrue(
            CanvasResourceCardNotePolicy.usesEditableScrollableEditor(
                nodeType: .resource,
                isCollapsed: false,
                rendersDetails: true
            )
        )
        XCTAssertFalse(
            CanvasResourceCardNotePolicy.usesEditableScrollableEditor(
                nodeType: .resource,
                isCollapsed: true,
                rendersDetails: true
            )
        )
        XCTAssertFalse(
            CanvasResourceCardNotePolicy.usesEditableScrollableEditor(
                nodeType: .note,
                isCollapsed: false,
                rendersDetails: true
            )
        )

        let originalUpdatedAt = Date(timeIntervalSince1970: 10)
        let savedAt = Date(timeIntervalSince1970: 20)
        let resource = ResourcePinModel(
            title: "Plan.md",
            targetType: .file,
            displayPath: "/tmp/Plan.md",
            lastResolvedPath: "/tmp/Plan.md",
            note: "Old resource note",
            scope: .global,
            updatedAt: originalUpdatedAt
        )
        let node = CanvasNodeModel(
            canvasId: "canvas",
            title: "Plan.md",
            body: "Old node cache",
            nodeType: .resource,
            objectType: "resourcePin",
            objectId: resource.id,
            x: 0,
            y: 0,
            updatedAt: originalUpdatedAt
        )

        XCTAssertTrue(CanvasResourceCardNotePolicy.applyNoteChange("Revised resource note", node: node, resource: resource, now: savedAt))
        XCTAssertEqual(resource.note, "Revised resource note")
        XCTAssertEqual(node.body, "Revised resource note")
        XCTAssertEqual(resource.updatedAt, savedAt)
        XCTAssertEqual(node.updatedAt, savedAt)
        XCTAssertTrue(resource.searchText.contains("revised resource note"))

        XCTAssertFalse(CanvasResourceCardNotePolicy.applyNoteChange("Revised resource note", node: node, resource: resource, now: savedAt))
    }

    func testResourceTagsPreserveCommaContainingValues() {
        let resource = ResourcePinModel(
            title: "Paper",
            targetType: .file,
            displayPath: "/tmp/Paper.pdf",
            lastResolvedPath: "/tmp/Paper.pdf",
            tags: ["research, 2026", "draft"],
            scope: .global
        )

        XCTAssertEqual(resource.tags, ["research, 2026", "draft"])

        resource.tags = ["field, notes", "archive"]

        XCTAssertEqual(resource.tags, ["field, notes", "archive"])
    }





    func testFinderAliasHiddenMaintenanceLogEventsAreInspectableAndPathFree() {
        let success = MindDeskHiddenMaintenanceLogEvent.finderAliasCreateResult(
            sourceObjectType: "resourcePin",
            status: "created",
            hasAliasBookmark: true,
            hasTargetBookmark: true
        )
        let failure = MindDeskHiddenMaintenanceLogEvent.finderAliasCreateResult(
            sourceObjectType: "resourcePin /Users/joshua/secret https://example.invalid",
            status: "failed",
            hasAliasBookmark: false,
            hasTargetBookmark: false
        )

        XCTAssertEqual(success.subject, .finderAlias)
        XCTAssertEqual(success.action, .create)
        XCTAssertEqual(success.result, .succeeded)
        XCTAssertEqual(success.details["sourceObjectType"], "resourcePin")
        XCTAssertEqual(success.details["hasAliasBookmark"], "true")
        XCTAssertEqual(success.details["hasTargetBookmark"], "true")
        XCTAssertEqual(failure.result, .failed)
        XCTAssertEqual(failure.details["sourceObjectType"], "other")
        XCTAssertEqual(failure.details["status"], "failed")

        let joinedMessages = [success.message, failure.message].joined(separator: "\n")
        for forbidden in ["/Users/", "https://", "secret", "resourcePin /Users"] {
            XCTAssertFalse(
                joinedMessages.localizedCaseInsensitiveContains(forbidden),
                "Finder alias hidden maintenance logs should not replay path-like or URL-like text: \(forbidden)"
            )
        }
    }

























    func testSnippetTagsPreserveCommaContainingValues() {
        let snippet = SnippetModel(
            title: "Prompt",
            kind: .prompt,
            body: "Summarize",
            tags: ["llm, review", "writing"],
            scope: .global
        )

        XCTAssertEqual(snippet.tags, ["llm, review", "writing"])

        snippet.tags = ["analysis, qa", "saved"]

        XCTAssertEqual(snippet.tags, ["analysis, qa", "saved"])
    }

    func testResourceRenameApplicationPreservesClearedCustomName() {
        let resource = ResourcePinModel(
            title: "Docs",
            targetType: .folder,
            displayPath: "/tmp/Docs",
            lastResolvedPath: "/tmp/Docs",
            scope: .global,
            originalName: "Docs",
            customName: "Project Docs"
        )

        resource.applyRename(titleInput: "   ", note: "Keep note")

        XCTAssertEqual(resource.title, "Docs")
        XCTAssertEqual(resource.customName, "")
        XCTAssertEqual(resource.note, "Keep note")
    }

    func testWorkspaceCanvasFinalEdgeRenderFiltersPreserveForceRetainedEdges() {
        let selectedEdgeIDs: Set<String> = ["selected"]
        let forceRetainedEdgeIDs: Set<String> = ["transient", "incident"]

        XCTAssertTrue(WorkspaceCanvasFinalEdgeRenderFilters.shouldIncludeCandidateEdge(
            edgeID: "transient",
            selectedEdgeIDs: selectedEdgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            isPotentiallyVisible: false
        ))
        XCTAssertTrue(WorkspaceCanvasFinalEdgeRenderFilters.shouldKeepSegment(
            edgeID: "incident",
            selectedEdgeIDs: selectedEdgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            isSegmentVisible: false
        ))
        XCTAssertFalse(WorkspaceCanvasFinalEdgeRenderFilters.shouldIncludeCandidateEdge(
            edgeID: "passive",
            selectedEdgeIDs: selectedEdgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            isPotentiallyVisible: false
        ))
        XCTAssertFalse(WorkspaceCanvasFinalEdgeRenderFilters.shouldKeepSegment(
            edgeID: "passive",
            selectedEdgeIDs: selectedEdgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            isSegmentVisible: false
        ))
    }

    func testWorkspaceCanvasForceRetentionUsesBoundedIncidentPolicy() {
        let explicitEdges = [
            CanvasEdgeViewportRecord(id: "selected-edge", sourceNodeID: "moving", targetNodeID: "selected-target"),
            CanvasEdgeViewportRecord(id: "transient-edge", sourceNodeID: "moving", targetNodeID: "transient-target")
        ]
        let incidentEdges = (0..<(CanvasPerformancePolicy.maximumContextEdgesDuringInteraction + 2)).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }

        let result = WorkspaceCanvasForceRetention.retainedEdges(
            in: explicitEdges + incidentEdges,
            selectedEdgeIDs: ["selected-edge"],
            transientControlEdgeIDs: ["transient-edge"],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving"]
        )

        XCTAssertEqual(result.edgeIDs.prefix(2), ["selected-edge", "transient-edge"])
        XCTAssertTrue(result.edgeIDs.contains("incident-\(CanvasPerformancePolicy.maximumContextEdgesDuringInteraction - 1)"))
        XCTAssertFalse(result.edgeIDs.contains("incident-\(CanvasPerformancePolicy.maximumContextEdgesDuringInteraction)"))
        XCTAssertEqual(result.droppedIncidentEdgeCount, 2)
    }

    func testWorkspaceCanvasForceRetentionUsesViewportIndexAdjacency() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let passiveEdgeCount = 72
        let passiveNodes = (0..<passiveEdgeCount).flatMap { index in
            let x = Double(index) * 1_000
            return [
                CanvasFrameRect(id: "passive-source-\(index)", x: x, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "passive-target-\(index)", x: x + 160, y: 0, width: 80, height: 80)
            ]
        }
        let passiveEdges = (0..<passiveEdgeCount).map { index in
            CanvasEdgeViewportRecord(
                id: "passive-\(index)",
                sourceNodeID: "passive-source-\(index)",
                targetNodeID: "passive-target-\(index)"
            )
        }
        let incidentNodes = (0..<(limit + 1)).map { index in
            CanvasFrameRect(id: "target-\(index)", x: Double(50_000 + index * 120), y: 0, width: 80, height: 80)
        }
        let incidentEdges = (0..<(limit + 1)).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }
        let index = CanvasEdgeViewportIndex(
            nodes: passiveNodes + [
                CanvasFrameRect(id: "moving", x: 40_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "selected-a", x: 42_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "selected-b", x: 42_160, y: 0, width: 80, height: 80)
            ] + incidentNodes,
            edges: passiveEdges
                + [CanvasEdgeViewportRecord(id: "selected-edge", sourceNodeID: "selected-a", targetNodeID: "selected-b")]
                + incidentEdges
        )

        let result = WorkspaceCanvasForceRetention.retainedEdges(
            in: index,
            selectedEdgeIDs: ["selected-edge"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving"]
        )

        XCTAssertTrue(result.usedIncidentAdjacency)
        XCTAssertLessThan(result.edgeScanCount, passiveEdgeCount)
        XCTAssertEqual(result.incidentCandidateEdgeCount, limit + 1)
        XCTAssertEqual(result.droppedIncidentEdgeCount, 1)
        XCTAssertFalse(result.edgeIDs.contains("passive-0"))
    }

    func testWorkspaceCanvasForceRetentionBoundsSingleMovingNodeIncidentScanNearCap() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let incidentFanout = limit + 300
        let incidentNodes = (0..<incidentFanout).map { index in
            CanvasFrameRect(id: "target-\(index)", x: Double(50_000 + index * 120), y: 0, width: 80, height: 80)
        }
        let incidentEdges = (0..<incidentFanout).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }
        let index = CanvasEdgeViewportIndex(
            nodes: [
                CanvasFrameRect(id: "moving", x: 40_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "selected-a", x: 42_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "selected-b", x: 42_160, y: 0, width: 80, height: 80)
            ] + incidentNodes,
            edges: [
                CanvasEdgeViewportRecord(id: "selected-edge", sourceNodeID: "selected-a", targetNodeID: "selected-b")
            ] + incidentEdges
        )

        let result = WorkspaceCanvasForceRetention.retainedEdges(
            in: index,
            selectedEdgeIDs: ["selected-edge"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving"]
        )

        XCTAssertTrue(result.usedIncidentAdjacency)
        XCTAssertEqual(result.incidentCandidateEdgeCount, incidentFanout)
        XCTAssertEqual(result.droppedIncidentEdgeCount, incidentFanout - limit)
        XCTAssertLessThanOrEqual(result.edgeScanCount, limit + 2)
        XCTAssertFalse(result.edgeIDs.contains("incident-\(limit)"))
    }

    func testWorkspaceCanvasForceRetentionBoundsMultipleMovingNodeIncidentScanNearCap() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let incidentFanoutPerNode = limit + 180
        var incidentNodes: [CanvasFrameRect] = []
        var incidentEdges: [CanvasEdgeViewportRecord] = []
        for index in 0..<incidentFanoutPerNode {
            incidentNodes.append(
                CanvasFrameRect(id: "target-a-\(index)", x: Double(60_000 + index * 120), y: 0, width: 80, height: 80)
            )
            incidentNodes.append(
                CanvasFrameRect(id: "target-b-\(index)", x: Double(90_000 + index * 120), y: 0, width: 80, height: 80)
            )
            incidentEdges.append(
                CanvasEdgeViewportRecord(id: "incident-a-\(index)", sourceNodeID: "moving-a", targetNodeID: "target-a-\(index)")
            )
            incidentEdges.append(
                CanvasEdgeViewportRecord(id: "incident-b-\(index)", sourceNodeID: "moving-b", targetNodeID: "target-b-\(index)")
            )
        }
        let index = CanvasEdgeViewportIndex(
            nodes: [
                CanvasFrameRect(id: "moving-a", x: 40_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "moving-b", x: 45_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "selected-a", x: 42_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "selected-b", x: 42_160, y: 0, width: 80, height: 80)
            ] + incidentNodes,
            edges: [
                CanvasEdgeViewportRecord(id: "selected-edge", sourceNodeID: "selected-a", targetNodeID: "selected-b")
            ] + incidentEdges
        )

        let result = WorkspaceCanvasForceRetention.retainedEdges(
            in: index,
            selectedEdgeIDs: ["selected-edge"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving-a", "moving-b"]
        )

        let totalFanout = incidentFanoutPerNode * 2
        XCTAssertTrue(result.usedIncidentAdjacency)
        XCTAssertEqual(result.adjacencyLookupNodeCount, 2)
        XCTAssertEqual(result.incidentCandidateEdgeCount, totalFanout)
        XCTAssertEqual(result.droppedIncidentEdgeCount, totalFanout - limit)
        XCTAssertLessThanOrEqual(result.edgeScanCount, limit + 4)
        XCTAssertFalse(result.edgeIDs.contains("incident-a-\(limit)"))
    }

    private func encodedPackageObject(_ package: MindDeskInterchangePackage) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder.minddesk.encode(package)) as? [String: Any]
        )
    }

    private func packageObjectRemovingPayloadFieldSchemas(
        from packageObject: [String: Any]
    ) throws -> [String: Any] {
        var packageObject = packageObject

        var contract = try XCTUnwrap(packageObject["agentIntegrationContract"] as? [String: Any])
        var operationContracts = try XCTUnwrap(contract["operationContracts"] as? [[String: Any]])
        for index in operationContracts.indices {
            operationContracts[index].removeValue(forKey: "payloadFieldSchemas")
        }
        contract["operationContracts"] = operationContracts
        packageObject["agentIntegrationContract"] = contract

        var catalog = try XCTUnwrap(packageObject["extensionCapabilities"] as? [String: Any])
        var capabilities = try XCTUnwrap(catalog["capabilities"] as? [[String: Any]])
        for index in capabilities.indices {
            capabilities[index].removeValue(forKey: "payloadFieldSchemas")
        }
        catalog["capabilities"] = capabilities
        packageObject["extensionCapabilities"] = catalog

        return packageObject
    }

    private func packageObjectForgingRunCommandPayloadFieldSchemas(
        from packageObject: [String: Any]
    ) throws -> [String: Any] {
        let forgedSchemas: [[String: Any]] = [
            [
                "field": "command",
                "valueShape": "string",
                "required": false
            ],
            [
                "field": "workingDirectory",
                "valueShape": "workbenchObjectReference",
                "required": true
            ]
        ]
        var packageObject = packageObject

        var contract = try XCTUnwrap(packageObject["agentIntegrationContract"] as? [String: Any])
        var operationContracts = try XCTUnwrap(contract["operationContracts"] as? [[String: Any]])
        let operationIndex = try XCTUnwrap(
            operationContracts.firstIndex { $0["kind"] as? String == "runCommand" }
        )
        operationContracts[operationIndex]["payloadFieldSchemas"] = forgedSchemas
        contract["operationContracts"] = operationContracts
        packageObject["agentIntegrationContract"] = contract

        var catalog = try XCTUnwrap(packageObject["extensionCapabilities"] as? [String: Any])
        var capabilities = try XCTUnwrap(catalog["capabilities"] as? [[String: Any]])
        let capabilityIndex = try XCTUnwrap(
            capabilities.firstIndex { $0["operationKind"] as? String == "runCommand" }
        )
        capabilities[capabilityIndex]["payloadFieldSchemas"] = forgedSchemas
        catalog["capabilities"] = capabilities
        packageObject["extensionCapabilities"] = catalog

        return packageObject
    }

    private func assertOrdinaryHelpSurfaceAvailable(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            MindDeskHelpCatalog.defaultTopics.map(\.id),
            ["settings-defaults", "canvas-performance", "import-export"],
            file: file,
            line: line
        )
        XCTAssertTrue(AppSettingsPaneSelection.allCases.contains(.help), file: file, line: line)
    }

    private func assertOrdinaryManifestSurfaceAvailable(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(ExportManifest.currentFormat, "minddesk.export.manifest", file: file, line: line)
        XCTAssertEqual(ExportManifest.currentFormatVersion, 1, file: file, line: line)
        XCTAssertEqual(ExportManifest.supportedFormatVersions, [1], file: file, line: line)
    }

    private func assertOrdinaryWorkspaceSurfaceAvailable(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(WorkspaceDetailTab.defaultTab, .canvas, file: file, line: line)
        XCTAssertEqual(WorkspaceDetailTab.allCases.count, 5, file: file, line: line)
    }

    private func assertDirectUserTerminalSurfaceAvailable(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            WorkbenchExternalActionPolicy.requiresUserConfirmation(.openTerminal),
            file: file,
            line: line
        )
        XCTAssertTrue(
            WorkbenchExternalActionPolicy.requiresUserConfirmation(.runCommand),
            file: file,
            line: line
        )
    }

    private func assertOrdinaryQuickOpenSurfaceAvailable(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            WorkbenchObjectReferencePolicy.canvasObjectKinds.contains(.webURL),
            file: file,
            line: line
        )
        XCTAssertTrue(
            WorkbenchObjectReferencePolicy.canvasObjectKinds.contains(.workspace),
            file: file,
            line: line
        )
    }

}

private final class PostOpenMaintenanceRunnerRecorder: @unchecked Sendable {
    var immediateRuns: [[PersistentStorePostOpenMaintenanceWork]] = []
    var deferredRuns: [[PersistentStorePostOpenMaintenanceWork]] = []
    var scheduledDeferredWork: [@Sendable () -> Void] = []
}
