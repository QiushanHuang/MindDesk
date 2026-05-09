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

    func testTerminalCommandStopsWhenCdFails() {
        XCTAssertEqual(
            ShellQuoter.terminalCommand(command: "rm -rf build", workingDirectory: "/tmp/Missing Folder"),
            "cd '/tmp/Missing Folder' && rm -rf build"
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

    func testPersistentStoreStartupBackupPolicySkipsRecentBackup() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let now = Date(timeIntervalSince1970: 1_800_000)
        let recentBackup = backupRoot.appendingPathComponent(
            MindDeskStoreLayout.backupFolderName(
                for: now.addingTimeInterval(-60 * 60),
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
                for: now.addingTimeInterval(-25 * 60 * 60),
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

    func testPersistentStoreBackupFolderNameSupportsMigrationReasonSuffix() {
        let date = Date(timeIntervalSince1970: 1_800_000)

        XCTAssertEqual(
            MindDeskStoreLayout.backupFolderName(for: date, reason: .migration),
            "19700121-200000-migration"
        )
    }

    func testPersistentStoreRecoveryCandidatesPreferNewestTimestampedBackup() {
        let backupRoot = URL(fileURLWithPath: "/tmp/Backups", isDirectory: true)
        let folders = [
            backupRoot.appendingPathComponent("20260430-091100-startup", isDirectory: true),
            backupRoot.appendingPathComponent("20260430-091500-migration", isDirectory: true),
            backupRoot.appendingPathComponent("not-a-backup", isDirectory: true),
            backupRoot.appendingPathComponent("20260430-091300-restore", isDirectory: true)
        ]

        XCTAssertEqual(
            MindDeskStoreLayout.recoveryCandidateFolders(folders).map(\.lastPathComponent),
            ["20260430-091500-migration", "20260430-091300-restore", "20260430-091100-startup"]
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
        XCTAssertEqual(AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen, "workspaceCanvasTodoPanelDefaultOpen")
        XCTAssertEqual(AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen, "workspaceCanvasTodoDoneColumnDefaultOpen")
        XCTAssertEqual(AppPreferenceKeys.workspaceCanvasTodoDoneColumnOpen, "workspaceCanvasTodoDoneColumnOpen")
        XCTAssertEqual(AppPreferenceKeys.workspaceCanvasTodoColumnRatio, "workspaceCanvasTodoColumnRatio")
        XCTAssertEqual(AppPreferenceKeys.canvasConnectSingleShot, "canvasConnectSingleShot")
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
        XCTAssertTrue(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 24, obstacleCount: 60, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 24, obstacleCount: 60, isInteracting: true))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: CanvasPerformancePolicy.maximumRoutedEdgeCount + 1, obstacleCount: 20, isInteracting: false))
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

    func testQuickOpenIndexRanksTitleMatchesBeforeSubtitleMatches() {
        let records = [
            QuickOpenRecord(id: "subtitle", kind: .resource, title: "Draft.pdf", subtitle: "OpenAI Docs"),
            QuickOpenRecord(id: "title", kind: .webCard, title: "Docs Home", subtitle: "https://example.com")
        ]

        XCTAssertEqual(QuickOpenIndex.results(for: "docs", in: records).map(\.id), ["title", "subtitle"])
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
        XCTAssertTrue(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 24, obstacleCount: 60, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 41, obstacleCount: 20, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 24, obstacleCount: 90, isInteracting: false))
        XCTAssertFalse(CanvasPerformancePolicy.usesObstacleRouting(edgeCount: 24, obstacleCount: 60, isInteracting: true))
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
        XCTAssertTrue(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: true, reduceMotion: false, edgeCount: 20))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "off", animationsEnabled: true, reduceMotion: false, edgeCount: 20))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: false, reduceMotion: false, edgeCount: 20))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: true, reduceMotion: true, edgeCount: 20))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateEdge(theme: "blue", animationsEnabled: true, reduceMotion: false, edgeCount: CanvasPerformancePolicy.maximumAnimatedEdgeCount + 1))
    }
}
