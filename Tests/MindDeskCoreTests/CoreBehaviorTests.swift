import XCTest
@testable import MindDeskCore

final class CoreBehaviorTests: XCTestCase {
    func testShellQuoterHandlesSpacesAndSingleQuotes() {
        XCTAssertEqual(ShellQuoter.singleQuote("/tmp/My Folder"), "'/tmp/My Folder'")
        XCTAssertEqual(ShellQuoter.singleQuote("/tmp/Joshua's Work"), "'/tmp/Joshua'\\''s Work'")
    }

    func testAppleScriptStringEscapesQuotesAndBackslashes() {
        XCTAssertEqual(ShellQuoter.appleScriptString("say \"hi\" \\"), "\"say \\\"hi\\\" \\\\\"")
    }

    func testAppleScriptStringEscapesLineSeparators() {
        XCTAssertEqual(
            ShellQuoter.appleScriptString("one\rtwo\u{2028}three\u{2029}four"),
            "\"one\" & character id 13 & \"two\" & character id 8232 & \"three\" & character id 8233 & \"four\""
        )
    }

    func testTerminalCommandStopsWhenCdFails() {
        XCTAssertEqual(
            ShellQuoter.terminalCommand(command: "rm -rf build", workingDirectory: "/tmp/Missing Folder"),
            "cd -- '/tmp/Missing Folder' && rm -rf build"
        )
        XCTAssertEqual(
            ShellQuoter.changeDirectoryCommand(workingDirectory: "-P"),
            "cd -- '-P'"
        )
        XCTAssertEqual(
            ShellQuoter.terminalCommand(command: "pwd", workingDirectory: "-P"),
            "cd -- '-P' && pwd"
        )
    }

    func testPersistentStoreLayoutUsesMindDeskStoreDirectoryWithLegacyMigrationSource() {
        let support = URL(fileURLWithPath: "/tmp/Application Support", isDirectory: true)
        let layout = MindDeskStoreLayout(applicationSupportDirectory: support)
        let previousBundleIdentifier = ["studio", "qiushan", "my" + "desk"].joined(separator: ".")
        let previousStoreFileName = "My" + "Desk.store"

        XCTAssertEqual(
            layout.storeURL.path,
            "/tmp/Application Support/studio.qiushan.minddesk/Stores/MindDesk.store"
        )
        XCTAssertEqual(
            layout.legacyStoreURL.path,
            "/tmp/Application Support/\(previousBundleIdentifier)/Stores/\(previousStoreFileName)"
        )
        XCTAssertEqual(layout.legacyDefaultStoreURL.path, "/tmp/Application Support/default.store")
        XCTAssertEqual(
            layout.backupDirectory.path,
            "/tmp/Application Support/studio.qiushan.minddesk/Backups"
        )
        XCTAssertEqual(
            layout.quarantineDirectory.path,
            "/tmp/Application Support/studio.qiushan.minddesk/Quarantine"
        )
    }

    func testPersistentStoreLayoutTreatsSQLiteCompanionsAsOneStore() {
        let store = URL(fileURLWithPath: "/tmp/MindDesk.store")

        XCTAssertEqual(
            MindDeskStoreLayout.sqliteFileSet(for: store).map(\.lastPathComponent),
            ["MindDesk.store", "MindDesk.store-wal", "MindDesk.store-shm"]
        )
    }

    func testPersistentStoreBackupRetentionDeletesOldestFoldersFirst() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let folders = [
            backupRoot.appendingPathComponent("20260430-091100", isDirectory: true),
            backupRoot.appendingPathComponent("20260430-091300", isDirectory: true),
            backupRoot.appendingPathComponent("20260430-091200", isDirectory: true),
            backupRoot.appendingPathComponent("not-a-backup", isDirectory: true)
        ]

        XCTAssertEqual(
            MindDeskStoreLayout.backupFoldersToPrune(folders, keepingNewest: 2).map(\.lastPathComponent),
            ["20260430-091100"]
        )
    }

    func testPersistentStoreBackupRetentionRecognizesSameSecondSuffixedFolders() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let folders = [
            backupRoot.appendingPathComponent("20260430-091100", isDirectory: true),
            backupRoot.appendingPathComponent("20260430-091200", isDirectory: true),
            backupRoot.appendingPathComponent("20260430-091300", isDirectory: true),
            backupRoot.appendingPathComponent("20260430-091300-abcdef12", isDirectory: true),
            backupRoot.appendingPathComponent("not-a-backup-20260430-091000", isDirectory: true)
        ]

        XCTAssertEqual(
            MindDeskStoreLayout.backupFoldersToPrune(folders, keepingNewest: 2).map(\.lastPathComponent),
            ["20260430-091100", "20260430-091200"]
        )
    }

    func testPersistentStoreDefaultBackupRetentionKeepsNewestTwentyFolders() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let folders = (0..<22).map { minute in
            backupRoot.appendingPathComponent(
                String(format: "20260430-09%02d00-startup", minute),
                isDirectory: true
            )
        }

        XCTAssertEqual(MindDeskStoreLayout.backupRetentionCount, 20)
        XCTAssertEqual(
            MindDeskStoreLayout.backupFoldersToPrune(
                folders,
                keepingNewest: MindDeskStoreLayout.backupRetentionCount
            ).map(\.lastPathComponent),
            ["20260430-090000-startup", "20260430-090100-startup"]
        )
    }

    func testPersistentStoreStartupBackupPolicySkipsRecentBackup() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let now = Date(timeIntervalSince1970: 1_800_000)
        let recentBackup = backupRoot.appendingPathComponent(
            MindDeskStoreLayout.backupFolderName(
                for: now.addingTimeInterval(-20 * 60),
                reason: .startup
            ),
            isDirectory: true
        )

        XCTAssertFalse(
            MindDeskStoreLayout.shouldCreateStartupBackup(
                storeExists: true,
                backupFolders: [recentBackup],
                now: now
            )
        )
    }

    func testPersistentStoreStartupBackupPolicyCreatesWhenBackupIsStale() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let now = Date(timeIntervalSince1970: 1_800_000)
        let staleBackup = backupRoot.appendingPathComponent(
            MindDeskStoreLayout.backupFolderName(
                for: now.addingTimeInterval(-31 * 60),
                reason: .startup
            ),
            isDirectory: true
        )

        XCTAssertTrue(
            MindDeskStoreLayout.shouldCreateStartupBackup(
                storeExists: true,
                backupFolders: [staleBackup],
                now: now
            )
        )
        XCTAssertFalse(
            MindDeskStoreLayout.shouldCreateStartupBackup(
                storeExists: false,
                backupFolders: [staleBackup],
                now: now
            )
        )
    }

    func testPersistentStoreStartupBackupPolicyIsThrottledByRecentMigrationBackup() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let now = Date(timeIntervalSince1970: 1_800_000)
        let recentMigrationBackup = backupRoot.appendingPathComponent(
            MindDeskStoreLayout.backupFolderName(
                for: now.addingTimeInterval(-5 * 60),
                reason: .migration
            ),
            isDirectory: true
        )

        XCTAssertFalse(
            MindDeskStoreLayout.shouldCreateStartupBackup(
                storeExists: true,
                backupFolders: [recentMigrationBackup],
                now: now
            )
        )
    }

    func testPersistentStoreBackupFolderNameSupportsMigrationReasonSuffix() {
        let date = Date(timeIntervalSince1970: 1_800_000)

        XCTAssertEqual(
            MindDeskStoreLayout.backupFolderName(for: date, reason: .migration),
            "19700121-200000-migration"
        )
        XCTAssertEqual(
            MindDeskStoreLayout.backupFolderName(for: date, reason: .failedOpen),
            "19700121-200000-failed-open"
        )
    }

    func testPersistentStoreRecoveryCandidatesPreferNewestTimestampedBackup() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let folders = [
            backupRoot.appendingPathComponent("20260430-091100-startup", isDirectory: true),
            backupRoot.appendingPathComponent("20260430-091500-migration", isDirectory: true),
            backupRoot.appendingPathComponent("not-a-backup", isDirectory: true),
            backupRoot.appendingPathComponent(".20260430-091700-startup.incomplete-abcd", isDirectory: true),
            backupRoot.appendingPathComponent("20260430-091300-restore", isDirectory: true)
        ]

        XCTAssertEqual(
            MindDeskStoreLayout.recoveryCandidateFolders(folders).map(\.lastPathComponent),
            ["20260430-091500-migration", "20260430-091300-restore", "20260430-091100-startup"]
        )
    }

    func testPersistentStoreIncompleteBackupFolderNamesAreStrict() {
        XCTAssertTrue(MindDeskStoreLayout.isIncompleteBackupFolderName(".20260430-091700-startup.incomplete-abcd"))
        XCTAssertTrue(MindDeskStoreLayout.isIncompleteBackupFolderName(".20260430-091700.incomplete-abcd"))
        XCTAssertFalse(MindDeskStoreLayout.isIncompleteBackupFolderName("20260430-091700-startup.incomplete-abcd"))
        XCTAssertFalse(MindDeskStoreLayout.isIncompleteBackupFolderName(".not-a-backup.incomplete-abcd"))
        XCTAssertFalse(MindDeskStoreLayout.isIncompleteBackupFolderName(".20260430-091700-startup.incomplete-"))
    }

    func testPersistentStoreBackupFolderNamesRejectInvalidDates() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let folders = [
            backupRoot.appendingPathComponent("20260430-091100-startup", isDirectory: true),
            backupRoot.appendingPathComponent("20269999-999999-startup", isDirectory: true),
            backupRoot.appendingPathComponent("20260230-120000-startup", isDirectory: true)
        ]

        XCTAssertEqual(
            MindDeskStoreLayout.recoveryCandidateFolders(folders).map(\.lastPathComponent),
            ["20260430-091100-startup"]
        )
        XCTAssertFalse(
            MindDeskStoreLayout.isIncompleteBackupFolderName(".20269999-999999-startup.incomplete-abcd")
        )
    }

    func testCanvasAutoArrangeProducesGridPositions() {
        let nodes = [
            CanvasLayoutNode(id: "a", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "b", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "c", x: 0, y: 0, width: 120, height: 80)
        ]
        let arranged = CanvasLayoutEngine.autoArrange(nodes, columns: 2, spacing: 40)
        XCTAssertEqual(arranged[0].x, 0)
        XCTAssertEqual(arranged[1].x, 160)
        XCTAssertEqual(arranged[2].y, 120)
    }

    func testCanvasAutoArrangeGridUsesColumnWidthsToAvoidOverlap() {
        let nodes = [
            CanvasLayoutNode(id: "wide", x: 0, y: 0, width: 360, height: 80),
            CanvasLayoutNode(id: "right", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "bottom", x: 0, y: 0, width: 180, height: 80)
        ]

        let arranged = CanvasLayoutEngine.autoArrange(nodes, columns: 2, spacing: 40)

        XCTAssertEqual(arranged[1].x, 400)
        XCTAssertFalse(layoutNodesOverlap(arranged))
    }

    func testCanvasAutoArrangeUsesEdgesForLeftToRightWorkflowLayers() {
        let nodes = [
            CanvasLayoutNode(id: "finish", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "source", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "branch", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "middle", x: 0, y: 0, width: 120, height: 80)
        ]
        let edges = [
            CanvasLayoutEdge(sourceNodeId: "source", targetNodeId: "middle"),
            CanvasLayoutEdge(sourceNodeId: "source", targetNodeId: "branch"),
            CanvasLayoutEdge(sourceNodeId: "middle", targetNodeId: "finish")
        ]

        let arranged = Dictionary(
            uniqueKeysWithValues: CanvasLayoutEngine.autoArrange(
                nodes,
                edges: edges,
                horizontalSpacing: 80,
                verticalSpacing: 40
            ).map { ($0.id, $0) }
        )

        XCTAssertLessThan(arranged["source"]!.x, arranged["middle"]!.x)
        XCTAssertLessThan(arranged["source"]!.x, arranged["branch"]!.x)
        XCTAssertLessThan(arranged["middle"]!.x, arranged["finish"]!.x)
        XCTAssertEqual(arranged["middle"]!.x, arranged["branch"]!.x)
        XCTAssertLessThan(arranged["middle"]!.y, arranged["branch"]!.y)
    }

    func testCanvasAutoArrangePlacesDisconnectedNodesAfterWorkflowWithoutOverlap() {
        let nodes = [
            CanvasLayoutNode(id: "source", x: 0, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "target", x: 0, y: 0, width: 140, height: 90),
            CanvasLayoutNode(id: "loose-a", x: 0, y: 0, width: 180, height: 110),
            CanvasLayoutNode(id: "loose-b", x: 0, y: 0, width: 120, height: 80)
        ]
        let edges = [
            CanvasLayoutEdge(sourceNodeId: "source", targetNodeId: "target")
        ]

        let arranged = CanvasLayoutEngine.autoArrange(
            nodes,
            edges: edges,
            horizontalSpacing: 80,
            verticalSpacing: 40
        )
        let byId = Dictionary(uniqueKeysWithValues: arranged.map { ($0.id, $0) })
        let workflowBottom = max(byId["source"]!.y + byId["source"]!.height, byId["target"]!.y + byId["target"]!.height)

        XCTAssertGreaterThan(byId["loose-a"]!.y, workflowBottom)
        XCTAssertGreaterThan(byId["loose-b"]!.y, workflowBottom)
        XCTAssertFalse(layoutNodesOverlap(arranged))
    }

    func testAlignLeftUsesMinimumX() {
        let nodes = [
            CanvasLayoutNode(id: "a", x: 50, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "b", x: 10, y: 20, width: 120, height: 80)
        ]
        let aligned = CanvasLayoutEngine.alignLeft(nodes)
        XCTAssertEqual(aligned.map(\.x), [10, 10])
    }

    func testAlignTopUsesMinimumY() {
        let nodes = [
            CanvasLayoutNode(id: "a", x: 0, y: 50, width: 120, height: 80),
            CanvasLayoutNode(id: "b", x: 20, y: 10, width: 120, height: 80)
        ]
        let aligned = CanvasLayoutEngine.alignTop(nodes)
        XCTAssertEqual(aligned.map(\.y), [10, 10])
    }

    private func layoutNodesOverlap(_ nodes: [CanvasLayoutNode]) -> Bool {
        for lhsIndex in nodes.indices {
            for rhsIndex in nodes.indices where rhsIndex > lhsIndex {
                let lhs = nodes[lhsIndex]
                let rhs = nodes[rhsIndex]
                let separated = lhs.x + lhs.width <= rhs.x ||
                    rhs.x + rhs.width <= lhs.x ||
                    lhs.y + lhs.height <= rhs.y ||
                    rhs.y + rhs.height <= lhs.y
                if !separated {
                    return true
                }
            }
        }
        return false
    }


    func testWorkspaceSidebarOrderingPinsFirstThenUsesStableSort() {
        let older = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        let records = [
            WorkspaceSidebarOrderRecord(id: "recent", isPinned: false, sortIndex: 0, updatedAt: newer),
            WorkspaceSidebarOrderRecord(id: "pinned-later", isPinned: true, sortIndex: 20, updatedAt: older),
            WorkspaceSidebarOrderRecord(id: "pinned-earlier", isPinned: true, sortIndex: 10, updatedAt: newer),
            WorkspaceSidebarOrderRecord(id: "old", isPinned: false, sortIndex: 0, updatedAt: older)
        ]

        XCTAssertEqual(
            WorkspaceSidebarOrdering.ordered(records).map(\.id),
            ["pinned-earlier", "pinned-later", "recent", "old"]
        )
    }

    func testWorkspaceSidebarOrderingMovesItemsWithinCurrentOrder() {
        XCTAssertEqual(
            WorkspaceSidebarOrdering.movedIDs(["a", "b", "c"], moving: "b", direction: .up),
            ["b", "a", "c"]
        )
        XCTAssertEqual(
            WorkspaceSidebarOrdering.movedIDs(["a", "b", "c"], moving: "b", direction: .down),
            ["a", "c", "b"]
        )
        XCTAssertEqual(
            WorkspaceSidebarOrdering.movedIDs(["a", "b", "c"], moving: "missing", direction: .up),
            ["a", "b", "c"]
        )
    }

    func testWorkspaceSidebarOrderingMovesDraggedRowsWithinCurrentOrder() {
        XCTAssertEqual(
            WorkspaceSidebarOrdering.movedIDs(["a", "b", "c", "d"], fromOffsets: IndexSet(integer: 1), toOffset: 3),
            ["a", "c", "b", "d"]
        )
        XCTAssertEqual(
            WorkspaceSidebarOrdering.movedIDs(["a", "b", "c", "d"], fromOffsets: IndexSet([1, 2]), toOffset: 4),
            ["a", "d", "b", "c"]
        )
        XCTAssertEqual(
            WorkspaceSidebarOrdering.movedIDs(["a", "b", "c"], fromOffsets: IndexSet(integer: 9), toOffset: 1),
            ["a", "b", "c"]
        )
    }

    func testWorkspaceSidebarOrderingKeepsPinnedItemsBeforeUnpinnedItems() {
        let pinned = Set(["pinned-a", "pinned-b"])

        XCTAssertTrue(
            WorkspaceSidebarOrdering.keepsPinnedPrefix(["pinned-a", "pinned-b", "regular-a"], pinnedIDs: pinned)
        )
        XCTAssertTrue(
            WorkspaceSidebarOrdering.keepsPinnedPrefix(["regular-a", "regular-b"], pinnedIDs: pinned)
        )
        XCTAssertFalse(
            WorkspaceSidebarOrdering.keepsPinnedPrefix(["regular-a", "pinned-a", "regular-b"], pinnedIDs: pinned)
        )
    }

    func testWorkbenchSidebarMetricsAreCompactButReadable() {
        XCTAssertLessThan(WorkbenchSidebarMetrics.idealWidth, 240)
        XCTAssertGreaterThanOrEqual(WorkbenchSidebarMetrics.minimumWidth, 200)
        XCTAssertGreaterThanOrEqual(WorkbenchSidebarMetrics.maximumWidth, WorkbenchSidebarMetrics.idealWidth)
    }

    func testWorkspaceCanvasTodoPreferenceKeysAreStable() {
        XCTAssertEqual(AppPreferenceKeys.canvasScrollZoomDirection, "canvasScrollZoomDirection")
        XCTAssertEqual(AppPreferenceKeys.canvasDefaultZoomPercent, "canvasDefaultZoomPercent")
        XCTAssertEqual(AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen, "workspaceCanvasTodoPanelDefaultOpen")
        XCTAssertEqual(AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen, "workspaceCanvasTodoDoneColumnDefaultOpen")
        XCTAssertEqual(AppPreferenceKeys.workspaceCanvasTodoDoneColumnOpen, "workspaceCanvasTodoDoneColumnOpen")
        XCTAssertEqual(AppPreferenceKeys.workspaceCanvasTodoColumnRatio, "workspaceCanvasTodoColumnRatio")
        XCTAssertEqual(AppPreferenceKeys.canvasConnectSingleShot, "canvasConnectSingleShot")
        XCTAssertEqual(AppPreferenceKeys.appearanceMode, "appearanceMode")
        XCTAssertEqual(AppPreferenceKeys.interfaceTextScale, "interfaceTextScale")
        XCTAssertEqual(AppPreferenceKeys.interfaceDensity, "interfaceDensity")
        XCTAssertEqual(AppPreferenceKeys.startupDestination, "startupDestination")
        XCTAssertEqual(AppPreferenceKeys.manifestExportScope, "manifestExportScope")
        XCTAssertEqual(AppPreferenceKeys.manifestExportIncludesUsageDates, "manifestExportIncludesUsageDates")
    }

    func testAppPreferenceEnumsResolveInvalidValuesToSafeDefaults() {
        XCTAssertEqual(AppAppearanceMode.resolved("unknown"), .system)
        XCTAssertEqual(AppInterfaceTextScale.resolved("unknown"), .system)
        XCTAssertEqual(AppInterfaceDensity.resolved("unknown"), .balanced)
        XCTAssertEqual(AppStartupDestination.resolved("unknown"), .home)
        XCTAssertEqual(ManifestExportScope.resolved("unknown"), .completeWorkspaceMap)
    }

    func testAppPreferenceDefaultsRestoreGlobalSettingsAndClearObsoleteViewState() throws {
        let suiteName = "MindDeskTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(AppAppearanceMode.dark.rawValue, forKey: AppPreferenceKeys.appearanceMode)
        defaults.set(AppInterfaceTextScale.extraLarge.rawValue, forKey: AppPreferenceKeys.interfaceTextScale)
        defaults.set(AppInterfaceDensity.spacious.rawValue, forKey: AppPreferenceKeys.interfaceDensity)
        defaults.set(AppStartupDestination.snippets.rawValue, forKey: AppPreferenceKeys.startupDestination)
        defaults.set(ManifestExportScope.globalLibraryOnly.rawValue, forKey: AppPreferenceKeys.manifestExportScope)
        defaults.set(true, forKey: AppPreferenceKeys.manifestExportIncludesUsageDates)
        defaults.set(CanvasScrollZoomDirection.scrollDownZoomsIn.rawValue, forKey: AppPreferenceKeys.canvasScrollZoomDirection)
        defaults.set(250.0, forKey: AppPreferenceKeys.canvasDefaultZoomPercent)
        defaults.set(false, forKey: AppPreferenceKeys.canvasConnectSingleShot)
        defaults.set(true, forKey: AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen)
        defaults.set(true, forKey: AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen)
        defaults.set(0.7, forKey: AppPreferenceKeys.workspaceCanvasTodoColumnRatio)
        defaults.set(true, forKey: AppPreferenceKeys.workspaceCanvasTodoDoneColumnOpen)

        AppPreferenceDefaults.restore(in: defaults)

        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.appearanceMode), AppAppearanceMode.system.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.interfaceTextScale), AppInterfaceTextScale.system.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.interfaceDensity), AppInterfaceDensity.balanced.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.startupDestination), AppStartupDestination.home.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.manifestExportScope), ManifestExportScope.completeWorkspaceMap.rawValue)
        XCTAssertFalse(defaults.bool(forKey: AppPreferenceKeys.manifestExportIncludesUsageDates))
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.canvasScrollZoomDirection), CanvasScrollZoomDirection.scrollDownZoomsOut.rawValue)
        XCTAssertEqual(defaults.double(forKey: AppPreferenceKeys.canvasDefaultZoomPercent), CanvasZoomBaseline.defaultPercent, accuracy: 0.0001)
        XCTAssertTrue(defaults.bool(forKey: AppPreferenceKeys.canvasConnectSingleShot))
        XCTAssertFalse(defaults.bool(forKey: AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen))
        XCTAssertFalse(defaults.bool(forKey: AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen))
        XCTAssertEqual(defaults.double(forKey: AppPreferenceKeys.workspaceCanvasTodoColumnRatio), TodoBoardColumnSplit.defaultRatio, accuracy: 0.0001)
        XCTAssertNil(defaults.object(forKey: AppPreferenceKeys.workspaceCanvasTodoDoneColumnOpen))
    }

    func testWorkspaceRecencyOrderingUsesLastOpenedBeforeSidebarOrder() {
        let old = Date(timeIntervalSince1970: 100)
        let recent = Date(timeIntervalSince1970: 300)
        let fallbackUpdated = Date(timeIntervalSince1970: 200)
        let records = [
            WorkspaceRecencyRecord(id: "pinned-old", lastOpenedAt: old, updatedAt: Date(timeIntervalSince1970: 900)),
            WorkspaceRecencyRecord(id: "recent", lastOpenedAt: recent, updatedAt: old),
            WorkspaceRecencyRecord(id: "fallback", lastOpenedAt: nil, updatedAt: fallbackUpdated)
        ]

        XCTAssertEqual(
            WorkspaceRecencyOrdering.recent(records, limit: 3).map(\.id),
            ["recent", "fallback", "pinned-old"]
        )
        XCTAssertEqual(
            WorkspaceRecencyOrdering.recent(records, limit: 2).map(\.id),
            ["recent", "fallback"]
        )
    }

    func testExportManifestUsageDatePolicyRemovesBehaviorDatesOnly() {
        let usageDate = Date(timeIntervalSince1970: 123)
        let createdAt = Date(timeIntervalSince1970: 456)
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 789),
            workspaces: [
                WorkspaceRecord(
                    id: "workspace",
                    title: "Workspace",
                    details: "",
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    lastOpenedAt: usageDate
                )
            ],
            resources: [
                ResourceRecord(
                    id: "resource",
                    workspaceId: nil,
                    title: "Resource",
                    targetType: "folder",
                    displayPath: "/tmp/resource",
                    lastResolvedPath: "/tmp/resource",
                    note: "",
                    tags: [],
                    scope: "global",
                    status: "available",
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    lastOpenedAt: usageDate
                )
            ],
            snippets: [
                SnippetRecord(
                    id: "snippet",
                    workspaceId: nil,
                    title: "Snippet",
                    kind: "prompt",
                    body: "Body",
                    details: "",
                    tags: [],
                    scope: "global",
                    workingDirectoryRef: nil,
                    requiresConfirmation: false,
                    lastCopiedAt: usageDate,
                    lastUsedAt: usageDate,
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
            ],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )

        let redacted = ExportManifestUsageDatePolicy.removingUsageDates(from: manifest)

        XCTAssertNil(redacted.workspaces.first?.lastOpenedAt)
        XCTAssertNil(redacted.resources.first?.lastOpenedAt)
        XCTAssertNil(redacted.snippets.first?.lastCopiedAt)
        XCTAssertNil(redacted.snippets.first?.lastUsedAt)
        XCTAssertEqual(redacted.workspaces.first?.createdAt, createdAt)
        XCTAssertEqual(redacted.resources.first?.updatedAt, createdAt)
        XCTAssertEqual(redacted.exportedAt, manifest.exportedAt)
    }

    func testExportManifestScopePolicyCanExportOnlyGlobalLibraryMetadata() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(
                    id: "workspace",
                    title: "Workspace",
                    details: "",
                    createdAt: Date(timeIntervalSince1970: 0),
                    updatedAt: Date(timeIntervalSince1970: 0),
                    lastOpenedAt: nil
                )
            ],
            resources: [
                ResourceRecord(
                    id: "global-resource",
                    workspaceId: nil,
                    title: "Global",
                    targetType: "folder",
                    displayPath: "/tmp/global",
                    lastResolvedPath: "/tmp/global",
                    note: "",
                    tags: [],
                    scope: "global",
                    status: "available"
                ),
                ResourceRecord(
                    id: "workspace-resource",
                    workspaceId: "workspace",
                    title: "Workspace",
                    targetType: "folder",
                    displayPath: "/tmp/workspace",
                    lastResolvedPath: "/tmp/workspace",
                    note: "",
                    tags: [],
                    scope: "workspace",
                    status: "available"
                )
            ],
            snippets: [
                SnippetRecord(
                    id: "global-snippet",
                    workspaceId: nil,
                    title: "Global Snippet",
                    kind: "prompt",
                    body: "Body",
                    details: "",
                    tags: [],
                    scope: "global",
                    workingDirectoryRef: "global-resource",
                    requiresConfirmation: false
                ),
                SnippetRecord(
                    id: "dangling-global-snippet",
                    workspaceId: nil,
                    title: "Dangling Global Snippet",
                    kind: "prompt",
                    body: "Body",
                    details: "",
                    tags: [],
                    scope: "global",
                    workingDirectoryRef: "workspace-resource",
                    requiresConfirmation: false
                ),
                SnippetRecord(
                    id: "workspace-snippet",
                    workspaceId: "workspace",
                    title: "Workspace Snippet",
                    kind: "prompt",
                    body: "Body",
                    details: "",
                    tags: [],
                    scope: "workspace",
                    workingDirectoryRef: nil,
                    requiresConfirmation: false
                )
            ],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Canvas", viewportX: 0, viewportY: 0, zoom: 1)
            ],
            nodes: [
                CanvasNodeRecord(id: "node", canvasId: "canvas", title: "Node", body: "", nodeType: "note", objectType: nil, objectId: nil, x: 0, y: 0, width: 100, height: 100)
            ],
            edges: [
                CanvasEdgeRecord(id: "edge", canvasId: "canvas", sourceNodeId: "node", targetNodeId: "node", label: "")
            ],
            aliases: [
                AliasRecord(id: "alias", sourceObjectType: "resourcePin", sourceObjectId: "global-resource", aliasDisplayPath: "/tmp/alias", status: "created")
            ]
        )

        let globalOnly = ExportManifestScopePolicy.manifest(
            from: manifest,
            scope: .globalLibraryOnly
        )

        XCTAssertEqual(globalOnly.workspaces, [])
        XCTAssertEqual(globalOnly.resources.map(\.id), ["global-resource"])
        XCTAssertEqual(globalOnly.snippets.map(\.id), ["global-snippet", "dangling-global-snippet"])
        XCTAssertEqual(globalOnly.snippets.first { $0.id == "global-snippet" }?.workingDirectoryRef, "global-resource")
        XCTAssertNil(globalOnly.snippets.first { $0.id == "dangling-global-snippet" }?.workingDirectoryRef)
        XCTAssertEqual(globalOnly.canvases, [])
        XCTAssertEqual(globalOnly.nodes, [])
        XCTAssertEqual(globalOnly.edges, [])
        XCTAssertEqual(globalOnly.aliases, [])
    }

    func testCanvasConnectionPolicySupportsSingleShotAndChainModes() {
        XCTAssertEqual(
            CanvasConnectionPolicy.completion(targetNodeId: "b", singleShot: true),
            CanvasConnectionCompletion(nextSourceNodeId: nil, returnsToSelectMode: true)
        )
        XCTAssertEqual(
            CanvasConnectionPolicy.completion(targetNodeId: "b", singleShot: false),
            CanvasConnectionCompletion(nextSourceNodeId: "b", returnsToSelectMode: false)
        )
    }

    func testCanvasConnectSourcePolicyStartsLinkFromSelectedCard() {
        XCTAssertEqual(
            CanvasConnectSourcePolicy.start(from: "node-a"),
            CanvasConnectSourceCommand(
                nextSourceNodeId: "node-a",
                selectedNodeIDs: ["node-a"],
                entersConnectMode: true
            )
        )
    }

    func testCanvasEdgeDirectionPolicyReversesEndpointsAndKeepsTargetArrow() {
        let reversed = CanvasEdgeDirectionPolicy.reversed(
            CanvasEdgeDirectionRecord(
                id: "edge-1",
                sourceNodeId: "a",
                targetNodeId: "b",
                sourceArrow: "none",
                targetArrow: "arrow"
            )
        )

        XCTAssertEqual(reversed.sourceNodeId, "b")
        XCTAssertEqual(reversed.targetNodeId, "a")
        XCTAssertEqual(reversed.sourceArrow, "none")
        XCTAssertEqual(reversed.targetArrow, "arrow")
    }

    func testCanvasEdgeDirectionPolicyRejectsDuplicateOppositeDirection() {
        let edge = CanvasEdgeDirectionRecord(
            id: "edge-1",
            sourceNodeId: "a",
            targetNodeId: "b",
            sourceArrow: "none",
            targetArrow: "arrow"
        )
        let existing = [
            CanvasEdgeEndpointRecord(id: "edge-1", sourceNodeId: "a", targetNodeId: "b"),
            CanvasEdgeEndpointRecord(id: "edge-2", sourceNodeId: "b", targetNodeId: "a")
        ]

        XCTAssertFalse(CanvasEdgeDirectionPolicy.canReverse(edge, existingEdges: existing))
        XCTAssertTrue(CanvasEdgeDirectionPolicy.canReverse(edge, existingEdges: Array(existing.prefix(1))))
    }


    func testCanvasPerformancePolicyDisablesExpensiveRoutingWhileInteractingOrDense() {
        XCTAssertTrue(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 20, obstacleCount: 40, isInteracting: false))
        XCTAssertTrue(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 24, obstacleCount: 37, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 20, obstacleCount: 40, isInteracting: true))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 1, obstacleCount: CanvasPerformancePolicy.maximumRoutingObstacleCount + 1, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: CanvasPerformancePolicy.maximumRoutedEdgeCount + 1, obstacleCount: 20, isInteracting: false))
    }

    func testCanvasPerformancePolicyUsesChosenLimits() {
        XCTAssertEqual(CanvasPerformancePolicy.maximumRoutedEdgeCount, 24)
        XCTAssertEqual(CanvasPerformancePolicy.maximumRoutingObstacleCount, 40)
        XCTAssertEqual(CanvasPerformancePolicy.maximumRoutingWorkload, 900)
        XCTAssertEqual(CanvasPerformancePolicy.maximumAnimatedEdgeCount, 16)
        XCTAssertEqual(CanvasPerformancePolicy.maximumAnimatedVisibleEdgeCount, 12)
        XCTAssertEqual(CanvasPerformancePolicy.maximumAnimatedVisibleCardCount, 60)
        XCTAssertEqual(CanvasPerformancePolicy.maximumAnimatedRoutePointCount, 96)
        XCTAssertEqual(CanvasPerformancePolicy.maximumDetailedVisibleCardCount, 48)
        XCTAssertEqual(CanvasPerformancePolicy.maximumDetailedInteractingVisibleCardCount, 8)
        XCTAssertEqual(CanvasPerformancePolicy.maximumContextEdgesDuringInteraction, 48)
        XCTAssertEqual(CanvasPerformancePolicy.maximumPassiveResizeHandleNodeCount, 12)
        XCTAssertEqual(CanvasPerformancePolicy.maximumPassiveEdgeControlHandleCount, 24)
        XCTAssertEqual(CanvasPerformancePolicy.minimumPassiveEdgeControlZoom, 0.30, accuracy: 0.0001)
    }

    func testCanvasPerformancePolicyUsesConservativeRoutingWorkloadBoundary() {
        XCTAssertTrue(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 22, obstacleCount: 40, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 23, obstacleCount: 40, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 25, obstacleCount: 20, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 12, obstacleCount: 0, isInteracting: false))
    }

    func testCanvasEdgeAnimationPolicyGatesVisibleTimelineByZoomDensityAndComplexity() {
        XCTAssertTrue(CanvasEdgeAnimationPolicy.shouldAnimateVisibleEdges(
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: 12,
            visibleCardCount: 60,
            routedPointCount: 96,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        ))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateVisibleEdges(
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: 13,
            visibleCardCount: 48,
            routedPointCount: 32,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        ))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateVisibleEdges(
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: 12,
            visibleCardCount: 61,
            routedPointCount: 32,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        ))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateVisibleEdges(
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: 12,
            visibleCardCount: 48,
            routedPointCount: 97,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        ))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateVisibleEdges(
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: 12,
            visibleCardCount: 48,
            routedPointCount: 32,
            zoom: 0.24,
            baselineZoom: 0.35,
            isInteracting: false
        ))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateVisibleEdges(
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: 12,
            visibleCardCount: 48,
            routedPointCount: 32,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: true
        ))
    }

    func testCanvasCardRenderDetailPolicyUsesLightweightCardsDuringMotionOrDenseZoomOut() {
        XCTAssertTrue(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.35,
            baselineZoom: 0.35,
            visibleCardCount: 48,
            isInteracting: false,
            isSelected: false,
            isEditing: false
        ))
        XCTAssertFalse(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.35,
            baselineZoom: 0.35,
            visibleCardCount: 40,
            isInteracting: true,
            isSelected: false,
            isEditing: false
        ))
        XCTAssertFalse(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.35,
            baselineZoom: 0.35,
            visibleCardCount: 8,
            isInteracting: true,
            isSelected: false,
            isEditing: false
        ))
        XCTAssertTrue(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.35,
            baselineZoom: 0.35,
            visibleCardCount: 40,
            isInteracting: true,
            isSelected: true,
            isEditing: false
        ))
        XCTAssertTrue(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.35,
            baselineZoom: 0.35,
            visibleCardCount: 8,
            isInteracting: true,
            isSelected: true,
            isEditing: false
        ))
        XCTAssertTrue(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.24,
            baselineZoom: 0.35,
            visibleCardCount: 80,
            isInteracting: true,
            isSelected: false,
            isEditing: true
        ))
        XCTAssertFalse(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.35,
            baselineZoom: 0.35,
            visibleCardCount: 49,
            isInteracting: false,
            isSelected: false,
            isEditing: false
        ))
        XCTAssertFalse(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.24,
            baselineZoom: 0.35,
            visibleCardCount: 48,
            isInteracting: false,
            isSelected: false,
            isEditing: false
        ))
    }

    func testCanvasCardDetailInteractionPolicyKeepsPeerDetailsDuringSpatialDragOnly() {
        let sparseVisibleCount = 24
        XCTAssertFalse(CanvasCardDetailInteractionPolicy.shouldReducePeerDetails(
            isNodeDragging: true,
            isViewportMoving: false,
            isZooming: false,
            isResizing: false,
            isEdgeControlDragging: false,
            visibleCardCount: sparseVisibleCount
        ))
        XCTAssertFalse(CanvasCardDetailInteractionPolicy.shouldReducePeerDetails(
            isNodeDragging: false,
            isViewportMoving: true,
            isZooming: false,
            isResizing: false,
            isEdgeControlDragging: false,
            visibleCardCount: sparseVisibleCount
        ))
        XCTAssertTrue(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.35,
            baselineZoom: 0.35,
            visibleCardCount: sparseVisibleCount,
            isInteracting: CanvasCardDetailInteractionPolicy.shouldReducePeerDetails(
                isNodeDragging: true,
                isViewportMoving: false,
                isZooming: false,
                isResizing: false,
                isEdgeControlDragging: false,
                visibleCardCount: sparseVisibleCount
            ),
            isSelected: false,
            isEditing: false
        ))
        XCTAssertTrue(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.35,
            baselineZoom: 0.35,
            visibleCardCount: sparseVisibleCount,
            isInteracting: CanvasCardDetailInteractionPolicy.shouldReducePeerDetails(
                isNodeDragging: false,
                isViewportMoving: true,
                isZooming: false,
                isResizing: false,
                isEdgeControlDragging: false,
                visibleCardCount: sparseVisibleCount
            ),
            isSelected: false,
            isEditing: false
        ))
    }

    func testCanvasCardDetailInteractionPolicyReducesDenseSpatialInteractions() {
        let boundary = CanvasPerformancePolicy.maximumRichSpatialInteractionCardCount
        XCTAssertFalse(CanvasCardDetailInteractionPolicy.shouldReducePeerDetails(
            isNodeDragging: true,
            isViewportMoving: false,
            isZooming: false,
            isResizing: false,
            isEdgeControlDragging: false,
            visibleCardCount: boundary
        ))
        XCTAssertTrue(CanvasCardDetailInteractionPolicy.shouldReducePeerDetails(
            isNodeDragging: true,
            isViewportMoving: false,
            isZooming: false,
            isResizing: false,
            isEdgeControlDragging: false,
            visibleCardCount: boundary + 1
        ))
        XCTAssertTrue(CanvasCardDetailInteractionPolicy.shouldReducePeerDetails(
            isNodeDragging: false,
            isViewportMoving: true,
            isZooming: false,
            isResizing: false,
            isEdgeControlDragging: false,
            visibleCardCount: boundary + 1
        ))
    }

    func testCanvasCardDetailInteractionPolicyStillReducesDetailsForGeometryWork() {
        XCTAssertTrue(CanvasCardDetailInteractionPolicy.shouldReducePeerDetails(
            isNodeDragging: true,
            isViewportMoving: false,
            isZooming: false,
            isResizing: true,
            isEdgeControlDragging: false,
            visibleCardCount: 1
        ))
        XCTAssertTrue(CanvasCardDetailInteractionPolicy.shouldReducePeerDetails(
            isNodeDragging: false,
            isViewportMoving: false,
            isZooming: true,
            isResizing: false,
            isEdgeControlDragging: true,
            visibleCardCount: 1
        ))
    }

    func testCanvasScrollWheelEventPolicyPassesThroughHorizontalAndTinyEvents() {
        XCTAssertTrue(CanvasScrollWheelEventPolicy.shouldZoom(deltaX: 0, deltaY: 12))
        XCTAssertTrue(CanvasScrollWheelEventPolicy.shouldZoom(deltaX: 3, deltaY: 12))
        XCTAssertFalse(CanvasScrollWheelEventPolicy.shouldZoom(deltaX: 24, deltaY: 5))
        XCTAssertFalse(CanvasScrollWheelEventPolicy.shouldZoom(deltaX: 0, deltaY: 0.005))
    }

    func testCanvasResizeHandlePolicyAvoidsDensePassiveHandles() {
        XCTAssertTrue(CanvasResizeHandleVisibilityPolicy.shouldShow(
            isSelected: true,
            isDragging: false,
            isResizing: false,
            isInteracting: true,
            visibleNodeCount: 120
        ))
        XCTAssertTrue(CanvasResizeHandleVisibilityPolicy.shouldShow(
            isSelected: false,
            isDragging: true,
            isResizing: false,
            isInteracting: true,
            visibleNodeCount: 120
        ))
        XCTAssertTrue(CanvasResizeHandleVisibilityPolicy.shouldShow(
            isSelected: false,
            isDragging: false,
            isResizing: true,
            isInteracting: true,
            visibleNodeCount: 120
        ))
        XCTAssertTrue(CanvasResizeHandleVisibilityPolicy.shouldShow(
            isSelected: false,
            isDragging: false,
            isResizing: false,
            isInteracting: false,
            visibleNodeCount: 12
        ))
        XCTAssertFalse(CanvasResizeHandleVisibilityPolicy.shouldShow(
            isSelected: false,
            isDragging: false,
            isResizing: false,
            isInteracting: true,
            visibleNodeCount: 12
        ))
        XCTAssertFalse(CanvasResizeHandleVisibilityPolicy.shouldShow(
            isSelected: false,
            isDragging: false,
            isResizing: false,
            isInteracting: false,
            visibleNodeCount: CanvasPerformancePolicy.maximumPassiveResizeHandleNodeCount + 1
        ))
    }

    func testCanvasEdgeControlHandlePolicyKeepsSelectedAndCustomHandlesOnlyInDenseViews() {
        XCTAssertTrue(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: true,
            hasTransientControlPoint: false,
            hasStoredControlPoint: false,
            isLocked: false,
            isInteracting: true,
            edgeCount: 300,
            zoom: 0.1
        ))
        XCTAssertTrue(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: true,
            hasStoredControlPoint: false,
            isLocked: false,
            isInteracting: true,
            edgeCount: 300,
            zoom: 0.1
        ))
        XCTAssertTrue(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: false,
            hasStoredControlPoint: true,
            isLocked: false,
            isInteracting: false,
            edgeCount: 300,
            zoom: 0.1
        ))
        XCTAssertTrue(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: false,
            hasStoredControlPoint: false,
            isLocked: true,
            isInteracting: false,
            edgeCount: 300,
            zoom: 0.1
        ))
        XCTAssertFalse(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: false,
            hasStoredControlPoint: false,
            isLocked: false,
            isInteracting: true,
            edgeCount: 12,
            zoom: 0.35
        ))
        XCTAssertTrue(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: false,
            hasStoredControlPoint: false,
            isLocked: false,
            isInteracting: false,
            edgeCount: 24,
            zoom: 0.30
        ))
        XCTAssertFalse(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: false,
            hasStoredControlPoint: false,
            isLocked: false,
            isInteracting: false,
            edgeCount: 25,
            zoom: 0.35
        ))
        XCTAssertFalse(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: false,
            hasStoredControlPoint: false,
            isLocked: false,
            isInteracting: false,
            edgeCount: 24,
            zoom: 0.29
        ))
        XCTAssertTrue(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: false,
            hasStoredControlPoint: false,
            isLocked: false,
            isInteracting: true,
            isDragging: true,
            edgeCount: CanvasPerformancePolicy.maximumPassiveEdgeControlHandleCount + 1,
            zoom: 0.1
        ))
    }

    func testCanvasNodeStateReconciliationDropsMissingNodes() {
        let existing: Set<String> = ["a", "c"]

        XCTAssertEqual(
            CanvasNodeStateReconciliation.validIDs(["a", "b", "c"], existingNodeIDs: existing),
            ["a", "c"]
        )
        XCTAssertNil(CanvasNodeStateReconciliation.validOptionalID("b", existingNodeIDs: existing))
        XCTAssertEqual(CanvasNodeStateReconciliation.validOptionalID("c", existingNodeIDs: existing), "c")
        XCTAssertEqual(
            CanvasNodeStateReconciliation.filteredKeys(
                ["a": 1, "b": 2],
                existingNodeIDs: existing
            ).keys.sorted(),
            ["a"]
        )
    }

    func testCanvasActiveEdgeRenderPolicyLimitsEdgesDuringNodeMotion() {
        XCTAssertTrue(CanvasActiveEdgeRenderPolicy.shouldRenderEdge(
            edgeID: "unrelated",
            sourceNodeID: "a",
            targetNodeID: "b",
            movingNodeIDs: ["moving"],
            selectedEdgeIDs: [],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            isGeometryInteracting: false
        ))
        XCTAssertTrue(CanvasActiveEdgeRenderPolicy.shouldRenderEdge(
            edgeID: "incident",
            sourceNodeID: "moving",
            targetNodeID: "b",
            movingNodeIDs: ["moving"],
            selectedEdgeIDs: [],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            isGeometryInteracting: true
        ))
        XCTAssertTrue(CanvasActiveEdgeRenderPolicy.shouldRenderEdge(
            edgeID: "selected",
            sourceNodeID: "a",
            targetNodeID: "b",
            movingNodeIDs: ["moving"],
            selectedEdgeIDs: ["selected"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            isGeometryInteracting: true
        ))
        XCTAssertTrue(CanvasActiveEdgeRenderPolicy.shouldRenderEdge(
            edgeID: "bend",
            sourceNodeID: "a",
            targetNodeID: "b",
            movingNodeIDs: ["moving"],
            selectedEdgeIDs: [],
            transientControlEdgeIDs: ["bend"],
            movedControlEdgeIDs: [],
            isGeometryInteracting: true
        ))
        XCTAssertTrue(CanvasActiveEdgeRenderPolicy.shouldRenderEdge(
            edgeID: "frame-bend",
            sourceNodeID: "a",
            targetNodeID: "b",
            movingNodeIDs: ["moving"],
            selectedEdgeIDs: [],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: ["frame-bend"],
            isGeometryInteracting: true
        ))
        XCTAssertTrue(CanvasActiveEdgeRenderPolicy.shouldRenderEdge(
            edgeID: "context",
            sourceNodeID: "a",
            targetNodeID: "b",
            movingNodeIDs: ["moving"],
            selectedEdgeIDs: [],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            isGeometryInteracting: true,
            visibleEdgeCount: CanvasPerformancePolicy.maximumContextEdgesDuringInteraction
        ))
        XCTAssertFalse(CanvasActiveEdgeRenderPolicy.shouldRenderEdge(
            edgeID: "unrelated",
            sourceNodeID: "a",
            targetNodeID: "b",
            movingNodeIDs: ["moving"],
            selectedEdgeIDs: [],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            isGeometryInteracting: true
        ))
    }

    func testCanvasNodeVisualZIndexPolicyKeepsMovingCardsAboveEdgesAndPeerCards() {
        let idleCard = CanvasNodeVisualZIndexPolicy.zIndex(
            storedZIndex: 0,
            isFrame: false,
            isSelected: false,
            isDragging: false,
            isResizing: false,
            isConnectionSource: false,
            isEditing: false
        )
        let selectedCard = CanvasNodeVisualZIndexPolicy.zIndex(
            storedZIndex: 0,
            isFrame: false,
            isSelected: true,
            isDragging: false,
            isResizing: false,
            isConnectionSource: false,
            isEditing: false
        )
        let draggingCard = CanvasNodeVisualZIndexPolicy.zIndex(
            storedZIndex: 0,
            isFrame: false,
            isSelected: true,
            isDragging: true,
            isResizing: false,
            isConnectionSource: false,
            isEditing: false
        )
        let draggingFrame = CanvasNodeVisualZIndexPolicy.zIndex(
            storedZIndex: 0,
            isFrame: true,
            isSelected: true,
            isDragging: true,
            isResizing: false,
            isConnectionSource: false,
            isEditing: false
        )

        XCTAssertGreaterThan(selectedCard, idleCard)
        XCTAssertGreaterThan(draggingCard, 3.0)
        XCTAssertLessThan(draggingFrame, idleCard)
    }

    func testCanvasEdgeVisualMetricsKeepLowZoomStrokesReadable() {
        XCTAssertEqual(CanvasEdgeVisualMetrics.strokeWidth(zoom: 0.12, baseWidth: 1.7, minimumWidth: 0.9, maximumWidth: 2.0), 0.9, accuracy: 0.0001)
        XCTAssertEqual(CanvasEdgeVisualMetrics.strokeWidth(zoom: 2.0, baseWidth: 1.7, minimumWidth: 0.9, maximumWidth: 2.0), 2.0, accuracy: 0.0001)
        XCTAssertEqual(CanvasEdgeVisualMetrics.arrowLength(zoom: 0.12, baseLength: 13, minimumLength: 6, maximumLength: 16), 6, accuracy: 0.0001)
        XCTAssertEqual(CanvasEdgeVisualMetrics.arrowLength(zoom: 2.0, baseLength: 13, minimumLength: 6, maximumLength: 16), 16, accuracy: 0.0001)
    }

    func testCanvasSideRailLayoutShrinksRightRailForNarrowWindows() {
        XCTAssertEqual(CanvasSideRailLayout.rightRailWidth(availableWidth: 1120), 244)
        XCTAssertEqual(CanvasSideRailLayout.rightRailWidth(availableWidth: 900), 198)
        XCTAssertEqual(CanvasSideRailLayout.rightRailWidth(availableWidth: 760), 180)
    }

    func testTodoColumnSplitRatioIsClampedToUsableRange() {
        XCTAssertEqual(TodoBoardColumnSplit.clampedRatio(-1), 0.3)
        XCTAssertEqual(TodoBoardColumnSplit.clampedRatio(0.5), 0.5)
        XCTAssertEqual(TodoBoardColumnSplit.clampedRatio(2), 0.7)
    }

    func testTodoBoardOrderingPinsFirstThenSortsByIndexAndTitle() {
        let records = [
            TodoBoardOrderRecord(id: "normal-late", title: "Later", isPinned: false, sortIndex: 10),
            TodoBoardOrderRecord(id: "pinned-late", title: "Pinned Later", isPinned: true, sortIndex: 20),
            TodoBoardOrderRecord(id: "pinned-early", title: "Pinned Early", isPinned: true, sortIndex: 5),
            TodoBoardOrderRecord(id: "normal-early", title: "Early", isPinned: false, sortIndex: 0)
        ]

        XCTAssertEqual(
            TodoBoardOrdering.ordered(records).map(\.id),
            ["pinned-early", "pinned-late", "normal-early", "normal-late"]
        )
    }

    func testTodoBoardOrderingBreaksExactTiesByID() {
        let records = [
            TodoBoardOrderRecord(id: "b", title: "Same", isPinned: false, sortIndex: 1),
            TodoBoardOrderRecord(id: "a", title: "Same", isPinned: false, sortIndex: 1)
        ]

        XCTAssertEqual(TodoBoardOrdering.ordered(records).map(\.id), ["a", "b"])
    }

    func testTodoBoardOrderingMovesIDsWithinCurrentOrder() {
        XCTAssertEqual(
            TodoBoardOrdering.movedIDs(["a", "b", "c"], moving: "a", to: "c"),
            ["b", "c", "a"]
        )
        XCTAssertEqual(
            TodoBoardOrdering.movedIDs(["a", "b", "c"], moving: "c", to: "a"),
            ["c", "a", "b"]
        )
        XCTAssertEqual(
            TodoBoardOrdering.movedIDs(["a", "b", "c"], moving: "missing", to: "a"),
            ["a", "b", "c"]
        )
    }

    func testTodoGroupDeletionPolicyMovesTasksToDefaultAndSelectsFallback() {
        let plan = TodoGroupDeletionPolicy.plan(
            deletingGroupId: "custom",
            defaultGroupId: "default",
            orderedGroupIds: ["default", "custom", "next"]
        )

        XCTAssertEqual(plan.todoTargetGroupId, "default")
        XCTAssertEqual(plan.nextSelectedGroupId, "default")
        XCTAssertTrue(plan.deletesGroup)
    }

    func testTodoGroupDeletionPolicyKeepsDefaultGroupSelection() {
        let plan = TodoGroupDeletionPolicy.plan(
            deletingGroupId: "default",
            defaultGroupId: "default",
            orderedGroupIds: ["default", "next"]
        )

        XCTAssertNil(plan.todoTargetGroupId)
        XCTAssertEqual(plan.nextSelectedGroupId, "default")
        XCTAssertFalse(plan.deletesGroup)
    }

    func testTodoBoardTaskSummaryCleansInlineDetails() {
        XCTAssertEqual(
            TodoBoardTaskSummary.inlineDetail("  Needs copy\nand screenshots  "),
            "Needs copy and screenshots"
        )
        XCTAssertNil(TodoBoardTaskSummary.inlineDetail(" \n\t "))
    }

    func testWebCardURLNormalizationAddsHTTPSAndRejectsInvalidHosts() {
        XCTAssertEqual(WebCardURL.normalized("example.com")?.absoluteString, "https://example.com")
        XCTAssertEqual(WebCardURL.normalized("https://example.com/path?q=1")?.absoluteString, "https://example.com/path?q=1")
        XCTAssertEqual(WebCardURL.normalized("localhost:3000")?.absoluteString, "https://localhost:3000")
        XCTAssertEqual(WebCardURL.normalized("http://localhost:3000")?.absoluteString, "http://localhost:3000")
        XCTAssertEqual(WebCardURL.normalized("https://intranet")?.absoluteString, "https://intranet")
        XCTAssertNil(WebCardURL.normalized("not a url"))
    }

    func testWebCardURLRejectsUnsupportedSchemesAndBlankHosts() {
        XCTAssertNil(WebCardURL.normalized("file:///tmp/notes.html"))
        XCTAssertNil(WebCardURL.normalized("javascript:alert(1)"))
        XCTAssertNil(WebCardURL.normalized("mailto:user@example.com"))
        XCTAssertNil(WebCardURL.normalized("https:///missing-host"))
        XCTAssertNil(WebCardURL.normalized("https://"))
    }

    func testWorkspaceDeletionPolicyRemovesCrossCanvasResourceSnippetReferencesAndEdges() {
        let plan = WorkspaceDeletionPolicy.plan(
            workspaceId: "workspace-a",
            canvases: [
                WorkspaceDeletionCanvasRecord(id: "canvas-a", workspaceId: "workspace-a"),
                WorkspaceDeletionCanvasRecord(id: "canvas-b", workspaceId: "workspace-b")
            ],
            nodes: [
                WorkspaceDeletionNodeRecord(id: "owned-node", canvasId: "canvas-a", objectType: nil, objectId: nil),
                WorkspaceDeletionNodeRecord(id: "workspace-ref", canvasId: "canvas-b", objectType: "workspace", objectId: "workspace-a"),
                WorkspaceDeletionNodeRecord(id: "resource-ref", canvasId: "canvas-b", objectType: "resourcePin", objectId: "resource-a"),
                WorkspaceDeletionNodeRecord(id: "snippet-ref", canvasId: "canvas-b", objectType: "snippet", objectId: "snippet-a"),
                WorkspaceDeletionNodeRecord(id: "unrelated", canvasId: "canvas-b", objectType: "resourcePin", objectId: "resource-b")
            ],
            edges: [
                WorkspaceDeletionEdgeRecord(id: "owned-edge", canvasId: "canvas-a", sourceNodeId: "owned-node", targetNodeId: "owned-node"),
                WorkspaceDeletionEdgeRecord(id: "cross-resource-edge", canvasId: "canvas-b", sourceNodeId: "resource-ref", targetNodeId: "unrelated"),
                WorkspaceDeletionEdgeRecord(id: "cross-snippet-edge", canvasId: "canvas-b", sourceNodeId: "unrelated", targetNodeId: "snippet-ref"),
                WorkspaceDeletionEdgeRecord(id: "keep-edge", canvasId: "canvas-b", sourceNodeId: "unrelated", targetNodeId: "unrelated")
            ],
            snippets: [
                WorkspaceDeletionSnippetRecord(id: "global-command", workingDirectoryRef: "resource-a"),
                WorkspaceDeletionSnippetRecord(id: "other-command", workingDirectoryRef: "resource-b")
            ],
            resourceIds: ["resource-a"],
            snippetIds: ["snippet-a"]
        )

        XCTAssertEqual(plan.nodeIds, ["owned-node", "resource-ref", "snippet-ref", "workspace-ref"])
        XCTAssertEqual(plan.edgeIds, ["cross-resource-edge", "cross-snippet-edge", "owned-edge"])
        XCTAssertEqual(plan.snippetIdsClearingWorkingDirectory, ["global-command"])
    }

    func testCanvasNodeObjectReferenceMapperRemapsWorkspaceAndWebCards() {
        XCTAssertEqual(
            CanvasNodeObjectReferenceMapper.mappedObjectId(
                objectType: "workspace",
                objectId: "old-workspace",
                resourceMap: [:],
                snippetMap: [:],
                workspaceMap: ["old-workspace": "new-workspace"]
            ),
            "new-workspace"
        )
        XCTAssertEqual(
            CanvasNodeObjectReferenceMapper.mappedObjectId(
                objectType: "webURL",
                objectId: nil,
                body: "example.com",
                resourceMap: [:],
                snippetMap: [:],
                workspaceMap: [:]
            ),
            "https://example.com"
        )
        XCTAssertEqual(
            CanvasNodeObjectReferenceMapper.mappedObjectId(
                objectType: "webURL",
                objectId: "https://example.com",
                body: "Edited description",
                resourceMap: [:],
                snippetMap: [:],
                workspaceMap: [:]
            ),
            "https://example.com"
        )
    }

    func testCanvasManifestParentMapperRemapsParentsAfterNodeMapIsComplete() {
        let nodeMap = [
            "old-child": "new-child",
            "old-parent": "new-parent"
        ]

        XCTAssertEqual(
            CanvasManifestParentMapper.mappedParentNodeId("old-parent", nodeMap: nodeMap),
            "new-parent"
        )
        XCTAssertNil(CanvasManifestParentMapper.mappedParentNodeId(nil, nodeMap: nodeMap))
        XCTAssertNil(CanvasManifestParentMapper.mappedParentNodeId("missing-parent", nodeMap: nodeMap))
    }

    func testQuickOpenIndexSearchesWorkspacesResourcesWebCardsAndSnippets() {
        let records = [
            QuickOpenRecord(id: "w1", kind: .workspace, title: "Research Map", subtitle: "Workspace"),
            QuickOpenRecord(id: "r1", kind: .resource, title: "Draft.pdf", subtitle: "/tmp/Draft.pdf"),
            QuickOpenRecord(id: "web1", kind: .webCard, title: "OpenAI Docs", subtitle: "https://platform.openai.com"),
            QuickOpenRecord(id: "s1", kind: .snippet, title: "Release prompt", subtitle: "Snippet")
        ]

        XCTAssertEqual(QuickOpenIndex.results(for: "docs", in: records).map(\.id), ["web1"])
        XCTAssertEqual(QuickOpenIndex.results(for: "map", in: records).map(\.id), ["w1"])
        XCTAssertEqual(QuickOpenIndex.results(for: "", in: records, limit: 2).map(\.id), ["w1", "r1"])
    }

    func testQuickOpenIndexSearchesKindTokensCaseInsensitively() {
        let records = [
            QuickOpenRecord(id: "workspace", kind: .workspace, title: "Roadmap", subtitle: "Plan"),
            QuickOpenRecord(id: "resource", kind: .resource, title: "Roadmap", subtitle: "File"),
            QuickOpenRecord(id: "web", kind: .webCard, title: "Roadmap", subtitle: "URL"),
            QuickOpenRecord(id: "snippet", kind: .snippet, title: "Roadmap", subtitle: "Prompt")
        ]

        XCTAssertEqual(QuickOpenIndex.results(for: "RESOURCE", in: records).map(\.id), ["resource"])
        XCTAssertEqual(QuickOpenIndex.results(for: "webcard", in: records).map(\.id), ["web"])
        XCTAssertEqual(QuickOpenIndex.results(for: "snippet", in: records).map(\.id), ["snippet"])
    }

    func testQuickOpenIndexRanksTitleMatchesBeforeSubtitleMatches() {
        let records = [
            QuickOpenRecord(id: "subtitle", kind: .resource, title: "Draft.pdf", subtitle: "OpenAI Docs"),
            QuickOpenRecord(id: "title", kind: .webCard, title: "Docs Home", subtitle: "https://example.com")
        ]

        XCTAssertEqual(QuickOpenIndex.results(for: "docs", in: records).map(\.id), ["title", "subtitle"])
    }

    func testQuickOpenIndexHandlesMultipleTokensAndZeroLimit() {
        let records = [
            QuickOpenRecord(id: "match", kind: .workspace, title: "Research Map", subtitle: "OpenAI Docs"),
            QuickOpenRecord(id: "partial", kind: .workspace, title: "Research Plan", subtitle: "Notebook"),
            QuickOpenRecord(id: "miss", kind: .snippet, title: "Release prompt", subtitle: "Docs")
        ]

        XCTAssertEqual(QuickOpenIndex.results(for: "research docs", in: records).map(\.id), ["match"])
        XCTAssertTrue(QuickOpenIndex.results(for: "research", in: records, limit: 0).isEmpty)
    }

    func testQuickOpenIndexKeepsBestBoundedResultsStable() {
        let records = [
            QuickOpenRecord(id: "old-contains", kind: .workspace, title: "Research Docs", subtitle: ""),
            QuickOpenRecord(id: "subtitle-prefix", kind: .resource, title: "Research", subtitle: "Docs Folder"),
            QuickOpenRecord(id: "exact", kind: .snippet, title: "Docs", subtitle: ""),
            QuickOpenRecord(id: "prefix", kind: .webCard, title: "Docs Home", subtitle: ""),
            QuickOpenRecord(id: "later-contains", kind: .workspace, title: "Team Docs", subtitle: "")
        ]

        XCTAssertEqual(
            QuickOpenIndex.results(for: "docs", in: records, limit: 3).map(\.id),
            ["exact", "prefix", "old-contains"]
        )
    }

    func testQuickOpenSelectionPolicyWrapsAndClampsSelection() {
        XCTAssertEqual(QuickOpenSelectionPolicy.movedIndex(current: 0, delta: 1, resultCount: 3), 1)
        XCTAssertEqual(QuickOpenSelectionPolicy.movedIndex(current: 2, delta: 1, resultCount: 3), 0)
        XCTAssertEqual(QuickOpenSelectionPolicy.movedIndex(current: 0, delta: -1, resultCount: 3), 2)
        XCTAssertEqual(QuickOpenSelectionPolicy.normalizedIndex(4, resultCount: 2), 1)
        XCTAssertEqual(QuickOpenSelectionPolicy.normalizedIndex(0, resultCount: 0), 0)
    }

    func testManifestRoundTripKeepsSchemaVersion() throws {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Map", viewportX: 12, viewportY: -8, zoom: 1.4)
            ],
            nodes: [
                CanvasNodeRecord(id: "node", canvasId: "canvas", title: "Node", body: "Body", nodeType: "note", objectType: nil, objectId: nil, x: 1, y: 2, width: 180, height: 96, collapsed: true)
            ],
            edges: [
                CanvasEdgeRecord(id: "edge", canvasId: "canvas", sourceNodeId: "node", targetNodeId: "node", label: "relates", style: "dashed")
            ],
            aliases: []
        )
        let data = try JSONEncoder.minddesk.encode(manifest)
        let decoded = try JSONDecoder.minddesk.decode(ExportManifest.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.canvases.first?.viewportX, 12)
        XCTAssertEqual(decoded.canvases.first?.viewportY, -8)
        XCTAssertEqual(decoded.canvases.first?.zoom, 1.4)
        XCTAssertEqual(decoded.nodes.first?.collapsed, true)
        XCTAssertEqual(decoded.edges.first?.style, "dashed")
    }

    func testManifestV2RoundTripKeepsTodoGroupsAndTasks() throws {
        let due = Date(timeIntervalSince1970: 1_900_000_000)
        let completed = Date(timeIntervalSince1970: 1_800_000_000)
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "resource", workspaceId: "workspace", title: "Paper", targetType: "file", displayPath: "/tmp/Paper.pdf", lastResolvedPath: "/tmp/Paper.pdf", note: "", tags: [], scope: "workspace", status: "available")
            ],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: [],
            todoGroups: [
                TodoGroupRecord(id: "group", workspaceId: "workspace", title: "Writing", isPinned: true, sortIndex: 2, createdAt: .distantPast, updatedAt: .distantPast)
            ],
            todos: [
                TodoRecord(id: "todo", workspaceId: "workspace", groupId: "group", title: "Revise intro", details: "Tighten claims", isCompleted: true, isPinned: true, sortIndex: 4, createdAt: .distantPast, updatedAt: .distantPast, completedAt: completed, dueAt: due, linkedResourceId: "resource")
            ]
        )

        let data = try JSONEncoder.minddesk.encode(manifest)
        let decoded = try JSONDecoder.minddesk.decode(ExportManifest.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.todoGroups.first?.title, "Writing")
        XCTAssertEqual(decoded.todoGroups.first?.isPinned, true)
        XCTAssertEqual(decoded.todos.first?.title, "Revise intro")
        XCTAssertEqual(decoded.todos.first?.details, "Tighten claims")
        XCTAssertEqual(decoded.todos.first?.isCompleted, true)
        XCTAssertEqual(decoded.todos.first?.isPinned, true)
        XCTAssertEqual(decoded.todos.first?.groupId, "group")
        XCTAssertEqual(decoded.todos.first?.linkedResourceId, "resource")
        XCTAssertEqual(decoded.todos.first?.dueAt, due)
        XCTAssertEqual(decoded.todos.first?.completedAt, completed)
    }

    func testLegacyManifestDefaultsNewCanvasFields() throws {
        let json = """
        {
          "aliases": [],
          "canvases": [
            { "id": "canvas", "workspaceId": "workspace", "title": "Map" }
          ],
          "edges": [
            { "id": "edge", "canvasId": "canvas", "sourceNodeId": "node", "targetNodeId": "node", "label": "" }
          ],
          "exportedAt": "1970-01-01T00:00:00Z",
          "nodes": [
            { "id": "node", "canvasId": "canvas", "title": "Node", "body": "", "nodeType": "note", "x": 1, "y": 2, "width": 180, "height": 96 }
          ],
          "resources": [
            { "id": "resource", "workspaceId": null, "title": "Projects", "targetType": "folder", "displayPath": "/tmp/Projects", "lastResolvedPath": "/tmp/Projects", "note": "", "tags": [], "scope": "global", "status": "available" }
          ],
          "schemaVersion": 1,
          "snippets": [],
          "workspaces": []
        }
        """

        let decoded = try JSONDecoder.minddesk.decode(ExportManifest.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.todoGroups, [])
        XCTAssertEqual(decoded.todos, [])
        XCTAssertEqual(decoded.canvases.first?.viewportX, 0)
        XCTAssertEqual(decoded.canvases.first?.viewportY, 0)
        XCTAssertEqual(decoded.canvases.first?.zoom, 1)
        XCTAssertEqual(decoded.nodes.first?.collapsed, false)
        XCTAssertEqual(decoded.edges.first?.style, "default")
        XCTAssertEqual(decoded.resources.first?.isPinned, true)
        XCTAssertEqual(decoded.resources.first?.originalName, "")
        XCTAssertEqual(decoded.canvases.first?.linkAnimationTheme, "blue")
        XCTAssertEqual(decoded.canvases.first?.animationsEnabled, true)
        XCTAssertEqual(decoded.nodes.first?.zIndex, 0)
        XCTAssertEqual(decoded.edges.first?.targetArrow, "arrow")
    }

    func testManifestScopePolicyDropsTodosForGlobalLibraryOnly() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "resource", workspaceId: nil, title: "Shared", targetType: "folder", displayPath: "/tmp/Shared", lastResolvedPath: "/tmp/Shared", note: "", tags: [], scope: "global", status: "available")
            ],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: [],
            todoGroups: [
                TodoGroupRecord(id: "group", workspaceId: "workspace", title: "Tasks", isPinned: false, sortIndex: 0)
            ],
            todos: [
                TodoRecord(id: "todo", workspaceId: "workspace", groupId: "group", title: "Task", details: "", isCompleted: false, isPinned: false, sortIndex: 0, linkedResourceId: "resource")
            ]
        )

        let scoped = ExportManifestScopePolicy.manifest(from: manifest, scope: .globalLibraryOnly)

        XCTAssertEqual(scoped.resources.map(\.id), ["resource"])
        XCTAssertTrue(scoped.todoGroups.isEmpty)
        XCTAssertTrue(scoped.todos.isEmpty)
    }

    func testManifestImportValidationReportsBrokenReferences() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [
                ResourceRecord(id: "resource", workspaceId: "missing-workspace", title: "File", targetType: "file", displayPath: "/tmp/file", lastResolvedPath: "/tmp/file", note: "", tags: [], scope: "workspace", status: "available")
            ],
            snippets: [
                SnippetRecord(id: "snippet", workspaceId: "missing-workspace", title: "Command", kind: "command", body: "pwd", details: "", tags: [], scope: "workspace", workingDirectoryRef: "missing-resource", requiresConfirmation: false)
            ],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "missing-workspace", title: "Map")
            ],
            nodes: [
                CanvasNodeRecord(id: "node", canvasId: "missing-canvas", title: "Node", body: "", nodeType: "resource", objectType: "resourcePin", objectId: "missing-resource", x: 0, y: 0, width: 160, height: 96, parentNodeId: "missing-parent")
            ],
            edges: [
                CanvasEdgeRecord(id: "edge", canvasId: "missing-canvas", sourceNodeId: "missing-source", targetNodeId: "missing-target", label: "")
            ],
            aliases: []
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Resource resource references missing workspace missing-workspace."))
        XCTAssertTrue(issues.contains("Snippet snippet references missing working directory resource missing-resource."))
        XCTAssertTrue(issues.contains("Canvas canvas references missing workspace missing-workspace."))
        XCTAssertTrue(issues.contains("Node node references missing canvas missing-canvas."))
        XCTAssertTrue(issues.contains("Edge edge references missing source node missing-source."))
    }

    func testManifestImportValidationReportsBrokenTodoReferences() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: [],
            todoGroups: [
                TodoGroupRecord(id: "group", workspaceId: "missing-workspace", title: "Tasks", isPinned: false, sortIndex: 0)
            ],
            todos: [
                TodoRecord(id: "todo", workspaceId: "workspace", groupId: "missing-group", title: "Task", details: "", isCompleted: false, isPinned: false, sortIndex: 0, linkedResourceId: "missing-resource"),
                TodoRecord(id: "orphan", workspaceId: "missing-workspace", groupId: nil, title: "Orphan", details: "", isCompleted: false, isPinned: false, sortIndex: 1, linkedResourceId: nil)
            ]
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Todo group group references missing workspace missing-workspace."))
        XCTAssertTrue(issues.contains("Todo todo references missing group missing-group."))
        XCTAssertTrue(issues.contains("Todo todo references missing linked resource missing-resource."))
        XCTAssertTrue(issues.contains("Todo orphan references missing workspace missing-workspace."))
    }

    func testManifestImportValidationRejectsCrossWorkspaceTodoReferences() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace-a", title: "A", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil),
                WorkspaceRecord(id: "workspace-b", title: "B", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "resource-b", workspaceId: "workspace-b", title: "B File", targetType: "file", displayPath: "/tmp/b", lastResolvedPath: "/tmp/b", note: "", tags: [], scope: "workspace", status: "available"),
                ResourceRecord(id: "global-resource", workspaceId: nil, title: "Global", targetType: "file", displayPath: "/tmp/global", lastResolvedPath: "/tmp/global", note: "", tags: [], scope: "global", status: "available")
            ],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: [],
            todoGroups: [
                TodoGroupRecord(id: "group-b", workspaceId: "workspace-b", title: "B Tasks", isPinned: false, sortIndex: 0)
            ],
            todos: [
                TodoRecord(id: "cross-group", workspaceId: "workspace-a", groupId: "group-b", title: "Cross Group", details: "", isCompleted: false, isPinned: false, sortIndex: 0, linkedResourceId: nil),
                TodoRecord(id: "cross-resource", workspaceId: "workspace-a", groupId: nil, title: "Cross Resource", details: "", isCompleted: false, isPinned: false, sortIndex: 1, linkedResourceId: "resource-b"),
                TodoRecord(id: "global-link", workspaceId: "workspace-a", groupId: nil, title: "Global Link", details: "", isCompleted: false, isPinned: false, sortIndex: 2, linkedResourceId: "global-resource")
            ]
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Todo cross-group references group group-b from another workspace."))
        XCTAssertTrue(issues.contains("Todo cross-resource references linked resource resource-b from another workspace."))
        XCTAssertFalse(issues.contains("Todo global-link references linked resource global-resource from another workspace."))
    }

    func testManifestImportValidationRejectsCrossWorkspaceSnippetAndCanvasResourceReferences() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace-a", title: "A", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil),
                WorkspaceRecord(id: "workspace-b", title: "B", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "resource-b", workspaceId: "workspace-b", title: "B Folder", targetType: "folder", displayPath: "/tmp/b", lastResolvedPath: "/tmp/b", note: "", tags: [], scope: "workspace", status: "available"),
                ResourceRecord(id: "global-resource", workspaceId: nil, title: "Global Folder", targetType: "folder", displayPath: "/tmp/global", lastResolvedPath: "/tmp/global", note: "", tags: [], scope: "global", status: "available")
            ],
            snippets: [
                SnippetRecord(id: "cross-snippet", workspaceId: "workspace-a", title: "Cross", kind: "command", body: "pwd", details: "", tags: [], scope: "workspace", workingDirectoryRef: "resource-b", requiresConfirmation: true),
                SnippetRecord(id: "global-snippet", workspaceId: "workspace-a", title: "Global OK", kind: "command", body: "pwd", details: "", tags: [], scope: "workspace", workingDirectoryRef: "global-resource", requiresConfirmation: true),
                SnippetRecord(id: "snippet-b", workspaceId: "workspace-b", title: "B Snippet", kind: "note", body: "B", details: "", tags: [], scope: "workspace", workingDirectoryRef: nil, requiresConfirmation: true),
                SnippetRecord(id: "shared-snippet", workspaceId: nil, title: "Shared Snippet", kind: "note", body: "Shared", details: "", tags: [], scope: "global", workingDirectoryRef: nil, requiresConfirmation: true)
            ],
            canvases: [
                CanvasRecord(id: "canvas-a", workspaceId: "workspace-a", title: "A")
            ],
            nodes: [
                CanvasNodeRecord(id: "cross-resource-node", canvasId: "canvas-a", title: "Cross", body: "", nodeType: "resource", objectType: "resourcePin", objectId: "resource-b", x: 0, y: 0, width: 180, height: 120),
                CanvasNodeRecord(id: "global-resource-node", canvasId: "canvas-a", title: "Global", body: "", nodeType: "resource", objectType: "resourcePin", objectId: "global-resource", x: 220, y: 0, width: 180, height: 120),
                CanvasNodeRecord(id: "cross-snippet-node", canvasId: "canvas-a", title: "Cross Snippet", body: "", nodeType: "snippet", objectType: "snippet", objectId: "snippet-b", x: 440, y: 0, width: 180, height: 120),
                CanvasNodeRecord(id: "global-snippet-node", canvasId: "canvas-a", title: "Shared Snippet", body: "", nodeType: "snippet", objectType: "snippet", objectId: "shared-snippet", x: 660, y: 0, width: 180, height: 120)
            ],
            edges: [],
            aliases: []
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Snippet cross-snippet references working directory resource resource-b from another workspace."))
        XCTAssertTrue(issues.contains("Node cross-resource-node references resource resource-b from another workspace."))
        XCTAssertTrue(issues.contains("Node cross-snippet-node references snippet snippet-b from another workspace."))
        XCTAssertFalse(issues.contains("Snippet global-snippet references working directory resource global-resource from another workspace."))
        XCTAssertFalse(issues.contains("Node global-resource-node references resource global-resource from another workspace."))
        XCTAssertFalse(issues.contains("Node global-snippet-node references snippet shared-snippet from another workspace."))
    }

    func testManifestImportValidationRejectsWorkspaceScopedResourcesAndSnippetsWithoutWorkspaceID() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "resource", workspaceId: nil, title: "File", targetType: "file", displayPath: "/tmp/file", lastResolvedPath: "/tmp/file", note: "", tags: [], scope: "workspace", status: "available")
            ],
            snippets: [
                SnippetRecord(id: "snippet", workspaceId: nil, title: "Command", kind: "command", body: "pwd", details: "", tags: [], scope: "workspace", workingDirectoryRef: nil, requiresConfirmation: false)
            ],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Resource resource has workspace scope without a workspace id."))
        XCTAssertTrue(issues.contains("Snippet snippet has workspace scope without a workspace id."))
    }

    func testManifestImportValidationReportsDuplicateIDs() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "One", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil),
                WorkspaceRecord(id: "workspace", title: "Two", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "resource", workspaceId: nil, title: "One", targetType: "file", displayPath: "/tmp/one", lastResolvedPath: "/tmp/one", note: "", tags: [], scope: "global", status: "available"),
                ResourceRecord(id: "resource", workspaceId: nil, title: "Two", targetType: "file", displayPath: "/tmp/two", lastResolvedPath: "/tmp/two", note: "", tags: [], scope: "global", status: "available")
            ],
            snippets: [
                SnippetRecord(id: "snippet", workspaceId: nil, title: "One", kind: "prompt", body: "", details: "", tags: [], scope: "global", workingDirectoryRef: nil, requiresConfirmation: false),
                SnippetRecord(id: "snippet", workspaceId: nil, title: "Two", kind: "prompt", body: "", details: "", tags: [], scope: "global", workingDirectoryRef: nil, requiresConfirmation: false)
            ],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "One"),
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Two")
            ],
            nodes: [
                CanvasNodeRecord(id: "node", canvasId: "canvas", title: "One", body: "", nodeType: "note", objectType: nil, objectId: nil, x: 0, y: 0, width: 180, height: 120),
                CanvasNodeRecord(id: "node", canvasId: "canvas", title: "Two", body: "", nodeType: "note", objectType: nil, objectId: nil, x: 200, y: 0, width: 180, height: 120)
            ],
            edges: [
                CanvasEdgeRecord(id: "edge", canvasId: "canvas", sourceNodeId: "node", targetNodeId: "node", label: ""),
                CanvasEdgeRecord(id: "edge", canvasId: "canvas", sourceNodeId: "node", targetNodeId: "node", label: "")
            ],
            aliases: [
                AliasRecord(id: "alias", sourceObjectType: "resourcePin", sourceObjectId: "resource", aliasDisplayPath: "/tmp/one alias", status: "created"),
                AliasRecord(id: "alias", sourceObjectType: "resourcePin", sourceObjectId: "resource", aliasDisplayPath: "/tmp/two alias", status: "created")
            ]
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Duplicate workspace id workspace."))
        XCTAssertTrue(issues.contains("Duplicate resource id resource."))
        XCTAssertTrue(issues.contains("Duplicate snippet id snippet."))
        XCTAssertTrue(issues.contains("Duplicate canvas id canvas."))
        XCTAssertTrue(issues.contains("Duplicate node id node."))
        XCTAssertTrue(issues.contains("Duplicate edge id edge."))
        XCTAssertTrue(issues.contains("Duplicate alias id alias."))
    }

    func testManifestImportValidationRejectsCrossCanvasLinksAndParents() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas-a", workspaceId: "workspace", title: "A"),
                CanvasRecord(id: "canvas-b", workspaceId: "workspace", title: "B")
            ],
            nodes: [
                CanvasNodeRecord(id: "parent", canvasId: "canvas-a", title: "Parent", body: "", nodeType: "groupFrame", objectType: nil, objectId: nil, x: 0, y: 0, width: 300, height: 240),
                CanvasNodeRecord(id: "child", canvasId: "canvas-b", title: "Child", body: "", nodeType: "note", objectType: nil, objectId: nil, x: 20, y: 20, width: 180, height: 120, parentNodeId: "parent")
            ],
            edges: [
                CanvasEdgeRecord(id: "edge", canvasId: "canvas-a", sourceNodeId: "parent", targetNodeId: "child", label: "")
            ],
            aliases: []
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Node child references parent node parent from another canvas."))
        XCTAssertTrue(issues.contains("Edge edge references target node child from another canvas."))
    }

    func testManifestImportValidationRequiresObjectIDsAndAliasSources() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Canvas")
            ],
            nodes: [
                CanvasNodeRecord(id: "resource-node", canvasId: "canvas", title: "Resource", body: "", nodeType: "resource", objectType: "resourcePin", objectId: nil, x: 0, y: 0, width: 180, height: 120)
            ],
            edges: [],
            aliases: [
                AliasRecord(id: "alias", sourceObjectType: "resourcePin", sourceObjectId: "missing-resource", aliasDisplayPath: "/tmp/missing alias", status: "created")
            ]
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Node resource-node has object type resourcePin without an object id."))
        XCTAssertTrue(issues.contains("Alias alias references missing resource object missing-resource."))
    }

    func testManifestImportValidationAllowsLegacyWebURLBodyFallback() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Canvas")
            ],
            nodes: [
                CanvasNodeRecord(id: "web", canvasId: "canvas", title: "Web", body: "example.com", nodeType: "snippet", objectType: "webURL", objectId: nil, x: 0, y: 0, width: 180, height: 120)
            ],
            edges: [],
            aliases: []
        )

        XCTAssertTrue(ManifestImportValidation.issues(in: manifest).isEmpty)
    }

    func testManifestImportValidationRejectsEmptyIDsAndWhitespaceReferences() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "resource", workspaceId: nil, title: "Resource", targetType: "file", displayPath: "/tmp/file", lastResolvedPath: "/tmp/file", note: "", tags: [], scope: "global", status: "available")
            ],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "", title: "Canvas")
            ],
            nodes: [
                CanvasNodeRecord(id: "node", canvasId: "canvas", title: "Node", body: "", nodeType: "resource", objectType: "resourcePin", objectId: " resource ", x: 0, y: 0, width: 180, height: 120)
            ],
            edges: [],
            aliases: [
                AliasRecord(id: "alias", sourceObjectType: "resourcePin", sourceObjectId: " resource ", aliasDisplayPath: "/tmp/alias", status: "created")
            ]
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Workspace has empty id."))
        XCTAssertTrue(issues.contains("Node node has object id with leading or trailing whitespace."))
        XCTAssertTrue(issues.contains("Alias alias has source object id with leading or trailing whitespace."))
    }

    func testManifestImportValidationRejectsUnsupportedAliasSourceTypes() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: [
                AliasRecord(id: "alias", sourceObjectType: "workspace", sourceObjectId: "workspace", aliasDisplayPath: "/tmp/alias", status: "created")
            ]
        )

        XCTAssertTrue(
            ManifestImportValidation.issues(in: manifest).contains("Alias alias has unsupported source object type workspace.")
        )
    }

    func testManifestImportValidationAllowsMissingAliasHistory() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: [
                AliasRecord(id: "alias", sourceObjectType: "resourcePin", sourceObjectId: "deleted-resource", aliasDisplayPath: "/tmp/deleted alias", status: "missing")
            ]
        )

        XCTAssertTrue(ManifestImportValidation.issues(in: manifest).isEmpty)
    }

    func testManifestImportValidationAllowsDefaultResetAccentColor() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Canvas")
            ],
            nodes: [
                CanvasNodeRecord(id: "node", canvasId: "canvas", title: "Node", body: "", nodeType: "note", objectType: nil, objectId: nil, x: 0, y: 0, width: 180, height: 120, accentColor: "")
            ],
            edges: [],
            aliases: []
        )

        XCTAssertFalse(
            ManifestImportValidation.issues(in: manifest).contains("Node node has unsupported accent color .")
        )
    }

    func testManifestImportValidationRejectsInvalidEnumsAndUnsafeGeometry() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "file-resource", workspaceId: nil, title: "File", targetType: "file", displayPath: "/tmp/file", lastResolvedPath: "/tmp/file", note: "", tags: [], scope: "global", status: "available"),
                ResourceRecord(id: "bad-resource", workspaceId: nil, title: "Bad", targetType: "socket", displayPath: "/tmp/bad", lastResolvedPath: "/tmp/bad", note: "", tags: [], scope: "team", status: "trusted")
            ],
            snippets: [
                SnippetRecord(id: "snippet", workspaceId: nil, title: "Command", kind: "command", body: "pwd", details: "", tags: [], scope: "global", workingDirectoryRef: "file-resource", requiresConfirmation: true),
                SnippetRecord(id: "bad-snippet", workspaceId: nil, title: "Bad", kind: "script", body: "", details: "", tags: [], scope: "global", workingDirectoryRef: nil, requiresConfirmation: false)
            ],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Canvas", viewportX: ManifestImportLimits.maximumCanvasCoordinate + 1, viewportY: 0, zoom: 0)
            ],
            nodes: [
                CanvasNodeRecord(id: "node", canvasId: "canvas", title: "Node", body: "", nodeType: "mystery", objectType: "unknown", objectId: "object", x: 0, y: 0, width: -1, height: ManifestImportLimits.maximumNodeSize + 1, parentNodeId: "node", zIndex: ManifestImportLimits.maximumZIndex + 1)
            ],
            edges: [
                CanvasEdgeRecord(id: "edge", canvasId: "canvas", sourceNodeId: "node", targetNodeId: "node", label: "", sourceArrow: "maybe", targetArrow: "arrow")
            ],
            aliases: [
                AliasRecord(id: "alias", sourceObjectType: "resourcePin", sourceObjectId: "file-resource", aliasDisplayPath: "/tmp/alias", status: "unknown")
            ]
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Resource bad-resource has unsupported target type socket."))
        XCTAssertTrue(issues.contains("Resource bad-resource has unsupported scope team."))
        XCTAssertTrue(issues.contains("Resource bad-resource has unsupported status trusted."))
        XCTAssertTrue(issues.contains("Snippet bad-snippet has unsupported kind script."))
        XCTAssertTrue(issues.contains("Snippet snippet working directory file-resource is not a folder resource."))
        XCTAssertTrue(issues.contains("Canvas canvas has viewportX outside the supported range."))
        XCTAssertTrue(issues.contains("Canvas canvas has zoom outside the supported range."))
        XCTAssertTrue(issues.contains("Node node has unsupported node type mystery."))
        XCTAssertTrue(issues.contains("Node node has unsupported object type unknown."))
        XCTAssertTrue(issues.contains("Node node has width outside the supported range."))
        XCTAssertTrue(issues.contains("Node node has height outside the supported range."))
        XCTAssertTrue(issues.contains("Node node cannot be its own parent."))
        XCTAssertTrue(issues.contains("Node node has zIndex outside the supported range."))
        XCTAssertTrue(issues.contains("Edge edge has unsupported source arrow maybe."))
        XCTAssertTrue(issues.contains("Alias alias has unsupported status unknown."))
    }

    func testManifestImportValidationRejectsOversizedImportsAndTextFields() {
        let oversizedResources = (0...ManifestImportLimits.maximumResources).map { index in
            ResourceRecord(id: "resource-\(index)", workspaceId: nil, title: "Resource", targetType: "file", displayPath: "/tmp/file-\(index)", lastResolvedPath: "/tmp/file-\(index)", note: "", tags: [], scope: "global", status: "available")
        }
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: String(repeating: "A", count: ManifestImportLimits.maximumTextLength + 1), details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: oversizedResources,
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Manifest has too many resources."))
        XCTAssertTrue(issues.contains("Workspace workspace title is too long."))
    }

    func testManifestImportValidationRejectsGlobalRecordsWithWorkspaceIDs() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "resource", workspaceId: "workspace", title: "Resource", targetType: "file", displayPath: "/tmp/file", lastResolvedPath: "/tmp/file", note: "", tags: [], scope: "global", status: "available")
            ],
            snippets: [
                SnippetRecord(id: "snippet", workspaceId: "workspace", title: "Snippet", kind: "prompt", body: "Body", details: "", tags: [], scope: "global", workingDirectoryRef: nil, requiresConfirmation: false)
            ],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Resource resource has global scope with a workspace id."))
        XCTAssertTrue(issues.contains("Snippet snippet has global scope with a workspace id."))
    }

    func testLegacySnippetRecordDefaultsMissingCommandConfirmationToSafeValue() throws {
        let json = """
        {
          "id": "snippet",
          "workspaceId": null,
          "title": "List files",
          "kind": "command",
          "body": "ls",
          "details": "",
          "tags": [],
          "scope": "global"
        }
        """

        let decoded = try JSONDecoder.minddesk.decode(SnippetRecord.self, from: Data(json.utf8))

        XCTAssertTrue(decoded.requiresConfirmation)
        XCTAssertNil(decoded.workingDirectoryRef)
    }

    func testLegacySnippetRecordDefaultsMissingPromptConfirmationToFalse() throws {
        let json = """
        {
          "id": "snippet",
          "workspaceId": null,
          "title": "Draft",
          "kind": "prompt",
          "body": "Summarize",
          "details": "",
          "tags": [],
          "scope": "global"
        }
        """

        let decoded = try JSONDecoder.minddesk.decode(SnippetRecord.self, from: Data(json.utf8))

        XCTAssertFalse(decoded.requiresConfirmation)
    }

    func testImportedCommandSnippetsAlwaysRequireConfirmation() {
        XCTAssertTrue(SnippetImportTrustPolicy.requiresConfirmation(kind: "command", exportedRequiresConfirmation: false))
        XCTAssertTrue(SnippetImportTrustPolicy.requiresConfirmation(kind: "command", exportedRequiresConfirmation: true))
        XCTAssertFalse(SnippetImportTrustPolicy.requiresConfirmation(kind: "prompt", exportedRequiresConfirmation: false))
    }

    func testCommandWorkingDirectoryPolicyFallsBackOnlyWhenNoReferenceWasConfigured() {
        XCTAssertTrue(CommandWorkingDirectoryPolicy.allowsHomeFallback(workingDirectoryRef: nil))
        XCTAssertTrue(CommandWorkingDirectoryPolicy.allowsHomeFallback(workingDirectoryRef: "  "))
        XCTAssertFalse(CommandWorkingDirectoryPolicy.allowsHomeFallback(workingDirectoryRef: "folder-resource"))
    }

    func testResourceDropTargetPolicyFiltersMismatchedDropZones() {
        XCTAssertTrue(ResourceDropTargetPolicy.accepts(targetType: "folder", targetFilter: "folder"))
        XCTAssertTrue(ResourceDropTargetPolicy.accepts(targetType: "file", targetFilter: nil))
        XCTAssertFalse(ResourceDropTargetPolicy.accepts(targetType: "file", targetFilter: "folder"))
        XCTAssertFalse(ResourceDropTargetPolicy.accepts(targetType: "folder", targetFilter: "file"))
    }

    func testImportedResourcesRequireCurrentBookmarkBeforeFileAccess() {
        XCTAssertFalse(ResourceAuthorizationPolicy.canAccessFileSystem(status: "unavailable", hasBookmarkData: false))
        XCTAssertFalse(ResourceAuthorizationPolicy.canAccessFileSystem(status: "available", hasBookmarkData: false))
        XCTAssertFalse(ResourceAuthorizationPolicy.canAccessFileSystem(status: "staleAuthorization", hasBookmarkData: true))
        XCTAssertTrue(ResourceAuthorizationPolicy.canAccessFileSystem(status: "available", hasBookmarkData: true))
    }

    func testReauthorizationMustPreserveResourceTargetType() {
        XCTAssertTrue(ResourceAuthorizationPolicy.acceptsReauthorization(existingTargetType: "folder", selectedTargetType: "folder"))
        XCTAssertTrue(ResourceAuthorizationPolicy.acceptsReauthorization(existingTargetType: "file", selectedTargetType: "file"))
        XCTAssertFalse(ResourceAuthorizationPolicy.acceptsReauthorization(existingTargetType: "folder", selectedTargetType: "file"))
        XCTAssertFalse(ResourceAuthorizationPolicy.acceptsReauthorization(existingTargetType: "file", selectedTargetType: "folder"))
    }

    func testCanvasObstacleRoutingRequiresSmallVisibleWorkload() {
        XCTAssertTrue(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 20, obstacleCount: 40, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 25, obstacleCount: 20, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 20, obstacleCount: 41, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 20, obstacleCount: 40, isInteracting: true))
    }

    func testCanvasPerformancePolicyRejectsInvalidAndOverflowingCounts() {
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: -1, obstacleCount: 20, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 20, obstacleCount: -1, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: Int.max, obstacleCount: Int.max, isInteracting: false))
    }

    func testFolderPreviewScanPolicyBoundsEnumerationBeforeSorting() {
        XCTAssertEqual(FolderPreviewScanPolicy.scanLimit(requestedLimit: 200), 256)
        XCTAssertEqual(FolderPreviewScanPolicy.scanLimit(requestedLimit: 1), 57)
        XCTAssertEqual(FolderPreviewScanPolicy.scanLimit(requestedLimit: 0), 0)
        XCTAssertEqual(FolderPreviewScanPolicy.scanLimit(requestedLimit: -10), 0)
    }

    func testCanvasNodeColorStyleParsesHexInputs() {
        XCTAssertEqual(CanvasNodeColorStyle(rawValue: "#38bdf8")?.normalizedRawValue, "#38BDF8FF")
        XCTAssertEqual(CanvasNodeColorStyle(rawValue: "38bdf880")?.normalizedRawValue, "#38BDF880")
        XCTAssertEqual(CanvasNodeColorStyle(rawValue: "#fb3")?.normalizedRawValue, "#FFBB33FF")
    }

    func testCanvasNodeColorStyleUpdatesOpacityWithoutChangingColor() throws {
        let style = try XCTUnwrap(CanvasNodeColorStyle(rawValue: "#38BDF8"))
        XCTAssertEqual(style.withOpacity(0.42).normalizedRawValue, "#38BDF86B")
        XCTAssertEqual(style.withOpacity(-1).normalizedRawValue, "#38BDF800")
        XCTAssertEqual(style.withOpacity(2).normalizedRawValue, "#38BDF8FF")
    }

    func testCanvasNodeColorStyleRejectsInvalidInput() {
        XCTAssertNil(CanvasNodeColorStyle(rawValue: "blue"))
        XCTAssertNil(CanvasNodeColorStyle(rawValue: "#12"))
        XCTAssertNil(CanvasNodeColorStyle(rawValue: "#zzzzzz"))
    }

    func testResourceLibraryFilteringKeepsGlobalSourcesSeparateFromPinnedShortcuts() {
        let records = [
            ResourceLibraryRecord(id: "folder-source", targetType: "folder", title: "Projects", originalName: "Projects", customName: "", displayPath: "/Users/me/Projects", isPinned: false, updatedAt: Date(timeIntervalSince1970: 10), sortIndex: 0),
            ResourceLibraryRecord(id: "folder-pin", targetType: "folder", title: "Archive", originalName: "Archive", customName: "", displayPath: "/Users/me/Archive", isPinned: true, updatedAt: Date(timeIntervalSince1970: 20), sortIndex: 0),
            ResourceLibraryRecord(id: "file-pin", targetType: "file", title: "Plan.md", originalName: "Plan.md", customName: "Launch Plan", displayPath: "/Users/me/Plan.md", isPinned: true, updatedAt: Date(timeIntervalSince1970: 30), sortIndex: 0)
        ]

        XCTAssertEqual(ResourceLibraryFiltering.folders(in: records).map(\.id), ["folder-pin", "folder-source"])
        XCTAssertEqual(ResourceLibraryFiltering.files(in: records).map(\.id), ["file-pin"])
        XCTAssertEqual(ResourceLibraryFiltering.pinnedFolders(in: records).map(\.id), ["folder-pin"])
        XCTAssertEqual(ResourceLibraryFiltering.pinnedFiles(in: records).map(\.id), ["file-pin"])
    }

    func testResourceDisplayNameShowsOriginalNameThenCustomName() {
        XCTAssertEqual(
            ResourceLibraryRecord(id: "a", targetType: "file", title: "Fallback", originalName: "Invoice.pdf", customName: "Client Copy", displayPath: "/tmp/Invoice.pdf", isPinned: false).displayName,
            "Invoice.pdf · Client Copy"
        )
        XCTAssertEqual(
            ResourceLibraryRecord(id: "b", targetType: "folder", title: "Fallback", originalName: "", customName: "", displayPath: "/tmp/Research", isPinned: false).displayName,
            "Fallback"
        )
    }

    func testGlobalResourceLibraryIncludesWorkspaceOnlyResourcesWithUsage() {
        let resources = [
            ResourceLibraryRecord(id: "global-plan", targetType: "file", title: "Plan", originalName: "Plan.md", customName: "", displayPath: "/tmp/Plan.md", isPinned: false, updatedAt: Date(timeIntervalSince1970: 10), scope: "global", workspaceId: nil),
            ResourceLibraryRecord(id: "workspace-plan", targetType: "file", title: "Plan", originalName: "Plan.md", customName: "", displayPath: "/tmp/Plan.md", isPinned: false, updatedAt: Date(timeIntervalSince1970: 20), scope: "workspace", workspaceId: "workspace-a"),
            ResourceLibraryRecord(id: "workspace-only", targetType: "folder", title: "Research", originalName: "Research", customName: "", displayPath: "/tmp/Research", isPinned: false, updatedAt: Date(timeIntervalSince1970: 30), scope: "workspace", workspaceId: "workspace-b")
        ]
        let workspaces = [
            WorkspaceLibraryRecord(id: "workspace-a", title: "Alpha"),
            WorkspaceLibraryRecord(id: "workspace-b", title: "Beta")
        ]

        let records = GlobalResourceLibrary.displayRecords(resources: resources, workspaces: workspaces)

        XCTAssertEqual(records.map(\.resource.id), ["workspace-only", "global-plan"])
        XCTAssertEqual(records.first { $0.resource.id == "global-plan" }?.workspaceTitles, ["Alpha"])
        XCTAssertEqual(records.first { $0.resource.id == "workspace-only" }?.workspaceTitles, ["Beta"])
    }

    func testGlobalResourceLibraryIncludesCanvasResourceUsage() {
        let resources = [
            ResourceLibraryRecord(id: "global-md", targetType: "folder", title: "MD", originalName: "MD", customName: "", displayPath: "/tmp/MD", isPinned: false, scope: "global", workspaceId: nil),
            ResourceLibraryRecord(id: "workspace-md", targetType: "folder", title: "MD", originalName: "MD", customName: "", displayPath: "/tmp/MD", isPinned: false, scope: "workspace", workspaceId: "workspace-a"),
            ResourceLibraryRecord(id: "venv", targetType: "folder", title: "venv", originalName: "venv", customName: "", displayPath: "/tmp/MD/venv", isPinned: false, scope: "global", workspaceId: nil)
        ]
        let workspaces = [
            WorkspaceLibraryRecord(id: "workspace-a", title: "MD-Simulation"),
            WorkspaceLibraryRecord(id: "workspace-b", title: "2")
        ]
        let canvasUsages = [
            ResourceCanvasUsageRecord(resourceId: "global-md", workspaceId: "workspace-b"),
            ResourceCanvasUsageRecord(resourceId: "venv", workspaceId: "workspace-a")
        ]

        let records = GlobalResourceLibrary.displayRecords(
            resources: resources,
            workspaces: workspaces,
            canvasUsages: canvasUsages
        )

        XCTAssertEqual(records.first { $0.resource.id == "global-md" }?.workspaceTitles, ["2", "MD-Simulation"])
        XCTAssertEqual(records.first { $0.resource.id == "venv" }?.workspaceTitles, ["MD-Simulation"])
    }

    func testGlobalResourceLibraryFiltersByWorkspaceUsage() {
        let resources = [
            ResourceLibraryRecord(id: "alpha", targetType: "file", title: "Alpha", originalName: "Alpha.md", customName: "", displayPath: "/tmp/Alpha.md", isPinned: false, scope: "workspace", workspaceId: "workspace-a"),
            ResourceLibraryRecord(id: "beta", targetType: "file", title: "Beta", originalName: "Beta.md", customName: "", displayPath: "/tmp/Beta.md", isPinned: false, scope: "workspace", workspaceId: "workspace-b")
        ]
        let workspaces = [
            WorkspaceLibraryRecord(id: "workspace-a", title: "Alpha Workspace"),
            WorkspaceLibraryRecord(id: "workspace-b", title: "Beta Workspace")
        ]

        let records = GlobalResourceLibrary.displayRecords(resources: resources, workspaces: workspaces, workspaceFilterId: "workspace-b")

        XCTAssertEqual(records.map(\.resource.id), ["beta"])
        XCTAssertEqual(records.first?.workspaceTitles, ["Beta Workspace"])
    }

    func testResourceImportDeduplicationKeepsWorkspaceUsageSeparateFromGlobalPins() {
        let existing = [
            ResourceImportExistingRecord(id: "global", path: "/tmp/Plan.md", scope: "global", workspaceId: nil),
            ResourceImportExistingRecord(id: "workspace-a", path: "/tmp/Plan.md", scope: "workspace", workspaceId: "a")
        ]

        XCTAssertNil(
            ResourceImportDeduplication.reusableRecordID(
                forPath: "/tmp/Plan.md",
                scope: "workspace",
                workspaceId: "b",
                existingRecords: existing
            )
        )
        XCTAssertEqual(
            ResourceImportDeduplication.reusableRecordID(
                forPath: "/tmp/Plan.md",
                scope: "workspace",
                workspaceId: "a",
                existingRecords: existing
            ),
            "workspace-a"
        )
        XCTAssertEqual(
            ResourceImportDeduplication.reusableRecordID(
                forPath: "/tmp/Plan.md",
                scope: "global",
                workspaceId: nil,
                existingRecords: existing
            ),
            "global"
        )
    }

    func testResourceIdentityNormalizesPathsAndClassifiesKinds() {
        XCTAssertEqual(ResourceIdentity.normalizedPath("/tmp/Project/../Project/Plan.md"), "/tmp/Project/Plan.md")
        XCTAssertEqual(ResourceKind.resolved(exists: true, isDirectory: true, isPackage: false, isSymbolicLink: false, isAliasFile: false), .folder)
        XCTAssertEqual(ResourceKind.resolved(exists: true, isDirectory: true, isPackage: true, isSymbolicLink: false, isAliasFile: false), .package)
        XCTAssertEqual(ResourceKind.resolved(exists: true, isDirectory: false, isPackage: false, isSymbolicLink: true, isAliasFile: false), .symlink)
        XCTAssertEqual(ResourceKind.resolved(exists: false, isDirectory: false, isPackage: false, isSymbolicLink: false, isAliasFile: false), .unavailable)
    }

    func testReferenceIndexBuildsWhereUsedAndCleanupPlanForResource() {
        let index = ReferenceIndex(
            workspaceResources: [
                WorkspaceResourceReference(resourceId: "resource", workspaceId: "workspace")
            ],
            canvasObjects: [
                CanvasObjectReference(nodeId: "node", canvasId: "canvas", workspaceId: "workspace", objectType: "resourcePin", objectId: "resource")
            ],
            todoLinks: [
                TodoResourceReference(todoId: "todo", workspaceId: "workspace", linkedResourceId: "resource")
            ],
            snippetWorkingDirectories: [
                SnippetWorkingDirectoryReference(snippetId: "snippet", resourceId: "resource")
            ],
            aliases: [
                AliasObjectReference(aliasId: "alias", sourceObjectType: "resourcePin", sourceObjectId: "resource")
            ]
        )

        let usages = index.resourceUsages(resourceId: "resource")
        let plan = CleanupPlan.deletingResource(resourceId: "resource", index: index)

        XCTAssertEqual(usages.map(\.kind), [.workspaceResource, .canvasNode, .todo, .snippetWorkingDirectory, .alias])
        XCTAssertEqual(plan.canvasNodeIdsToDelete, ["node"])
        XCTAssertEqual(plan.todoIdsClearingLinkedResource, ["todo"])
        XCTAssertEqual(plan.snippetIdsClearingWorkingDirectory, ["snippet"])
        XCTAssertEqual(plan.aliasIdsMarkingMissing, ["alias"])
    }

    func testCanvasDropPolicySkipsExistingResourceNodesOnSameCanvas() {
        let plan = CanvasResourceDropPolicy.plan(
            resourceIds: ["resource-a", "resource-b", "resource-a"],
            canvasId: "canvas",
            existingNodes: [
                CanvasObjectReference(nodeId: "existing", canvasId: "canvas", workspaceId: "workspace", objectType: "resourcePin", objectId: "resource-a"),
                CanvasObjectReference(nodeId: "other-canvas", canvasId: "other", workspaceId: "workspace", objectType: "resourcePin", objectId: "resource-b")
            ]
        )

        XCTAssertEqual(plan.resourceIdsToCreateNodes, ["resource-b"])
        XCTAssertEqual(plan.skippedExistingResourceIds, ["resource-a"])
        XCTAssertEqual(plan.skippedDuplicateInputResourceIds, ["resource-a"])
    }

    func testResourceImportBatchSummaryReportsPerItemOutcomesAndLimit() {
        let summary = ResourceImportBatchSummary(
            insertedCount: 1,
            reusedCount: 2,
            skipped: [
                ResourceImportItemIssue(path: "/tmp/skipped", reason: "Already on this canvas")
            ],
            failed: [
                ResourceImportItemIssue(path: "/tmp/failed", reason: "Bookmark failed")
            ],
            truncatedCount: 3,
            maximumInputCount: 200
        )

        XCTAssertEqual(summary.importedCount, 3)
        XCTAssertEqual(summary.statusText, "Imported 1, reused 2, skipped 1, failed 1. 3 items were not processed because the limit is 200.")
    }

    func testSnippetLibraryFilteringShowsGlobalAndCurrentWorkspaceOnly() {
        let global = SnippetLibraryRecord(id: "global", scope: "global", workspaceId: nil, title: "Global", updatedAt: Date(timeIntervalSince1970: 1))
        let current = SnippetLibraryRecord(id: "current", scope: "workspace", workspaceId: "workspace-a", title: "Current", updatedAt: Date(timeIntervalSince1970: 3))
        let other = SnippetLibraryRecord(id: "other", scope: "workspace", workspaceId: "workspace-b", title: "Other", updatedAt: Date(timeIntervalSince1970: 4))

        let visible = SnippetLibraryFiltering.visible(
            [global, current, other],
            scope: "workspace",
            workspaceId: "workspace-a"
        )

        XCTAssertEqual(visible.map(\.id), ["current", "global"])
    }

    func testCommandRunConfirmationPolicyAlwaysConfirmsCommands() {
        XCTAssertTrue(CommandRunConfirmationPolicy.shouldConfirm(kind: "command", requiresConfirmation: true))
        XCTAssertTrue(CommandRunConfirmationPolicy.shouldConfirm(kind: "command", requiresConfirmation: false))
        XCTAssertFalse(CommandRunConfirmationPolicy.shouldConfirm(kind: "prompt", requiresConfirmation: true))
    }

    func testSnippetWorkingDirectoryOptionsKeepFoldersInResourceOrder() {
        let older = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        let records = [
            ResourceLibraryRecord(id: "file", targetType: "file", title: "Plan.md", originalName: "Plan.md", customName: "", displayPath: "/tmp/Plan.md", isPinned: true, updatedAt: newer, sortIndex: 0),
            ResourceLibraryRecord(id: "folder-b", targetType: "folder", title: "Beta", originalName: "Beta", customName: "", displayPath: "/tmp/Beta", isPinned: true, updatedAt: older, sortIndex: 2),
            ResourceLibraryRecord(id: "folder-a", targetType: "folder", title: "Alpha", originalName: "Alpha", customName: "", displayPath: "/tmp/Alpha", isPinned: true, updatedAt: newer, sortIndex: 1)
        ]

        XCTAssertEqual(SnippetWorkingDirectoryOptions.folders(in: records).map(\.id), ["folder-a", "folder-b"])
    }

    func testSnippetWorkingDirectoryOptionsDropInvalidSelection() {
        let records = [
            ResourceLibraryRecord(id: "folder", targetType: "folder", title: "Folder", originalName: "Folder", customName: "", displayPath: "/tmp/Folder", isPinned: true),
            ResourceLibraryRecord(id: "file", targetType: "file", title: "Plan.md", originalName: "Plan.md", customName: "", displayPath: "/tmp/Plan.md", isPinned: true)
        ]

        XCTAssertEqual(SnippetWorkingDirectoryOptions.validSelection("folder", in: records), "folder")
        XCTAssertNil(SnippetWorkingDirectoryOptions.validSelection("file", in: records))
        XCTAssertNil(SnippetWorkingDirectoryOptions.validSelection("missing", in: records))
        XCTAssertNil(SnippetWorkingDirectoryOptions.validSelection(nil, in: records))
    }

    func testCanvasEdgeIdentityTreatsOppositeDirectionsAsDifferentLinks() {
        let existing = [
            CanvasEdgeIdentity(sourceNodeId: "a", targetNodeId: "b")
        ]

        XCTAssertTrue(CanvasEdgeIdentity.exists(sourceNodeId: "a", targetNodeId: "b", in: existing))
        XCTAssertFalse(CanvasEdgeIdentity.exists(sourceNodeId: "b", targetNodeId: "a", in: existing))
    }

    func testFinderRoutingRevealsFilesButOpensFolders() {
        XCTAssertEqual(ResourceFinderRouting.doubleClickAction(forTargetType: "folder"), .open)
        XCTAssertEqual(ResourceFinderRouting.doubleClickAction(forTargetType: "file"), .reveal)
    }

    func testFrameGeometryFindsFullyContainedChildrenOnly() {
        let frame = CanvasFrameRect(id: "frame", x: 0, y: 0, width: 300, height: 220)
        let candidates = [
            CanvasFrameRect(id: "inside", x: 40, y: 50, width: 120, height: 80),
            CanvasFrameRect(id: "overlap", x: 250, y: 50, width: 120, height: 80),
            CanvasFrameRect(id: "outside", x: 320, y: 50, width: 80, height: 80)
        ]

        XCTAssertEqual(CanvasFrameGeometry.childNodeIDs(inside: frame, candidates: candidates), ["inside"])
    }

    func testFrameGeometryMovesFrameAndChildrenBySameDelta() {
        let positions = [
            CanvasFramePosition(id: "frame", x: 0, y: 0),
            CanvasFramePosition(id: "child-a", x: 40, y: 50),
            CanvasFramePosition(id: "child-b", x: 100, y: 120),
            CanvasFramePosition(id: "outside", x: 400, y: 120)
        ]

        let moved = CanvasFrameGeometry.movedPositions(
            positions,
            movingFrameId: "frame",
            childNodeIDs: ["child-a", "child-b"],
            deltaX: 24,
            deltaY: -16
        )

        XCTAssertEqual(moved.first { $0.id == "frame" }?.x, 24)
        XCTAssertEqual(moved.first { $0.id == "frame" }?.y, -16)
        XCTAssertEqual(moved.first { $0.id == "child-a" }?.x, 64)
        XCTAssertEqual(moved.first { $0.id == "child-a" }?.y, 34)
        XCTAssertEqual(moved.first { $0.id == "outside" }?.x, 400)
        XCTAssertEqual(moved.first { $0.id == "outside" }?.y, 120)
    }

    func testFrameGeometryMovesContainedEdgeControlPointsWithFrame() {
        let frame = CanvasFrameRect(id: "frame", x: 100, y: 80, width: 300, height: 220)
        let points = [
            CanvasFramePosition(id: "inside", x: 180, y: 140),
            CanvasFramePosition(id: "outside", x: 40, y: 140)
        ]

        let moved = CanvasFrameGeometry.movedControlPoints(
            points,
            inside: frame,
            deltaX: 32,
            deltaY: -12
        )

        XCTAssertEqual(moved.first { $0.id == "inside" }?.x, 212)
        XCTAssertEqual(moved.first { $0.id == "inside" }?.y, 128)
        XCTAssertEqual(moved.first { $0.id == "outside" }?.x, 40)
        XCTAssertEqual(moved.first { $0.id == "outside" }?.y, 140)
    }

    func testFrameGeometryResolvesContainmentFromMovedRects() throws {
        let rects = [
            CanvasFrameRect(id: "frame", x: 0, y: 0, width: 300, height: 220),
            CanvasFrameRect(id: "child", x: 40, y: 50, width: 120, height: 80),
            CanvasFrameRect(id: "other-frame", x: 500, y: 0, width: 300, height: 220)
        ]

        let movedRects = CanvasFrameGeometry.movedRects(
            rects,
            movedIDs: ["frame", "child"],
            deltaX: 500,
            deltaY: 0
        )
        let child = try XCTUnwrap(movedRects.first { $0.id == "child" })
        let frames = movedRects.filter { ["frame", "other-frame"].contains($0.id) }

        XCTAssertEqual(CanvasFrameGeometry.containingFrameId(for: child, frames: frames), "frame")
    }

    func testCanvasEdgeAnchoringUsesHorizontalEdgeMidpoints() {
        let source = CanvasFrameRect(id: "left", x: 0, y: 20, width: 100, height: 80)
        let target = CanvasFrameRect(id: "right", x: 240, y: 60, width: 120, height: 90)

        let anchors = CanvasEdgeAnchoring.anchors(source: source, target: target)

        XCTAssertEqual(anchors.start, CanvasEdgePoint(x: 100, y: 60))
        XCTAssertEqual(anchors.end, CanvasEdgePoint(x: 240, y: 105))
    }

    func testCanvasEdgeAnchoringUsesVerticalEdgeMidpoints() {
        let source = CanvasFrameRect(id: "top", x: 20, y: 0, width: 120, height: 80)
        let target = CanvasFrameRect(id: "bottom", x: 60, y: 240, width: 100, height: 70)

        let anchors = CanvasEdgeAnchoring.anchors(source: source, target: target)

        XCTAssertEqual(anchors.start, CanvasEdgePoint(x: 80, y: 80))
        XCTAssertEqual(anchors.end, CanvasEdgePoint(x: 110, y: 240))
    }

    func testCanvasEdgeAnchoringCanStopBeforeTargetBorderForVisibleArrowheads() {
        let source = CanvasFrameRect(id: "left", x: 0, y: 0, width: 100, height: 80)
        let target = CanvasFrameRect(id: "right", x: 240, y: 0, width: 120, height: 80)

        let anchors = CanvasEdgeAnchoring.anchors(source: source, target: target, targetClearance: 14)

        XCTAssertEqual(anchors.start, CanvasEdgePoint(x: 100, y: 40))
        XCTAssertEqual(anchors.end, CanvasEdgePoint(x: 226, y: 40))
    }

    func testCanvasEdgeAnchoringUsesControlPointDirectionForSourceWhenPresent() {
        let source = CanvasFrameRect(id: "left", x: 0, y: 80, width: 100, height: 80)
        let target = CanvasFrameRect(id: "right", x: 240, y: 80, width: 120, height: 90)
        let control = CanvasEdgePoint(x: 50, y: 250)

        let anchors = CanvasEdgeAnchoring.anchors(
            source: source,
            target: target,
            control: control,
            targetClearance: 12
        )

        XCTAssertEqual(anchors.start, CanvasEdgePoint(x: 50, y: 160))
        XCTAssertEqual(anchors.end, CanvasEdgePoint(x: 228, y: 125))
    }

    func testCanvasEdgeAnchoringUsesControlPointDirectionForTargetWhenPresent() {
        let source = CanvasFrameRect(id: "left", x: 0, y: 80, width: 100, height: 80)
        let target = CanvasFrameRect(id: "right", x: 240, y: 80, width: 120, height: 90)
        let control = CanvasEdgePoint(x: 300, y: 0)

        let anchors = CanvasEdgeAnchoring.anchors(
            source: source,
            target: target,
            control: control,
            targetClearance: 12
        )

        XCTAssertEqual(anchors.start, CanvasEdgePoint(x: 100, y: 120))
        XCTAssertEqual(anchors.end, CanvasEdgePoint(x: 300, y: 68))
    }

    func testCanvasEdgeAnchoringReportsInwardTargetDirectionForLeftAndTopEdges() {
        let source = CanvasFrameRect(id: "source", x: 0, y: 80, width: 100, height: 80)
        let leftTarget = CanvasFrameRect(id: "left-target", x: 240, y: 80, width: 120, height: 90)
        let topTarget = CanvasFrameRect(id: "top-target", x: 240, y: 80, width: 120, height: 90)

        let leftAnchors = CanvasEdgeAnchoring.anchors(
            source: source,
            target: leftTarget,
            control: CanvasEdgePoint(x: 40, y: 120)
        )
        let topAnchors = CanvasEdgeAnchoring.anchors(
            source: source,
            target: topTarget,
            control: CanvasEdgePoint(x: 300, y: 0)
        )

        XCTAssertEqual(leftAnchors.endDirection, CanvasEdgePoint(x: 1, y: 0))
        XCTAssertEqual(topAnchors.endDirection, CanvasEdgePoint(x: 0, y: 1))
    }

    func testCanvasEdgeCurveApproachesTargetFromOutsideLeftBorder() {
        let controls = CanvasEdgeCurveGeometry.automaticControls(
            start: CanvasEdgePoint(x: 100, y: 120),
            end: CanvasEdgePoint(x: 240, y: 125),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0)
        )

        XCTAssertGreaterThan(controls.control1.x, 100)
        XCTAssertLessThan(controls.control2.x, 240)
        XCTAssertEqual(
            CanvasEdgeCurveGeometry.terminalAngleRadians(endDirection: CanvasEdgePoint(x: 1, y: 0)),
            0,
            accuracy: 0.0001
        )
    }

    func testCanvasEdgeCurveApproachesTargetFromOutsideTopBorder() {
        let controls = CanvasEdgeCurveGeometry.automaticControls(
            start: CanvasEdgePoint(x: 100, y: 120),
            end: CanvasEdgePoint(x: 300, y: 80),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 0, y: 1)
        )

        XCTAssertLessThan(controls.control2.y, 80)
        XCTAssertEqual(
            CanvasEdgeCurveGeometry.terminalAngleRadians(endDirection: CanvasEdgePoint(x: 0, y: 1)),
            Double.pi / 2,
            accuracy: 0.0001
        )
    }

    func testCanvasEdgeCurveKeepsContinuousTangentThroughControlPoint() {
        let segments = CanvasEdgeCurveGeometry.controlsThroughPoint(
            start: CanvasEdgePoint(x: 100, y: 120),
            control: CanvasEdgePoint(x: 190, y: 20),
            end: CanvasEdgePoint(x: 300, y: 80),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 0, y: 1)
        )

        let incomingTangent = CanvasEdgePoint(
            x: 190 - segments.first.control2.x,
            y: 20 - segments.first.control2.y
        )
        let outgoingTangent = CanvasEdgePoint(
            x: segments.second.control1.x - 190,
            y: segments.second.control1.y - 20
        )

        XCTAssertEqual(
            incomingTangent.x * outgoingTangent.y - incomingTangent.y * outgoingTangent.x,
            0,
            accuracy: 0.0001
        )
        XCTAssertGreaterThan(incomingTangent.x * outgoingTangent.x + incomingTangent.y * outgoingTangent.y, 0)
    }

    func testCanvasEdgeRoutePlannerReturnsNoRouteWhenDirectPathIsClear() {
        let route = CanvasEdgeRoutePlanner.routePoints(
            start: CanvasEdgePoint(x: 100, y: 40),
            end: CanvasEdgePoint(x: 320, y: 40),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [
                CanvasFrameRect(id: "clear", x: 160, y: 120, width: 100, height: 80)
            ],
            clearance: 24
        )

        XCTAssertTrue(route.isEmpty)
    }

    func testCanvasEdgeRoutePlannerRoutesAroundCardOnDirectPath() {
        let obstacle = CanvasFrameRect(id: "middle", x: 160, y: 0, width: 100, height: 90)
        let route = CanvasEdgeRoutePlanner.routePoints(
            start: CanvasEdgePoint(x: 100, y: 40),
            end: CanvasEdgePoint(x: 340, y: 40),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [obstacle],
            clearance: 24
        )
        let polyline = [CanvasEdgePoint(x: 100, y: 40)] + route + [CanvasEdgePoint(x: 340, y: 40)]

        XCTAssertFalse(route.isEmpty)
        XCTAssertFalse(CanvasEdgeRoutePlanner.polylineIntersectsObstacles(polyline, obstacles: [obstacle], clearance: 24))
    }

    func testCanvasEdgeRoutePlannerReroutesWhenMovedCardBecomesObstacle() {
        let start = CanvasEdgePoint(x: 100, y: 40)
        let end = CanvasEdgePoint(x: 340, y: 40)
        let clearObstacle = CanvasFrameRect(id: "middle", x: 160, y: 140, width: 100, height: 90)
        let blockingObstacle = CanvasFrameRect(id: "middle", x: 160, y: 0, width: 100, height: 90)

        let clearRoute = CanvasEdgeRoutePlanner.routePoints(
            start: start,
            end: end,
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [clearObstacle],
            clearance: 24
        )
        let blockingRoute = CanvasEdgeRoutePlanner.routePoints(
            start: start,
            end: end,
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [blockingObstacle],
            clearance: 24
        )

        XCTAssertTrue(clearRoute.isEmpty)
        XCTAssertFalse(blockingRoute.isEmpty)
    }

    func testCanvasEdgeRoutePlannerRoutesControlPointSegmentsAroundCard() {
        let start = CanvasEdgePoint(x: 100, y: 40)
        let control = CanvasEdgePoint(x: 220, y: 140)
        let end = CanvasEdgePoint(x: 340, y: 40)
        let obstacle = CanvasFrameRect(id: "middle", x: 170, y: 55, width: 100, height: 65)

        let route = CanvasEdgeRoutePlanner.routePoints(
            start: start,
            end: end,
            waypoints: [control],
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [obstacle],
            clearance: 18
        )
        let polyline = [start] + route + [end]

        XCTAssertTrue(route.contains(control))
        XCTAssertFalse(route.isEmpty)
        XCTAssertFalse(CanvasEdgeRoutePlanner.polylineIntersectsObstacles(polyline, obstacles: [obstacle], clearance: 18))
    }

    func testCanvasEdgeRouteDefaultsDoNotRerouteNearButClearCards() {
        let route = CanvasEdgeRoutePlanner.routePoints(
            start: CanvasEdgePoint(x: 100, y: 40),
            end: CanvasEdgePoint(x: 340, y: 40),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [
                CanvasFrameRect(id: "near", x: 160, y: 43, width: 100, height: 80)
            ],
            clearance: CanvasEdgeRouteDefaults.routingClearance
        )

        XCTAssertTrue(route.isEmpty)
        XCTAssertLessThanOrEqual(CanvasEdgeRouteDefaults.routingClearance, 3)
    }

    func testCanvasEdgeRouteDefaultsStillRerouteActualIntersections() {
        let route = CanvasEdgeRoutePlanner.routePoints(
            start: CanvasEdgePoint(x: 100, y: 40),
            end: CanvasEdgePoint(x: 340, y: 40),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            obstacles: [
                CanvasFrameRect(id: "blocking", x: 160, y: 20, width: 100, height: 80)
            ],
            clearance: CanvasEdgeRouteDefaults.routingClearance
        )

        XCTAssertFalse(route.isEmpty)
    }

    func testCanvasEdgeHitTestingSelectsOnlyTheNearestLineWithinThreshold() {
        let hit = CanvasEdgeHitTesting.nearestEdgeID(
            at: CanvasEdgePoint(x: 180, y: 43),
            edges: [
                CanvasEdgeHitRecord(id: "a-b", points: [
                    CanvasEdgePoint(x: 100, y: 40),
                    CanvasEdgePoint(x: 260, y: 40)
                ]),
                CanvasEdgeHitRecord(id: "far", points: [
                    CanvasEdgePoint(x: 100, y: 120),
                    CanvasEdgePoint(x: 260, y: 120)
                ])
            ],
            threshold: 6
        )

        XCTAssertEqual(hit, "a-b")
        XCTAssertNil(CanvasEdgeHitTesting.nearestEdgeID(
            at: CanvasEdgePoint(x: 180, y: 60),
            edges: [
                CanvasEdgeHitRecord(id: "a-b", points: [
                    CanvasEdgePoint(x: 100, y: 40),
                    CanvasEdgePoint(x: 260, y: 40)
                ])
            ],
            threshold: 6
        ))
    }

    func testCanvasEdgeDeletionPrefersSelectedEdgesAndDoesNotDeleteSingleNodeLinks() {
        let edges = [
            CanvasEdgeEndpointRecord(id: "a-b", sourceNodeId: "a", targetNodeId: "b"),
            CanvasEdgeEndpointRecord(id: "a-c", sourceNodeId: "a", targetNodeId: "c")
        ]

        XCTAssertEqual(
            CanvasEdgeDeletionPolicy.edgeIDsToDelete(selectedEdgeIDs: ["a-b"], selectedNodeIDs: ["a"], edges: edges),
            ["a-b"]
        )
        XCTAssertEqual(
            CanvasEdgeDeletionPolicy.edgeIDsToDelete(selectedEdgeIDs: [], selectedNodeIDs: ["a"], edges: edges),
            []
        )
        XCTAssertEqual(
            CanvasEdgeDeletionPolicy.edgeIDsToDelete(selectedEdgeIDs: [], selectedNodeIDs: ["a", "b"], edges: edges),
            ["a-b"]
        )
    }

    func testCanvasEdgeDeletionRequiresLineSelectionForAmbiguousPairLinks() {
        let edges = [
            CanvasEdgeEndpointRecord(id: "a-b", sourceNodeId: "a", targetNodeId: "b"),
            CanvasEdgeEndpointRecord(id: "b-a", sourceNodeId: "b", targetNodeId: "a")
        ]

        XCTAssertEqual(
            CanvasEdgeDeletionPolicy.edgeIDsToDelete(selectedEdgeIDs: [], selectedNodeIDs: ["a", "b"], edges: edges),
            []
        )
    }

    func testCanvasNodeDeletionPolicyDeletesIncidentEdges() {
        let edges = [
            CanvasEdgeEndpointRecord(id: "a-b", sourceNodeId: "a", targetNodeId: "b"),
            CanvasEdgeEndpointRecord(id: "b-c", sourceNodeId: "b", targetNodeId: "c"),
            CanvasEdgeEndpointRecord(id: "c-d", sourceNodeId: "c", targetNodeId: "d")
        ]

        XCTAssertEqual(
            CanvasNodeDeletionPolicy.incidentEdgeIDs(selectedNodeIDs: ["a", "b"], edges: edges),
            ["a-b", "b-c"]
        )
    }

    func testCanvasViewportProjectionUsesScaledVisibleBounds() {
        let rect = CanvasViewportProjection.screenRect(
            id: "node",
            x: 100,
            y: 40,
            width: 214,
            height: 132,
            offsetX: 12,
            offsetY: -4,
            zoom: 0.5425,
            viewportX: 20,
            viewportY: 30
        )

        XCTAssertEqual(rect.x, 80.76, accuracy: 0.0001)
        XCTAssertEqual(rect.y, 49.53, accuracy: 0.0001)
        XCTAssertEqual(rect.width, 116.095, accuracy: 0.0001)
        XCTAssertEqual(rect.height, 71.61, accuracy: 0.0001)
    }

    func testCanvasViewportProjectionSanitizesNonFiniteGeometry() {
        let rect = CanvasViewportProjection.screenRect(
            id: "bad",
            x: .nan,
            y: .infinity,
            width: .nan,
            height: -.infinity,
            offsetX: .infinity,
            offsetY: .nan,
            zoom: .nan,
            viewportX: .infinity,
            viewportY: .nan
        )

        XCTAssertTrue(rect.x.isFinite)
        XCTAssertTrue(rect.y.isFinite)
        XCTAssertTrue(rect.width.isFinite)
        XCTAssertTrue(rect.height.isFinite)
        XCTAssertGreaterThanOrEqual(rect.width, 0)
        XCTAssertGreaterThanOrEqual(rect.height, 0)
    }

    func testProjectedEdgeAnchorsLandOnTargetVisibleBorder() {
        let source = CanvasViewportProjection.screenRect(
            id: "source",
            x: 100,
            y: 80,
            width: 214,
            height: 132,
            zoom: 0.5425,
            viewportX: 20,
            viewportY: 30
        )
        let target = CanvasViewportProjection.screenRect(
            id: "target",
            x: 460,
            y: 120,
            width: 214,
            height: 132,
            zoom: 0.5425,
            viewportX: 20,
            viewportY: 30
        )

        let anchors = CanvasEdgeAnchoring.anchors(source: source, target: target)

        XCTAssertEqual(anchors.start.x, source.x + source.width, accuracy: 0.0001)
        XCTAssertEqual(anchors.end.x, target.x, accuracy: 0.0001)
    }

    func testCanvasViewportProjectionConvertsScreenPointBackToCanvasPoint() {
        let point = CanvasViewportProjection.canvasPoint(
            screenX: 220,
            screenY: 146,
            zoom: 0.5,
            viewportX: 20,
            viewportY: -4
        )

        XCTAssertEqual(point.x, 400, accuracy: 0.0001)
        XCTAssertEqual(point.y, 300, accuracy: 0.0001)
    }

    func testCanvasHitTestingTreatsFullScaledCardRectAsNode() {
        let folder = CanvasFrameRect(id: "folder", x: 150, y: 300, width: 316, height: 226)

        XCTAssertEqual(
            CanvasHitTesting.target(
                at: CanvasEdgePoint(x: 158, y: 306),
                nodes: [folder]
            ),
            .node("folder")
        )
    }

    func testCanvasHitTestingFallsBackToBackgroundOutsideNodes() {
        let folder = CanvasFrameRect(id: "folder", x: 150, y: 300, width: 316, height: 226)

        XCTAssertEqual(
            CanvasHitTesting.target(
                at: CanvasEdgePoint(x: 149, y: 306),
                nodes: [folder]
            ),
            .background
        )
    }

    func testCanvasHitTestingUsesInteractionSlopAroundCardBorders() {
        let folder = CanvasFrameRect(id: "folder", x: 150, y: 300, width: 316, height: 226)

        XCTAssertEqual(
            CanvasHitTesting.target(
                at: CanvasEdgePoint(x: 158, y: 296),
                nodes: [folder],
                hitSlop: CanvasInteractionMetrics.nodeHitSlop
            ),
            .node("folder")
        )
    }

    func testCanvasIconButtonMetricsCenterSymbolInCircle() {
        XCTAssertEqual(CanvasIconButtonMetrics.circleDiameter, 22)
        XCTAssertEqual(CanvasIconButtonMetrics.symbolDiameter, 13)
        XCTAssertEqual(CanvasIconButtonMetrics.symbolOrigin, 4.5)
    }

    func testCanvasResizeHandleOverlayTracksScaledBottomRightCorner() {
        let rect = CanvasFrameRect(id: "card", x: 120, y: 80, width: 214 * 1.4, height: 132 * 1.4)

        let center = CanvasResizeHandleGeometry.center(in: rect, zoom: 1.4)
        let hitRect = CanvasResizeHandleGeometry.hitRect(center: center, zoom: 1.4)

        XCTAssertEqual(center.x, rect.x + rect.width - 17 * 1.4, accuracy: 0.0001)
        XCTAssertEqual(center.y, rect.y + rect.height - 17 * 1.4, accuracy: 0.0001)
        XCTAssertTrue(hitRect.width >= 34 * 1.4)
        XCTAssertTrue(CanvasResizeHandleGeometry.contains(center, in: hitRect))
    }

    func testCanvasResizeHandleHitRectIsClampedForExtremeZoom() {
        let center = CanvasEdgePoint(x: 200, y: 160)

        XCTAssertEqual(CanvasResizeHandleGeometry.hitRect(center: center, zoom: 0.12).width, 30, accuracy: 0.0001)
        XCTAssertEqual(CanvasResizeHandleGeometry.hitRect(center: center, zoom: 4.0).width, 56, accuracy: 0.0001)
    }

    func testCanvasEdgeControlPointAndHandleScaleWithZoom() {
        let control = CanvasViewportProjection.screenPoint(
            x: 300,
            y: 160,
            zoom: 1.85,
            viewportX: 24,
            viewportY: -10
        )

        XCTAssertEqual(control.x, 579, accuracy: 0.0001)
        XCTAssertEqual(control.y, 286, accuracy: 0.0001)
        XCTAssertEqual(CanvasEdgeControlHandleMetrics.diameter(zoom: 1.85, baseDiameter: 13), 24.05, accuracy: 0.0001)
    }

    func testCanvasGeometryUsesFiniteFallbackZoom() {
        let canvasPoint = CanvasViewportProjection.canvasPoint(
            screenX: 400,
            screenY: 300,
            zoom: .nan,
            viewportX: 20,
            viewportY: -10
        )
        let dropOrigin = CanvasDropPlacement.cardOrigin(
            dropX: 400,
            dropY: 300,
            viewportX: 20,
            viewportY: -10,
            zoom: .nan,
            cardWidth: 200,
            cardHeight: 120
        )

        XCTAssertEqual(canvasPoint.x, 380, accuracy: 0.0001)
        XCTAssertEqual(canvasPoint.y, 310, accuracy: 0.0001)
        XCTAssertEqual(dropOrigin.x, 280, accuracy: 0.0001)
        XCTAssertEqual(dropOrigin.y, 250, accuracy: 0.0001)
        XCTAssertEqual(CanvasEdgeControlHandleMetrics.diameter(zoom: .nan, baseDiameter: 13), 13, accuracy: 0.0001)
    }

    func testCanvasViewportVisibilityPolicyKeepsOverscanBounded() {
        XCTAssertEqual(CanvasViewportVisibilityPolicy.nodeOverscanPixels(zoom: 0.02, baselineZoom: 0.35), 220, accuracy: 0.0001)
        XCTAssertEqual(CanvasViewportVisibilityPolicy.nodeOverscanPixels(zoom: 0.35, baselineZoom: 0.35), 320, accuracy: 0.0001)
        XCTAssertEqual(CanvasViewportVisibilityPolicy.nodeOverscanPixels(zoom: 4.0, baselineZoom: 0.35), 640, accuracy: 0.0001)
    }

    func testCanvasZoomScaleRejectsNonFiniteValues() {
        XCTAssertEqual(CanvasZoomScale.clamped(.nan, minimum: 0.12, maximum: 2.4), 0.35, accuracy: 0.0001)
        XCTAssertEqual(CanvasZoomScale.displayPercent(forZoom: .nan, baseline: 0.35), 100)
        XCTAssertEqual(CanvasZoomBaseline.actualZoom(percent: .nan, standardBaseline: 0.35, minimum: 0.12, maximum: 2.4), 0.35, accuracy: 0.0001)
        XCTAssertEqual(CanvasZoomBaseline.actualZoom(percent: .nan, standardBaseline: 0.5, minimum: 0.12, maximum: 2.4), 0.5, accuracy: 0.0001)
        XCTAssertEqual(CanvasZoomScale.zoom(forScrollDeltaY: 10, current: .infinity, minimum: 0.12, maximum: 2.4), 0.35, accuracy: 0.0001)
    }

    func testCanvasAutoArrangeHandlesDuplicateNodeIDs() {
        let arranged = CanvasLayoutEngine.autoArrange(
            [
                CanvasLayoutNode(id: "duplicate", x: 10, y: 10, width: 180, height: 120),
                CanvasLayoutNode(id: "duplicate", x: 20, y: 20, width: 220, height: 160),
                CanvasLayoutNode(id: "unique", x: 30, y: 30, width: 200, height: 140)
            ],
            edges: [
                CanvasLayoutEdge(sourceNodeId: "duplicate", targetNodeId: "unique")
            ]
        )

        XCTAssertEqual(arranged.count, 3)
        XCTAssertTrue(arranged.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }

    func testCanvasEdgeStyleOptionsKeepBaseStyleWhenLockingAnchor() {
        let locked = CanvasEdgeStyleOptions.style("dashed", controlPointLocked: true)

        XCTAssertTrue(CanvasEdgeStyleOptions.isControlPointLocked(locked))
        XCTAssertEqual(CanvasEdgeStyleOptions.style(locked, controlPointLocked: false), "dashed")
    }

    func testCanvasEdgeRecordKeepsCustomControlPoint() throws {
        let edge = CanvasEdgeRecord(
            id: "edge",
            canvasId: "canvas",
            sourceNodeId: "source",
            targetNodeId: "target",
            label: "",
            controlPointX: 320,
            controlPointY: 180
        )

        let encoded = try JSONEncoder().encode(edge)
        let decoded = try JSONDecoder().decode(CanvasEdgeRecord.self, from: encoded)

        XCTAssertEqual(decoded.controlPointX, 320)
        XCTAssertEqual(decoded.controlPointY, 180)
    }

    func testCanvasEdgeFlowPhaseWrapsWithoutStatefulAnimation() {
        XCTAssertEqual(CanvasEdgeFlowPhase.dashPhase(elapsed: 0, duration: 2, cycleLength: 180), 0)
        XCTAssertEqual(CanvasEdgeFlowPhase.dashPhase(elapsed: 1, duration: 2, cycleLength: 180), -90)
        XCTAssertEqual(CanvasEdgeFlowPhase.dashPhase(elapsed: 2.5, duration: 2, cycleLength: 180), -45)
    }

    func testCanvasEdgeAnimationPolicyPausesWhileCanvasIsInteracting() {
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            edgeCount: 12,
            isInteracting: true
        ))
    }

    func testFrameGeometryResizingClampsToMinimumSize() {
        let frame = CanvasFrameRect(id: "frame", x: 0, y: 0, width: 300, height: 220)

        let resized = CanvasFrameGeometry.resizedFrame(frame, deltaWidth: -200, deltaHeight: -120, minimumWidth: 240, minimumHeight: 160)

        XCTAssertEqual(resized.x, 0)
        XCTAssertEqual(resized.y, 0)
        XCTAssertEqual(resized.width, 240)
        XCTAssertEqual(resized.height, 160)
    }

    func testCanvasNodeSizePolicyUsesStoredCardSizeWithMinimums() {
        let resource = CanvasNodeSizePolicy.size(
            kind: "resource",
            storedWidth: 360,
            storedHeight: 240,
            defaultWidth: 214,
            defaultHeight: 132,
            minimumWidth: 180,
            minimumHeight: 112
        )
        let note = CanvasNodeSizePolicy.size(
            kind: "note",
            storedWidth: 80,
            storedHeight: 60,
            defaultWidth: 240,
            defaultHeight: 180,
            minimumWidth: 180,
            minimumHeight: 140
        )

        XCTAssertEqual(resource.width, 360)
        XCTAssertEqual(resource.height, 240)
        XCTAssertEqual(note.width, 180)
        XCTAssertEqual(note.height, 140)
    }

    func testCanvasNodeSizePolicyRejectsNonFiniteAndExtremeStoredSizes() {
        let fallback = CanvasNodeSizePolicy.size(
            kind: "resource",
            storedWidth: .infinity,
            storedHeight: .nan,
            defaultWidth: 214,
            defaultHeight: 132,
            minimumWidth: 180,
            minimumHeight: 112
        )
        let huge = CanvasNodeSizePolicy.size(
            kind: "resource",
            storedWidth: 99_999,
            storedHeight: 80_000,
            defaultWidth: 214,
            defaultHeight: 132,
            minimumWidth: 180,
            minimumHeight: 112
        )

        XCTAssertEqual(fallback.width, 214)
        XCTAssertEqual(fallback.height, 132)
        XCTAssertEqual(huge.width, CanvasNodeSizePolicy.maximumDimension)
        XCTAssertEqual(huge.height, CanvasNodeSizePolicy.maximumDimension)
    }

    func testCanvasCardTitleLayoutKeepsNoteTitleBoxHalfResourceHeight() {
        let noteHeight = CanvasCardTitleLayoutPolicy.maxTitleHeight(
            kind: "note",
            cardHeight: 180
        )
        let resourceHeight = CanvasCardTitleLayoutPolicy.maxTitleHeight(
            kind: "resource",
            cardHeight: 180
        )

        XCTAssertEqual(noteHeight, resourceHeight / 2)
        XCTAssertEqual(noteHeight, 18)
        XCTAssertEqual(resourceHeight, 36)
    }

    func testCanvasChromeRenderingUsesNativeDrawingForSmallText() {
        XCTAssertTrue(CanvasChromeRenderingPolicy.requiresNativeDrawing(.cardHeader))
        XCTAssertTrue(CanvasChromeRenderingPolicy.requiresNativeDrawing(.cardDetailLabel))
        XCTAssertTrue(CanvasChromeRenderingPolicy.requiresNativeDrawing(.cardDetailBody))
        XCTAssertTrue(CanvasChromeRenderingPolicy.requiresNativeDrawing(.frameNote))
    }

    func testFrameGeometryChoosesSmallestContainingFrame() {
        let card = CanvasFrameRect(id: "card", x: 80, y: 80, width: 100, height: 80)
        let frames = [
            CanvasFrameRect(id: "outer", x: 0, y: 0, width: 400, height: 300),
            CanvasFrameRect(id: "inner", x: 60, y: 60, width: 180, height: 140)
        ]

        XCTAssertEqual(CanvasFrameGeometry.containingFrameId(for: card, frames: frames), "inner")
    }

    func testCanvasDropPlacementCentersCardAtDropLocation() {
        let placement = CanvasDropPlacement.cardOrigin(
            dropX: 260,
            dropY: 180,
            viewportX: 40,
            viewportY: -20,
            zoom: 2,
            cardWidth: 120,
            cardHeight: 80
        )

        XCTAssertEqual(placement.x, 50)
        XCTAssertEqual(placement.y, 60)
    }

    func testCanvasZoomScaleLabelsBaselineZoomAsOneHundredPercent() {
        XCTAssertEqual(CanvasZoomScale.displayPercent(forZoom: 0.35, baseline: 0.35), 100)
        XCTAssertEqual(CanvasZoomScale.displayPercent(forZoom: 0.175, baseline: 0.35), 50)
    }

    func testCanvasZoomBaselineUsesUserPercentAsDisplayedHundredPercent() {
        let baseline = CanvasZoomBaseline.actualZoom(
            percent: 250,
            standardBaseline: 0.35,
            minimum: 0.12,
            maximum: 2.4
        )

        XCTAssertEqual(baseline, 0.875, accuracy: 0.0001)
        XCTAssertEqual(CanvasZoomScale.displayPercent(forZoom: baseline, baseline: baseline), 100)
    }

    func testCanvasZoomScaleAllowsZoomBelowBaseline() {
        XCTAssertEqual(CanvasZoomScale.clamped(0.10, minimum: 0.12, maximum: 2.4), 0.12)
        XCTAssertEqual(CanvasZoomScale.zoom(forDisplayScale: 1, baseline: 0.35, minimum: 0.12, maximum: 2.4), 0.35)
        XCTAssertEqual(CanvasZoomScale.zoom(forDisplayScale: 0.5, baseline: 0.35, minimum: 0.12, maximum: 2.4), 0.175)
    }

    func testCanvasZoomScaleUsesWheelDeltaDirection() {
        let current = 1.0

        XCTAssertGreaterThan(
            CanvasZoomScale.zoom(forScrollDeltaY: -20, current: current, minimum: 0.12, maximum: 2.4),
            current
        )
        XCTAssertLessThan(
            CanvasZoomScale.zoom(forScrollDeltaY: 20, current: current, minimum: 0.12, maximum: 2.4),
            current
        )
    }

    func testCanvasZoomScaleCanReverseWheelDeltaDirection() {
        let current = 1.0

        XCTAssertLessThan(
            CanvasZoomScale.zoom(
                forScrollDeltaY: 20,
                current: current,
                minimum: 0.12,
                maximum: 2.4,
                direction: .scrollDownZoomsOut
            ),
            current
        )
        XCTAssertGreaterThan(
            CanvasZoomScale.zoom(
                forScrollDeltaY: 20,
                current: current,
                minimum: 0.12,
                maximum: 2.4,
                direction: .scrollDownZoomsIn
            ),
            current
        )
    }

    func testCanvasZoomScaleKeepsScreenAnchorStable() {
        let viewport = CanvasZoomScale.viewport(
            keepingScreenX: 300,
            screenY: 200,
            canvasX: 250,
            canvasY: 150,
            zoom: 1.5
        )

        XCTAssertEqual(viewport.x, -75, accuracy: 0.0001)
        XCTAssertEqual(viewport.y, -25, accuracy: 0.0001)
    }

    func testCanvasViewportFitPolicyCentersBoundsAndClampsZoom() {
        let fit = CanvasViewportFitPolicy.fit(
            bounds: CanvasFrameRect(id: "bounds", x: 100, y: 50, width: 400, height: 200),
            viewportWidth: 1_000,
            viewportHeight: 700,
            padding: 100,
            minimumZoom: 0.12,
            maximumZoom: 2.4
        )

        XCTAssertNotNil(fit)
        XCTAssertEqual(fit?.zoom ?? .nan, 2.0, accuracy: 0.0001)
        XCTAssertEqual(fit?.viewportX ?? .nan, -100, accuracy: 0.0001)
        XCTAssertEqual(fit?.viewportY ?? .nan, 50, accuracy: 0.0001)

        let clamped = CanvasViewportFitPolicy.fit(
            bounds: CanvasFrameRect(id: "large", x: 0, y: 0, width: 10_000, height: 10_000),
            viewportWidth: 300,
            viewportHeight: 300,
            padding: 40,
            minimumZoom: 0.12,
            maximumZoom: 2.4
        )

        XCTAssertNotNil(clamped)
        XCTAssertEqual(clamped?.zoom ?? .nan, 0.12, accuracy: 0.0001)
        XCTAssertNil(CanvasViewportFitPolicy.fit(
            bounds: CanvasFrameRect(id: "invalid", x: 0, y: 0, width: 0, height: 100),
            viewportWidth: 300,
            viewportHeight: 300,
            padding: 40,
            minimumZoom: 0.12,
            maximumZoom: 2.4
        ))
    }

    func testFolderPreviewOrderingPutsFoldersFirstThenNames() {
        let items = [
            FolderPreviewItemRecord(id: "file-b", name: "Beta.txt", isDirectory: false),
            FolderPreviewItemRecord(id: "folder-z", name: "Zeta", isDirectory: true),
            FolderPreviewItemRecord(id: "folder-a", name: "Archive", isDirectory: true),
            FolderPreviewItemRecord(id: "file-a", name: "alpha.md", isDirectory: false)
        ]

        XCTAssertEqual(
            FolderPreviewOrdering.ordered(items).map(\.id),
            ["folder-a", "folder-z", "file-a", "file-b"]
        )
    }

    func testCanvasEdgeAnimationPolicyOnlyAnimatesBlueEnabledEdgesAtSmallScale() {
        XCTAssertTrue(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: true, reduceMotion: false, edgeCount: CanvasPerformancePolicy.maximumAnimatedEdgeCount))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "off", animationsEnabled: true, reduceMotion: false, edgeCount: CanvasPerformancePolicy.maximumAnimatedEdgeCount))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: false, reduceMotion: false, edgeCount: CanvasPerformancePolicy.maximumAnimatedEdgeCount))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: true, reduceMotion: true, edgeCount: CanvasPerformancePolicy.maximumAnimatedEdgeCount))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: true, reduceMotion: false, edgeCount: CanvasPerformancePolicy.maximumAnimatedEdgeCount + 1))
    }
}
