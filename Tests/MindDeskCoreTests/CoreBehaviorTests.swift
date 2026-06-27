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

    func testTerminalPrefillCommandIsSingleLineAndDoesNotAutoSubmitEmbeddedNewlines() {
        let prefillCommand = ShellQuoter.terminalPrefillCommand(
            command: "  swift test\n\nswift build  ",
            workingDirectory: "/tmp/My Folder"
        )

        XCTAssertEqual(prefillCommand, "cd -- '/tmp/My Folder' && swift test ; swift build")
        XCTAssertFalse(prefillCommand.contains("\n"))
        XCTAssertFalse(prefillCommand.contains("\r"))
        XCTAssertEqual(
            ShellQuoter.terminalPrefillCommand(command: "\n\t ", workingDirectory: "/tmp/My Folder"),
            "cd -- '/tmp/My Folder'"
        )
    }

    func testCanvasCodexPromptBuilderIncludesReadOnlyProposalBoundary() {
        let prompt = CanvasCodexPromptBuilder.prompt(for: CanvasCodexPromptContext(
            workspaceTitle: "Launch Workspace",
            canvasTitle: "Workflow Map",
            userInstruction: "Organize this canvas into clearer groups.",
            nodes: [
                CanvasCodexPromptNodeRecord(id: "node-a", title: "Inbox", kind: "note", body: "Triage these ideas."),
                CanvasCodexPromptNodeRecord(id: "node-b", title: "Build", kind: "resource", body: "Implementation files.")
            ],
            edges: [
                CanvasCodexPromptEdgeRecord(sourceNodeID: "node-a", targetNodeID: "node-b", label: "next")
            ],
            selectedNodeIDs: ["node-a"],
            selectedEdgeIDs: ["edge-a"]
        ))

        XCTAssertFalse(prompt.wasTruncated)
        XCTAssertTrue(prompt.body.contains("read-only context"))
        XCTAssertTrue(prompt.body.contains("Do not execute commands"))
        XCTAssertTrue(prompt.body.contains("minddesk.proposal.envelope"))
        XCTAssertTrue(prompt.body.contains("Proposal Review"))
        XCTAssertTrue(prompt.body.contains("Launch Workspace"))
        XCTAssertTrue(prompt.body.contains("Workflow Map"))
        XCTAssertTrue(prompt.body.contains("node-a -> node-b"))
    }

    func testCanvasCodexPromptBuilderBoundsOversizedCanvasContext() {
        let nodes = (0..<80).map { index in
            CanvasCodexPromptNodeRecord(
                id: "node-\(index)",
                title: "Large Card \(index)",
                kind: "note",
                body: String(repeating: "Long canvas note. ", count: 80)
            )
        }
        let prompt = CanvasCodexPromptBuilder.prompt(for: CanvasCodexPromptContext(
            workspaceTitle: "Large Workspace",
            canvasTitle: "Large Canvas",
            userInstruction: String(repeating: "Organize this. ", count: 500),
            nodes: nodes,
            edges: [],
            selectedNodeIDs: [],
            selectedEdgeIDs: []
        ))

        XCTAssertTrue(prompt.wasTruncated)
        XCTAssertLessThanOrEqual(Data(prompt.body.utf8).count, CanvasCodexPromptBuilder.maximumPromptBytes)
        XCTAssertTrue(prompt.body.contains("prompt was bounded before opening Codex"))
    }

    func testCanvasCodexCommandBuilderUsesSafeInteractiveCodexFlagsAndSingleLinePrompt() {
        let prompt = "Organize 'Inbox'; do not run $(rm -rf ~)\nSecond line\u{2028}third"
        let command = CanvasCodexCommandBuilder.command(prompt: prompt)

        XCTAssertTrue(command.hasPrefix("codex --sandbox read-only --ask-for-approval untrusted -- "))
        XCTAssertFalse(command.contains("\n"))
        XCTAssertFalse(command.contains("\r"))
        XCTAssertFalse(command.contains("\u{2028}"))
        XCTAssertFalse(command.contains(" --full-auto"))
        XCTAssertFalse(command.contains("dangerously-bypass"))
        XCTAssertFalse(command.contains("--sandbox workspace-write"))
        XCTAssertFalse(command.contains("--sandbox danger-full-access"))
        XCTAssertFalse(command.contains("--ask-for-approval never"))
        XCTAssertFalse(command.contains("codex exec"))
        XCTAssertFalse(command.contains("codex apply"))
        XCTAssertTrue(command.contains("'Organize '\\''Inbox'\\''; do not run $(rm -rf ~) Second line third'"))
    }

    func testMindDeskJSONDocumentKindClassifiesManifestMIPProposalAndValidationReportWithoutFullDecode() throws {
        let manifestData = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 999,
            "workspaces": "not decoded by classifier"
        ])
        let typedManifestData = try JSONSerialization.data(withJSONObject: [
            "format": "minddesk.export.manifest",
            "formatVersion": 1,
            "schemaVersion": 999,
            "workspaces": "not decoded by classifier"
        ])
        let packageData = try JSONSerialization.data(withJSONObject: [
            "format": MindDeskInterchangePackage.currentFormat,
            "manifest": ["schemaVersion": 2]
        ])
        let proposalData = try JSONSerialization.data(withJSONObject: [
            "format": MindDeskProposalEnvelope.currentFormat,
            "schemaVersion": 2,
            "proposals": "not decoded by classifier"
        ])
        let validationReportData = try JSONSerialization.data(withJSONObject: [
            "format": MindDeskValidationReport.currentFormat,
            "issues": "not decoded by classifier"
        ])
        let foreignData = try JSONSerialization.data(withJSONObject: [
            "format": "foreign.document",
            "schemaVersion": 2
        ])
        let foreignClassification = MindDeskJSONDocumentClassifier.classify(foreignData)
        let typedManifestClassification = MindDeskJSONDocumentClassifier.classify(typedManifestData)
        let malformedData = Data("{".utf8)

        XCTAssertEqual(MindDeskJSONDocumentKind.classify(manifestData), .manifest)
        XCTAssertEqual(MindDeskJSONDocumentKind.classify(typedManifestData), .manifest)
        XCTAssertEqual(typedManifestClassification.kind, .manifest)
        XCTAssertTrue(typedManifestClassification.hasTopLevelFormat)
        XCTAssertEqual(MindDeskJSONDocumentKind.classify(packageData), .interchangePackage)
        XCTAssertEqual(MindDeskJSONDocumentKind.classify(proposalData), .proposalEnvelope)
        XCTAssertEqual(MindDeskJSONDocumentKind.classify(validationReportData), .validationReport)
        XCTAssertEqual(MindDeskJSONDocumentKind.classify(foreignData), .unknown)
        XCTAssertEqual(foreignClassification.kind, .unknown)
        XCTAssertTrue(foreignClassification.hasTopLevelFormat)
        XCTAssertEqual(MindDeskJSONDocumentKind.classify(malformedData), .unknown)
    }

    func testMindDeskJSONDocumentKindRejectsNestedAndConflictingMarkers() {
        let nestedManifestData = Data("""
        {"manifest":{"schemaVersion":2},"workspaces":[]}
        """.utf8)
        let conflictingFormatData = Data("""
        {"format":"\(MindDeskInterchangePackage.currentFormat)","format":"\(MindDeskProposalEnvelope.currentFormat)"}
        """.utf8)
        let stringSchemaData = Data("""
        {"schemaVersion":"2","workspaces":[]}
        """.utf8)

        XCTAssertEqual(MindDeskJSONDocumentKind.classify(nestedManifestData), .unknown)
        XCTAssertEqual(MindDeskJSONDocumentKind.classify(conflictingFormatData), .unknown)
        XCTAssertEqual(MindDeskJSONDocumentKind.classify(stringSchemaData), .unknown)
    }

    func testExportManifestEncodesTypedWireMetadataAndKeepsLegacyDecode() throws {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )

        let data = try JSONEncoder.minddesk.encode(manifest)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["format"] as? String, "minddesk.export.manifest")
        XCTAssertEqual(object["formatVersion"] as? Int, 1)
        XCTAssertEqual(object["schemaVersion"] as? Int, 2)
        XCTAssertEqual(MindDeskJSONDocumentKind.classify(data), .manifest)
        XCTAssertEqual(try JSONDecoder.minddesk.decode(ExportManifest.self, from: data), manifest)

        let legacyData = Data("""
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

        XCTAssertEqual(MindDeskJSONDocumentKind.classify(legacyData), .manifest)
        XCTAssertEqual(try JSONDecoder.minddesk.decode(ExportManifest.self, from: legacyData), manifest)
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

    func testPersistentStoreBackupRecoverabilityRequiresCompleteMarkerOrFullLegacyFileSet() {
        XCTAssertTrue(
            MindDeskStoreBackupRecoverability.isRecoverableBackupFolder(
                containing: [".complete", "MindDesk.store"]
            )
        )
        XCTAssertFalse(
            MindDeskStoreBackupRecoverability.isRecoverableBackupFolder(
                containing: [".complete"]
            )
        )
        XCTAssertFalse(
            MindDeskStoreBackupRecoverability.isRecoverableBackupFolder(
                containing: ["MindDesk.store"]
            )
        )
        XCTAssertFalse(
            MindDeskStoreBackupRecoverability.isRecoverableBackupFolder(
                containing: ["MindDesk.store", "MindDesk.store-wal"]
            )
        )
        XCTAssertTrue(
            MindDeskStoreBackupRecoverability.isRecoverableBackupFolder(
                containing: ["MindDesk.store", "MindDesk.store-wal", "MindDesk.store-shm"]
            )
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

    func testCanvasAutoArrangeAvoidsLockedFixedObstacles() {
        let locked = [
            CanvasLayoutNode(id: "locked", x: 0, y: 0, width: 180, height: 120)
        ]
        let movable = [
            CanvasLayoutNode(id: "source", x: 20, y: 20, width: 120, height: 80),
            CanvasLayoutNode(id: "target", x: 30, y: 30, width: 140, height: 90),
            CanvasLayoutNode(id: "loose", x: 40, y: 40, width: 120, height: 80)
        ]

        let arranged = CanvasLayoutEngine.autoArrange(
            movable,
            fixedNodes: locked,
            edges: [
                CanvasLayoutEdge(sourceNodeId: "source", targetNodeId: "target")
            ],
            horizontalSpacing: 80,
            verticalSpacing: 40,
            disconnectedColumns: 2
        )
        let byId = Dictionary(uniqueKeysWithValues: arranged.map { ($0.id, $0) })

        XCTAssertEqual(locked[0].x, 0)
        XCTAssertEqual(locked[0].y, 0)
        XCTAssertLessThan(byId["source"]!.x, byId["target"]!.x)
        XCTAssertFalse(layoutNodesOverlap(locked + arranged))
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

    func testAlignLeftIgnoresNonFiniteCoordinates() {
        let nodes = [
            CanvasLayoutNode(id: "bad", x: .nan, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "a", x: 50, y: 0, width: 120, height: 80),
            CanvasLayoutNode(id: "b", x: 10, y: 20, width: 120, height: 80)
        ]

        let aligned = CanvasLayoutEngine.alignLeft(nodes)

        XCTAssertTrue(aligned[0].x.isNaN)
        XCTAssertEqual(aligned[1].x, 10)
        XCTAssertEqual(aligned[2].x, 10)
    }

    func testAlignTopIgnoresNonFiniteCoordinates() {
        let nodes = [
            CanvasLayoutNode(id: "bad", x: 0, y: .nan, width: 120, height: 80),
            CanvasLayoutNode(id: "a", x: 0, y: 50, width: 120, height: 80),
            CanvasLayoutNode(id: "b", x: 20, y: 10, width: 120, height: 80)
        ]

        let aligned = CanvasLayoutEngine.alignTop(nodes)

        XCTAssertTrue(aligned[0].y.isNaN)
        XCTAssertEqual(aligned[1].y, 10)
        XCTAssertEqual(aligned[2].y, 10)
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
        XCTAssertEqual(
            WorkbenchSidebarMetrics.primaryNavigationLabels,
            ["Home", "Global Library", "Snippet Library", "Pinned Folders", "Pinned Files", "Workspaces"]
        )
        XCTAssertTrue(
            WorkbenchSidebarMetrics.canShowPrimaryNavigationLabels(
                at: WorkbenchSidebarMetrics.minimumWidth
            )
        )
        XCTAssertGreaterThanOrEqual(WorkbenchSidebarMetrics.minimumWidth, 240)
        XCTAssertGreaterThanOrEqual(WorkbenchSidebarMetrics.idealWidth, 260)
        XCTAssertLessThanOrEqual(WorkbenchSidebarMetrics.idealWidth, 280)
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
        XCTAssertEqual(AppPreferenceKeys.canvasAnimationFrameRate, "canvasAnimationFrameRate")
        XCTAssertEqual(AppPreferenceKeys.canvasZoomCommitCadence, "canvasZoomCommitCadence")
        XCTAssertEqual(AppPreferenceKeys.appearanceMode, "appearanceMode")
        XCTAssertEqual(AppPreferenceKeys.interfaceTextScale, "interfaceTextScale")
        XCTAssertEqual(AppPreferenceKeys.interfaceDensity, "interfaceDensity")
        XCTAssertEqual(AppPreferenceKeys.startupDestination, "startupDestination")
        XCTAssertEqual(AppPreferenceKeys.workspaceOpenDestination, "workspaceOpenDestination")
        XCTAssertEqual(AppPreferenceKeys.manifestExportScope, "manifestExportScope")
        XCTAssertEqual(AppPreferenceKeys.manifestExportIncludesUsageDates, "manifestExportIncludesUsageDates")
        XCTAssertEqual(AppPreferenceKeys.agentReviewCustomPromptGuidance, "agentReviewCustomPromptGuidance")
    }

    func testAppSettingsPaneSelectionDescriptorPersistsKnownPaneAndDefaultsInvalidValues() {
        XCTAssertEqual(AppPreferenceKeys.settingsSelectedPane, "settingsSelectedPane")
        XCTAssertEqual(AppSettingsPaneSelectionDescriptor.preferenceKey, AppPreferenceKeys.settingsSelectedPane)
        XCTAssertEqual(AppSettingsPaneSelectionDescriptor.defaultRawValue, AppPreferenceDefaults.settingsSelectedPane)
        XCTAssertEqual(AppPreferenceDefaults.settingsSelectedPane, AppSettingsPaneSelection.general.rawValue)
        XCTAssertEqual(AppSettingsPaneSelection.resolved(AppSettingsPaneSelection.canvas.rawValue), .canvas)
        XCTAssertEqual(AppSettingsPaneSelection.resolved("missing-pane"), .general)
        XCTAssertEqual(
            AppSettingsPaneSelectionDescriptor.optionRawValues,
            AppSettingsPaneSelection.allCases.map(\.rawValue)
        )
    }

    func testCanvasAnimationFrameRateSettingsDescriptorExplainsAdaptiveSmoothnessLimits() {
        XCTAssertEqual(CanvasAnimationFrameRateSettingsDescriptor.preferenceKey, AppPreferenceKeys.canvasAnimationFrameRate)
        XCTAssertEqual(CanvasAnimationFrameRateSettingsDescriptor.defaultRawValue, AppPreferenceDefaults.canvasAnimationFrameRate)
        XCTAssertEqual(CanvasAnimationFrameRateSettingsDescriptor.title, "Link Animation Smoothness")
        XCTAssertEqual(
            CanvasAnimationFrameRateSettingsDescriptor.optionRawValues,
            CanvasAnimationFrameRate.allCases.map(\.rawValue)
        )

        let helpText = CanvasAnimationFrameRateSettingsDescriptor.helpText.lowercased()
        for required in [
            "maximum",
            "target",
            "not a guaranteed constant frame rate",
            "reduce motion",
            "active interactions",
            "zoomed out below the baseline",
            "dense canvas",
            "degrade",
            "pause"
        ] {
            XCTAssertTrue(helpText.contains(required), "Missing animation smoothness settings disclosure: \(required)")
        }
    }

    func testCanvasZoomCommitCadenceSettingsDescriptorExplainsSaveTimingOnly() {
        XCTAssertEqual(CanvasZoomCommitCadenceSettingsDescriptor.preferenceKey, AppPreferenceKeys.canvasZoomCommitCadence)
        XCTAssertEqual(CanvasZoomCommitCadenceSettingsDescriptor.defaultRawValue, AppPreferenceDefaults.canvasZoomCommitCadence)
        XCTAssertEqual(CanvasZoomCommitCadenceSettingsDescriptor.title, "Zoom Save Timing")
        XCTAssertEqual(
            CanvasZoomCommitCadenceSettingsDescriptor.optionRawValues,
            CanvasZoomCommitCadence.allCases.map(\.rawValue)
        )

        let helpText = CanvasZoomCommitCadenceSettingsDescriptor.helpText.lowercased()
        for required in [
            "only",
            "save",
            "scroll zoom",
            "gesture settles",
            "does not change",
            "visual zoom smoothness",
            "frame rate"
        ] {
            XCTAssertTrue(helpText.contains(required), "Missing zoom save timing settings disclosure: \(required)")
        }

        for forbidden in [
            "improves visual",
            "higher frame rate",
            "smoother zoom"
        ] {
            XCTAssertFalse(helpText.contains(forbidden), "Zoom save timing copy should not promise visual smoothness: \(forbidden)")
        }
    }

    func testAppPreferenceEnumsResolveInvalidValuesToSafeDefaults() {
        XCTAssertEqual(AppAppearanceMode.resolved("unknown"), .system)
        XCTAssertEqual(AppInterfaceTextScale.resolved("unknown"), .system)
        XCTAssertEqual(AppInterfaceDensity.resolved("unknown"), .balanced)
        XCTAssertEqual(AppStartupDestination.resolved("unknown"), .home)
        XCTAssertEqual(AppWorkspaceOpenDestination.resolved("unknown"), .canvas)
        XCTAssertEqual(ManifestExportScope.resolved("unknown"), .completeWorkspaceMap)
        XCTAssertEqual(CanvasAnimationFrameRate.resolved("unknown"), .balanced)
        XCTAssertEqual(CanvasZoomCommitCadence.resolved("unknown"), .balanced)
    }

    func testCustomGuidancePresentationReportsBlankAsNotIncluded() {
        let presentation = MindDeskAgentReviewCustomGuidancePresentationPolicy.presentation(for: " \n ")

        XCTAssertEqual(presentation.title, MindDeskAgentReviewCustomGuidancePolicy.title)
        XCTAssertEqual(presentation.placeholder, MindDeskAgentReviewCustomGuidancePolicy.placeholder)
        XCTAssertEqual(presentation.settingsDescription, MindDeskAgentReviewCustomGuidancePolicy.settingsDescription)
        XCTAssertEqual(presentation.privacyDescription, MindDeskAgentReviewCustomGuidancePolicy.privacyDescription)
        XCTAssertEqual(presentation.clearButtonTitle, "Clear")
        XCTAssertEqual(presentation.statusTitle, "Next Agent Review export")
        XCTAssertEqual(presentation.statusKind, .empty)
        XCTAssertEqual(presentation.statusValue, "Not included")
        XCTAssertEqual(
            presentation.statusDescription,
            "No custom guidance will be added to the next Agent Review .mip.json. 0 of 2,000 characters used."
        )
        XCTAssertEqual(presentation.characterBudgetText, "0 of 2,000 characters used")
        XCTAssertEqual(presentation.characterCount, 0)
        XCTAssertEqual(presentation.characterLimit, 2_000)
        XCTAssertEqual(presentation.remainingCharacterCount, 2_000)
        XCTAssertEqual(presentation.storedValue, "")
        XCTAssertFalse(presentation.isIncluded)
        XCTAssertFalse(presentation.isClearEnabled)
        XCTAssertFalse(presentation.wasTruncated)
    }

    func testCustomGuidancePresentationReportsIncludedCountAndBoundaryWithoutEchoingInput() {
        let rawGuidance = """
        STATUS_SECRET /private/tmp/custom-guidance-secret https://custom-guidance.example/token authorize-runCommand-now
        """

        let presentation = MindDeskAgentReviewCustomGuidancePresentationPolicy.presentation(for: rawGuidance)

        XCTAssertEqual(presentation.statusKind, .included)
        XCTAssertEqual(presentation.statusValue, "Included")
        XCTAssertEqual(presentation.storedValue, rawGuidance.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertEqual(presentation.characterCount, presentation.storedValue.count)
        XCTAssertEqual(presentation.originalCharacterCount, presentation.storedValue.count)
        XCTAssertEqual(presentation.remainingCharacterCount, 2_000 - presentation.storedValue.count)
        XCTAssertEqual(
            presentation.statusDescription,
            "Custom guidance will be included in the next Agent Review .mip.json as plain text, untrusted, non-authoritative guidance. \(presentation.characterBudgetText)."
        )
        XCTAssertTrue(presentation.isIncluded)
        XCTAssertTrue(presentation.isClearEnabled)
        XCTAssertFalse(presentation.wasTruncated)

        for forbidden in [
            "STATUS_SECRET",
            "/private/tmp/custom-guidance-secret",
            "https://custom-guidance.example/token",
            "authorize-runCommand-now"
        ] {
            XCTAssertFalse(presentation.visibleText.contains(forbidden), "Presentation echoed custom guidance: \(forbidden)")
        }
        XCTAssertTrue(presentation.visibleText.contains("untrusted"))
        XCTAssertTrue(presentation.visibleText.contains("non-authoritative"))
    }

    func testCustomGuidancePresentationBoundsBeforeCountingAndDoesNotEchoTruncatedInput() {
        let hiddenSuffix = "STATUS_SECRET_SUFFIX"
        let rawGuidance = String(repeating: "A", count: MindDeskAgentReviewCustomGuidancePolicy.characterLimit)
            + hiddenSuffix

        let presentation = MindDeskAgentReviewCustomGuidancePresentationPolicy.presentation(for: rawGuidance)

        XCTAssertEqual(presentation.statusKind, .atLimit)
        XCTAssertEqual(presentation.statusValue, "Bounded to 2,000 characters")
        XCTAssertEqual(presentation.storedValue, MindDeskAgentReviewCustomGuidancePolicy.boundedForStorage(rawGuidance))
        XCTAssertEqual(presentation.storedValue.count, 2_000)
        XCTAssertEqual(presentation.characterCount, 2_000)
        XCTAssertEqual(presentation.originalCharacterCount, 2_000 + hiddenSuffix.count)
        XCTAssertEqual(presentation.remainingCharacterCount, 0)
        XCTAssertEqual(presentation.characterBudgetText, "2,000 of 2,000 characters used")
        XCTAssertEqual(
            presentation.statusDescription,
            "Custom guidance will be included in the next Agent Review .mip.json as plain text, untrusted, non-authoritative guidance. 2,000 of 2,000 characters used. Extra text was truncated before export."
        )
        XCTAssertTrue(presentation.isIncluded)
        XCTAssertTrue(presentation.isClearEnabled)
        XCTAssertTrue(presentation.wasTruncated)
        XCTAssertFalse(presentation.visibleText.contains(hiddenSuffix))

        for unsafePhrase in [
            "authorization granted",
            "safe to execute",
            "ready to execute",
            "run without confirmation",
            "trusted guidance"
        ] {
            XCTAssertFalse(presentation.visibleText.lowercased().contains(unsafePhrase))
        }
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
        defaults.set(AppWorkspaceOpenDestination.overview.rawValue, forKey: AppPreferenceKeys.workspaceOpenDestination)
        defaults.set(ManifestExportScope.globalLibraryOnly.rawValue, forKey: AppPreferenceKeys.manifestExportScope)
        defaults.set(true, forKey: AppPreferenceKeys.manifestExportIncludesUsageDates)
        defaults.set("Prioritize validation issues.", forKey: AppPreferenceKeys.agentReviewCustomPromptGuidance)
        defaults.set(CanvasScrollZoomDirection.scrollDownZoomsIn.rawValue, forKey: AppPreferenceKeys.canvasScrollZoomDirection)
        defaults.set(250.0, forKey: AppPreferenceKeys.canvasDefaultZoomPercent)
        defaults.set(false, forKey: AppPreferenceKeys.canvasConnectSingleShot)
        defaults.set(CanvasAnimationFrameRate.smooth.rawValue, forKey: AppPreferenceKeys.canvasAnimationFrameRate)
        defaults.set(CanvasZoomCommitCadence.responsive.rawValue, forKey: AppPreferenceKeys.canvasZoomCommitCadence)
        defaults.set(true, forKey: AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen)
        defaults.set(true, forKey: AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen)
        defaults.set(0.7, forKey: AppPreferenceKeys.workspaceCanvasTodoColumnRatio)
        for key in AppPreferenceDefaults.obsoleteKeys {
            defaults.set("stale", forKey: key)
        }

        AppPreferenceDefaults.restore(in: defaults)

        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.appearanceMode), AppAppearanceMode.system.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.interfaceTextScale), AppInterfaceTextScale.system.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.interfaceDensity), AppInterfaceDensity.balanced.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.startupDestination), AppStartupDestination.home.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.workspaceOpenDestination), AppWorkspaceOpenDestination.canvas.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.manifestExportScope), ManifestExportScope.completeWorkspaceMap.rawValue)
        XCTAssertFalse(defaults.bool(forKey: AppPreferenceKeys.manifestExportIncludesUsageDates))
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.agentReviewCustomPromptGuidance), AppPreferenceDefaults.agentReviewCustomPromptGuidance)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.canvasScrollZoomDirection), CanvasScrollZoomDirection.scrollDownZoomsOut.rawValue)
        XCTAssertEqual(defaults.double(forKey: AppPreferenceKeys.canvasDefaultZoomPercent), CanvasZoomBaseline.defaultPercent, accuracy: 0.0001)
        XCTAssertTrue(defaults.bool(forKey: AppPreferenceKeys.canvasConnectSingleShot))
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.canvasAnimationFrameRate), CanvasAnimationFrameRate.balanced.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferenceKeys.canvasZoomCommitCadence), CanvasZoomCommitCadence.balanced.rawValue)
        XCTAssertFalse(defaults.bool(forKey: AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen))
        XCTAssertFalse(defaults.bool(forKey: AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen))
        XCTAssertEqual(defaults.double(forKey: AppPreferenceKeys.workspaceCanvasTodoColumnRatio), TodoBoardColumnSplit.defaultRatio, accuracy: 0.0001)
        for key in AppPreferenceDefaults.obsoleteKeys {
            XCTAssertNil(defaults.object(forKey: key), "Obsolete setting key should be removed on restore: \(key)")
        }
    }

    func testAppSettingsResetDescriptorCoversEveryResettablePreferenceAndObsoleteKey() {
        let resetItems = AppSettingsResetDescriptor.resetItems
        let expectedResettableKeys: Set<String> = [
            AppPreferenceKeys.appearanceMode,
            AppPreferenceKeys.interfaceTextScale,
            AppPreferenceKeys.interfaceDensity,
            AppPreferenceKeys.startupDestination,
            AppPreferenceKeys.workspaceOpenDestination,
            AppPreferenceKeys.manifestExportScope,
            AppPreferenceKeys.manifestExportIncludesUsageDates,
            AppPreferenceKeys.agentReviewCustomPromptGuidance,
            AppPreferenceKeys.canvasScrollZoomDirection,
            AppPreferenceKeys.canvasDefaultZoomPercent,
            AppPreferenceKeys.canvasConnectSingleShot,
            AppPreferenceKeys.canvasAnimationFrameRate,
            AppPreferenceKeys.canvasZoomCommitCadence,
            AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen,
            AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen,
            AppPreferenceKeys.workspaceCanvasTodoColumnRatio
        ]

        XCTAssertEqual(Set(resetItems.map(\.key)), expectedResettableKeys)
        XCTAssertEqual(Set(resetItems.map(\.key)), Set(AppPreferenceDefaults.resettableKeys))
        XCTAssertEqual(resetItems.count, AppPreferenceDefaults.resettableKeys.count)
        XCTAssertEqual(AppSettingsResetDescriptor.obsoleteKeysCleared, AppPreferenceDefaults.obsoleteKeys)
        XCTAssertTrue(resetItems.allSatisfy { !AppPreferenceDefaults.obsoleteKeys.contains($0.key) })
        XCTAssertEqual(
            resetItems.first { $0.key == AppPreferenceKeys.agentReviewCustomPromptGuidance }?.defaultValueDescription,
            "Cleared"
        )

        for item in resetItems {
            XCTAssertFalse(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(item.defaultValueDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testAppSettingsResetDescriptorBuildsReviewableSummaryFromResetItems() {
        let lines = AppSettingsResetDescriptor.reviewableSummaryLines
        let summary = AppSettingsResetDescriptor.reviewableSummaryText.lowercased()

        XCTAssertFalse(lines.isEmpty)
        XCTAssertEqual(Set(lines).count, lines.count)

        for item in AppSettingsResetDescriptor.resetItems {
            XCTAssertTrue(
                lines.contains("\(item.title): \(item.defaultValueDescription)"),
                "Review summary should include reset item default semantics: \(item.title)"
            )
        }

        for required in [
            "custom agent review guidance: cleared",
            "obsolete settings keys",
            AppPreferenceKeys.workspaceCanvasTodoDoneColumnOpen.lowercased(),
            "does not delete workspaces",
            "resources",
            "snippets",
            "tasks",
            "canvases",
            "cards",
            "exports",
            "raw backups",
            "quarantine",
            "local recovery data"
        ] {
            XCTAssertTrue(summary.contains(required), "Missing reviewable reset summary term: \(required)")
        }
    }

    func testAppSettingsResetDescriptorExplainsScopeAndProtectedUserData() {
        let combined = [
            AppSettingsResetDescriptor.alertTitle,
            AppSettingsResetDescriptor.alertInformativeText,
            AppSettingsResetDescriptor.settingsPaneHelpText,
            AppSettingsResetDescriptor.resetScopeSummary,
            AppSettingsResetDescriptor.protectedDataSummary,
            AppSettingsResetDescriptor.obsoleteKeySummary
        ]
            .joined(separator: " ")
            .lowercased()

        for required in [
            "reset all settings",
            "launch destination",
            "appearance",
            "canvas interaction",
            "workspace task defaults",
            "portable json defaults",
            "custom agent review guidance",
            "does not delete",
            "workspaces",
            "resources",
            "snippets",
            "tasks",
            "canvases",
            "cards",
            "exports",
            "raw backups",
            "quarantine",
            "local recovery data",
            "obsolete settings keys"
        ] {
            XCTAssertTrue(combined.contains(required), "Missing Reset All Settings disclosure term: \(required)")
        }
    }

    func testAppPreferenceDefaultsRestoreWritesDescriptorDefaultValues() throws {
        let suiteName = "MindDeskTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(AppAppearanceMode.dark.rawValue, forKey: AppPreferenceKeys.appearanceMode)
        defaults.set(AppInterfaceTextScale.extraLarge.rawValue, forKey: AppPreferenceKeys.interfaceTextScale)
        defaults.set(AppInterfaceDensity.spacious.rawValue, forKey: AppPreferenceKeys.interfaceDensity)
        defaults.set(AppStartupDestination.snippets.rawValue, forKey: AppPreferenceKeys.startupDestination)
        defaults.set(AppWorkspaceOpenDestination.overview.rawValue, forKey: AppPreferenceKeys.workspaceOpenDestination)
        defaults.set(ManifestExportScope.globalLibraryOnly.rawValue, forKey: AppPreferenceKeys.manifestExportScope)
        defaults.set(true, forKey: AppPreferenceKeys.manifestExportIncludesUsageDates)
        defaults.set("Custom reset guidance", forKey: AppPreferenceKeys.agentReviewCustomPromptGuidance)
        defaults.set(CanvasScrollZoomDirection.scrollDownZoomsIn.rawValue, forKey: AppPreferenceKeys.canvasScrollZoomDirection)
        defaults.set(250.0, forKey: AppPreferenceKeys.canvasDefaultZoomPercent)
        defaults.set(false, forKey: AppPreferenceKeys.canvasConnectSingleShot)
        defaults.set(CanvasAnimationFrameRate.smooth.rawValue, forKey: AppPreferenceKeys.canvasAnimationFrameRate)
        defaults.set(CanvasZoomCommitCadence.responsive.rawValue, forKey: AppPreferenceKeys.canvasZoomCommitCadence)
        defaults.set(true, forKey: AppPreferenceKeys.workspaceCanvasTodoPanelDefaultOpen)
        defaults.set(true, forKey: AppPreferenceKeys.workspaceCanvasTodoDoneColumnDefaultOpen)
        defaults.set(0.7, forKey: AppPreferenceKeys.workspaceCanvasTodoColumnRatio)
        for key in AppPreferenceDefaults.obsoleteKeys {
            defaults.set("stale", forKey: key)
        }

        AppPreferenceDefaults.restore(in: defaults)

        for item in AppSettingsResetDescriptor.resetItems {
            XCTAssertEqual(
                item.storedValue(in: defaults),
                item.defaultStoredValue,
                "Reset descriptor default drifted from restore behavior for key \(item.key)."
            )
        }
        for key in AppPreferenceDefaults.obsoleteKeys {
            XCTAssertNil(defaults.object(forKey: key), "Obsolete setting key should be removed on restore: \(key)")
        }
    }

    func testAppSettingsStoredPreferenceValueRejectsMismatchedStoredTypes() throws {
        let suiteName = "MindDeskTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("false", forKey: "bool-as-string")
        defaults.set("0.5", forKey: "double-as-string")
        defaults.set(123, forKey: "string-as-number")

        XCTAssertNil(AppSettingsStoredPreferenceValue.bool(false).storedValue(in: defaults, forKey: "bool-as-string"))
        XCTAssertNil(AppSettingsStoredPreferenceValue.double(0).storedValue(in: defaults, forKey: "double-as-string"))
        XCTAssertNil(AppSettingsStoredPreferenceValue.string("").storedValue(in: defaults, forKey: "string-as-number"))
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

    func testCanvasConnectTapPolicyStartsSourceClearsSourceAndRequestsTargetEdge() {
        XCTAssertEqual(
            CanvasConnectTapPolicy.command(tappedNodeId: "node-a", currentSourceNodeId: nil),
            CanvasConnectTapCommand(
                action: .startSource(nodeId: "node-a"),
                selectedNodeIDs: ["node-a"]
            )
        )
        XCTAssertEqual(
            CanvasConnectTapPolicy.command(tappedNodeId: "node-a", currentSourceNodeId: "node-a"),
            CanvasConnectTapCommand(
                action: .clearSource(nodeId: "node-a"),
                selectedNodeIDs: ["node-a"]
            )
        )
        XCTAssertEqual(
            CanvasConnectTapPolicy.command(tappedNodeId: "node-b", currentSourceNodeId: "node-a"),
            CanvasConnectTapCommand(
                action: .createEdge(sourceNodeId: "node-a", targetNodeId: "node-b"),
                selectedNodeIDs: ["node-a", "node-b"]
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

    func testCanvasInteractionPerformanceBudgetAcceptsHundredNodeDragZoomAndConnectWorkload() {
        let nodes = (0..<100).map { index in
            CanvasFrameRect(
                id: "node-\(index)",
                x: Double(index % 10) * 220,
                y: Double(index / 10) * 160,
                width: 160,
                height: 96
            )
        }
        let fanoutEdges = (1..<100).map { index in
            CanvasEdgeViewportRecord(id: "fanout-\(index)", sourceNodeID: "node-0", targetNodeID: "node-\(index)")
        }
        let chainEdges = (0..<99).map { index in
            CanvasEdgeViewportRecord(id: "chain-\(index)", sourceNodeID: "node-\(index)", targetNodeID: "node-\(index + 1)")
        }
        let cache = CanvasEdgeViewportIndexCache()

        _ = cache.index(nodes: nodes, edges: fanoutEdges + chainEdges, bucketSize: 256)
        let reusedIndex = cache.index(nodes: nodes, edges: fanoutEdges + chainEdges, bucketSize: 256)
        let plan = CanvasEdgeVisibilityPlanner.plan(
            edgeIndex: reusedIndex,
            cacheDiagnostics: cache.diagnostics,
            viewport: CanvasFrameRect(id: "viewport", x: -40, y: -40, width: 720, height: 520),
            overscan: 120,
            selectedEdgeIDs: ["chain-98"],
            transientControlEdgeIDs: ["fanout-1"],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["node-0"],
            visibleObstacleCount: nodes.count,
            visibleCardCount: nodes.count,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: true
        )
        let assessment = CanvasInteractionPerformanceBudget.assessment(
            nodeCount: nodes.count,
            movingNodeCount: 1,
            plan: plan
        )

        XCTAssertTrue(assessment.isAccepted, assessment.issueCodes.joined(separator: ", "))
        XCTAssertFalse(plan.usesObstacleRouting)
        XCTAssertFalse(plan.animatesVisibleEdges)
        XCTAssertEqual(cache.diagnostics.buildCount, 1)
        XCTAssertEqual(cache.diagnostics.reuseCount, 1)
        XCTAssertTrue(plan.diagnostics.forceRetention.usedIncidentAdjacency)
        XCTAssertLessThanOrEqual(
            plan.diagnostics.forceRetention.edgeScanCount,
            CanvasInteractionPerformanceBudget.maximumForceRetentionScanCount(
                explicitActiveEdgeCount: plan.diagnostics.forceRetention.explicitActiveEdgeCount,
                movingNodeCount: 1
            )
        )
        XCTAssertLessThanOrEqual(
            plan.diagnostics.renderQuery.candidateExaminedCount,
            CanvasInteractionPerformanceBudget.maximumInteractiveQueryWorkCount(nodeCount: nodes.count)
        )
    }

    func testCanvasEdgeViewportIndexQueriesSparseViewportWithoutFullEdgeScan() {
        let fixture = makeSparseCanvasEdgeViewportFixture(edgeCount: 10_000)
        let index = CanvasEdgeViewportIndex(
            nodes: fixture.nodes,
            edges: fixture.edges,
            bucketSize: 256
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: 42_000, y: -20, width: 260, height: 160),
            overscan: 0
        )

        XCTAssertEqual(result.edgeIDs, ["edge-42"])
        XCTAssertEqual(result.candidateEdgeCount, 1)
        XCTAssertLessThan(result.examinedEdgeCount, 100)
        XCTAssertEqual(result.diagnostics.bucketCandidateEdgeCount, 2)
        XCTAssertEqual(result.diagnostics.fallbackExaminedEdgeCount, 0)
        XCTAssertEqual(result.diagnostics.candidateExaminedCount, 1)
        XCTAssertEqual(result.orderedScanCount, 1)
        XCTAssertLessThan(result.orderedScanCount, fixture.edges.count)
    }

    func testCanvasEdgeViewportIndexPublishesBuildDiagnostics() {
        let nodes = [
            CanvasFrameRect(id: "source", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "target", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "invalid", x: .nan, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "valid", sourceNodeID: "source", targetNodeID: "target"),
            CanvasEdgeViewportRecord(id: "valid", sourceNodeID: "source", targetNodeID: "target"),
            CanvasEdgeViewportRecord(id: "dangling", sourceNodeID: "source", targetNodeID: "missing"),
            CanvasEdgeViewportRecord(id: "invalid-node", sourceNodeID: "invalid", targetNodeID: "target")
        ]

        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: edges,
            bucketSize: .nan
        )

        XCTAssertEqual(index.diagnostics.totalEdgeCount, 4)
        XCTAssertEqual(index.diagnostics.indexedEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.duplicateEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.droppedDanglingEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.droppedInvalidGeometryEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.bucketSize, 512, accuracy: 0.0001)
        XCTAssertTrue(index.diagnostics.bucketSizeWasDefaulted)
        XCTAssertEqual(index.diagnostics.bucketedEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.bucketFallbackEdgeCount, 0)
    }

    func testCanvasEdgeViewportIndexIndexesLaterValidDuplicateAfterDanglingFirstOccurrence() {
        let nodes = [
            CanvasFrameRect(id: "source", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "target", x: 160, y: 0, width: 80, height: 80)
        ]
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: [
                CanvasEdgeViewportRecord(id: "recover", sourceNodeID: "source", targetNodeID: "missing"),
                CanvasEdgeViewportRecord(id: "recover", sourceNodeID: "source", targetNodeID: "target")
            ],
            bucketSize: 128
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0
        )

        XCTAssertEqual(result.edgeIDs, ["recover"])
        XCTAssertEqual(index.diagnostics.totalEdgeCount, 2)
        XCTAssertEqual(index.diagnostics.indexedEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.duplicateEdgeCount, 0)
        XCTAssertEqual(index.diagnostics.droppedDanglingEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.droppedInvalidGeometryEdgeCount, 0)
        XCTAssertEqual(index.diagnostics.bucketedEdgeCount, 1)
    }

    func testCanvasEdgeViewportIndexIndexesLaterValidDuplicateAfterInvalidGeometryFirstOccurrence() {
        let nodes = [
            CanvasFrameRect(id: "source", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "target", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "invalid", x: .nan, y: 0, width: 80, height: 80)
        ]
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: [
                CanvasEdgeViewportRecord(id: "recover", sourceNodeID: "invalid", targetNodeID: "target"),
                CanvasEdgeViewportRecord(id: "recover", sourceNodeID: "source", targetNodeID: "target")
            ],
            bucketSize: 128
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0
        )

        XCTAssertEqual(result.edgeIDs, ["recover"])
        XCTAssertEqual(index.diagnostics.totalEdgeCount, 2)
        XCTAssertEqual(index.diagnostics.indexedEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.duplicateEdgeCount, 0)
        XCTAssertEqual(index.diagnostics.droppedDanglingEdgeCount, 0)
        XCTAssertEqual(index.diagnostics.droppedInvalidGeometryEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.bucketedEdgeCount, 1)
    }

    func testCanvasEdgeViewportIndexClassifiesInvalidDuplicateAfterIndexedEdgeByDropReason() {
        let nodes = [
            CanvasFrameRect(id: "source", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "target", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "invalid", x: .nan, y: 0, width: 80, height: 80)
        ]
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: [
                CanvasEdgeViewportRecord(id: "accepted", sourceNodeID: "source", targetNodeID: "target"),
                CanvasEdgeViewportRecord(id: "accepted", sourceNodeID: "source", targetNodeID: "missing"),
                CanvasEdgeViewportRecord(id: "accepted", sourceNodeID: "invalid", targetNodeID: "target")
            ],
            bucketSize: 128
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0
        )

        XCTAssertEqual(result.edgeIDs, ["accepted"])
        XCTAssertEqual(index.diagnostics.totalEdgeCount, 3)
        XCTAssertEqual(index.diagnostics.indexedEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.duplicateEdgeCount, 0)
        XCTAssertEqual(index.diagnostics.droppedDanglingEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.droppedInvalidGeometryEdgeCount, 1)
        XCTAssertEqual(
            index.diagnostics.indexedEdgeCount +
                index.diagnostics.duplicateEdgeCount +
                index.diagnostics.droppedDanglingEdgeCount +
                index.diagnostics.droppedInvalidGeometryEdgeCount,
            index.diagnostics.totalEdgeCount
        )
    }

    func testCanvasEdgeViewportIndexPublishesQueryDiagnosticsForSparseAndForcedEdges() {
        let fixture = makeSparseCanvasEdgeViewportFixture(edgeCount: 10_000)
        let index = CanvasEdgeViewportIndex(
            nodes: fixture.nodes,
            edges: fixture.edges,
            bucketSize: 256
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: 42_000, y: 0, width: 50, height: 50),
            overscan: 0,
            forcedEdgeIDs: ["edge-9999", "missing-edge"]
        )

        XCTAssertEqual(result.edgeIDs, ["edge-42", "edge-9999"])
        XCTAssertEqual(result.diagnostics.renderEdgeCount, 2)
        XCTAssertEqual(result.diagnostics.queriedBucketCount, 1)
        XCTAssertEqual(result.diagnostics.bucketCandidateEdgeCount, 1)
        XCTAssertEqual(result.examinedEdgeCount, 2)
        XCTAssertEqual(result.diagnostics.candidateExaminedCount, 2)
        XCTAssertEqual(result.diagnostics.fallbackExaminedEdgeCount, 0)
        XCTAssertFalse(result.diagnostics.bucketEnumerationWasBounded)
        XCTAssertEqual(result.orderedScanCount, 2)
        XCTAssertEqual(result.diagnostics.orderedScanCount, 2)
        XCTAssertEqual(result.diagnostics.forcedRequestedCount, 2)
        XCTAssertEqual(result.diagnostics.forcedValidCount, 1)
        XCTAssertEqual(result.diagnostics.forcedInvalidCount, 1)
        XCTAssertEqual(result.diagnostics.forcedRetentionCount, 1)
    }

    func testCanvasEdgeViewportIndexReportsOrderedScanCountForSortedQueryMatches() {
        let nodes = [
            CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "also-visible-a", x: 0, y: 160, width: 80, height: 80),
            CanvasFrameRect(id: "also-visible-b", x: 160, y: 160, width: 80, height: 80),
            CanvasFrameRect(id: "forced-a", x: 30_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "forced-b", x: 30_160, y: 0, width: 80, height: 80)
        ]
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: [
                CanvasEdgeViewportRecord(id: "visible-first", sourceNodeID: "visible-a", targetNodeID: "visible-b"),
                CanvasEdgeViewportRecord(id: "forced-offscreen", sourceNodeID: "forced-a", targetNodeID: "forced-b"),
                CanvasEdgeViewportRecord(id: "visible-later", sourceNodeID: "also-visible-a", targetNodeID: "also-visible-b")
            ],
            bucketSize: 128
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: -40, y: -40, width: 320, height: 320),
            overscan: 0,
            forcedEdgeIDs: ["forced-offscreen"]
        )

        XCTAssertEqual(result.edgeIDs, ["visible-first", "forced-offscreen", "visible-later"])
        XCTAssertEqual(result.orderedScanCount, 3)
        XCTAssertEqual(result.diagnostics.orderedScanCount, 3)
        XCTAssertLessThan(result.orderedScanCount, index.diagnostics.totalEdgeCount + 1)
    }

    func testCanvasEdgeViewportIndexOrderedScanCountDeduplicatesMultiBucketCandidates() {
        let index = CanvasEdgeViewportIndex(
            nodes: [
                CanvasFrameRect(id: "source", x: 0, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "target", x: 420, y: 0, width: 80, height: 80)
            ],
            edges: [
                CanvasEdgeViewportRecord(id: "wide-edge", sourceNodeID: "source", targetNodeID: "target")
            ],
            bucketSize: 64
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 560, height: 160),
            overscan: 0
        )

        XCTAssertEqual(result.edgeIDs, ["wide-edge"])
        XCTAssertGreaterThan(result.diagnostics.bucketCandidateEdgeCount, result.orderedScanCount)
        XCTAssertEqual(result.diagnostics.candidateExaminedCount, 1)
        XCTAssertEqual(result.orderedScanCount, 1)
        XCTAssertEqual(result.diagnostics.orderedScanCount, 1)
    }

    func testCanvasEdgeViewportIndexOrderedScanCountExcludesInvalidAndDuplicateForcedEdges() {
        let index = CanvasEdgeViewportIndex(
            nodes: [
                CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80)
            ],
            edges: [
                CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "visible-a", targetNodeID: "visible-b")
            ],
            bucketSize: 128
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            forcedEdgeIDs: ["visible", "missing-forced"]
        )

        XCTAssertEqual(result.edgeIDs, ["visible"])
        XCTAssertEqual(result.examinedEdgeCount, 1)
        XCTAssertEqual(result.diagnostics.candidateExaminedCount, 1)
        XCTAssertEqual(result.orderedScanCount, 1)
        XCTAssertEqual(result.diagnostics.orderedScanCount, 1)
        XCTAssertEqual(result.diagnostics.forcedRequestedCount, 2)
        XCTAssertEqual(result.diagnostics.forcedValidCount, 1)
        XCTAssertEqual(result.diagnostics.forcedInvalidCount, 1)
        XCTAssertEqual(result.diagnostics.forcedRetentionCount, 1)
    }

    func testCanvasEdgeViewportIndexCandidateExaminedCountIncludesOnlyValidOffscreenForcedEdge() {
        let index = CanvasEdgeViewportIndex(
            nodes: [
                CanvasFrameRect(id: "forced-a", x: 30_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "forced-b", x: 30_160, y: 0, width: 80, height: 80)
            ],
            edges: [
                CanvasEdgeViewportRecord(id: "forced-offscreen", sourceNodeID: "forced-a", targetNodeID: "forced-b")
            ],
            bucketSize: 128
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            forcedEdgeIDs: ["forced-offscreen", "missing-forced"]
        )

        XCTAssertEqual(result.edgeIDs, ["forced-offscreen"])
        XCTAssertEqual(result.diagnostics.bucketCandidateEdgeCount, 0)
        XCTAssertEqual(result.diagnostics.fallbackExaminedEdgeCount, 0)
        XCTAssertEqual(result.examinedEdgeCount, 1)
        XCTAssertEqual(result.diagnostics.candidateExaminedCount, 1)
        XCTAssertEqual(result.orderedScanCount, 1)
        XCTAssertEqual(result.diagnostics.forcedRequestedCount, 2)
        XCTAssertEqual(result.diagnostics.forcedValidCount, 1)
        XCTAssertEqual(result.diagnostics.forcedInvalidCount, 1)
    }

    func testCanvasEdgeViewportQueryDiagnosticsEncodeAggregateFieldsOnly() throws {
        let sensitiveEdgeID = "card-title Quarterly Plan /Users/joshua/secret.md https://example.com?q=token"
        let sensitiveSourceID = "note-text raw-node-id source snippet command rm -rf"
        let sensitiveTargetID = "workspace-content raw-node-id target api-key resource path"
        let missingForcedID = "missing forced raw edge /Users/joshua/missing https://example.invalid"
        let index = CanvasEdgeViewportIndex(
            nodes: [
                CanvasFrameRect(id: sensitiveSourceID, x: 10_000.25, y: -4_000.75, width: 80, height: 80),
                CanvasFrameRect(id: sensitiveTargetID, x: 10_160.25, y: -4_000.75, width: 80, height: 80)
            ],
            edges: [
                CanvasEdgeViewportRecord(
                    id: sensitiveEdgeID,
                    sourceNodeID: sensitiveSourceID,
                    targetNodeID: sensitiveTargetID,
                    controlPoint: CanvasEdgePoint(x: 12_345.678, y: -9_876.543)
                )
            ],
            bucketSize: 64
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport raw geometry 0,0 320x160", x: 0, y: 0, width: 320, height: 160),
            overscan: 0,
            forcedEdgeIDs: [sensitiveEdgeID, missingForcedID]
        )
        let diagnostics = result.diagnostics

        XCTAssertEqual(result.edgeIDs, [sensitiveEdgeID])
        let allowedFields: Set<String> = [
            "queriedBucketCount",
            "bucketCandidateEdgeCount",
            "candidateExaminedCount",
            "orderedScanCount",
            "forcedRequestedCount",
            "forcedValidCount",
            "forcedInvalidCount",
            "forcedRetentionCount",
            "renderEdgeCount",
            "fallbackExaminedEdgeCount",
            "bucketEnumerationWasBounded"
        ]
        XCTAssertEqual(Set(Mirror(reflecting: diagnostics).children.compactMap(\.label)), allowedFields)

        let encoded = try JSONEncoder().encode(diagnostics)
        let encodedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(Set(encodedObject.keys), allowedFields)
        XCTAssertEqual(encodedObject["candidateExaminedCount"] as? Int, 1)
        XCTAssertEqual(encodedObject["orderedScanCount"] as? Int, 1)
        XCTAssertEqual(encodedObject["forcedRequestedCount"] as? Int, 2)
        XCTAssertEqual(encodedObject["forcedValidCount"] as? Int, 1)
        XCTAssertEqual(encodedObject["forcedInvalidCount"] as? Int, 1)
        XCTAssertEqual(encodedObject["forcedRetentionCount"] as? Int, 1)
        XCTAssertEqual(encodedObject["renderEdgeCount"] as? Int, 1)
        XCTAssertEqual(encodedObject["fallbackExaminedEdgeCount"] as? Int, 0)
        XCTAssertEqual(encodedObject["bucketEnumerationWasBounded"] as? Bool, false)

        let encodedText = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        for forbiddenText in [
            sensitiveEdgeID,
            sensitiveSourceID,
            sensitiveTargetID,
            missingForcedID,
            "/Users/",
            "https://",
            "rm -rf",
            "api-key",
            "10000.25",
            "-4000.75",
            "12345.678",
            "-9876.543",
            "320x160"
        ] {
            XCTAssertFalse(
                encodedText.localizedCaseInsensitiveContains(forbiddenText),
                "Viewport query diagnostics should not encode raw workspace content, identifiers, coordinates, bucket keys, or route geometry: \(forbiddenText)"
            )
        }
    }

    func testCanvasEdgeViewportQueryResultEqualityIgnoresDiagnostics() {
        let baseline = CanvasEdgeViewportQueryResult(
            edgeIDs: ["edge"],
            examinedEdgeCount: 1,
            orderedScanCount: 0,
            diagnostics: CanvasEdgeViewportQueryDiagnostics(
                queriedBucketCount: 1,
                bucketCandidateEdgeCount: 1,
                candidateExaminedCount: 1,
                orderedScanCount: 0,
                forcedRequestedCount: 0,
                forcedValidCount: 0,
                forcedInvalidCount: 0,
                forcedRetentionCount: 0,
                renderEdgeCount: 1
            )
        )
        let sameBehaviorDifferentDiagnostics = CanvasEdgeViewportQueryResult(
            edgeIDs: ["edge"],
            examinedEdgeCount: 1,
            orderedScanCount: 0,
            diagnostics: CanvasEdgeViewportQueryDiagnostics(
                queriedBucketCount: 4,
                bucketCandidateEdgeCount: 3,
                candidateExaminedCount: 2,
                orderedScanCount: 0,
                forcedRequestedCount: 8,
                forcedValidCount: 1,
                forcedInvalidCount: 7,
                forcedRetentionCount: 1,
                renderEdgeCount: 1
            )
        )

        XCTAssertEqual(baseline, sameBehaviorDifferentDiagnostics)

        let differentOrderedScanCount = CanvasEdgeViewportQueryResult(
            edgeIDs: ["edge"],
            examinedEdgeCount: 1,
            orderedScanCount: 2,
            diagnostics: baseline.diagnostics
        )

        XCTAssertNotEqual(baseline, differentOrderedScanCount)

        let differentExaminedEdgeCount = CanvasEdgeViewportQueryResult(
            edgeIDs: ["edge"],
            examinedEdgeCount: 2,
            orderedScanCount: 0,
            diagnostics: baseline.diagnostics
        )

        XCTAssertNotEqual(baseline, differentExaminedEdgeCount)
    }

    func testCanvasEdgeViewportIndexPreservesCrossingEdgeWithoutVisibleEndpoints() {
        let nodes = [
            CanvasFrameRect(id: "left", x: -1_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "right", x: 1_000, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "crossing", sourceNodeID: "left", targetNodeID: "right")
        ]
        let index = CanvasEdgeViewportIndex(nodes: nodes, edges: edges, bucketSize: 128)

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: -40, y: -20, width: 120, height: 120),
            overscan: 0
        )

        XCTAssertEqual(result.edgeIDs, ["crossing"])
    }

    func testCanvasEdgeViewportIndexPreservesRoutedCrossingEdgeWithoutVisibleEndpoints() {
        let nodes = [
            CanvasFrameRect(id: "left", x: -1_000, y: 1_000, width: 80, height: 80),
            CanvasFrameRect(id: "right", x: 1_000, y: 1_000, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(
                id: "routed-crossing",
                sourceNodeID: "left",
                targetNodeID: "right",
                controlPoint: CanvasEdgePoint(x: 0, y: 20)
            )
        ]
        let index = CanvasEdgeViewportIndex(nodes: nodes, edges: edges, bucketSize: 128)

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: -40, y: -20, width: 120, height: 120),
            overscan: 0
        )

        XCTAssertEqual(result.edgeIDs, ["routed-crossing"])
        XCTAssertEqual(result.diagnostics.renderEdgeCount, 1)
        XCTAssertEqual(result.orderedScanCount, 1)
    }

    func testCanvasEdgeViewportIndexFallsBackForLongEdgeWithoutHugeBucketWrite() {
        let nodes = [
            CanvasFrameRect(id: "left", x: -1_000_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "right", x: 1_000_000, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "crossing", sourceNodeID: "left", targetNodeID: "right")
        ]
        let index = CanvasEdgeViewportIndex(nodes: nodes, edges: edges, bucketSize: 8)

        XCTAssertEqual(index.diagnostics.indexedEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.bucketedEdgeCount, 0)
        XCTAssertEqual(index.diagnostics.bucketFallbackEdgeCount, 1)

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: -40, y: -20, width: 120, height: 120),
            overscan: 0
        )

        XCTAssertEqual(result.edgeIDs, ["crossing"])
        XCTAssertEqual(result.examinedEdgeCount, 1)
        XCTAssertEqual(result.diagnostics.candidateExaminedCount, 1)
        XCTAssertEqual(result.diagnostics.fallbackExaminedEdgeCount, 1)
        XCTAssertFalse(result.diagnostics.bucketEnumerationWasBounded)
        XCTAssertLessThan(result.diagnostics.queriedBucketCount, 10_000)
        XCTAssertEqual(result.orderedScanCount, 1)
    }

    func testCanvasEdgeViewportIndexFallsBackWhenBucketCoordinateExceedsIntRange() {
        let extreme = Double(Int.max)
        let nodes = [
            CanvasFrameRect(id: "source", x: extreme, y: 0, width: 0, height: 0),
            CanvasFrameRect(id: "target", x: extreme, y: 0, width: 0, height: 0)
        ]
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: [
                CanvasEdgeViewportRecord(id: "extreme", sourceNodeID: "source", targetNodeID: "target")
            ],
            bucketSize: 1
        )

        XCTAssertEqual(index.diagnostics.indexedEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.bucketedEdgeCount, 0)
        XCTAssertEqual(index.diagnostics.bucketFallbackEdgeCount, 1)
        XCTAssertEqual(index.diagnostics.droppedInvalidGeometryEdgeCount, 0)

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: extreme, y: 0, width: 0, height: 0),
            overscan: 0
        )

        XCTAssertEqual(result.edgeIDs, ["extreme"])
        XCTAssertEqual(result.examinedEdgeCount, 1)
        XCTAssertEqual(result.diagnostics.fallbackExaminedEdgeCount, 1)
        XCTAssertTrue(result.diagnostics.bucketEnumerationWasBounded)
    }

    func testCanvasEdgeViewportIndexCapsHugeViewportBucketEnumerationWithFallbackDiagnostics() {
        let fixture = makeSparseCanvasEdgeViewportFixture(edgeCount: 120)
        let index = CanvasEdgeViewportIndex(
            nodes: fixture.nodes,
            edges: fixture.edges,
            bucketSize: 128
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "huge", x: -1_000_000, y: -1_000_000, width: 3_000_000, height: 2_000_000),
            overscan: 0
        )

        XCTAssertEqual(result.edgeIDs.count, 120)
        XCTAssertEqual(result.edgeIDs.first, "edge-0")
        XCTAssertEqual(result.edgeIDs.last, "edge-119")
        XCTAssertTrue(result.diagnostics.bucketEnumerationWasBounded)
        XCTAssertEqual(result.examinedEdgeCount, 120)
        XCTAssertEqual(result.diagnostics.candidateExaminedCount, 120)
        XCTAssertEqual(result.diagnostics.fallbackExaminedEdgeCount, 120)
        XCTAssertLessThan(result.diagnostics.queriedBucketCount, 10_000)
        XCTAssertEqual(result.orderedScanCount, 120)
    }

    func testCanvasEdgeViewportIndexCapsHugeOverscanBucketEnumerationWithFallbackDiagnostics() {
        let fixture = makeSparseCanvasEdgeViewportFixture(edgeCount: 120)
        let index = CanvasEdgeViewportIndex(
            nodes: fixture.nodes,
            edges: fixture.edges,
            bucketSize: 128
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "small", x: 0, y: 0, width: 120, height: 120),
            overscan: 1_000_000
        )

        XCTAssertEqual(result.edgeIDs.count, 120)
        XCTAssertEqual(result.edgeIDs.first, "edge-0")
        XCTAssertEqual(result.edgeIDs.last, "edge-119")
        XCTAssertTrue(result.diagnostics.bucketEnumerationWasBounded)
        XCTAssertEqual(result.examinedEdgeCount, 120)
        XCTAssertEqual(result.diagnostics.candidateExaminedCount, 120)
        XCTAssertEqual(result.diagnostics.fallbackExaminedEdgeCount, 120)
        XCTAssertEqual(result.diagnostics.queriedBucketCount, 0)
        XCTAssertEqual(result.orderedScanCount, 120)
    }

    func testCanvasEdgeViewportIndexBoundedFallbackPreservesInputOrder() {
        let nodes = [
            CanvasFrameRect(id: "za", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "zb", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "aa", x: 400, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "ab", x: 560, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "ma", x: 800, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "mb", x: 960, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "z-edge", sourceNodeID: "za", targetNodeID: "zb"),
            CanvasEdgeViewportRecord(id: "a-edge", sourceNodeID: "aa", targetNodeID: "ab"),
            CanvasEdgeViewportRecord(id: "m-edge", sourceNodeID: "ma", targetNodeID: "mb")
        ]
        let index = CanvasEdgeViewportIndex(nodes: nodes, edges: edges, bucketSize: 128)

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "huge", x: -1_000_000, y: -1_000_000, width: 3_000_000, height: 2_000_000),
            overscan: 0
        )

        XCTAssertEqual(result.edgeIDs, ["z-edge", "a-edge", "m-edge"])
        XCTAssertTrue(result.diagnostics.bucketEnumerationWasBounded)
        XCTAssertEqual(result.diagnostics.fallbackExaminedEdgeCount, 3)
        XCTAssertEqual(result.candidateEdgeCount, 3)
        XCTAssertEqual(result.orderedScanCount, 3)
    }

    func testCanvasEdgeViewportIndexAlwaysIncludesForcedActiveEdges() {
        let nodes = [
            CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "off-a", x: 20_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "off-b", x: 20_160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "ignored-a", x: 30_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "ignored-b", x: 30_160, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "visible-a", targetNodeID: "visible-b"),
            CanvasEdgeViewportRecord(id: "forced-selected", sourceNodeID: "off-a", targetNodeID: "off-b"),
            CanvasEdgeViewportRecord(id: "ordinary-offscreen", sourceNodeID: "ignored-a", targetNodeID: "ignored-b")
        ]
        let index = CanvasEdgeViewportIndex(nodes: nodes, edges: edges, bucketSize: 128)

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            forcedEdgeIDs: ["forced-selected"]
        )

        XCTAssertEqual(result.edgeIDs, ["visible", "forced-selected"])
        XCTAssertFalse(result.edgeIDs.contains("ordinary-offscreen"))
        XCTAssertEqual(result.orderedScanCount, 2)
    }

    func testCanvasEdgeViewportIndexInvalidViewportReturnsForcedEdgesWithoutFullOrderedScan() {
        let fixture = makeSparseCanvasEdgeViewportFixture(edgeCount: 10_000)
        let index = CanvasEdgeViewportIndex(
            nodes: fixture.nodes,
            edges: fixture.edges,
            bucketSize: 256
        )

        let result = index.query(
            visibleRect: CanvasFrameRect(id: "invalid", x: .nan, y: 0, width: 200, height: 160),
            overscan: 0,
            forcedEdgeIDs: ["edge-9_999", "edge-9999", "missing-edge"]
        )

        XCTAssertEqual(result.edgeIDs, ["edge-9999"])
        XCTAssertEqual(result.candidateEdgeCount, 1)
        XCTAssertEqual(result.examinedEdgeCount, 0)
        XCTAssertEqual(result.orderedScanCount, 1)
        XCTAssertEqual(result.diagnostics.queriedBucketCount, 0)
        XCTAssertEqual(result.diagnostics.bucketCandidateEdgeCount, 0)
        XCTAssertEqual(result.diagnostics.candidateExaminedCount, 0)
        XCTAssertEqual(result.diagnostics.fallbackExaminedEdgeCount, 0)
        XCTAssertEqual(result.diagnostics.orderedScanCount, 1)
        XCTAssertFalse(result.diagnostics.bucketEnumerationWasBounded)
        XCTAssertEqual(result.diagnostics.forcedRequestedCount, 3)
        XCTAssertEqual(result.diagnostics.forcedValidCount, 1)
        XCTAssertEqual(result.diagnostics.forcedInvalidCount, 2)
        XCTAssertEqual(result.diagnostics.forcedRetentionCount, 1)
        XCTAssertEqual(result.diagnostics.renderEdgeCount, 1)
    }

    func testCanvasEdgeViewportIndexCacheReusesStableGeometryAndInvalidatesOnGeometryOrBucketChanges() {
        let nodes = [
            CanvasFrameRect(id: "a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "b", x: 160, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "edge", sourceNodeID: "a", targetNodeID: "b")
        ]
        let cache = CanvasEdgeViewportIndexCache()

        let firstIndex = cache.index(nodes: nodes, edges: edges, bucketSize: 128)
        XCTAssertEqual(firstIndex.diagnostics.indexedEdgeCount, 1)
        XCTAssertEqual(cache.diagnostics.buildCount, 1)
        XCTAssertEqual(cache.diagnostics.reuseCount, 0)
        XCTAssertEqual(cache.diagnostics.lastInvalidationReason, .initial)

        let reusedIndex = cache.index(nodes: nodes, edges: edges, bucketSize: 128)
        XCTAssertEqual(reusedIndex.diagnostics, firstIndex.diagnostics)
        XCTAssertEqual(cache.diagnostics.buildCount, 1)
        XCTAssertEqual(cache.diagnostics.reuseCount, 1)
        XCTAssertEqual(cache.diagnostics.lastInvalidationReason, .initial)

        let movedNodes = [
            CanvasFrameRect(id: "a", x: 10, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "b", x: 160, y: 0, width: 80, height: 80)
        ]
        _ = cache.index(nodes: movedNodes, edges: edges, bucketSize: 128)
        XCTAssertEqual(cache.diagnostics.buildCount, 2)
        XCTAssertEqual(cache.diagnostics.reuseCount, 1)
        XCTAssertEqual(cache.diagnostics.lastInvalidationReason, .geometryChanged)

        _ = cache.index(nodes: movedNodes, edges: edges, bucketSize: 256)
        XCTAssertEqual(cache.diagnostics.buildCount, 3)
        XCTAssertEqual(cache.diagnostics.reuseCount, 1)
        XCTAssertEqual(cache.diagnostics.lastInvalidationReason, .bucketSizeChanged)
    }

    func testCanvasEdgeViewportIndexCacheEmitsHiddenMaintenanceCreateReuseAndCleanupEvents() {
        var events: [MindDeskHiddenMaintenanceLogEvent] = []
        let cache = CanvasEdgeViewportIndexCache(logEvent: { events.append($0) })
        let nodes = [
            CanvasFrameRect(id: "source raw /Users/joshua/file https://example.invalid", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "target raw", x: 160, y: 0, width: 80, height: 80)
        ]
        let movedNodes = [
            CanvasFrameRect(id: "source raw /Users/joshua/file https://example.invalid", x: 12, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "target raw", x: 160, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(
                id: "edge secret /Users/joshua/file https://example.invalid",
                sourceNodeID: "source raw /Users/joshua/file https://example.invalid",
                targetNodeID: "target raw"
            )
        ]

        _ = cache.index(nodes: nodes, edges: edges, bucketSize: 128)
        _ = cache.index(nodes: nodes, edges: edges, bucketSize: 128)
        _ = cache.index(nodes: movedNodes, edges: edges, bucketSize: 128)

        XCTAssertEqual(
            events.map { "\($0.subject.rawValue):\($0.action.rawValue):\($0.result.rawValue)" },
            [
                "canvasEdgeViewportIndexCache:create:succeeded",
                "canvasEdgeViewportIndexCache:reuse:succeeded",
                "canvasEdgeViewportIndexCache:cleanup:succeeded",
                "canvasEdgeViewportIndexCache:create:succeeded"
            ]
        )
        XCTAssertEqual(events[0].details["reason"], "initial")
        XCTAssertEqual(events[2].details["reason"], "geometryChanged")
        XCTAssertEqual(events[3].details["buildCount"], "2")
        let joinedMessages = events.map(\.message).joined(separator: "\n")
        for forbidden in ["source raw", "target raw", "edge secret", "/Users/", "https://"] {
            XCTAssertFalse(
                joinedMessages.localizedCaseInsensitiveContains(forbidden),
                "Hidden maintenance cache logs should stay aggregate-only: \(forbidden)"
            )
        }
    }

    func testCanvasEdgeViewportIndexCacheReusesStableNonFiniteNodeGeometryInputs() {
        let invalidNodes = [
            CanvasFrameRect(id: "a", x: .nan, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "b", x: 160, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "edge", sourceNodeID: "a", targetNodeID: "b")
        ]
        let cache = CanvasEdgeViewportIndexCache()

        let firstIndex = cache.index(nodes: invalidNodes, edges: edges, bucketSize: 128)
        XCTAssertEqual(firstIndex.diagnostics.indexedEdgeCount, 0)
        XCTAssertEqual(firstIndex.diagnostics.droppedInvalidGeometryEdgeCount, 1)
        XCTAssertEqual(cache.diagnostics.buildCount, 1)
        XCTAssertEqual(cache.diagnostics.reuseCount, 0)

        let reusedIndex = cache.index(nodes: invalidNodes, edges: edges, bucketSize: 128)

        XCTAssertEqual(reusedIndex.diagnostics, firstIndex.diagnostics)
        XCTAssertEqual(cache.diagnostics.buildCount, 1)
        XCTAssertEqual(cache.diagnostics.reuseCount, 1)
        XCTAssertEqual(cache.diagnostics.lastInvalidationReason, .initial)
    }

    func testCanvasEdgeViewportIndexCacheInvalidatesWhenInvalidGeometryBecomesIndexable() {
        let invalidNodes = [
            CanvasFrameRect(id: "a", x: .nan, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "b", x: 160, y: 0, width: 80, height: 80)
        ]
        let validNodes = [
            CanvasFrameRect(id: "a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "b", x: 160, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "edge", sourceNodeID: "a", targetNodeID: "b")
        ]
        let cache = CanvasEdgeViewportIndexCache()

        _ = cache.index(nodes: invalidNodes, edges: edges, bucketSize: 128)
        let validIndex = cache.index(nodes: validNodes, edges: edges, bucketSize: 128)

        XCTAssertEqual(validIndex.diagnostics.indexedEdgeCount, 1)
        XCTAssertEqual(validIndex.diagnostics.droppedInvalidGeometryEdgeCount, 0)
        XCTAssertEqual(cache.diagnostics.buildCount, 2)
        XCTAssertEqual(cache.diagnostics.reuseCount, 0)
        XCTAssertEqual(cache.diagnostics.lastInvalidationReason, .geometryChanged)
    }

    func testCanvasEdgeViewportIndexCacheTreatsNonFiniteControlPointAsStableIgnoredGeometry() {
        let nodes = [
            CanvasFrameRect(id: "a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "b", x: 160, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(
                id: "edge",
                sourceNodeID: "a",
                targetNodeID: "b",
                controlPoint: CanvasEdgePoint(x: .nan, y: 40)
            )
        ]
        let cache = CanvasEdgeViewportIndexCache()

        let firstIndex = cache.index(nodes: nodes, edges: edges, bucketSize: 128)
        XCTAssertEqual(firstIndex.diagnostics.indexedEdgeCount, 1)
        XCTAssertEqual(firstIndex.diagnostics.droppedInvalidGeometryEdgeCount, 0)

        let reusedIndex = cache.index(nodes: nodes, edges: edges, bucketSize: 128)

        XCTAssertEqual(reusedIndex.diagnostics, firstIndex.diagnostics)
        XCTAssertEqual(cache.diagnostics.buildCount, 1)
        XCTAssertEqual(cache.diagnostics.reuseCount, 1)
    }

    func testCanvasEdgeViewportIndexCacheReusesCanvasSpaceIndexAcrossPanZoomQueries() {
        let nodes = [
            CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "later-a", x: 1_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "later-b", x: 1_160, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "visible-a", targetNodeID: "visible-b"),
            CanvasEdgeViewportRecord(id: "later", sourceNodeID: "later-a", targetNodeID: "later-b")
        ]
        let cache = CanvasEdgeViewportIndexCache()
        let index = cache.index(nodes: nodes, edges: edges, bucketSize: 128)

        let initialQuery = index.query(
            visibleRect: CanvasFrameRect(id: "initial", x: -80, y: -80, width: 360, height: 240),
            overscan: 0
        )
        XCTAssertEqual(initialQuery.edgeIDs, ["visible"])

        let reusedIndex = cache.index(nodes: nodes, edges: edges, bucketSize: 128)
        let pannedQuery = reusedIndex.query(
            visibleRect: CanvasFrameRect(id: "panned", x: 900, y: -80, width: 420, height: 240),
            overscan: 0
        )

        XCTAssertEqual(pannedQuery.edgeIDs, ["later"])
        XCTAssertEqual(cache.diagnostics.buildCount, 1)
        XCTAssertEqual(cache.diagnostics.reuseCount, 1)
        XCTAssertNotEqual(initialQuery.diagnostics, pannedQuery.diagnostics)
    }

    func testCanvasEdgeViewportIndexCacheReusesIncidentAdjacencyWithCachedIndex() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let passiveEdgeCount = max(limit * 4, 160)
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
        let incidentNodes = (0..<(limit + 5)).map { index in
            CanvasFrameRect(id: "target-\(index)", x: Double(50_000 + index * 120), y: 0, width: 80, height: 80)
        }
        let incidentEdges = (0..<(limit + 5)).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }
        let selected = CanvasEdgeViewportRecord(id: "selected-late", sourceNodeID: "selected-a", targetNodeID: "selected-b")
        let nodes = passiveNodes + [
            CanvasFrameRect(id: "moving", x: 40_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-a", x: 42_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-b", x: 42_160, y: 0, width: 80, height: 80)
        ] + incidentNodes
        let edges = passiveEdges + [incidentEdges[0], selected] + Array(incidentEdges.dropFirst())
        let cache = CanvasEdgeViewportIndexCache()

        _ = cache.index(nodes: nodes, edges: edges, bucketSize: 128)
        let reusedIndex = cache.index(nodes: nodes, edges: edges, bucketSize: 128)
        let result = reusedIndex.forceRetainedEdgeIDs(
            selectedEdgeIDs: ["selected-late"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving"]
        )

        XCTAssertEqual(cache.diagnostics.buildCount, 1)
        XCTAssertEqual(cache.diagnostics.reuseCount, 1)
        XCTAssertTrue(result.usedIncidentAdjacency)
        XCTAssertEqual(result.adjacencyLookupNodeCount, 1)
        XCTAssertEqual(result.incidentCandidateEdgeCount, limit + 5)
        XCTAssertEqual(result.maximumIncidentEdgeCount, limit)
        XCTAssertLessThan(result.edgeScanCount, passiveEdgeCount)
        XCTAssertEqual(result.edgeIDs.prefix(2), ["incident-0", "selected-late"])
        XCTAssertFalse(result.edgeIDs.contains("passive-0"))
    }

    func testCanvasEdgeVisibilityPlannerCarriesCacheDiagnosticsAcrossPanZoomQueries() throws {
        let nodes = [
            CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "later-a", x: 1_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "later-b", x: 1_160, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "visible-a", targetNodeID: "visible-b"),
            CanvasEdgeViewportRecord(id: "later", sourceNodeID: "later-a", targetNodeID: "later-b")
        ]
        let cache = CanvasEdgeViewportIndexCache()
        let firstIndex = cache.index(nodes: nodes, edges: edges, bucketSize: 128)
        let initialPlan = CanvasEdgeVisibilityPlanner.plan(
            edgeIndex: firstIndex,
            cacheDiagnostics: cache.diagnostics,
            viewport: CanvasFrameRect(id: "initial", x: -80, y: -80, width: 360, height: 240),
            overscan: 0,
            forcedEdgeIDs: [],
            visibleObstacleCount: 0,
            visibleCardCount: 2,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        )
        let initialCacheDiagnostics = try XCTUnwrap(initialPlan.diagnostics.cache)

        XCTAssertEqual(initialPlan.renderEdgeIDs, ["visible"])
        XCTAssertEqual(initialCacheDiagnostics.buildCount, 1)
        XCTAssertEqual(initialCacheDiagnostics.reuseCount, 0)
        XCTAssertEqual(initialCacheDiagnostics.lastInvalidationReason, .initial)

        let reusedIndex = cache.index(nodes: nodes, edges: edges, bucketSize: 128)
        let pannedPlan = CanvasEdgeVisibilityPlanner.plan(
            edgeIndex: reusedIndex,
            cacheDiagnostics: cache.diagnostics,
            viewport: CanvasFrameRect(id: "panned", x: 900, y: -80, width: 420, height: 240),
            overscan: 0,
            forcedEdgeIDs: [],
            visibleObstacleCount: 0,
            visibleCardCount: 2,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        )
        let pannedCacheDiagnostics = try XCTUnwrap(pannedPlan.diagnostics.cache)

        XCTAssertEqual(pannedPlan.renderEdgeIDs, ["later"])
        XCTAssertEqual(pannedCacheDiagnostics.buildCount, 1)
        XCTAssertEqual(pannedCacheDiagnostics.reuseCount, 1)
        XCTAssertEqual(pannedCacheDiagnostics.lastInvalidationReason, .initial)
        XCTAssertNotEqual(initialPlan.diagnostics.renderQuery, pannedPlan.diagnostics.renderQuery)
    }

    func testCanvasEdgeVisibilityDiagnosticsCacheFieldStaysAggregateOnly() throws {
        let diagnostics = CanvasEdgeVisibilityDiagnostics(
            index: CanvasEdgeViewportIndexDiagnostics(
                totalEdgeCount: 2,
                indexedEdgeCount: 1,
                duplicateEdgeCount: 0,
                droppedDanglingEdgeCount: 1,
                bucketSize: 128
            ),
            visibleQuery: CanvasEdgeViewportQueryDiagnostics(
                queriedBucketCount: 1,
                bucketCandidateEdgeCount: 1,
                candidateExaminedCount: 1,
                orderedScanCount: 1,
                forcedRequestedCount: 0,
                forcedValidCount: 0,
                forcedInvalidCount: 0,
                renderEdgeCount: 1
            ),
            renderQuery: CanvasEdgeViewportQueryDiagnostics(
                queriedBucketCount: 1,
                bucketCandidateEdgeCount: 1,
                candidateExaminedCount: 1,
                orderedScanCount: 1,
                forcedRequestedCount: 0,
                forcedValidCount: 0,
                forcedInvalidCount: 0,
                renderEdgeCount: 1
            ),
            cache: CanvasEdgeViewportIndexCacheDiagnostics(
                buildCount: 1,
                reuseCount: 2,
                lastInvalidationReason: .geometryChanged
            ),
            forceRetainedEdgeCount: 0,
            renderEdgeCount: 1
        )
        let cacheDiagnostics = try XCTUnwrap(diagnostics.cache)

        XCTAssertEqual(
            Set(Mirror(reflecting: diagnostics).children.compactMap(\.label)),
            [
                "index",
                "visibleQuery",
                "renderQuery",
                "cache",
                "forceRetention",
                "forceRetainedEdgeCount",
                "renderEdgeCount"
            ]
        )
        XCTAssertEqual(
            Set(Mirror(reflecting: cacheDiagnostics).children.compactMap(\.label)),
            ["buildCount", "reuseCount", "lastInvalidationReason"]
        )
        let forbiddenFieldFragments = [
            "signature",
            "hash",
            "bucket",
            "point",
            "route",
            "bounds",
            "x",
            "y",
            "width",
            "height",
            "controlPoint"
        ]
        let cacheFieldNames = Mirror(reflecting: cacheDiagnostics).children.compactMap(\.label)
        for fieldName in cacheFieldNames {
            XCTAssertFalse(["id", "ids"].contains(fieldName.lowercased()))
            XCTAssertFalse(
                forbiddenFieldFragments.contains { fieldName.localizedCaseInsensitiveContains($0) },
                "Cache diagnostics should stay aggregate-only, but exposed field \(fieldName)."
            )
        }
        let diagnosticText = [
            String(cacheDiagnostics.buildCount),
            String(cacheDiagnostics.reuseCount),
            cacheDiagnostics.lastInvalidationReason.rawValue
        ].joined(separator: " ")

        XCTAssertFalse(diagnosticText.contains("node-"))
        XCTAssertFalse(diagnosticText.contains("edge-"))
        XCTAssertFalse(diagnosticText.contains("bucket("))
        XCTAssertFalse(diagnosticText.contains("/Users/"))
        XCTAssertFalse(diagnosticText.contains("https://"))
    }

    func testCanvasEdgeVisibilityPlannerCanvasSpaceIndexMatchesScreenSpacePlanAcrossPanZoom() {
        let canvasNodes = [
            CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "cross-a", x: -1_000, y: 20, width: 80, height: 80),
            CanvasFrameRect(id: "cross-b", x: 1_000, y: 20, width: 80, height: 80),
            CanvasFrameRect(id: "forced-a", x: 2_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "forced-b", x: 2_160, y: 0, width: 80, height: 80)
        ]
        let canvasEdges = [
            CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "visible-a", targetNodeID: "visible-b"),
            CanvasEdgeViewportRecord(
                id: "crossing",
                sourceNodeID: "cross-a",
                targetNodeID: "cross-b",
                controlPoint: CanvasEdgePoint(x: 50, y: 20)
            ),
            CanvasEdgeViewportRecord(id: "forced", sourceNodeID: "forced-a", targetNodeID: "forced-b")
        ]
        let zoom = 0.5
        let viewportX = 120.0
        let viewportY = -40.0
        let screenViewport = CanvasFrameRect(id: "screen", x: 80, y: -80, width: 260, height: 220)
        let screenOverscan = 120.0
        let screenNodes = canvasNodes.map {
            CanvasViewportProjection.screenRect(
                id: $0.id,
                x: $0.x,
                y: $0.y,
                width: $0.width,
                height: $0.height,
                zoom: zoom,
                viewportX: viewportX,
                viewportY: viewportY
            )
        }
        let screenEdges = canvasEdges.map { edge in
            CanvasEdgeViewportRecord(
                id: edge.id,
                sourceNodeID: edge.sourceNodeID,
                targetNodeID: edge.targetNodeID,
                controlPoint: edge.controlPoint.map {
                    CanvasViewportProjection.screenPoint(
                        x: $0.x,
                        y: $0.y,
                        zoom: zoom,
                        viewportX: viewportX,
                        viewportY: viewportY
                    )
                }
            )
        }

        let screenPlan = CanvasEdgeVisibilityPlanner.plan(
            nodes: screenNodes,
            edges: screenEdges,
            viewport: screenViewport,
            overscan: screenOverscan,
            selectedEdgeIDs: ["forced"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: [],
            visibleObstacleCount: 0,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: zoom,
            baselineZoom: 0.35,
            isInteracting: false
        )

        let topLeft = CanvasViewportProjection.canvasPoint(
            screenX: screenViewport.x,
            screenY: screenViewport.y,
            zoom: zoom,
            viewportX: viewportX,
            viewportY: viewportY
        )
        let bottomRight = CanvasViewportProjection.canvasPoint(
            screenX: screenViewport.x + screenViewport.width,
            screenY: screenViewport.y + screenViewport.height,
            zoom: zoom,
            viewportX: viewportX,
            viewportY: viewportY
        )
        let canvasViewport = CanvasFrameRect(
            id: "canvas",
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(bottomRight.x - topLeft.x),
            height: abs(bottomRight.y - topLeft.y)
        )
        let canvasPlan = CanvasEdgeVisibilityPlanner.plan(
            edgeIndex: CanvasEdgeViewportIndex(nodes: canvasNodes, edges: canvasEdges, bucketSize: 128),
            viewport: canvasViewport,
            overscan: screenOverscan / CanvasZoomScale.safeZoom(zoom, minimum: 0.01),
            forcedEdgeIDs: ["forced"],
            visibleObstacleCount: 0,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: zoom,
            baselineZoom: 0.35,
            isInteracting: false
        )

        XCTAssertEqual(screenPlan.renderEdgeIDs, canvasPlan.renderEdgeIDs)
        XCTAssertEqual(screenPlan.forceRetainedEdgeIDs, canvasPlan.forceRetainedEdgeIDs)
        XCTAssertEqual(screenPlan.visibleCandidateCount, canvasPlan.visibleCandidateCount)
        XCTAssertEqual(canvasPlan.renderEdgeIDs, ["visible", "crossing", "forced"])
    }

    func testCanvasEdgeVisibilityPlannerRetainsForcedEdgeWhenDenseZoomDisablesExpensiveRendering() {
        let fixture = makeSparseCanvasEdgeViewportFixture(edgeCount: 400)
        let plan = CanvasEdgeVisibilityPlanner.plan(
            nodes: fixture.nodes,
            edges: fixture.edges,
            viewport: CanvasFrameRect(id: "viewport", x: -10_000, y: -10_000, width: 120, height: 120),
            overscan: 0,
            selectedEdgeIDs: ["edge-399"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: [],
            visibleObstacleCount: 20,
            visibleCardCount: 400,
            routedPointCount: 0,
            zoom: 0.10,
            baselineZoom: 0.35,
            isInteracting: false
        )

        XCTAssertEqual(plan.renderEdgeIDs, ["edge-399"])
        XCTAssertEqual(plan.forceRetainedEdgeIDs, ["edge-399"])
        XCTAssertEqual(plan.visibleCandidateCount, 0)
        XCTAssertFalse(plan.usesObstacleRouting)
        XCTAssertFalse(plan.animatesVisibleEdges)
    }

    func testCanvasEdgeVisibilityPlannerReusesPrebuiltIndexAndKeepsDiagnosticsSeparated() {
        let nodes = [
            CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "near-a", x: 420, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "near-b", x: 580, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "off-a", x: 20_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "off-b", x: 20_160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "invalid", x: .nan, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "visible-a", targetNodeID: "visible-b"),
            CanvasEdgeViewportRecord(id: "near", sourceNodeID: "near-a", targetNodeID: "near-b"),
            CanvasEdgeViewportRecord(id: "offscreen", sourceNodeID: "off-a", targetNodeID: "off-b"),
            CanvasEdgeViewportRecord(id: "offscreen", sourceNodeID: "visible-a", targetNodeID: "visible-b"),
            CanvasEdgeViewportRecord(id: "dangling", sourceNodeID: "visible-a", targetNodeID: "missing"),
            CanvasEdgeViewportRecord(id: "invalid-node", sourceNodeID: "invalid", targetNodeID: "visible-b")
        ]
        let index = CanvasEdgeViewportIndex(nodes: nodes, edges: edges, bucketSize: 128)
        let buildDiagnostics = index.diagnostics

        XCTAssertEqual(buildDiagnostics.totalEdgeCount, 6)
        XCTAssertEqual(buildDiagnostics.indexedEdgeCount, 3)
        XCTAssertEqual(buildDiagnostics.duplicateEdgeCount, 1)
        XCTAssertEqual(buildDiagnostics.droppedDanglingEdgeCount, 1)
        XCTAssertEqual(buildDiagnostics.droppedInvalidGeometryEdgeCount, 1)

        func plan(
            viewport: CanvasFrameRect,
            forcedEdgeIDs: Set<String> = []
        ) -> CanvasEdgeVisibilityPlan {
            CanvasEdgeVisibilityPlanner.plan(
                edgeIndex: index,
                viewport: viewport,
                overscan: 0,
                forcedEdgeIDs: forcedEdgeIDs,
                visibleObstacleCount: 0,
                visibleCardCount: 1,
                routedPointCount: 0,
                zoom: 0.35,
                baselineZoom: 0.35,
                isInteracting: false
            )
        }

        let tightPlan = plan(viewport: CanvasFrameRect(id: "tight", x: 0, y: 0, width: 240, height: 80))
        let widePlan = plan(viewport: CanvasFrameRect(id: "wide", x: -128, y: -128, width: 768, height: 384))
        let forcedPlan = plan(
            viewport: CanvasFrameRect(id: "tight", x: 0, y: 0, width: 240, height: 80),
            forcedEdgeIDs: ["offscreen"]
        )

        for reusedPlan in [tightPlan, widePlan, forcedPlan] {
            XCTAssertEqual(reusedPlan.diagnostics.index, buildDiagnostics)
            XCTAssertNil(reusedPlan.diagnostics.cache)
        }

        XCTAssertEqual(tightPlan.renderEdgeIDs, ["visible"])
        XCTAssertEqual(tightPlan.diagnostics.visibleQuery.orderedScanCount, 1)
        XCTAssertEqual(tightPlan.diagnostics.renderQuery.orderedScanCount, 1)
        XCTAssertEqual(widePlan.renderEdgeIDs, ["visible", "near"])
        XCTAssertEqual(widePlan.diagnostics.visibleQuery.orderedScanCount, 2)
        XCTAssertEqual(widePlan.diagnostics.renderQuery.orderedScanCount, 2)
        XCTAssertNotEqual(tightPlan.diagnostics.renderQuery, widePlan.diagnostics.renderQuery)
        XCTAssertNotEqual(tightPlan, widePlan)

        XCTAssertEqual(forcedPlan.renderEdgeIDs, ["visible", "offscreen"])
        XCTAssertEqual(forcedPlan.forceRetainedEdgeIDs, ["offscreen"])
        XCTAssertEqual(forcedPlan.diagnostics.visibleQuery.orderedScanCount, 1)
        XCTAssertEqual(forcedPlan.diagnostics.renderQuery.orderedScanCount, 2)
        XCTAssertEqual(forcedPlan.diagnostics.renderQuery.forcedRequestedCount, 1)
        XCTAssertEqual(forcedPlan.diagnostics.renderQuery.forcedValidCount, 1)
        XCTAssertEqual(forcedPlan.diagnostics.renderQuery.forcedRetentionCount, 1)
        XCTAssertNotEqual(tightPlan.diagnostics.renderQuery, forcedPlan.diagnostics.renderQuery)
    }

    func testCanvasEdgeVisibilityPlannerForcesTransientMovedAndIncidentEdgesOutsideViewport() {
        let nodes = [
            CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "transient-a", x: 8_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "transient-b", x: 8_160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moved-a", x: 9_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moved-b", x: 9_160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moving-node", x: 10_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "incident-target", x: 10_160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "passive-a", x: 11_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "passive-b", x: 11_160, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "visible-a", targetNodeID: "visible-b"),
            CanvasEdgeViewportRecord(id: "transient", sourceNodeID: "transient-a", targetNodeID: "transient-b"),
            CanvasEdgeViewportRecord(id: "moved", sourceNodeID: "moved-a", targetNodeID: "moved-b"),
            CanvasEdgeViewportRecord(id: "incident", sourceNodeID: "moving-node", targetNodeID: "incident-target"),
            CanvasEdgeViewportRecord(id: "passive", sourceNodeID: "passive-a", targetNodeID: "passive-b")
        ]

        let plan = CanvasEdgeVisibilityPlanner.plan(
            nodes: nodes,
            edges: edges,
            viewport: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            selectedEdgeIDs: [],
            transientControlEdgeIDs: ["transient"],
            movedControlEdgeIDs: ["moved"],
            movingNodeIDs: ["moving-node"],
            visibleObstacleCount: 0,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: true
        )

        XCTAssertEqual(plan.visibleCandidateCount, 1)
        XCTAssertEqual(plan.forceRetainedEdgeIDs, ["transient", "moved", "incident"])
        XCTAssertEqual(plan.renderEdgeIDs, ["visible", "transient", "moved", "incident"])
        XCTAssertEqual(plan.diagnostics.forceRetainedEdgeCount, 3)
        XCTAssertEqual(plan.diagnostics.renderEdgeCount, 4)
        XCTAssertEqual(plan.diagnostics.visibleQuery.renderEdgeCount, 1)
        XCTAssertEqual(plan.diagnostics.visibleQuery.orderedScanCount, 1)
        XCTAssertEqual(plan.diagnostics.renderQuery.orderedScanCount, 4)
        XCTAssertEqual(plan.diagnostics.renderQuery.forcedRetentionCount, 3)
        XCTAssertFalse(plan.renderEdgeIDs.contains("passive"))
    }

    func testCanvasEdgeForceRetentionPolicyBoundsHighFanoutMovingNodeIncidents() {
        let explicitActiveEdges = [
            CanvasEdgeViewportRecord(id: "selected-edge", sourceNodeID: "moving", targetNodeID: "selected-target"),
            CanvasEdgeViewportRecord(id: "transient-edge", sourceNodeID: "moving", targetNodeID: "transient-target"),
            CanvasEdgeViewportRecord(id: "moved-control-edge", sourceNodeID: "moving", targetNodeID: "moved-target")
        ]
        let incidentEdges = (0..<(CanvasPerformancePolicy.maximumContextEdgesDuringInteraction + 12)).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }
        let passiveEdge = CanvasEdgeViewportRecord(id: "passive", sourceNodeID: "source", targetNodeID: "target")
        let result = CanvasEdgeForceRetentionPolicy.forceRetainedEdgeIDs(
            in: explicitActiveEdges + incidentEdges + [passiveEdge],
            selectedEdgeIDs: ["selected-edge"],
            transientControlEdgeIDs: ["transient-edge"],
            movedControlEdgeIDs: ["moved-control-edge"],
            movingNodeIDs: ["moving"]
        )

        XCTAssertEqual(result.edgeIDs.prefix(3), ["selected-edge", "transient-edge", "moved-control-edge"])
        XCTAssertTrue(result.edgeIDs.contains("incident-0"))
        XCTAssertTrue(result.edgeIDs.contains("incident-\(CanvasPerformancePolicy.maximumContextEdgesDuringInteraction - 1)"))
        XCTAssertFalse(result.edgeIDs.contains("incident-\(CanvasPerformancePolicy.maximumContextEdgesDuringInteraction)"))
        XCTAssertFalse(result.edgeIDs.contains("passive"))
        XCTAssertEqual(result.explicitActiveEdgeCount, 3)
        XCTAssertEqual(result.incidentEdgeCount, CanvasPerformancePolicy.maximumContextEdgesDuringInteraction)
        XCTAssertEqual(result.droppedIncidentEdgeCount, 12)
    }

    func testCanvasEdgeForceRetentionPolicyKeepsExplicitActiveEdgesPastIncidentLimitInInputOrder() {
        let limit = CanvasPerformancePolicy.maximumContextEdgesDuringInteraction
        let incidentEdges = (0..<(limit + 6)).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }
        let selected = CanvasEdgeViewportRecord(id: "selected-late", sourceNodeID: "selected-a", targetNodeID: "selected-b")
        let transient = CanvasEdgeViewportRecord(id: "transient-late", sourceNodeID: "transient-a", targetNodeID: "transient-b")
        let movedControl = CanvasEdgeViewportRecord(id: "moved-control-late", sourceNodeID: "moved-a", targetNodeID: "moved-b")
        let passive = CanvasEdgeViewportRecord(id: "passive", sourceNodeID: "passive-a", targetNodeID: "passive-b")

        let result = CanvasEdgeForceRetentionPolicy.forceRetainedEdgeIDs(
            in: [incidentEdges[0], selected]
                + Array(incidentEdges[1...limit])
                + [transient]
                + Array(incidentEdges[(limit + 1)...])
                + [movedControl, passive],
            selectedEdgeIDs: ["selected-late"],
            transientControlEdgeIDs: ["transient-late"],
            movedControlEdgeIDs: ["moved-control-late"],
            movingNodeIDs: ["moving"]
        )

        let expectedEdgeIDs = ["incident-0", "selected-late"]
            + (1..<limit).map { "incident-\($0)" }
            + ["transient-late", "moved-control-late"]

        XCTAssertEqual(result.edgeIDs, expectedEdgeIDs)
        XCTAssertEqual(result.incidentEdgeCount, limit)
        XCTAssertEqual(result.droppedIncidentEdgeCount, 6)
        XCTAssertFalse(result.edgeIDs.contains("incident-\(limit)"))
        XCTAssertFalse(result.edgeIDs.contains("passive"))
    }

    func testCanvasEdgeViewportIndexForceRetentionUsesIncidentAdjacencyInsteadOfScanningPassiveEdges() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let passiveEdgeCount = 160
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
        let incidentNodes = (0..<(limit + 4)).map { index in
            CanvasFrameRect(id: "target-\(index)", x: Double(50_000 + index * 120), y: 0, width: 80, height: 80)
        }
        let incidentEdges = (0..<(limit + 4)).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }
        let selected = CanvasEdgeViewportRecord(id: "selected-late", sourceNodeID: "selected-a", targetNodeID: "selected-b")
        let nodes = passiveNodes + [
            CanvasFrameRect(id: "moving", x: 40_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-a", x: 42_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-b", x: 42_160, y: 0, width: 80, height: 80)
        ] + incidentNodes
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: passiveEdges + [incidentEdges[0], selected] + Array(incidentEdges.dropFirst())
        )

        let result = index.forceRetainedEdgeIDs(
            selectedEdgeIDs: ["selected-late"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving"]
        )

        XCTAssertTrue(result.usedIncidentAdjacency)
        XCTAssertEqual(result.adjacencyLookupNodeCount, 1)
        XCTAssertEqual(result.incidentCandidateEdgeCount, limit + 4)
        XCTAssertLessThan(result.edgeScanCount, passiveEdgeCount)
        XCTAssertEqual(result.edgeIDs.prefix(2), ["incident-0", "selected-late"])
        XCTAssertTrue(result.edgeIDs.contains("incident-\(limit - 1)"))
        XCTAssertFalse(result.edgeIDs.contains("incident-\(limit)"))
        XCTAssertFalse(result.edgeIDs.contains("passive-0"))
    }

    func testCanvasEdgeViewportIndexForceRetentionBoundsSingleMovingNodeVisitsNearCapNotFullFanout() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let incidentFanout = limit + 500
        let incidentNodes = (0..<incidentFanout).map { index in
            CanvasFrameRect(id: "target-\(index)", x: Double(50_000 + index * 120), y: 0, width: 80, height: 80)
        }
        let incidentEdges = (0..<incidentFanout).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }
        let selected = CanvasEdgeViewportRecord(id: "selected-late", sourceNodeID: "selected-a", targetNodeID: "selected-b")
        let index = CanvasEdgeViewportIndex(
            nodes: [
                CanvasFrameRect(id: "moving", x: 40_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "selected-a", x: 42_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "selected-b", x: 42_160, y: 0, width: 80, height: 80)
            ] + incidentNodes,
            edges: [incidentEdges[0], selected] + Array(incidentEdges.dropFirst())
        )

        let result = index.forceRetainedEdgeIDs(
            selectedEdgeIDs: ["selected-late"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving"]
        )

        XCTAssertTrue(result.usedIncidentAdjacency)
        XCTAssertEqual(result.incidentCandidateEdgeCount, incidentFanout)
        XCTAssertEqual(result.incidentEdgeCount, limit)
        XCTAssertEqual(result.droppedIncidentEdgeCount, incidentFanout - limit)
        XCTAssertLessThanOrEqual(result.edgeScanCount, limit + 2)
        XCTAssertEqual(result.edgeIDs.prefix(2), ["incident-0", "selected-late"])
        XCTAssertTrue(result.edgeIDs.contains("incident-\(limit - 1)"))
        XCTAssertFalse(result.edgeIDs.contains("incident-\(limit)"))
    }

    func testCanvasEdgeViewportIndexForceRetentionDoesNotChargeExplicitIncidentAgainstSingleNodeCap() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let incidentFanout = limit + 5
        let incidentNodes = (0..<incidentFanout).map { index in
            CanvasFrameRect(id: "target-\(index)", x: Double(60_000 + index * 120), y: 0, width: 80, height: 80)
        }
        let incidentEdges = (0..<incidentFanout).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }
        let selected = CanvasEdgeViewportRecord(id: "selected-incident", sourceNodeID: "moving", targetNodeID: "selected-target")
        let index = CanvasEdgeViewportIndex(
            nodes: [
                CanvasFrameRect(id: "moving", x: 50_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "selected-target", x: 50_160, y: 0, width: 80, height: 80)
            ] + incidentNodes,
            edges: [incidentEdges[0], selected] + Array(incidentEdges.dropFirst())
        )

        let result = index.forceRetainedEdgeIDs(
            selectedEdgeIDs: ["selected-incident"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving"]
        )

        XCTAssertEqual(result.explicitActiveEdgeCount, 1)
        XCTAssertEqual(result.incidentCandidateEdgeCount, incidentFanout)
        XCTAssertEqual(result.incidentEdgeCount, limit)
        XCTAssertEqual(result.droppedIncidentEdgeCount, incidentFanout - limit)
        XCTAssertEqual(result.edgeIDs.prefix(2), ["incident-0", "selected-incident"])
        XCTAssertTrue(result.edgeIDs.contains("incident-\(limit - 1)"))
        XCTAssertFalse(result.edgeIDs.contains("incident-\(limit)"))
        XCTAssertLessThanOrEqual(result.edgeScanCount, limit + 2)
    }

    func testCanvasEdgeViewportIndexForceRetentionCountsMovingNodeSelfLoopOnce() {
        let index = CanvasEdgeViewportIndex(
            nodes: [
                CanvasFrameRect(id: "moving", x: 0, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "target", x: 160, y: 0, width: 80, height: 80)
            ],
            edges: [
                CanvasEdgeViewportRecord(id: "self-loop", sourceNodeID: "moving", targetNodeID: "moving"),
                CanvasEdgeViewportRecord(id: "incident", sourceNodeID: "moving", targetNodeID: "target")
            ]
        )

        let result = index.forceRetainedEdgeIDs(
            selectedEdgeIDs: [],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving"]
        )

        XCTAssertEqual(result.edgeIDs, ["self-loop", "incident"])
        XCTAssertEqual(result.incidentCandidateEdgeCount, 2)
        XCTAssertEqual(result.incidentEdgeCount, 2)
        XCTAssertEqual(result.droppedIncidentEdgeCount, 0)
        XCTAssertEqual(result.edgeScanCount, 2)
    }

    func testCanvasEdgeViewportIndexForceRetentionBoundsMultipleMovingNodeVisitsNearCapNotFullFanout() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let incidentFanoutPerNode = limit + 220
        let movingNodes = [
            CanvasFrameRect(id: "moving-a", x: 40_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moving-b", x: 45_000, y: 0, width: 80, height: 80)
        ]
        let targetNodes = (0..<incidentFanoutPerNode).flatMap { index in
            let targetAX = Double(60_000 + index * 120)
            let targetBX = Double(90_000 + index * 120)
            return [
                CanvasFrameRect(id: "target-a-\(index)", x: targetAX, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "target-b-\(index)", x: targetBX, y: 0, width: 80, height: 80)
            ]
        }
        let incidentEdges = (0..<incidentFanoutPerNode).flatMap { index in
            let incidentA = CanvasEdgeViewportRecord(
                id: "incident-a-\(index)",
                sourceNodeID: "moving-a",
                targetNodeID: "target-a-\(index)"
            )
            let incidentB = CanvasEdgeViewportRecord(
                id: "incident-b-\(index)",
                sourceNodeID: "moving-b",
                targetNodeID: "target-b-\(index)"
            )
            return [
                incidentA,
                incidentB
            ]
        }
        let selected = CanvasEdgeViewportRecord(id: "selected-late", sourceNodeID: "selected-a", targetNodeID: "selected-b")
        let index = CanvasEdgeViewportIndex(
            nodes: movingNodes + [
                CanvasFrameRect(id: "selected-a", x: 42_000, y: 0, width: 80, height: 80),
                CanvasFrameRect(id: "selected-b", x: 42_160, y: 0, width: 80, height: 80)
            ] + targetNodes,
            edges: [incidentEdges[0], selected] + Array(incidentEdges.dropFirst())
        )

        let result = index.forceRetainedEdgeIDs(
            selectedEdgeIDs: ["selected-late"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving-a", "moving-b"]
        )

        XCTAssertTrue(result.usedIncidentAdjacency)
        XCTAssertEqual(result.adjacencyLookupNodeCount, 2)
        XCTAssertEqual(result.incidentCandidateEdgeCount, incidentFanoutPerNode * 2)
        XCTAssertEqual(result.incidentEdgeCount, limit)
        XCTAssertEqual(result.droppedIncidentEdgeCount, incidentFanoutPerNode * 2 - limit)
        XCTAssertLessThanOrEqual(result.edgeScanCount, limit + 4)
        XCTAssertEqual(result.edgeIDs.prefix(2), ["incident-a-0", "selected-late"])
        XCTAssertTrue(result.edgeIDs.contains("incident-b-23"))
        XCTAssertFalse(result.edgeIDs.contains("incident-a-\(limit)"))
    }

    func testCanvasEdgeViewportIndexForceRetentionCountsSharedMultiMovingNodeIncidentOnceWithoutFullUnionScan() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let aFanout = limit + 120
        let bFanout = limit + 140
        var targetNodes: [CanvasFrameRect] = [
            CanvasFrameRect(id: "moving-a", x: 40_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moving-b", x: 45_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-target", x: 46_000, y: 0, width: 80, height: 80)
        ]
        var incidentEdges: [CanvasEdgeViewportRecord] = [
            CanvasEdgeViewportRecord(id: "shared-moving", sourceNodeID: "moving-a", targetNodeID: "moving-b"),
            CanvasEdgeViewportRecord(id: "selected-incident", sourceNodeID: "moving-a", targetNodeID: "selected-target")
        ]
        for index in 0..<max(aFanout, bFanout) {
            if index < aFanout {
                targetNodes.append(
                    CanvasFrameRect(id: "target-a-\(index)", x: Double(60_000 + index * 120), y: 0, width: 80, height: 80)
                )
                incidentEdges.append(
                    CanvasEdgeViewportRecord(id: "incident-a-\(index)", sourceNodeID: "moving-a", targetNodeID: "target-a-\(index)")
                )
            }
            if index < bFanout {
                targetNodes.append(
                    CanvasFrameRect(id: "target-b-\(index)", x: Double(90_000 + index * 120), y: 0, width: 80, height: 80)
                )
                incidentEdges.append(
                    CanvasEdgeViewportRecord(id: "incident-b-\(index)", sourceNodeID: "moving-b", targetNodeID: "target-b-\(index)")
                )
            }
        }
        let index = CanvasEdgeViewportIndex(nodes: targetNodes, edges: incidentEdges)

        let result = index.forceRetainedEdgeIDs(
            selectedEdgeIDs: ["selected-incident"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving-a", "moving-b"]
        )

        XCTAssertEqual(result.explicitActiveEdgeCount, 1)
        XCTAssertEqual(result.incidentCandidateEdgeCount, aFanout + bFanout + 1)
        XCTAssertEqual(result.incidentEdgeCount, limit)
        XCTAssertEqual(result.droppedIncidentEdgeCount, aFanout + bFanout + 1 - limit)
        XCTAssertEqual(result.edgeIDs.prefix(2), ["shared-moving", "selected-incident"])
        XCTAssertTrue(result.edgeIDs.contains("selected-incident"))
        XCTAssertTrue(result.edgeIDs.contains("shared-moving"))
        XCTAssertLessThanOrEqual(result.edgeScanCount, limit + 5)
    }

    func testCanvasEdgeVisibilityPlannerBoundsSingleMovingNodeIncidentScanNearCap() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let incidentFanout = limit + 400
        let incidentNodes = (0..<incidentFanout).map { index in
            CanvasFrameRect(id: "target-\(index)", x: Double(90_000 + index * 120), y: 0, width: 80, height: 80)
        }
        let incidentEdges = (0..<incidentFanout).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }
        let nodes = [
            CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moving", x: 80_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-a", x: 82_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-b", x: 82_160, y: 0, width: 80, height: 80)
        ] + incidentNodes
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: [
                CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "visible-a", targetNodeID: "visible-b"),
                CanvasEdgeViewportRecord(id: "selected-edge", sourceNodeID: "selected-a", targetNodeID: "selected-b")
            ] + incidentEdges
        )

        let plan = CanvasEdgeVisibilityPlanner.plan(
            edgeIndex: index,
            viewport: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            selectedEdgeIDs: ["selected-edge"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving"],
            visibleObstacleCount: 0,
            visibleCardCount: 0,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: true
        )

        XCTAssertTrue(plan.diagnostics.forceRetention.usedIncidentAdjacency)
        XCTAssertEqual(plan.diagnostics.forceRetention.incidentCandidateEdgeCount, incidentFanout)
        XCTAssertEqual(plan.diagnostics.forceRetention.incidentEdgeCount, limit)
        XCTAssertEqual(plan.diagnostics.forceRetention.droppedIncidentEdgeCount, incidentFanout - limit)
        XCTAssertLessThanOrEqual(plan.diagnostics.forceRetention.edgeScanCount, limit + 2)
        XCTAssertEqual(plan.diagnostics.renderQuery.forcedRequestedCount, 1 + limit)
        XCTAssertTrue(plan.renderEdgeIDs.contains("visible"))
        XCTAssertTrue(plan.renderEdgeIDs.contains("selected-edge"))
        XCTAssertFalse(plan.renderEdgeIDs.contains("incident-\(limit)"))
    }

    func testCanvasEdgeVisibilityPlannerBoundsMultipleMovingNodeIncidentScanNearCap() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let incidentFanoutPerNode = limit + 180
        var incidentNodes: [CanvasFrameRect] = []
        var incidentEdges: [CanvasEdgeViewportRecord] = []
        for index in 0..<incidentFanoutPerNode {
            incidentNodes.append(
                CanvasFrameRect(id: "target-a-\(index)", x: Double(80_000 + index * 120), y: 0, width: 80, height: 80)
            )
            incidentNodes.append(
                CanvasFrameRect(id: "target-b-\(index)", x: Double(110_000 + index * 120), y: 0, width: 80, height: 80)
            )
            incidentEdges.append(
                CanvasEdgeViewportRecord(id: "incident-a-\(index)", sourceNodeID: "moving-a", targetNodeID: "target-a-\(index)")
            )
            incidentEdges.append(
                CanvasEdgeViewportRecord(id: "incident-b-\(index)", sourceNodeID: "moving-b", targetNodeID: "target-b-\(index)")
            )
        }
        let nodes = [
            CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moving-a", x: 70_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moving-b", x: 72_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-a", x: 74_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-b", x: 74_160, y: 0, width: 80, height: 80)
        ] + incidentNodes
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: [
                CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "visible-a", targetNodeID: "visible-b"),
                CanvasEdgeViewportRecord(id: "selected-edge", sourceNodeID: "selected-a", targetNodeID: "selected-b")
            ] + incidentEdges
        )

        let plan = CanvasEdgeVisibilityPlanner.plan(
            edgeIndex: index,
            viewport: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            selectedEdgeIDs: ["selected-edge"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving-a", "moving-b"],
            visibleObstacleCount: 0,
            visibleCardCount: 0,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: true
        )

        let totalFanout = incidentFanoutPerNode * 2
        XCTAssertTrue(plan.diagnostics.forceRetention.usedIncidentAdjacency)
        XCTAssertEqual(plan.diagnostics.forceRetention.adjacencyLookupNodeCount, 2)
        XCTAssertEqual(plan.diagnostics.forceRetention.incidentCandidateEdgeCount, totalFanout)
        XCTAssertEqual(plan.diagnostics.forceRetention.incidentEdgeCount, limit)
        XCTAssertEqual(plan.diagnostics.forceRetention.droppedIncidentEdgeCount, totalFanout - limit)
        XCTAssertLessThanOrEqual(plan.diagnostics.forceRetention.edgeScanCount, limit + 4)
        XCTAssertEqual(plan.diagnostics.renderQuery.forcedRequestedCount, 1 + limit)
        XCTAssertTrue(plan.renderEdgeIDs.contains("visible"))
        XCTAssertTrue(plan.renderEdgeIDs.contains("selected-edge"))
        XCTAssertFalse(plan.renderEdgeIDs.contains("incident-a-\(limit)"))
    }

    func testCanvasEdgeVisibilityPlannerCanBuildForceRetentionFromIndexAdjacency() {
        let limit = CanvasPerformancePolicy.maximumMovingNodeIncidentForceRetainedEdgeCount
        let passiveEdgeCount = 96
        let passiveNodes = (0..<passiveEdgeCount).flatMap { index in
            let x = 1_000 + Double(index) * 1_000
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
        let incidentNodes = (0..<(limit + 3)).map { index in
            CanvasFrameRect(id: "target-\(index)", x: Double(80_000 + index * 120), y: 0, width: 80, height: 80)
        }
        let incidentEdges = (0..<(limit + 3)).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }
        let selected = CanvasEdgeViewportRecord(id: "selected-edge", sourceNodeID: "selected-a", targetNodeID: "selected-b")
        let nodes = passiveNodes + [
            CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moving", x: 70_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-a", x: 71_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-b", x: 71_160, y: 0, width: 80, height: 80)
        ] + incidentNodes
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: [CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "visible-a", targetNodeID: "visible-b")]
                + passiveEdges
                + [selected]
                + incidentEdges
        )

        let plan = CanvasEdgeVisibilityPlanner.plan(
            edgeIndex: index,
            viewport: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            selectedEdgeIDs: ["selected-edge"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: ["moving"],
            visibleObstacleCount: 0,
            visibleCardCount: 0,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: true
        )

        XCTAssertEqual(plan.visibleCandidateCount, 1)
        XCTAssertTrue(plan.diagnostics.forceRetention.usedIncidentAdjacency)
        XCTAssertLessThan(plan.diagnostics.forceRetention.edgeScanCount, passiveEdgeCount)
        XCTAssertEqual(plan.diagnostics.forceRetention.incidentCandidateEdgeCount, limit + 3)
        XCTAssertEqual(plan.diagnostics.forceRetention.droppedIncidentEdgeCount, 3)
        XCTAssertEqual(plan.diagnostics.renderQuery.forcedRequestedCount, 1 + limit)
        XCTAssertTrue(plan.renderEdgeIDs.contains("visible"))
        XCTAssertTrue(plan.renderEdgeIDs.contains("selected-edge"))
        XCTAssertTrue(plan.renderEdgeIDs.contains("incident-\(limit - 1)"))
        XCTAssertFalse(plan.renderEdgeIDs.contains("incident-\(limit)"))
        XCTAssertFalse(plan.renderEdgeIDs.contains("passive-0"))
    }

    func testCanvasEdgeVisibilityDiagnosticsExposeBoundedForceRetentionCounts() {
        let limit = CanvasPerformancePolicy.maximumContextEdgesDuringInteraction
        let incidentNodes = (0..<(limit + 5)).map { index in
            CanvasFrameRect(id: "target-\(index)", x: Double(10_000 + index * 120), y: 0, width: 80, height: 80)
        }
        let nodes = [
            CanvasFrameRect(id: "selected-a", x: 8_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "selected-b", x: 8_120, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "transient-a", x: 8_500, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "transient-b", x: 8_620, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moved-a", x: 9_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moved-b", x: 9_120, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moving", x: 9_500, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "passive-a", x: 20_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "passive-b", x: 20_120, y: 0, width: 80, height: 80)
        ] + incidentNodes
        let explicitEdges = [
            CanvasEdgeViewportRecord(id: "selected-edge", sourceNodeID: "selected-a", targetNodeID: "selected-b"),
            CanvasEdgeViewportRecord(id: "transient-edge", sourceNodeID: "transient-a", targetNodeID: "transient-b"),
            CanvasEdgeViewportRecord(id: "moved-control-edge", sourceNodeID: "moved-a", targetNodeID: "moved-b")
        ]
        let incidentEdges = (0..<(limit + 5)).map { index in
            CanvasEdgeViewportRecord(id: "incident-\(index)", sourceNodeID: "moving", targetNodeID: "target-\(index)")
        }
        let passiveEdge = CanvasEdgeViewportRecord(id: "passive", sourceNodeID: "passive-a", targetNodeID: "passive-b")

        let plan = CanvasEdgeVisibilityPlanner.plan(
            nodes: nodes,
            edges: explicitEdges + incidentEdges + [passiveEdge],
            viewport: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            selectedEdgeIDs: ["selected-edge"],
            transientControlEdgeIDs: ["transient-edge"],
            movedControlEdgeIDs: ["moved-control-edge"],
            movingNodeIDs: ["moving"],
            visibleObstacleCount: 0,
            visibleCardCount: 0,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: true
        )

        XCTAssertEqual(plan.diagnostics.forceRetention.explicitActiveEdgeCount, 3)
        XCTAssertEqual(plan.diagnostics.forceRetention.incidentEdgeCount, limit)
        XCTAssertEqual(plan.diagnostics.forceRetention.droppedIncidentEdgeCount, 5)
        XCTAssertEqual(plan.diagnostics.forceRetention.maximumIncidentEdgeCount, limit)
        XCTAssertEqual(plan.diagnostics.forceRetainedEdgeCount, 3 + limit)
        XCTAssertEqual(plan.diagnostics.renderQuery.forcedRequestedCount, 3 + limit)
        XCTAssertEqual(plan.diagnostics.renderQuery.forcedRetentionCount, 3 + limit)
    }

    func testCanvasEdgeForceRetentionDiagnosticsEncodeAggregateFieldsOnly() throws {
        let sensitiveEdgeID = "card-title Quarterly Plan /Users/joshua/secret.md https://example.com?q=token"
        let sensitiveMovingNodeID = "note-text Ship roadmap snippet command rm -rf"
        let sensitiveTargetNodeID = "workspace-content api-key resource path"
        let result = CanvasEdgeForceRetentionPolicy.forceRetainedEdgeIDs(
            in: [
                CanvasEdgeViewportRecord(
                    id: sensitiveEdgeID,
                    sourceNodeID: sensitiveMovingNodeID,
                    targetNodeID: sensitiveTargetNodeID
                ),
                CanvasEdgeViewportRecord(
                    id: "dropped incident raw edge id",
                    sourceNodeID: sensitiveMovingNodeID,
                    targetNodeID: "raw-node-id"
                )
            ],
            selectedEdgeIDs: [sensitiveEdgeID],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: [sensitiveMovingNodeID],
            maximumIncidentEdgeCount: 1
        )
        let diagnostics = result.diagnostics

        let allowedFields: Set<String> = [
            "explicitActiveEdgeCount",
            "incidentEdgeCount",
            "droppedIncidentEdgeCount",
            "maximumIncidentEdgeCount",
            "incidentCandidateEdgeCount",
            "edgeScanCount",
            "adjacencyLookupNodeCount",
            "usedIncidentAdjacency"
        ]
        XCTAssertEqual(Set(Mirror(reflecting: diagnostics).children.compactMap(\.label)), allowedFields)

        let encoded = try JSONEncoder().encode(diagnostics)
        let encodedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(Set(encodedObject.keys), allowedFields)
        XCTAssertEqual(encodedObject["explicitActiveEdgeCount"] as? Int, 1)
        XCTAssertEqual(encodedObject["incidentEdgeCount"] as? Int, 1)
        XCTAssertEqual(encodedObject["droppedIncidentEdgeCount"] as? Int, 0)
        XCTAssertEqual(encodedObject["maximumIncidentEdgeCount"] as? Int, 1)
        XCTAssertEqual(encodedObject["incidentCandidateEdgeCount"] as? Int, 1)
        XCTAssertEqual(encodedObject["edgeScanCount"] as? Int, 2)
        XCTAssertEqual(encodedObject["adjacencyLookupNodeCount"] as? Int, 0)
        XCTAssertEqual(encodedObject["usedIncidentAdjacency"] as? Bool, false)

        let encodedText = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        for forbiddenText in [
            sensitiveEdgeID,
            sensitiveMovingNodeID,
            sensitiveTargetNodeID,
            "dropped incident raw edge id",
            "raw-node-id",
            "/Users/",
            "https://",
            "rm -rf",
            "api-key"
        ] {
            XCTAssertFalse(
                encodedText.localizedCaseInsensitiveContains(forbiddenText),
                "Force-retention diagnostics should not encode raw workspace content or identifiers: \(forbiddenText)"
            )
        }
    }

    func testCanvasFinalEdgeRenderPolicyKeepsPlannerForcedEdgesInFinalSegmentStage() {
        let nodes = [
            CanvasFrameRect(id: "visible-a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "visible-b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "transient-a", x: 8_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "transient-b", x: 8_160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moved-a", x: 9_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moved-b", x: 9_160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "moving-node", x: 10_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "incident-target", x: 10_160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "passive-a", x: 11_000, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "passive-b", x: 11_160, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "visible-a", targetNodeID: "visible-b"),
            CanvasEdgeViewportRecord(id: "transient", sourceNodeID: "transient-a", targetNodeID: "transient-b"),
            CanvasEdgeViewportRecord(id: "moved", sourceNodeID: "moved-a", targetNodeID: "moved-b"),
            CanvasEdgeViewportRecord(id: "incident", sourceNodeID: "moving-node", targetNodeID: "incident-target"),
            CanvasEdgeViewportRecord(id: "passive", sourceNodeID: "passive-a", targetNodeID: "passive-b")
        ]

        let plan = CanvasEdgeVisibilityPlanner.plan(
            nodes: nodes,
            edges: edges,
            viewport: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            selectedEdgeIDs: [],
            transientControlEdgeIDs: ["transient"],
            movedControlEdgeIDs: ["moved"],
            movingNodeIDs: ["moving-node"],
            visibleObstacleCount: 0,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: true
        )

        let potentiallyVisibleEdgeIDs: Set<String> = ["visible"]
        let includedEdgeIDs = plan.renderEdgeIDs.filter { edgeID in
            CanvasFinalEdgeRenderPolicy.shouldIncludeCandidateEdge(
                edgeID: edgeID,
                selectedEdgeIDs: [],
                forceRetainedEdgeIDs: plan.forceRetainedEdgeIDs,
                isPotentiallyVisible: potentiallyVisibleEdgeIDs.contains(edgeID)
            )
        }
        let segmentVisibleEdgeIDs: Set<String> = ["visible"]
        let retainedEdgeIDs = includedEdgeIDs.filter { edgeID in
            CanvasFinalEdgeRenderPolicy.shouldKeepSegment(
                edgeID: edgeID,
                selectedEdgeIDs: [],
                forceRetainedEdgeIDs: plan.forceRetainedEdgeIDs,
                isSegmentVisible: segmentVisibleEdgeIDs.contains(edgeID)
            )
        }

        XCTAssertEqual(includedEdgeIDs, ["visible", "transient", "moved", "incident"])
        XCTAssertEqual(retainedEdgeIDs, ["visible", "transient", "moved", "incident"])
        XCTAssertFalse(CanvasFinalEdgeRenderPolicy.shouldIncludeCandidateEdge(
            edgeID: "passive",
            selectedEdgeIDs: [],
            forceRetainedEdgeIDs: plan.forceRetainedEdgeIDs,
            isPotentiallyVisible: false
        ))
    }

    func testCanvasEdgeVisibilityPlannerPreservesInputOrderDeduplicatesAndDropsDanglingForcedEdges() {
        let nodes = [
            CanvasFrameRect(id: "a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "b", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "c", x: 320, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "second", sourceNodeID: "b", targetNodeID: "c"),
            CanvasEdgeViewportRecord(id: "first", sourceNodeID: "a", targetNodeID: "b"),
            CanvasEdgeViewportRecord(id: "second", sourceNodeID: "a", targetNodeID: "c"),
            CanvasEdgeViewportRecord(id: "dangling", sourceNodeID: "a", targetNodeID: "missing")
        ]

        let plan = CanvasEdgeVisibilityPlanner.plan(
            nodes: nodes,
            edges: edges,
            viewport: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 500, height: 160),
            overscan: 0,
            selectedEdgeIDs: ["dangling"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: [],
            visibleObstacleCount: 0,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        )

        XCTAssertEqual(plan.renderEdgeIDs, ["second", "first"])
        XCTAssertTrue(plan.forceRetainedEdgeIDs.isEmpty)
        XCTAssertEqual(plan.diagnostics.index.totalEdgeCount, 4)
        XCTAssertEqual(plan.diagnostics.index.indexedEdgeCount, 2)
        XCTAssertEqual(plan.diagnostics.index.duplicateEdgeCount, 1)
        XCTAssertEqual(plan.diagnostics.index.droppedDanglingEdgeCount, 1)
    }

    func testCanvasEdgeVisibilityPlannerDropsDanglingForcedEdgeWithQueryDiagnostics() {
        let nodes = [
            CanvasFrameRect(id: "a", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "b", x: 160, y: 0, width: 80, height: 80)
        ]
        let index = CanvasEdgeViewportIndex(
            nodes: nodes,
            edges: [
                CanvasEdgeViewportRecord(id: "visible", sourceNodeID: "a", targetNodeID: "b"),
                CanvasEdgeViewportRecord(id: "dangling", sourceNodeID: "a", targetNodeID: "missing")
            ],
            bucketSize: 128
        )

        let plan = CanvasEdgeVisibilityPlanner.plan(
            edgeIndex: index,
            viewport: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            forcedEdgeIDs: ["dangling"],
            visibleObstacleCount: 0,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        )

        XCTAssertEqual(plan.renderEdgeIDs, ["visible"])
        XCTAssertTrue(plan.forceRetainedEdgeIDs.isEmpty)
        XCTAssertEqual(plan.diagnostics.index.droppedDanglingEdgeCount, 1)
        XCTAssertEqual(plan.diagnostics.renderQuery.forcedRequestedCount, 1)
        XCTAssertEqual(plan.diagnostics.renderQuery.forcedValidCount, 0)
        XCTAssertEqual(plan.diagnostics.renderQuery.forcedInvalidCount, 1)
        XCTAssertEqual(plan.diagnostics.renderQuery.forcedRetentionCount, 0)
    }

    func testCanvasEdgeVisibilityPlannerUsesLaterValidDuplicateAfterDanglingFirstOccurrence() {
        let nodes = [
            CanvasFrameRect(id: "source", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "target", x: 160, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "recover", sourceNodeID: "source", targetNodeID: "missing"),
            CanvasEdgeViewportRecord(id: "recover", sourceNodeID: "source", targetNodeID: "target")
        ]

        let plan = CanvasEdgeVisibilityPlanner.plan(
            nodes: nodes,
            edges: edges,
            viewport: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            selectedEdgeIDs: [],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: [],
            visibleObstacleCount: 0,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        )

        XCTAssertEqual(plan.renderEdgeIDs, ["recover"])
        XCTAssertTrue(plan.forceRetainedEdgeIDs.isEmpty)
        XCTAssertEqual(plan.diagnostics.index.totalEdgeCount, 2)
        XCTAssertEqual(plan.diagnostics.index.indexedEdgeCount, 1)
        XCTAssertEqual(plan.diagnostics.index.duplicateEdgeCount, 0)
        XCTAssertEqual(plan.diagnostics.index.droppedDanglingEdgeCount, 1)
    }

    func testCanvasEdgeVisibilityPlannerUsesLaterValidDuplicateAfterInvalidGeometryFirstOccurrence() {
        let nodes = [
            CanvasFrameRect(id: "source", x: 0, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "target", x: 160, y: 0, width: 80, height: 80),
            CanvasFrameRect(id: "invalid", x: .nan, y: 0, width: 80, height: 80)
        ]
        let edges = [
            CanvasEdgeViewportRecord(id: "recover", sourceNodeID: "invalid", targetNodeID: "target"),
            CanvasEdgeViewportRecord(id: "recover", sourceNodeID: "source", targetNodeID: "target")
        ]

        let plan = CanvasEdgeVisibilityPlanner.plan(
            nodes: nodes,
            edges: edges,
            viewport: CanvasFrameRect(id: "viewport", x: -20, y: -20, width: 320, height: 160),
            overscan: 0,
            selectedEdgeIDs: [],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            movingNodeIDs: [],
            visibleObstacleCount: 0,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        )

        XCTAssertEqual(plan.renderEdgeIDs, ["recover"])
        XCTAssertTrue(plan.forceRetainedEdgeIDs.isEmpty)
        XCTAssertEqual(plan.diagnostics.index.indexedEdgeCount, 1)
        XCTAssertEqual(plan.diagnostics.index.duplicateEdgeCount, 0)
        XCTAssertEqual(plan.diagnostics.index.droppedInvalidGeometryEdgeCount, 1)
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

    func testCanvasEdgeAnimationPolicyMapsFrameRatePreferenceToTimelineIntervals() {
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.timelineMinimumInterval(frameRate: .reduced),
            1.0 / 15.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.timelineMinimumInterval(frameRate: .balanced),
            1.0 / 30.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.timelineMinimumInterval(frameRate: .smooth),
            1.0 / 60.0,
            accuracy: 0.0001
        )
    }

    func testCanvasEdgeAnimationPolicyPublishesLoadAdaptedFrameRateAndStopsTimelinePastCaps() {
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveFrameRate(
                visibleEdgeCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleEdgeCount,
                visibleCardCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleCardCount,
                routedPointCount: CanvasPerformancePolicy.maximumSmoothAnimatedRoutePointCount,
                isInteracting: false
            ),
            .smooth
        )
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveFrameRate(
                visibleEdgeCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleEdgeCount + 1,
                visibleCardCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleCardCount,
                routedPointCount: CanvasPerformancePolicy.maximumSmoothAnimatedRoutePointCount,
                isInteracting: false
            ),
            .balanced
        )
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveFrameRate(
                visibleEdgeCount: CanvasPerformancePolicy.maximumBalancedAnimatedVisibleEdgeCount + 1,
                visibleCardCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleCardCount,
                routedPointCount: CanvasPerformancePolicy.maximumSmoothAnimatedRoutePointCount,
                isInteracting: false
            ),
            .reduced
        )
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveFrameRate(
                visibleEdgeCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleEdgeCount,
                visibleCardCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleCardCount,
                routedPointCount: CanvasPerformancePolicy.maximumSmoothAnimatedRoutePointCount,
                isInteracting: true
            ),
            .reduced
        )
        XCTAssertFalse(CanvasEdgeAnimationInteractionPolicy.shouldDeferGlowAnimation(
            isNodeDragging: false,
            isViewportMoving: true,
            isZooming: false,
            isResizing: false,
            isEdgeControlDragging: false
        ))
        XCTAssertFalse(CanvasEdgeAnimationInteractionPolicy.shouldDeferGlowAnimation(
            isNodeDragging: false,
            isViewportMoving: false,
            isZooming: true,
            isResizing: false,
            isEdgeControlDragging: false
        ))
        XCTAssertTrue(CanvasEdgeAnimationPolicy.effectiveTimelinePlan(
            preferredFrameRate: .smooth,
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleEdgeCount,
            visibleCardCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleCardCount,
            routedPointCount: CanvasPerformancePolicy.maximumSmoothAnimatedRoutePointCount,
            zoom: 1,
            baselineZoom: 1,
            isInteracting: CanvasEdgeAnimationInteractionPolicy.shouldDeferGlowAnimation(
                isNodeDragging: false,
                isViewportMoving: true,
                isZooming: true,
                isResizing: false,
                isEdgeControlDragging: false
            )
        ).shouldAnimate)
        XCTAssertTrue(CanvasEdgeAnimationInteractionPolicy.shouldDeferGlowAnimation(
            isNodeDragging: true,
            isViewportMoving: false,
            isZooming: false,
            isResizing: false,
            isEdgeControlDragging: false
        ))
        XCTAssertNil(CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
            preferredFrameRate: .smooth,
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: CanvasPerformancePolicy.maximumAnimatedVisibleEdgeCount + 1,
            visibleCardCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleCardCount,
            routedPointCount: CanvasPerformancePolicy.maximumSmoothAnimatedRoutePointCount,
            zoom: 1,
            baselineZoom: 1,
            isInteracting: false
        ))
        XCTAssertNil(CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
            preferredFrameRate: .smooth,
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleEdgeCount,
            visibleCardCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleCardCount,
            routedPointCount: CanvasPerformancePolicy.maximumSmoothAnimatedRoutePointCount,
            zoom: 1,
            baselineZoom: 1,
            isInteracting: true
        ))
    }

    func testCanvasEdgeAnimationPolicyKeepsFrameRatePreferenceAsUpperBound() {
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                preferredFrameRate: .smooth,
                visibleEdgeCount: 1,
                visibleCardCount: 1,
                routedPointCount: 0,
                isInteracting: false
            ),
            1.0 / 60.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                preferredFrameRate: .balanced,
                visibleEdgeCount: 1,
                visibleCardCount: 1,
                routedPointCount: 0,
                isInteracting: false
            ),
            1.0 / 30.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                preferredFrameRate: .reduced,
                visibleEdgeCount: 1,
                visibleCardCount: 1,
                routedPointCount: 0,
                isInteracting: false
            ),
            1.0 / 15.0,
            accuracy: 0.0001
        )
    }

    func testCanvasEdgeAnimationPolicyDegradesSmoothTimelineUnderVisibleLoad() {
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                preferredFrameRate: .smooth,
                visibleEdgeCount: CanvasPerformancePolicy.maximumSmoothAnimatedVisibleEdgeCount + 1,
                visibleCardCount: 1,
                routedPointCount: 0,
                isInteracting: false
            ),
            1.0 / 30.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                preferredFrameRate: .smooth,
                visibleEdgeCount: CanvasPerformancePolicy.maximumBalancedAnimatedVisibleEdgeCount + 1,
                visibleCardCount: 1,
                routedPointCount: 0,
                isInteracting: false
            ),
            1.0 / 15.0,
            accuracy: 0.0001
        )
    }

    func testCanvasEdgeAnimationPolicyDoesNotUpgradeReducedPreferenceWhenLoadIsLight() {
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                preferredFrameRate: .reduced,
                visibleEdgeCount: CanvasPerformancePolicy.maximumAnimatedVisibleEdgeCount,
                visibleCardCount: CanvasPerformancePolicy.maximumAnimatedVisibleCardCount,
                routedPointCount: CanvasPerformancePolicy.maximumAnimatedRoutePointCount,
                isInteracting: false
            ),
            1.0 / 15.0,
            accuracy: 0.0001
        )
    }

    func testCanvasEdgeAnimationPolicyDegradesWhenAnyLoadDimensionIsHigh() {
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                preferredFrameRate: .smooth,
                visibleEdgeCount: 1,
                visibleCardCount: CanvasPerformancePolicy.maximumAnimatedVisibleCardCount,
                routedPointCount: 0,
                isInteracting: false
            ),
            1.0 / 15.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                preferredFrameRate: .smooth,
                visibleEdgeCount: 1,
                visibleCardCount: 1,
                routedPointCount: CanvasPerformancePolicy.maximumAnimatedRoutePointCount,
                isInteracting: false
            ),
            1.0 / 15.0,
            accuracy: 0.0001
        )
    }

    func testCanvasEdgeAnimationTimelinePlanCapsBlueFlowStrokeWorkPerSecond() throws {
        let denseAllowedPlan = CanvasEdgeAnimationPolicy.effectiveTimelinePlan(
            preferredFrameRate: .smooth,
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: CanvasPerformancePolicy.maximumAnimatedVisibleEdgeCount,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        )

        XCTAssertTrue(denseAllowedPlan.shouldAnimate)
        XCTAssertEqual(try XCTUnwrap(denseAllowedPlan.minimumInterval), 1.0 / 15.0, accuracy: 0.0001)
        XCTAssertEqual(denseAllowedPlan.effectiveFrameRate, .reduced)
        XCTAssertEqual(denseAllowedPlan.reason, .withinBudget)
        XCTAssertLessThanOrEqual(
            denseAllowedPlan.estimatedFlowStrokePaintsPerSecond,
            CanvasPerformancePolicy.maximumAnimatedFlowStrokePaintsPerSecond
        )

        let overBudgetPlan = CanvasEdgeAnimationPolicy.effectiveTimelinePlan(
            preferredFrameRate: .smooth,
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: CanvasPerformancePolicy.maximumAnimatedVisibleEdgeCount + 1,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        )

        XCTAssertFalse(overBudgetPlan.shouldAnimate)
        XCTAssertNil(overBudgetPlan.minimumInterval)
        XCTAssertNil(overBudgetPlan.effectiveFrameRate)
        XCTAssertEqual(overBudgetPlan.reason, .tooManyVisibleEdges)
        XCTAssertEqual(overBudgetPlan.estimatedFlowStrokePaintsPerSecond, 0)
    }

    func testCanvasEdgeAnimationPolicyTreatsNegativeLoadAsZero() {
        XCTAssertEqual(
            CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                preferredFrameRate: .smooth,
                visibleEdgeCount: -20,
                visibleCardCount: -4,
                routedPointCount: -100,
                isInteracting: false
            ),
            1.0 / 60.0,
            accuracy: 0.0001
        )
    }

    func testCanvasEdgeAnimationPolicyRejectsNegativeLoadForVisibleTimelineAdmission() {
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateVisibleEdges(
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: -1,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        ))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateVisibleEdges(
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: 1,
            visibleCardCount: -1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        ))
        XCTAssertFalse(CanvasEdgeAnimationPolicy.shouldAnimateVisibleEdges(
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: 1,
            visibleCardCount: 1,
            routedPointCount: -1,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        ))
        XCTAssertNil(CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
            preferredFrameRate: .smooth,
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: 1,
            visibleCardCount: -1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        ))
        XCTAssertNil(CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
            preferredFrameRate: .smooth,
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: 1,
            visibleCardCount: 1,
            routedPointCount: -1,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        ))
    }

    func testCanvasEdgeAnimationPolicyEffectiveTimelineReturnsNilWhenAnimationGuardsFail() throws {
        let allowed = CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
            preferredFrameRate: .smooth,
            theme: "blue",
            animationsEnabled: true,
            reduceMotion: false,
            visibleEdgeCount: 1,
            visibleCardCount: 1,
            routedPointCount: 0,
            zoom: 0.35,
            baselineZoom: 0.35,
            isInteracting: false
        )
        XCTAssertEqual(try XCTUnwrap(allowed), 1.0 / 60.0, accuracy: 0.0001)

        let blockedCases: [(name: String, interval: Double?)] = [
            (
                "animations disabled",
                CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                    preferredFrameRate: .smooth,
                    theme: "blue",
                    animationsEnabled: false,
                    reduceMotion: false,
                    visibleEdgeCount: 1,
                    visibleCardCount: 1,
                    routedPointCount: 0,
                    zoom: 0.35,
                    baselineZoom: 0.35,
                    isInteracting: false
                )
            ),
            (
                "reduce motion",
                CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                    preferredFrameRate: .smooth,
                    theme: "blue",
                    animationsEnabled: true,
                    reduceMotion: true,
                    visibleEdgeCount: 1,
                    visibleCardCount: 1,
                    routedPointCount: 0,
                    zoom: 0.35,
                    baselineZoom: 0.35,
                    isInteracting: false
                )
            ),
            (
                "theme off",
                CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                    preferredFrameRate: .smooth,
                    theme: "off",
                    animationsEnabled: true,
                    reduceMotion: false,
                    visibleEdgeCount: 1,
                    visibleCardCount: 1,
                    routedPointCount: 0,
                    zoom: 0.35,
                    baselineZoom: 0.35,
                    isInteracting: false
                )
            ),
            (
                "no visible edges",
                CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                    preferredFrameRate: .smooth,
                    theme: "blue",
                    animationsEnabled: true,
                    reduceMotion: false,
                    visibleEdgeCount: 0,
                    visibleCardCount: 1,
                    routedPointCount: 0,
                    zoom: 0.35,
                    baselineZoom: 0.35,
                    isInteracting: false
                )
            ),
            (
                "too many edges",
                CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                    preferredFrameRate: .smooth,
                    theme: "blue",
                    animationsEnabled: true,
                    reduceMotion: false,
                    visibleEdgeCount: CanvasPerformancePolicy.maximumAnimatedVisibleEdgeCount + 1,
                    visibleCardCount: 1,
                    routedPointCount: 0,
                    zoom: 0.35,
                    baselineZoom: 0.35,
                    isInteracting: false
                )
            ),
            (
                "too many cards",
                CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                    preferredFrameRate: .smooth,
                    theme: "blue",
                    animationsEnabled: true,
                    reduceMotion: false,
                    visibleEdgeCount: 1,
                    visibleCardCount: CanvasPerformancePolicy.maximumAnimatedVisibleCardCount + 1,
                    routedPointCount: 0,
                    zoom: 0.35,
                    baselineZoom: 0.35,
                    isInteracting: false
                )
            ),
            (
                "too many route points",
                CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                    preferredFrameRate: .smooth,
                    theme: "blue",
                    animationsEnabled: true,
                    reduceMotion: false,
                    visibleEdgeCount: 1,
                    visibleCardCount: 1,
                    routedPointCount: CanvasPerformancePolicy.maximumAnimatedRoutePointCount + 1,
                    zoom: 0.35,
                    baselineZoom: 0.35,
                    isInteracting: false
                )
            ),
            (
                "interacting",
                CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                    preferredFrameRate: .smooth,
                    theme: "blue",
                    animationsEnabled: true,
                    reduceMotion: false,
                    visibleEdgeCount: 1,
                    visibleCardCount: 1,
                    routedPointCount: 0,
                    zoom: 0.35,
                    baselineZoom: 0.35,
                    isInteracting: true
                )
            ),
            (
                "zoom below baseline",
                CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                    preferredFrameRate: .smooth,
                    theme: "blue",
                    animationsEnabled: true,
                    reduceMotion: false,
                    visibleEdgeCount: 1,
                    visibleCardCount: 1,
                    routedPointCount: 0,
                    zoom: 0.24,
                    baselineZoom: 0.35,
                    isInteracting: false
                )
            ),
            (
                "non-finite zoom",
                CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                    preferredFrameRate: .smooth,
                    theme: "blue",
                    animationsEnabled: true,
                    reduceMotion: false,
                    visibleEdgeCount: 1,
                    visibleCardCount: 1,
                    routedPointCount: 0,
                    zoom: .infinity,
                    baselineZoom: 0.35,
                    isInteracting: false
                )
            ),
            (
                "invalid baseline",
                CanvasEdgeAnimationPolicy.effectiveTimelineMinimumInterval(
                    preferredFrameRate: .smooth,
                    theme: "blue",
                    animationsEnabled: true,
                    reduceMotion: false,
                    visibleEdgeCount: 1,
                    visibleCardCount: 1,
                    routedPointCount: 0,
                    zoom: 0.35,
                    baselineZoom: 0,
                    isInteracting: false
                )
            )
        ]

        for blockedCase in blockedCases {
            XCTAssertNil(blockedCase.interval, blockedCase.name)
        }
    }

    func testCanvasZoomCommitPolicyMapsResponsivenessToCommitDelays() {
        XCTAssertEqual(
            CanvasZoomCommitPolicy.commitDelayNanos(cadence: .responsive),
            120_000_000
        )
        XCTAssertEqual(
            CanvasZoomCommitPolicy.commitDelayNanos(cadence: .balanced),
            250_000_000
        )
        XCTAssertEqual(
            CanvasZoomCommitPolicy.commitDelayNanos(cadence: .relaxed),
            450_000_000
        )
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

    func testCanvasCardRenderDetailPolicyRejectsNegativePassiveVisibleCount() {
        XCTAssertFalse(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.35,
            baselineZoom: 0.35,
            visibleCardCount: -1,
            isInteracting: false,
            isSelected: false,
            isEditing: false
        ))
        XCTAssertTrue(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.24,
            baselineZoom: 0.35,
            visibleCardCount: -1,
            isInteracting: true,
            isSelected: true,
            isEditing: false
        ))
        XCTAssertTrue(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.24,
            baselineZoom: 0.35,
            visibleCardCount: -1,
            isInteracting: true,
            isSelected: false,
            isEditing: true
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

    func testCanvasCardDetailInteractionPolicyKeepsPeerDetailsDuringZoomOnly() {
        let sparseVisibleCount = 24
        let shouldReduceDetails = CanvasCardDetailInteractionPolicy.shouldReducePeerDetails(
            isNodeDragging: false,
            isViewportMoving: false,
            isZooming: true,
            isResizing: false,
            isEdgeControlDragging: false,
            visibleCardCount: sparseVisibleCount
        )

        XCTAssertFalse(shouldReduceDetails)
        XCTAssertTrue(CanvasCardRenderDetailPolicy.shouldRenderDetails(
            zoom: 0.35,
            baselineZoom: 0.35,
            visibleCardCount: sparseVisibleCount,
            isInteracting: shouldReduceDetails,
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

    func testCanvasResizeHandlePolicyRejectsNegativePassiveVisibleCount() {
        XCTAssertFalse(CanvasResizeHandleVisibilityPolicy.shouldShow(
            isSelected: false,
            isDragging: false,
            isResizing: false,
            isInteracting: false,
            visibleNodeCount: -1
        ))
        XCTAssertTrue(CanvasResizeHandleVisibilityPolicy.shouldShow(
            isSelected: true,
            isDragging: false,
            isResizing: false,
            isInteracting: true,
            visibleNodeCount: -1
        ))
        XCTAssertTrue(CanvasResizeHandleVisibilityPolicy.shouldShow(
            isSelected: false,
            isDragging: true,
            isResizing: false,
            isInteracting: true,
            visibleNodeCount: -1
        ))
        XCTAssertTrue(CanvasResizeHandleVisibilityPolicy.shouldShow(
            isSelected: false,
            isDragging: false,
            isResizing: true,
            isInteracting: true,
            visibleNodeCount: -1
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

    func testCanvasEdgeControlHandlePolicyRejectsNegativePassiveEdgeCount() {
        XCTAssertFalse(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: false,
            hasStoredControlPoint: false,
            isLocked: false,
            isInteracting: false,
            edgeCount: -1,
            zoom: 0.35
        ))
        XCTAssertTrue(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: true,
            hasTransientControlPoint: false,
            hasStoredControlPoint: false,
            isLocked: false,
            isInteracting: true,
            edgeCount: -1,
            zoom: 0.1
        ))
        XCTAssertTrue(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: true,
            hasStoredControlPoint: false,
            isLocked: false,
            isInteracting: true,
            edgeCount: -1,
            zoom: 0.1
        ))
        XCTAssertTrue(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: false,
            hasStoredControlPoint: true,
            isLocked: false,
            isInteracting: false,
            edgeCount: -1,
            zoom: 0.1
        ))
        XCTAssertTrue(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: false,
            hasStoredControlPoint: false,
            isLocked: true,
            isInteracting: false,
            edgeCount: -1,
            zoom: 0.1
        ))
        XCTAssertTrue(CanvasEdgeControlHandlePolicy.shouldShow(
            isSelected: false,
            hasTransientControlPoint: false,
            hasStoredControlPoint: false,
            isLocked: false,
            isInteracting: true,
            isDragging: true,
            edgeCount: -1,
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

    func testCanvasNodeStateReconciliationPlanDropsAllMissingNodeTransientState() {
        let plan = CanvasNodeStateReconciliation.plan(
            selectedNodeIDs: ["kept", "deleted"],
            editingNodeIDs: ["editing-kept", "editing-deleted"],
            connectionSourceNodeId: "connection-deleted",
            primaryDraggedNodeId: "drag-kept",
            suppressedTapNodeId: "tap-deleted",
            resizingNodeId: "resize-deleted",
            nodeDragStartIDs: ["drag-kept", "drag-deleted"],
            nodeDragSnapshotIDs: ["drag-kept", "drag-deleted"],
            transientNodeOffsetIDs: ["offset-kept", "offset-deleted"],
            resizeStartSizeIDs: ["resize-kept", "resize-deleted"],
            transientNodeSizeIDs: ["resize-kept", "resize-deleted"],
            existingNodeIDs: ["kept", "editing-kept", "drag-kept", "offset-kept", "resize-kept"]
        )

        XCTAssertEqual(plan.selectedNodeIDs, ["kept"])
        XCTAssertEqual(plan.editingNodeIDs, ["editing-kept"])
        XCTAssertNil(plan.connectionSourceNodeId)
        XCTAssertEqual(plan.primaryDraggedNodeId, "drag-kept")
        XCTAssertNil(plan.suppressedTapNodeId)
        XCTAssertNil(plan.resizingNodeId)
        XCTAssertEqual(plan.nodeDragStartIDs, ["drag-kept"])
        XCTAssertEqual(plan.nodeDragSnapshotIDs, ["drag-kept"])
        XCTAssertEqual(plan.transientNodeOffsetIDs, ["offset-kept"])
        XCTAssertEqual(plan.resizeStartSizeIDs, ["resize-kept"])
        XCTAssertEqual(plan.transientNodeSizeIDs, ["resize-kept"])
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

    func testCanvasActiveEdgeRenderPolicyRejectsNegativePassiveVisibleEdgeCount() {
        XCTAssertFalse(CanvasActiveEdgeRenderPolicy.shouldRenderEdge(
            edgeID: "unrelated",
            sourceNodeID: "a",
            targetNodeID: "b",
            movingNodeIDs: ["moving"],
            selectedEdgeIDs: [],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            isGeometryInteracting: true,
            visibleEdgeCount: -1
        ))
        XCTAssertTrue(CanvasActiveEdgeRenderPolicy.shouldRenderEdge(
            edgeID: "unrelated",
            sourceNodeID: "a",
            targetNodeID: "b",
            movingNodeIDs: ["moving"],
            selectedEdgeIDs: [],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            isGeometryInteracting: false,
            visibleEdgeCount: -1
        ))
        XCTAssertTrue(CanvasActiveEdgeRenderPolicy.shouldRenderEdge(
            edgeID: "incident",
            sourceNodeID: "moving",
            targetNodeID: "b",
            movingNodeIDs: ["moving"],
            selectedEdgeIDs: [],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            isGeometryInteracting: true,
            visibleEdgeCount: -1
        ))
        XCTAssertTrue(CanvasActiveEdgeRenderPolicy.shouldRenderEdge(
            edgeID: "selected",
            sourceNodeID: "a",
            targetNodeID: "b",
            movingNodeIDs: ["moving"],
            selectedEdgeIDs: ["selected"],
            transientControlEdgeIDs: [],
            movedControlEdgeIDs: [],
            isGeometryInteracting: true,
            visibleEdgeCount: -1
        ))
    }

    func testCanvasFinalEdgeRenderPolicyKeepsForcedEdgesThroughIncludeAndSegmentFilters() {
        let selectedEdgeIDs: Set<String> = ["selected"]
        let forceRetainedEdgeIDs: Set<String> = ["transient", "moved", "incident"]

        XCTAssertTrue(CanvasFinalEdgeRenderPolicy.shouldIncludeCandidateEdge(
            edgeID: "selected",
            selectedEdgeIDs: selectedEdgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            isPotentiallyVisible: false
        ))
        XCTAssertTrue(CanvasFinalEdgeRenderPolicy.shouldIncludeCandidateEdge(
            edgeID: "transient",
            selectedEdgeIDs: selectedEdgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            isPotentiallyVisible: false
        ))
        XCTAssertTrue(CanvasFinalEdgeRenderPolicy.shouldIncludeCandidateEdge(
            edgeID: "visible-passive",
            selectedEdgeIDs: selectedEdgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            isPotentiallyVisible: true
        ))
        XCTAssertFalse(CanvasFinalEdgeRenderPolicy.shouldIncludeCandidateEdge(
            edgeID: "offscreen-passive",
            selectedEdgeIDs: selectedEdgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            isPotentiallyVisible: false
        ))

        XCTAssertTrue(CanvasFinalEdgeRenderPolicy.shouldKeepSegment(
            edgeID: "incident",
            selectedEdgeIDs: selectedEdgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            isSegmentVisible: false
        ))
        XCTAssertTrue(CanvasFinalEdgeRenderPolicy.shouldKeepSegment(
            edgeID: "visible-passive",
            selectedEdgeIDs: selectedEdgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            isSegmentVisible: true
        ))
        XCTAssertFalse(CanvasFinalEdgeRenderPolicy.shouldKeepSegment(
            edgeID: "offscreen-passive",
            selectedEdgeIDs: selectedEdgeIDs,
            forceRetainedEdgeIDs: forceRetainedEdgeIDs,
            isSegmentVisible: false
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

    func testCanvasEdgeArrowHeadsRenderAboveCardChrome() {
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
        let editingCard = CanvasNodeVisualZIndexPolicy.zIndex(
            storedZIndex: 0,
            isFrame: false,
            isSelected: false,
            isDragging: false,
            isResizing: false,
            isConnectionSource: false,
            isEditing: true
        )

        XCTAssertLessThan(CanvasEdgeLayerZIndexPolicy.strokeLayer, idleCard)
        XCTAssertGreaterThan(CanvasEdgeLayerZIndexPolicy.arrowHeadLayer, selectedCard)
        XCTAssertGreaterThan(CanvasEdgeLayerZIndexPolicy.arrowHeadLayer, editingCard)
    }

    func testCanvasEdgeStrokeLayerRendersAboveInteractiveFramesButBelowCards() {
        let idleCard = CanvasNodeVisualZIndexPolicy.zIndex(
            storedZIndex: 0,
            isFrame: false,
            isSelected: false,
            isDragging: false,
            isResizing: false,
            isConnectionSource: false,
            isEditing: false
        )
        let selectedFrame = CanvasNodeVisualZIndexPolicy.zIndex(
            storedZIndex: 0,
            isFrame: true,
            isSelected: true,
            isDragging: false,
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

        XCTAssertGreaterThan(CanvasEdgeLayerZIndexPolicy.strokeLayer, selectedFrame)
        XCTAssertGreaterThan(CanvasEdgeLayerZIndexPolicy.strokeLayer, draggingFrame)
        XCTAssertLessThan(CanvasEdgeLayerZIndexPolicy.strokeLayer, idleCard)
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

    func testCanvasSideRailLayoutKeepsRightRailContentScrollableAtReadableWidth() {
        XCTAssertEqual(
            CanvasSideRailLayout.rightRailScrollableContentWidth(railWidth: 244),
            244
        )
        XCTAssertEqual(
            CanvasSideRailLayout.rightRailScrollableContentWidth(railWidth: 180),
            244
        )
        XCTAssertEqual(
            CanvasSideRailLayout.rightRailScrollableContentWidth(railWidth: Double.nan),
            244
        )
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

    func testTodoBoardStartupPolicyKeepsTaskPanelClosedWithoutCreatingDefaultGroup() {
        let state = TodoBoardStartupPolicy.initialState(
            defaultPanelOpen: AppPreferenceDefaults.workspaceCanvasTodoPanelDefaultOpen,
            defaultDoneColumnOpen: AppPreferenceDefaults.workspaceCanvasTodoDoneColumnDefaultOpen
        )

        XCTAssertFalse(state.isPanelOpen)
        XCTAssertFalse(state.isDoneColumnOpen)
        XCTAssertFalse(
            TodoBoardDefaultGroupCreationPolicy.shouldCreateDefaultGroup(
                trigger: .workspaceOpen,
                hasUsableGroup: false
            )
        )
        XCTAssertFalse(
            TodoBoardDefaultGroupCreationPolicy.shouldCreateDefaultGroup(
                trigger: .boardAppear,
                hasUsableGroup: false
            )
        )
    }

    func testTodoBoardDefaultGroupCreationPolicyOnlyCreatesForMutatingTaskActions() {
        XCTAssertTrue(
            TodoBoardDefaultGroupCreationPolicy.shouldCreateDefaultGroup(
                trigger: .addTask,
                hasUsableGroup: false
            )
        )
        XCTAssertFalse(
            TodoBoardDefaultGroupCreationPolicy.shouldCreateDefaultGroup(
                trigger: .addTask,
                hasUsableGroup: true
            )
        )
        XCTAssertTrue(
            TodoBoardDefaultGroupCreationPolicy.shouldCreateDefaultGroup(
                trigger: .deleteGroupFallback,
                hasUsableGroup: false
            )
        )
        XCTAssertFalse(
            TodoBoardDefaultGroupCreationPolicy.shouldCreateDefaultGroup(
                trigger: .deleteGroupFallback,
                hasUsableGroup: true
            )
        )
    }

    func testTodoDeletionUndoPolicyRestoresDeletedTask() {
        let plan = TodoDeletionUndoPolicy.restorePlan(deletedTodoId: "todo-a")

        XCTAssertEqual(plan.steps, [.restoreTask(id: "todo-a")])
        XCTAssertEqual(plan.successStatus, "Restored task")
        XCTAssertEqual(TodoDeletionUndoPolicy.actionName, "Delete Task")
    }

    func testTodoGroupDeletionUndoPolicyRestoresGroupBeforeTaskMemberships() {
        let plan = TodoGroupDeletionUndoPolicy.restorePlan(
            deletedGroupId: "group-custom",
            memberships: [
                TodoGroupMembershipUndoRecord(todoId: "todo-a", groupId: "group-custom"),
                TodoGroupMembershipUndoRecord(todoId: "todo-b", groupId: nil)
            ]
        )

        XCTAssertEqual(plan.steps, [
            .restoreGroup(id: "group-custom"),
            .restoreTaskMembership(todoId: "todo-a", groupId: "group-custom"),
            .restoreTaskMembership(todoId: "todo-b", groupId: nil)
        ])
        XCTAssertEqual(plan.successStatus, "Restored group")
        XCTAssertEqual(TodoGroupDeletionUndoPolicy.actionName, "Delete Group")
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

    func testCanvasWebCardCreationPolicyBuildsCardFromBareDomain() throws {
        let draft = try XCTUnwrap(CanvasWebCardCreationPolicy.draft(from: " docs.example.com/path "))

        XCTAssertEqual(draft.title, "docs.example.com")
        XCTAssertEqual(draft.body, "https://docs.example.com/path")
        XCTAssertEqual(draft.objectType, "webURL")
        XCTAssertEqual(draft.objectID, "https://docs.example.com/path")
        XCTAssertEqual(draft.accentColorRaw, "#33D499D1")
    }

    func testCanvasWebCardOpenPolicyAcceptsOnlyValidWebURLs() {
        XCTAssertEqual(
            CanvasWebCardOpenPolicy.openableURL(
                objectType: "webURL",
                objectID: "example.com",
                body: "ignored"
            )?.absoluteString,
            "https://example.com"
        )
        XCTAssertNil(CanvasWebCardOpenPolicy.openableURL(
            objectType: "webURL",
            objectID: "javascript:alert(1)",
            body: "https://safe.example.com"
        ))
        XCTAssertNil(CanvasWebCardOpenPolicy.openableURL(
            objectType: "resourcePin",
            objectID: "https://example.com",
            body: "https://example.com"
        ))
    }

    func testCanvasWebCardAffordancePolicySupportsCopyDetailsConnectionsAndQuickOpen() throws {
        let affordances = try XCTUnwrap(CanvasWebCardAffordancePolicy.affordances(
            objectType: "webURL",
            objectID: "example.com",
            body: "ignored",
            nodeType: "snippet"
        ))

        XCTAssertEqual(affordances.copyValue, "https://example.com")
        XCTAssertEqual(affordances.detailTitle, "Details")
        XCTAssertTrue(affordances.canShowDetails)
        XCTAssertTrue(affordances.canConnect)
        XCTAssertEqual(affordances.quickOpenKind, .webCard)
        XCTAssertNil(CanvasWebCardAffordancePolicy.affordances(
            objectType: "webURL",
            objectID: "javascript:alert(1)",
            body: "https://safe.example.com",
            nodeType: "snippet"
        ))
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

    func testQuickOpenRecordLocationDoesNotChangeSearchResults() {
        let records = [
            QuickOpenRecord(
                id: "workspace",
                kind: .workspace,
                title: "Roadmap",
                subtitle: "",
                location: "Canvas: Alpha / Web Targets"
            ),
            QuickOpenRecord(
                id: "web",
                kind: .webCard,
                title: "Platform",
                subtitle: "https://platform.example.com",
                location: "Canvas: Roadmap / Web Targets"
            )
        ]

        XCTAssertTrue(QuickOpenIndex.results(for: "web targets", in: records).isEmpty)
        XCTAssertEqual(QuickOpenIndex.results(for: "platform", in: records).map(\.id), ["web"])
    }

    func testQuickOpenIndexSearchesRelatedTermsAfterVisibleFields() {
        let records = [
            QuickOpenRecord(id: "title", kind: .resource, title: "Canvas Guide", subtitle: ""),
            QuickOpenRecord(id: "subtitle", kind: .resource, title: "Draft", subtitle: "Canvas folder"),
            QuickOpenRecord(
                id: "related",
                kind: .resource,
                title: "Budget",
                subtitle: "/tmp/budget",
                relatedSearchTerms: ["canvas linked resource", "linked task"]
            )
        ]

        XCTAssertEqual(QuickOpenIndex.results(for: "canvas", in: records).map(\.id), ["title", "subtitle", "related"])
        XCTAssertEqual(QuickOpenIndex.results(for: "linked task", in: records).map(\.id), ["related"])
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

    func testHelpCatalogIncludesRequiredHumanAndAgentTopics() {
        let topics = MindDeskHelpCatalog.defaultTopics
        let ids = Set(topics.map(\.id))

        XCTAssertTrue(ids.contains("settings-defaults"))
        XCTAssertTrue(ids.contains("canvas-performance"))
        XCTAssertTrue(ids.contains("import-export"))
        XCTAssertTrue(ids.contains("agent-readonly-mip"))
        XCTAssertTrue(ids.contains("agent-prompt-workflow"))
        XCTAssertTrue(ids.contains("agent-proposal-review"))
        XCTAssertEqual(ids.count, topics.count)
        XCTAssertTrue(topics.allSatisfy { !$0.anchor.isEmpty })
        XCTAssertEqual(Set(topics.map(\.anchor)).count, topics.count)
    }

    func testHelpTopicReaderPolicyKeepsShortTopicsAsSingleOverviewSection() throws {
        let topic = MindDeskHelpTopic(
            id: "short-topic",
            category: .settings,
            title: "Short Topic",
            summary: "Short summary",
            bodyMarkdown: "Short readable help body.",
            keywords: []
        )

        let sections = MindDeskHelpTopicReaderPolicy.sections(for: topic)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.id, "short-topic-overview")
        XCTAssertEqual(sections.first?.title, "Overview")
        XCTAssertEqual(sections.first?.bodyMarkdown, topic.bodyMarkdown)
    }

    func testHelpTopicReaderPolicySplitsLongTopicsIntoBoundedReadableSections() throws {
        let topic = try XCTUnwrap(
            MindDeskHelpCatalog.defaultTopics.first { $0.id == "canvas-performance" }
        )

        let sections = MindDeskHelpTopicReaderPolicy.sections(for: topic)

        XCTAssertGreaterThan(sections.count, 1)
        XCTAssertEqual(Set(sections.map(\.id)).count, sections.count)
        XCTAssertEqual(sections.first?.title, "Overview")
        XCTAssertTrue(sections.dropFirst().allSatisfy { $0.title.hasPrefix("Details") })
        XCTAssertTrue(
            sections.allSatisfy { $0.bodyMarkdown.count <= MindDeskHelpTopicReaderPolicy.maximumSectionCharacterCount },
            "Reader sections should keep long Help topics scan-friendly."
        )
        XCTAssertEqual(
            sections.map(\.bodyMarkdown).joined(),
            topic.bodyMarkdown
        )
    }

    func testHelpTopicReaderPolicyDoesNotChangeSearchableOrEncodedHelpTopicBody() throws {
        let topic = try XCTUnwrap(
            MindDeskHelpCatalog.defaultTopics.first { $0.id == "agent-prompt-workflow" }
        )

        _ = MindDeskHelpTopicReaderPolicy.sections(for: topic)
        let encoded = try JSONEncoder.minddesk.encode(topic)
        let decoded = try JSONDecoder.minddesk.decode(MindDeskHelpTopic.self, from: encoded)
        let encodedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertEqual(decoded.bodyMarkdown, topic.bodyMarkdown)
        XCTAssertNil(encodedObject["sections"])
        XCTAssertNil(encodedObject["readerSections"])
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "custom guidance", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "agent-prompt-workflow"
        )
    }

    func testHelpTopicReaderSectionsArePresentationOnlyAndExcludedFromMIPHelpTopics() throws {
        XCTAssertTrue(MindDeskHelpTopicReaderPolicy.isPresentationOnly)

        let shortTopic = MindDeskHelpTopic(
            id: "short-reader-topic",
            category: .settings,
            title: "Short Reader Topic",
            summary: "Short summary",
            bodyMarkdown: "Short body remains a single reader overview.",
            keywords: []
        )
        XCTAssertEqual(
            MindDeskHelpTopicReaderPolicy.sections(for: shortTopic),
            [
                MindDeskHelpTopicReaderSection(
                    id: "short-reader-topic-overview",
                    title: "Overview",
                    bodyMarkdown: shortTopic.bodyMarkdown
                )
            ]
        )

        let longBody = (1...24)
            .map { "Detail sentence \($0) keeps reader sections bounded while preserving the raw searchable body text." }
            .joined(separator: " ")
        XCTAssertGreaterThan(longBody.count, MindDeskHelpTopicReaderPolicy.maximumSectionCharacterCount)
        let longTopic = MindDeskHelpTopic(
            id: "long-reader-topic",
            category: .settings,
            title: "Long Reader Topic",
            summary: "Long summary",
            bodyMarkdown: longBody,
            keywords: []
        )

        let longSections = MindDeskHelpTopicReaderPolicy.sections(for: longTopic)

        XCTAssertGreaterThan(longSections.count, 1)
        XCTAssertEqual(longSections.first?.title, "Overview")
        XCTAssertEqual(
            longSections.dropFirst().map(\.title),
            (2...longSections.count).map { "Details \($0)" }
        )
        XCTAssertTrue(longSections.allSatisfy { $0.bodyMarkdown.count <= MindDeskHelpTopicReaderPolicy.maximumSectionCharacterCount })
        XCTAssertEqual(longSections.map(\.bodyMarkdown).joined(), longTopic.bodyMarkdown)

        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 10),
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )
        let package = MindDeskInterchangePackage(
            manifest: manifest,
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let encodedPackageObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder.minddesk.encode(package)) as? [String: Any]
        )
        let encodedHelpTopics = try XCTUnwrap(encodedPackageObject["helpTopics"] as? [[String: Any]])

        XCTAssertEqual(package.helpTopics, MindDeskHelpCatalog.agentReviewPackageTopics)
        XCTAssertTrue(encodedHelpTopics.allSatisfy { $0["bodyMarkdown"] is String })
        XCTAssertTrue(encodedHelpTopics.allSatisfy { $0["readerSections"] == nil })
        XCTAssertTrue(encodedHelpTopics.allSatisfy { $0["sections"] == nil })
        XCTAssertFalse(
            encodedHelpTopics
                .compactMap { $0["id"] as? String }
                .contains { $0.hasSuffix("-overview") || $0.contains("-details-") }
        )
    }

    func testHelpTopicReaderPolicyBoundsUnbrokenLongTokensWithoutBreakingCharacters() {
        let longToken = String(repeating: "A", count: MindDeskHelpTopicReaderPolicy.maximumSectionCharacterCount + 75)
        let topic = MindDeskHelpTopic(
            id: "long-token",
            category: .settings,
            title: "Long Token",
            summary: "Long token",
            bodyMarkdown: longToken,
            keywords: []
        )

        let sections = MindDeskHelpTopicReaderPolicy.sections(for: topic)

        XCTAssertGreaterThan(sections.count, 1)
        XCTAssertTrue(sections.allSatisfy { $0.bodyMarkdown.count <= MindDeskHelpTopicReaderPolicy.maximumSectionCharacterCount })
        XCTAssertEqual(sections.map(\.bodyMarkdown).joined(), longToken)
    }

    func testHelpTopicReaderPolicySplitsCJKSentencesAndPreservesEmojiCharacters() {
        let sentence = "这是一个帮助页面段落，包含中文标点和 emoji 👩‍💻。"
        let body = String(repeating: sentence, count: 80)
        let topic = MindDeskHelpTopic(
            id: "cjk-help",
            category: .settings,
            title: "CJK Help",
            summary: "CJK",
            bodyMarkdown: body,
            keywords: []
        )

        let sections = MindDeskHelpTopicReaderPolicy.sections(for: topic)

        XCTAssertGreaterThan(sections.count, 1)
        XCTAssertTrue(sections.allSatisfy { $0.bodyMarkdown.count <= MindDeskHelpTopicReaderPolicy.maximumSectionCharacterCount })
        XCTAssertEqual(sections.map(\.bodyMarkdown).joined(), body)
        XCTAssertTrue(sections.contains { $0.bodyMarkdown.contains("👩‍💻") })
    }

    func testSettingsDefaultsHelpExplainsResetAllSettingsScopeAndProtectedData() throws {
        let topic = try XCTUnwrap(
            MindDeskHelpCatalog.defaultTopics.first { $0.id == "settings-defaults" }
        )
        let helpText = [
            topic.title,
            topic.summary,
            topic.bodyMarkdown,
            topic.keywords.joined(separator: " ")
        ]
            .joined(separator: " ")
            .lowercased()

        for required in [
            "reset all settings",
            "custom agent review guidance",
            "custom agent review guidance field is cleared",
            "obsolete settings keys",
            "does not delete",
            "workspaces",
            "resources",
            "snippets",
            "tasks",
            "canvases",
            "cards",
            "exports",
            "raw backups",
            "quarantine"
        ] {
            XCTAssertTrue(helpText.contains(required), "Missing Settings reset help term: \(required)")
        }

        for query in [
            "reset all settings",
            "custom Agent Review Guidance reset",
            "obsolete settings keys",
            "settings protected data"
        ] {
            XCTAssertEqual(
                MindDeskHelpSearch.results(for: query, in: MindDeskHelpCatalog.defaultTopics).first?.id,
                "settings-defaults",
                "Expected Settings Defaults help topic for query: \(query)"
            )
        }
    }

    func testCanvasPerformanceHelpExplainsAdaptiveAnimationAndZoomSaveTiming() throws {
        let topic = try XCTUnwrap(
            MindDeskHelpCatalog.defaultTopics.first { $0.id == "canvas-performance" }
        )
        let helpText = [
            topic.title,
            topic.summary,
            topic.bodyMarkdown,
            topic.keywords.joined(separator: " ")
        ]
            .joined(separator: " ")
            .lowercased()

        for required in [
            "maximum",
            "not a guaranteed constant frame rate",
            "reduce motion",
            "dense canvases",
            "zoomed out below the baseline",
            "zoom save timing",
            "does not change visual zoom smoothness",
            "viewport diagnostics",
            "index cache diagnostics",
            "non-finite geometry cache reuse",
            "buildcount",
            "reusecount",
            "lastinvalidationreason",
            "bounded bucket fallback",
            "bucket coordinate overflow",
            "no raw geometry",
            "final render segment forced retention",
            "moving-node incident edge retention",
            "high fanout moving node",
            "moving-node incident retention bound",
            "forced retention cap",
            "incident adjacency index",
            "adjacency lookup diagnostics",
            "force retention edge scan count",
            "cap-near incident retention",
            "cap-near single-node high-fanout incident retention",
            "not full fanout edge scan",
            "incidentcandidateedgecount can report the full incident fanout",
            "edgescancount should stay near maximumincidentedgecount",
            "single and multiple moving-node drags",
            "multi moving-node force-retention diagnostics",
            "multi-moving-node force-retention diagnostics",
            "multiple moving-node incident retention",
            "force-retention diagnostics",
            "usedincidentadjacency and adjacencylookupnodecount",
            "aggregate count, cap, and flag fields only",
            "must not expose card titles",
            "orderedscancount",
            "query sort diagnostics",
            "canvasedgeviewportquerydiagnostics",
            "stable query output order",
            "candidateexaminedcount",
            "bounded candidate filter work",
            "first valid wins",
            "duplicateedgecount",
            "droppeddanglingedgecount",
            "droppedinvalidgeometryedgecount",
            "dangling forced edge diagnostics"
        ] {
            XCTAssertTrue(helpText.contains(required), "Missing Canvas performance help term: \(required)")
        }
        for forbidden in [
            "input signature",
            "cache signature",
            "inputsignature",
            "fingerprint"
        ] {
            XCTAssertFalse(helpText.contains(forbidden), "Canvas performance help should not expose derived cache fingerprints: \(forbidden)")
        }
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "viewport diagnostics", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "index cache diagnostics", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "non-finite geometry cache reuse", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "buildCount reuseCount lastInvalidationReason", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "bounded bucket fallback", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "final render segment forced retention", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "moving-node incident edge retention", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "high fanout moving node", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "moving-node incident retention bound", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "forced retention cap", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "incident adjacency index", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "force retention edge scan count", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "cap-near incident retention", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "cap-near single-node high-fanout", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "single node high fanout near cap edgeScanCount", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "not full fanout edge scan", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "multi moving-node force-retention diagnostics", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "multi-moving-node force-retention diagnostics", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "multiple moving nodes", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "multiple moving-node incident retention", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "usedIncidentAdjacency", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "adjacencyLookupNodeCount", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "orderedScanCount", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "query sort diagnostics", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "CanvasEdgeViewportQueryDiagnostics", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "candidateExaminedCount", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "bounded candidate filter work", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "total indexed candidate examined ordered scan forced retention render counts", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "totalEdgeCount indexedEdgeCount candidateExaminedCount orderedScanCount forceRetainedEdgeCount renderEdgeCount", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "duplicateEdgeCount", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "first valid wins", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "first-valid-wins", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "duplicate-edge", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "invalid geometry duplicate edge", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "canvas-performance"
        )
    }

    func testHelpCatalogSearchRanksTitleAndKeywordMatchesDeterministically() {
        let results = MindDeskHelpSearch.results(for: "agent workflow", in: MindDeskHelpCatalog.defaultTopics)

        XCTAssertEqual(results.first?.id, "agent-prompt-workflow")
        XCTAssertTrue(results.map(\.id).contains("agent-readonly-mip"))
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "", in: MindDeskHelpCatalog.defaultTopics, limit: 2).map(\.id),
            ["settings-defaults", "canvas-performance"]
        )
        XCTAssertTrue(MindDeskHelpSearch.results(for: "agent", in: MindDeskHelpCatalog.defaultTopics, limit: 0).isEmpty)
    }

    func testHelpCatalogSearchResponseEncodesBoundedReadOnlySummaries() throws {
        let response = MindDeskHelpSearch.summaryResponse(
            for: "agent workflow",
            in: MindDeskHelpCatalog.defaultTopics,
            limit: 2
        )
        let data = try JSONEncoder.minddesk.encode(response)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(response.format, "minddesk.help.search.response")
        XCTAssertEqual(response.formatVersion, 1)
        XCTAssertEqual(response.query, "agent workflow")
        XCTAssertEqual(response.requestedLimit, 2)
        XCTAssertEqual(response.resultCount, 2)
        XCTAssertTrue(response.truncated)
        XCTAssertEqual(response.results.count, 2)
        XCTAssertTrue(response.results.contains { $0.id == "agent-prompt-workflow" })
        XCTAssertTrue(response.results.allSatisfy { !$0.bodyMarkdownIncluded })
        XCTAssertFalse(response.authorizesSideEffects)
        XCTAssertTrue(response.boundaryText.lowercased().contains("not authorization"))
        XCTAssertEqual(object["resultCount"] as? Int, 2)
        XCTAssertEqual(object["truncated"] as? Bool, true)
        XCTAssertEqual(object["authorizesSideEffects"] as? Bool, false)
        XCTAssertEqual(try JSONDecoder.minddesk.decode(MindDeskHelpSearchResponse.self, from: data), response)

        let firstSummary = try XCTUnwrap(response.results.first)
        XCTAssertFalse(firstSummary.title.isEmpty)
        XCTAssertFalse(firstSummary.summary.isEmpty)
        XCTAssertFalse(firstSummary.anchor.isEmpty)

        let noMatchResponse = MindDeskHelpSearch.summaryResponse(
            for: "not-a-real-help-topic",
            in: MindDeskHelpCatalog.defaultTopics,
            limit: 3
        )
        XCTAssertEqual(noMatchResponse.resultCount, 0)
        XCTAssertFalse(noMatchResponse.truncated)
        XCTAssertTrue(noMatchResponse.results.isEmpty)
    }

    func testHelpCatalogSearchRequestIsCodableAndBuildsBoundedResponse() throws {
        let longQuery = String(repeating: "agent ", count: MindDeskHelpSearchRequest.maximumQueryCharacterCount)
        let expectedQuery = String(
            longQuery
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(MindDeskHelpSearchRequest.maximumQueryCharacterCount)
        )
        let request = MindDeskHelpSearchRequest(
            query: "\n \(longQuery) \t",
            limit: 999
        )
        let data = try JSONEncoder.minddesk.encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(request.query, expectedQuery)
        XCTAssertEqual(request.query.count, MindDeskHelpSearchRequest.maximumQueryCharacterCount)
        XCTAssertEqual(request.limit, MindDeskHelpSearchRequest.maximumLimit)
        XCTAssertEqual(object["query"] as? String, expectedQuery)
        XCTAssertEqual(object["limit"] as? Int, MindDeskHelpSearchRequest.maximumLimit)

        let decoded = try JSONDecoder.minddesk.decode(
            MindDeskHelpSearchRequest.self,
            from: try JSONSerialization.data(withJSONObject: [
                "query": "\t\(longQuery)\n",
                "limit": -5
            ])
        )
        XCTAssertEqual(decoded.query, expectedQuery)
        XCTAssertEqual(decoded.limit, 0)

        let response = MindDeskHelpSearch.summaryResponse(
            request: request,
            in: MindDeskHelpCatalog.defaultTopics
        )

        XCTAssertEqual(response.query, expectedQuery)
        XCTAssertEqual(response.requestedLimit, MindDeskHelpSearchRequest.maximumLimit)
        XCTAssertLessThanOrEqual(response.results.count, MindDeskHelpSearchRequest.maximumLimit)
        XCTAssertFalse(response.authorizesSideEffects)

        let defaultCatalogResponse = MindDeskHelpSearch.summaryResponse(request: request)
        XCTAssertEqual(defaultCatalogResponse, response)
    }

    func testHelpCatalogSearchFindsHumanAndAIRetrievalQueries() {
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "settings help", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "settings-defaults"
        )
        let settingsHelpTopic = MindDeskHelpCatalog.defaultTopics.first { $0.id == "settings-defaults" }
        let settingsHelpText = [
            settingsHelpTopic?.bodyMarkdown ?? "",
            settingsHelpTopic?.keywords.joined(separator: " ") ?? ""
        ]
            .joined(separator: " ")
            .lowercased()
        XCTAssertTrue(settingsHelpText.contains("minddeskhelpsearchrequest"))
        XCTAssertTrue(settingsHelpText.contains("query cap"))
        XCTAssertTrue(
            MindDeskHelpSearch.results(for: "AI retrieval", in: MindDeskHelpCatalog.defaultTopics)
                .map(\.id)
                .contains("agent-readonly-mip")
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(
                for: "proposal JSON references kind id",
                in: MindDeskHelpCatalog.defaultTopics
            ).first?.id,
            "agent-prompt-workflow"
        )
        for query in [
            "task group export",
            "task export",
            "todo group export",
            "todo export"
        ] {
            XCTAssertEqual(
                MindDeskHelpSearch.results(for: query, in: MindDeskHelpCatalog.defaultTopics).first?.id,
                "import-export",
                "Expected Import And Export help for Global Library Only task/todo query: \(query)"
            )
        }

        let agentWorkflowTopic = MindDeskHelpCatalog.defaultTopics.first { $0.id == "agent-prompt-workflow" }
        let agentWorkflowText = [
            agentWorkflowTopic?.bodyMarkdown ?? "",
            agentWorkflowTopic?.keywords.joined(separator: " ") ?? ""
        ]
            .joined(separator: " ")
            .lowercased()
        for required in [
            "minddeskagentworkflowsearchrequest",
            "minddesk.agent.workflow.search.response",
            "helplimit",
            "capabilitylimit",
            "includemetaactions",
            "maximumquerycharactercount",
            "query cap",
            "trim",
            "proposal json references",
            "\"kind\"",
            "\"id\"",
            "json object"
        ] {
            XCTAssertTrue(agentWorkflowText.contains(required), "Agent workflow help lost reference schema term: \(required)")
        }
    }

    func testHelpCatalogSearchTokenizesPunctuationDelimitedQueries() {
        for query in [
            "settings-defaults",
            "settings/defaults",
            "settings, defaults"
        ] {
            XCTAssertEqual(
                MindDeskHelpSearch.results(for: query, in: MindDeskHelpCatalog.defaultTopics).first?.id,
                "settings-defaults",
                "Expected settings help for punctuation-delimited query: \(query)"
            )
        }

        for expected in [
            (query: "proposal-runCommand", topicID: "agent-extension-capabilities"),
            (query: "actor/approvedAgent", topicID: "agent-extension-capabilities"),
            (query: "package:validation-report:missing", topicID: "agent-readonly-mip")
        ] {
            XCTAssertTrue(
                MindDeskHelpSearch.results(for: expected.query, in: MindDeskHelpCatalog.defaultTopics)
                    .map(\.id)
                    .contains(expected.topicID),
                "Expected \(expected.topicID) for punctuation-delimited query: \(expected.query)"
            )
        }
    }

    func testAgentReviewPackageHelpTopicsAreCuratedSearchableAndBudgeted() throws {
        let topics = MindDeskHelpCatalog.agentReviewPackageTopics
        let ids = topics.map(\.id)
        let requiredIDs: Set<String> = [
            "agent-readonly-mip",
            "agent-prompt-workflow",
            "agent-extension-capabilities",
            "agent-proposal-review",
            "import-export",
            "canvas-performance"
        ]
        let encodedTopics = try JSONEncoder.minddesk.encode(topics)

        XCTAssertEqual(Set(ids), requiredIDs)
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertEqual(topics.map(\.anchor).count, Set(topics.map(\.anchor)).count)
        XCTAssertFalse(ids.contains("settings-defaults"))
        XCTAssertLessThanOrEqual(encodedTopics.count, 96 * 1024)
        XCTAssertLessThanOrEqual(topics.map(\.bodyMarkdown.count).max() ?? 0, 16 * 1024)
        XCTAssertLessThanOrEqual(topics.map { $0.bodyMarkdown.utf8.count }.max() ?? 0, 16 * 1024)
        let searchableCorpusByteCount = topics.reduce(0) { total, topic in
            total
                + topic.title.utf8.count
                + topic.summary.utf8.count
                + topic.bodyMarkdown.utf8.count
                + topic.keywords.joined(separator: " ").utf8.count
                + topic.relatedObjectRefs.joined(separator: " ").utf8.count
                + topic.category.rawValue.utf8.count
        }
        XCTAssertLessThanOrEqual(searchableCorpusByteCount, 48 * 1024)
        XCTAssertLessThanOrEqual(topics.reduce(0) { $0 + $1.keywords.count }, 400)
        XCTAssertTrue(
            topics.filter { $0.category == .agent }.allSatisfy { topic in
                let text = "\(topic.summary) \(topic.bodyMarkdown)".lowercased()
                return text.contains("not authorization") || text.contains("does not authorize")
            }
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "agent workflow", in: topics).first?.id,
            "agent-prompt-workflow"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "MIP redactionPolicy", in: topics).first?.id,
            "agent-readonly-mip"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "validationReport.redactionPolicy", in: topics).first?.id,
            "agent-readonly-mip"
        )
        for query in [
            "task group export",
            "task export",
            "todo group export",
            "todo export"
        ] {
            XCTAssertEqual(
                MindDeskHelpSearch.results(for: query, in: topics).first?.id,
                "import-export",
                "Expected Agent Review package import/export help for task/todo query: \(query)"
            )
        }
        XCTAssertTrue(
            MindDeskHelpSearch.results(for: "proposal.runCommand", in: topics)
                .map(\.id)
                .contains("agent-extension-capabilities")
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "duplicateEdgeCount", in: topics).first?.id,
            "canvas-performance"
        )
        let packageCanvasTopic = try XCTUnwrap(topics.first { $0.id == "canvas-performance" })
        let packageCanvasText = [
            packageCanvasTopic.title,
            packageCanvasTopic.summary,
            packageCanvasTopic.bodyMarkdown,
            packageCanvasTopic.keywords.joined(separator: " ")
        ]
            .joined(separator: " ")
            .lowercased()
        for forbidden in [
            "input signature",
            "cache signature",
            "inputsignature",
            "fingerprint"
        ] {
            XCTAssertFalse(
                packageCanvasText.contains(forbidden),
                "Agent Review package Canvas help should not expose derived cache fingerprints: \(forbidden)"
            )
        }
        XCTAssertEqual(
            MindDeskHelpSearch.results(
                for: "cache reuse diagnostics buildCount reuseCount lastInvalidationReason",
                in: topics
            ).first?.id,
            "canvas-performance"
        )
        let requiredQueryResults: [(query: String, topicID: String)] = [
            ("helpTopics", "agent-readonly-mip"),
            (".mip.json helpTopics", "agent-readonly-mip"),
            ("non-authoritative helpTopics", "agent-readonly-mip"),
            ("tampered helpTopics", "agent-readonly-mip"),
            ("forged validationReport", "agent-readonly-mip"),
            ("validationReport drift", "agent-readonly-mip"),
            ("package.validation-report.missing", "agent-readonly-mip"),
            ("package.validation-report.mismatch", "agent-readonly-mip"),
            ("missing raw authority mirrors", "agent-readonly-mip"),
            ("missing agentIntegrationContract", "agent-readonly-mip"),
            ("contract.raw.missing", "agent-readonly-mip"),
            ("missing agentPolicy", "agent-readonly-mip"),
            ("package.agent-policy.missing", "agent-readonly-mip"),
            ("missing externalActionPolicy", "agent-readonly-mip"),
            ("package.external-action-policy.missing", "agent-readonly-mip"),
            ("missing extensionCapabilities", "agent-readonly-mip"),
            ("capability-catalog.raw.missing", "agent-readonly-mip"),
            ("agentIntegrationContract", "agent-readonly-mip"),
            ("agentPolicy", "agent-readonly-mip"),
            ("externalActionPolicy", "agent-readonly-mip"),
            ("forged extensionCapabilities", "agent-extension-capabilities"),
            ("forged agentIntegrationContract", "agent-extension-capabilities"),
            ("forged agentPolicy", "agent-extension-capabilities"),
            ("forged externalActionPolicy", "agent-extension-capabilities"),
            ("proposal review gate", "agent-proposal-review"),
            ("proposalEnvelopeData sourcePackageData raw JSON Data", "agent-proposal-review"),
            ("in-app confirmation", "agent-proposal-review"),
            ("immediate in-app confirmation", "agent-proposal-review"),
            ("outside the proposal review sheet", "agent-proposal-review"),
            ("Proposal Review confirmation", "agent-proposal-review"),
            ("proposal JSON schema", "agent-proposal-review"),
            ("accepted proposal JSON fields", "agent-proposal-review"),
            ("required proposal JSON fields", "agent-proposal-review"),
            ("schema is for review only", "agent-proposal-review"),
            ("runtime search helpTopics relatedObjectRefs", "agent-prompt-workflow"),
            ("proposal.runCommand workingDirectory", "agent-extension-capabilities")
        ]
        for requiredQueryResult in requiredQueryResults {
            XCTAssertTrue(
                MindDeskHelpSearch.results(for: requiredQueryResult.query, in: topics)
                    .map(\.id)
                    .contains(requiredQueryResult.topicID),
                "Agent Review package helpTopics search did not route \(requiredQueryResult.query) to \(requiredQueryResult.topicID)."
            )
        }
    }

    func testAgentReviewHelpTopicsContractIsDocumentedForHumansAndAgents() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let readme = try String(
            contentsOf: repositoryRoot.appendingPathComponent("README.md"),
            encoding: .utf8
        )
        let checklist = try String(
            contentsOf: repositoryRoot.appendingPathComponent("docs/feature-checklist.md"),
            encoding: .utf8
        )

        for required in [
            "helpTopics",
            "curated",
            "non-authoritative retrieval help",
            "MindDeskAgentWorkflowSearchRequest",
            "MindDeskAgentWorkflowSearch.response(request:)",
            "response(package:request:)",
            "minddesk.agent.workflow.search.response",
            "MindDeskHelpSearchRequest",
            "minddesk.help.search.response",
            "MindDeskExtensionCapabilitySearchRequest",
            "MindDeskExtensionCapabilitySearch.response(request:)",
            "minddesk.extension.capability.search.response",
            "helpLimit",
            "capabilityLimit",
            "includeMetaActions",
            "query cap",
            "limit cap",
            "bounded read-only retrieval result",
            "does not override validationReport",
            "agentIntegrationContract",
            "extensionCapabilities",
            "serialized `validationReport`",
            "MindDeskProposalReviewGate.evaluate(proposalEnvelopeData:sourcePackageData:gatedAt:)",
            "Forged source-package authority mirrors",
            "`agentIntegrationContract` drift",
            "top-level `agentPolicy`",
            "top-level `externalActionPolicy`",
            "`package.validation-report.*` diagnostics",
            "Missing raw authority mirrors",
            "`contract.raw.missing`",
            "`package.agent-policy.missing`",
            "`package.external-action-policy.missing`",
            "`capability-catalog.raw.missing`",
            "Top-level `helpTopics` are ignored/replaced",
            "Top-level `agentGuide` defaults are regenerated",
            "agentPolicy",
            "externalActionPolicy",
            "in-app confirmation",
            "explicit immediate in-app confirmation",
            "outside the proposal review sheet",
            "approval is not authorization"
        ] {
            XCTAssertTrue(readme.contains(required), "README missing Agent Review helpTopics contract: \(required)")
        }
        XCTAssertTrue(
            readme.contains("id, title, summary, bodyMarkdown, keywords, relatedObjectRefs, and category"),
            "README must document every runtime-searchable helpTopics field, including id."
        )
        let chineseAgentReviewSection = try XCTUnwrap(
            readme
                .components(separatedBy: "### Agent Review 工作流")
                .dropFirst()
                .first?
                .components(separatedBy: "###")
                .first,
            "README missing Chinese Agent Review workflow section."
        )
        for required in [
            "approval is not authorization",
            "explicit immediate in-app confirmation",
            "outside the proposal review sheet",
            "accepted proposal JSON fields",
            "MindDeskAgentWorkflowSearchRequest",
            "MindDeskAgentWorkflowSearch.response(request:)",
            "response(package:request:)",
            "minddesk.agent.workflow.search.response",
            "MindDeskHelpSearchRequest",
            "minddesk.help.search.response",
            "MindDeskExtensionCapabilitySearchRequest",
            "MindDeskExtensionCapabilitySearch.response(request:)",
            "minddesk.extension.capability.search.response",
            "helpLimit",
            "capabilityLimit",
            "includeMetaActions",
            "query cap",
            "limit cap",
            "Review Agent Proposal sheet 是 human review surface only"
        ] {
            XCTAssertTrue(
                chineseAgentReviewSection.contains(required),
                "README Chinese Agent Review section missing boundary text: \(required)"
            )
        }
        XCTAssertTrue(
            chineseAgentReviewSection.contains("id、title、summary、bodyMarkdown、keywords、relatedObjectRefs 和 category"),
            "README Chinese Agent Review section must document every runtime-searchable helpTopics field, including id."
        )

        for required in [
            "helpTopics",
            "agent-readonly-mip",
            "agent-prompt-workflow",
            "agent-extension-capabilities",
            "agent-proposal-review",
            "import-export",
            "canvas-performance",
            "validationReport.redactionPolicy",
            "forged validationReport",
            "validationReport drift",
            "package.validation-report.missing",
            "package.validation-report.mismatch",
            "missing raw authority mirrors",
            "missing agentIntegrationContract",
            "contract.raw.missing",
            "missing agentPolicy",
            "package.agent-policy.missing",
            "missing externalActionPolicy",
            "package.external-action-policy.missing",
            "missing extensionCapabilities",
            "capability-catalog.raw.missing",
            "MindDeskProposalReviewGate.evaluate(proposalEnvelopeData:sourcePackageData:gatedAt:)",
            "proposal.runCommand",
            "proposal JSON schema",
            "accepted proposal JSON fields",
            "required proposal JSON fields",
            "schema is for review only",
            "duplicateEdgeCount",
            "forged extensionCapabilities",
            "forged agentIntegrationContract",
            "forged agentPolicy",
            "forged externalActionPolicy",
            "extensionCapabilityCatalog",
            "contract.*.mismatch",
            "explicit immediate in-app confirmation",
            "outside the proposal review sheet",
            "approval is not authorization",
            "reader sections",
            "presentation-only",
            "single Overview",
            "bounded Details sections",
            "not encoded into `.mip.json` `helpTopics`",
            "`id`、`title`、`summary`、`bodyMarkdown`、`keywords`、`relatedObjectRefs` 和 `category`",
            "篡改",
            "授权"
        ] {
            XCTAssertTrue(checklist.contains(required), "Feature checklist missing Agent Review helpTopics regression item: \(required)")
        }
        let checklistLowercased = checklist.lowercased()
        for forbidden in [
            "input signature",
            "cache signature",
            "inputsignature",
            "fingerprint"
        ] {
            XCTAssertFalse(
                checklistLowercased.contains(forbidden),
                "Feature checklist should not require public cache fingerprint diagnostics: \(forbidden)"
            )
        }
        for required in [
            "buildcount",
            "reusecount",
            "lastinvalidationreason",
            "non-finite node geometry",
            "ignored control point"
        ] {
            XCTAssertTrue(
                checklistLowercased.contains(required),
                "Feature checklist missing aggregate cache diagnostics contract: \(required)"
            )
        }
    }

    func testSettingsResetDescriptorContractIsDocumentedInFeatureChecklist() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let checklist = try String(
            contentsOf: repositoryRoot.appendingPathComponent("docs/feature-checklist.md"),
            encoding: .utf8
        )

        for required in [
            "Reset All Settings",
            "shared reset descriptor",
            "default values",
            "Custom Agent Review Guidance",
            "obsolete settings keys",
            "workspaces",
            "resources",
            "snippets",
            "tasks",
            "canvases",
            "cards",
            "exports",
            "raw backups",
            "quarantine/local recovery data"
        ] {
            XCTAssertTrue(checklist.contains(required), "Checklist missing Settings Reset contract: \(required)")
        }
    }

    func testHelpCatalogSearchFindsCustomAgentGuidanceQueries() {
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "custom guidance", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "agent-prompt-workflow"
        )
        XCTAssertTrue(
            MindDeskHelpSearch.results(for: "agent review guidance", in: MindDeskHelpCatalog.defaultTopics)
                .map(\.id)
                .contains("agent-prompt-workflow")
        )
    }

    func testHelpCatalogSearchIndexesAgentRelatedObjectRefsAndCapabilityIDs() {
        XCTAssertTrue(
            MindDeskHelpSearch.results(
                for: "catalog:MindDeskExtensionCapabilityCatalog",
                in: MindDeskHelpCatalog.defaultTopics
            )
            .map(\.id)
            .contains("agent-readonly-mip")
        )
        XCTAssertTrue(
            MindDeskHelpSearch.results(for: "proposal.runCommand", in: MindDeskHelpCatalog.defaultTopics)
                .map(\.id)
                .contains("agent-prompt-workflow")
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "extension capabilities", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "agent-extension-capabilities"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "proposal.openURL", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "agent-extension-capabilities"
        )
        XCTAssertEqual(
            MindDeskHelpSearch.results(for: "actor:approvedAgent", in: MindDeskHelpCatalog.defaultTopics).first?.id,
            "agent-extension-capabilities"
        )
    }

    func testHelpCatalogCapabilitySearchResultsExposeWireTermsInVisibleTopicText() throws {
        for query in [
            "extension capabilities",
            "proposal.openURL",
            "proposal.runCommand",
            "actor:approvedAgent"
        ] {
            let topic = try XCTUnwrap(
                MindDeskHelpSearch.results(for: query, in: MindDeskHelpCatalog.defaultTopics).first,
                "Missing help result for \(query)"
            )
            let topicText = normalizedText([topic.title, topic.summary, topic.bodyMarkdown])
            for required in [
                "extension capabilities",
                "extensioncapabilities",
                "minddeskextensioncapabilitycatalog",
                "proposal.openurl",
                "proposal.runcommand",
                "actor:approvedagent",
                "approvedagent",
                "defaultagent",
                "directuser",
                "policydecisions",
                "minddeskextensioncapabilitysearchrequest",
                "minddeskextensioncapabilitysearch.response(request:)",
                "minddesk.extension.capability.search.response",
                "query cap",
                "includemetaactions",
                "not authorization"
            ] {
                XCTAssertTrue(
                    topicText.contains(required),
                    "Help result for \(query) does not visibly document \(required)"
                )
            }
        }
    }

    func testHelpCatalogSearchFindsProposalReviewWorkflowQueries() throws {
        for query in [
            "review agent proposal",
            "proposal review sheet",
            "pending review",
            "blocked proposal diagnostics",
            "agent free text",
            "redacted reference rows",
            "record approval only",
            "proposal.context.stale",
            "immediate in-app confirmation",
            "outside the proposal review sheet",
            "Proposal Review confirmation",
            "proposal envelope limits",
            "payload field whitelist",
            "proposal JSON schema",
            "accepted proposal JSON fields",
            "required proposal JSON fields",
            "schema is for review only",
            "unexpected payload field",
            "proposal.operation.unexpected-payload",
            "proposal.operation.unknown-payload-field",
            "proposal file size cap",
            "16 MiB",
            "decode-time proposal limit",
            "proposal.collection.too-large",
            "proposal.operation.payload-too-long",
            "too many proposals",
            "too many operations",
            "operation count limit"
        ] {
            XCTAssertEqual(
                MindDeskHelpSearch.results(for: query, in: MindDeskHelpCatalog.defaultTopics).first?.id,
                "agent-proposal-review",
                "Expected proposal review help for query: \(query)"
            )
        }

        let topic = try XCTUnwrap(
            MindDeskHelpCatalog.defaultTopics.first { $0.id == "agent-proposal-review" }
        )
        let topicText = normalizedText([topic.title, topic.summary, topic.bodyMarkdown])

        for required in [
            "read-only",
            "pending review",
            "blocked",
            "sanitized validation diagnostics",
            "agent free text",
            "redacted reference rows",
            "untrusted proposal title redacted",
            "untrusted operation title redacted",
            "proposal envelope limits",
            "payload field whitelist",
            "unexpected payload field",
            "proposal.operation.unexpected-payload",
            "proposal.operation.unknown-payload-field",
            "16 mib",
            "decode-time proposal limits",
            "proposal.collection.too-large",
            "proposal.operation.payload-too-long",
            "too many proposals",
            "too many operations",
            "operation count limit",
            "proposal json schema",
            "accepted proposal json fields",
            "required proposal json fields",
            "schema is for review only",
            "record approval only",
            "does not execute",
            "finder",
            "terminal",
            "url",
            "clipboard",
            "alias",
            "command",
            "import/export",
            "apply"
        ] {
            XCTAssertTrue(topicText.contains(required), "Missing proposal review help text: \(required)")
        }
    }

    func testHelpCatalogSearchRoutesChecklistQueriesToPrimaryTopics() {
        let requiredPrimaryResults: [(query: String, topicID: String)] = [
            ("settings help", "settings-defaults"),
            ("agent workflow", "agent-prompt-workflow"),
            ("MindDeskAgentWorkflowSearchRequest", "agent-prompt-workflow"),
            ("minddesk.agent.workflow.search.response", "agent-prompt-workflow"),
            ("custom guidance", "agent-prompt-workflow"),
            ("agent review guidance", "agent-prompt-workflow"),
            ("MindDeskExtensionCapabilitySearch.response(request:)", "agent-extension-capabilities"),
            ("minddesk.extension.capability.search.response", "agent-extension-capabilities"),
            ("proposal.runCommand", "agent-extension-capabilities"),
            ("review agent proposal", "agent-proposal-review"),
            ("proposal review sheet", "agent-proposal-review"),
            ("pending review", "agent-proposal-review"),
            ("blocked proposal diagnostics", "agent-proposal-review"),
            ("proposal JSON schema", "agent-proposal-review"),
            ("accepted proposal JSON fields", "agent-proposal-review"),
            ("required proposal JSON fields", "agent-proposal-review"),
            ("schema is for review only", "agent-proposal-review"),
            ("payload field whitelist", "agent-proposal-review"),
            ("unexpected payload field", "agent-proposal-review"),
            ("proposal.operation.unexpected-payload", "agent-proposal-review"),
            ("proposal.operation.unknown-payload-field", "agent-proposal-review"),
            ("proposal file size cap", "agent-proposal-review"),
            ("16 MiB", "agent-proposal-review"),
            ("decode-time proposal limit", "agent-proposal-review"),
            ("proposal.collection.too-large", "agent-proposal-review"),
            ("proposal.operation.payload-too-long", "agent-proposal-review"),
            ("record approval only", "agent-proposal-review"),
            ("proposal.context.stale", "agent-proposal-review"),
            ("incident adjacency", "canvas-performance"),
            ("multi moving-node force-retention diagnostics", "canvas-performance"),
            ("multi-moving-node force-retention diagnostics", "canvas-performance"),
            ("multiple moving nodes", "canvas-performance"),
            ("orderedScanCount", "canvas-performance"),
            ("candidateExaminedCount", "canvas-performance"),
            ("bounded candidate filter work", "canvas-performance"),
            ("duplicateEdgeCount", "canvas-performance"),
            ("first valid wins", "canvas-performance"),
            ("first-valid-wins", "canvas-performance"),
            ("duplicate-edge", "canvas-performance"),
            ("invalid geometry duplicate edge", "canvas-performance"),
            ("query sort diagnostics", "canvas-performance"),
            ("CanvasEdgeViewportQueryDiagnostics", "canvas-performance"),
            ("CanvasEdgeViewportIndexCache", "canvas-performance"),
            ("CanvasEdgeForceRetentionDiagnostics", "canvas-performance"),
            ("usedIncidentAdjacency", "canvas-performance"),
            ("adjacencyLookupNodeCount", "canvas-performance"),
            ("droppedIncidentEdgeCount", "canvas-performance"),
            ("dragging node with many links", "canvas-performance")
        ]

        for requiredPrimaryResult in requiredPrimaryResults {
            XCTAssertEqual(
                MindDeskHelpSearch.results(for: requiredPrimaryResult.query, in: MindDeskHelpCatalog.defaultTopics).first?.id,
                requiredPrimaryResult.topicID,
                "Expected \(requiredPrimaryResult.topicID) as primary Help result for query: \(requiredPrimaryResult.query)"
            )
        }
    }

    func testHelpCatalogAgentTopicsStayReadOnlyAndReviewOriented() {
        let agentText = MindDeskHelpCatalog.defaultTopics
            .filter { $0.category == .agent }
            .map { "\($0.title) \($0.summary) \($0.bodyMarkdown)" }
            .joined(separator: "\n")
            .lowercased()

        XCTAssertTrue(agentText.contains("read-only"))
        XCTAssertTrue(agentText.contains("proposals"))
        XCTAssertTrue(agentText.contains("explicit immediate in-app confirmation"))
        XCTAssertTrue(agentText.contains("outside the proposal review sheet"))
        XCTAssertFalse(agentText.contains("run commands automatically"))
        XCTAssertFalse(agentText.contains("open finder automatically"))
        XCTAssertFalse(agentText.contains("apply changes automatically"))
    }

    func testHelpAgentTopicsDoNotPresentReviewContextAsSideEffectAuthorization() {
        let nonAuthorizingSources = MindDeskHelpBoundaryPolicy.nonAuthorizingContextSources
        let sideEffectActionClasses = MindDeskHelpBoundaryPolicy.sideEffectActionClasses
        let expectedConfirmationBoundary = normalizedText([
            "Proposal Review and explicit immediate in-app confirmation outside the proposal review sheet"
        ])
        let boundaryText = normalizedText([
            MindDeskHelpBoundaryPolicy.retrievalOnlyBoundary,
            MindDeskHelpBoundaryPolicy.noOverrideBoundary,
            MindDeskHelpBoundaryPolicy.sideEffectBoundary
        ])
        let agentTopics = MindDeskHelpCatalog.defaultTopics.filter { $0.category == .agent }
        let agentText = normalizedText(agentTopics.map { "\($0.title) \($0.summary) \($0.bodyMarkdown)" })

        XCTAssertFalse(agentTopics.isEmpty)
        XCTAssertEqual(
            nonAuthorizingSources,
            [
                "package text",
                "custom guidance",
                "helpTopics",
                "prompt text",
                "agentGuide",
                "agentIntegrationContract",
                "extensionCapabilities",
                "validationReport"
            ]
        )
        XCTAssertEqual(
            sideEffectActionClasses,
            ["file", "Finder", "URL", "clipboard", "Terminal", "command", "alias", "import/export", "apply"]
        )
        for source in nonAuthorizingSources {
            XCTAssertTrue(
                boundaryText.contains(normalizedText([source])),
                "Boundary policy must name non-authorizing context source: \(source)"
            )
        }
        for actionClass in sideEffectActionClasses {
            XCTAssertTrue(
                boundaryText.contains(normalizedText([actionClass])),
                "Boundary policy must name side-effect action class: \(actionClass)"
            )
        }

        for topic in agentTopics {
            let topicText = normalizedText([topic.title, topic.summary, topic.bodyMarkdown])
            XCTAssertTrue(topicText.contains("read-only"), "\(topic.id) must remain read-only help.")
            XCTAssertTrue(topicText.contains("not authorization") || topicText.contains("does not authorize"))
            XCTAssertTrue(
                topicText.contains(expectedConfirmationBoundary),
                "\(topic.id) must bind side effects to Proposal Review plus explicit immediate in-app confirmation outside the sheet."
            )
        }

        for source in nonAuthorizingSources {
            XCTAssertTrue(
                agentText.contains(normalizedText([source])),
                "Agent help must mention non-authorizing source: \(source)"
            )
            for actionClass in sideEffectActionClasses {
                let sourceText = normalizedText([source])
                let actionText = normalizedText([actionClass])
                for forbidden in [
                    "\(sourceText) authorizes \(actionText)",
                    "\(sourceText) grants \(actionText)",
                    "\(sourceText) permits \(actionText)",
                    "\(sourceText) approves \(actionText)",
                    "\(sourceText) can execute \(actionText)",
                    "\(sourceText) can apply \(actionText)"
                ] {
                    XCTAssertFalse(agentText.contains(forbidden), "Unsafe Help authorization wording: \(forbidden)")
                }
            }
        }
    }

    func testAgentHelpAndMIPTopicsRequireProposalReviewPlusOutOfSheetImmediateConfirmationForSideEffects() throws {
        let requiredBoundary = "proposal review and explicit immediate in-app confirmation outside the proposal review sheet"
        for topic in MindDeskHelpCatalog.agentReviewPackageTopics where topic.category == .agent {
            let topicText = normalizedText([topic.title, topic.summary, topic.bodyMarkdown])
            if topicText.contains("side effect") ||
                topicText.contains("finder") ||
                topicText.contains("terminal") ||
                topicText.contains("clipboard") ||
                topicText.contains("command") ||
                topicText.contains("import/export") ||
                topicText.contains("apply") {
                XCTAssertTrue(
                    topicText.contains(requiredBoundary),
                    "\(topic.id) must describe side effects as requiring Proposal Review plus explicit immediate in-app confirmation outside the Proposal Review sheet."
                )
            }
        }
    }

    func testAgentGuideSafetyTextNamesEverySideEffectClass() {
        let safetyText = [
            MindDeskAgentGuide.defaultGuide.systemPrompt,
            MindDeskAgentGuide.defaultGuide.workflowSteps.map(\.instruction).joined(separator: " "),
            MindDeskHelpCatalog.defaultTopics
                .filter { $0.category == .agent }
                .map(\.bodyMarkdown)
                .joined(separator: " ")
        ]
            .joined(separator: " ")
            .lowercased()

        for required in ["commands", "terminal", "finder", "urls", "clipboard", "aliases", "files", "import/export", "apply changes", "explicit user confirmation"] {
            XCTAssertTrue(safetyText.contains(required), "Missing safety text for \(required)")
        }

        for forbidden in ["run silently", "without confirmation", "no confirmation needed", "mip authorizes", "package permission", "permission to execute", "apply changes automatically"] {
            XCTAssertFalse(safetyText.contains(forbidden), "Forbidden safety wording: \(forbidden)")
        }
    }

    func testAgentGuideConfirmStepNamesEverySideEffectClass() throws {
        let confirmStep = try XCTUnwrap(
            MindDeskAgentGuide.defaultGuide.workflowSteps.first { $0.id == "confirm" }
        )
        let instruction = confirmStep.instruction.lowercased()

        for required in ["file", "finder", "url", "clipboard", "terminal", "command", "alias", "import/export", "apply"] {
            XCTAssertTrue(instruction.contains(required), "Missing confirm-step safety text for \(required)")
        }
    }

    func testAgentGuideUsesValidationReportAsCanonicalDiagnostics() {
        let systemPrompt = MindDeskAgentGuide.defaultGuide.systemPrompt.lowercased()
        let guideText = normalizedText([
            MindDeskAgentGuide.defaultGuide.systemPrompt,
            MindDeskAgentGuide.defaultGuide.workflowSteps.map(\.instruction).joined(separator: " "),
            MindDeskAgentGuide.defaultGuide.customPromptGuidance.joined(separator: " ")
        ])

        for required in ["validationreport", "summary.isvalid", "errorcount"] {
            XCTAssertTrue(guideText.contains(required), "Missing validation report guidance: \(required)")
        }
        for required in ["code", "source", "details"] {
            XCTAssertTrue(containsWholeWord(required, in: guideText), "Missing validation report field: \(required)")
        }
        for required in ["proposal.context.stale", "contract.context.mismatch", "mismatchedfields"] {
            XCTAssertTrue(guideText.contains(required), "Missing validation report drift guidance: \(required)")
        }
        XCTAssertTrue(guideText.contains("validationissues"))
        XCTAssertTrue(guideText.contains("legacy") || guideText.contains("deprecated"))
        XCTAssertTrue(guideText.contains("not authorization"))
        for required in [
            "validationreport.redactionpolicy",
            "opaque token",
            "raw manifest record",
            "raw manifest records remain",
            "unknown manifest details",
            "non-manifest diagnostics",
            "package-local locator",
            "not a privacy boundary",
            "actualvaluetoken",
            "referenceidtoken",
            "proposalidtoken",
            "capabilityidtoken",
            "unexpectedbindingfieldstoken",
            "messages are static",
            "sha256-prefix-16"
        ] {
            XCTAssertTrue(guideText.contains(required), "Missing redaction policy guidance: \(required)")
        }
        XCTAssertTrue(systemPrompt.contains("manifest issue ownerid"))
        XCTAssertTrue(systemPrompt.contains("diagnostic fields are tokenized"))
        XCTAssertTrue(systemPrompt.contains("compatibility-only"))
        XCTAssertFalse(systemPrompt.contains("manifest ownerid"))
        for required in [
            "proposal context",
            "agentintegrationcontract.context",
            "packageinstanceid",
            "packagecreatedat",
            "manifestexportedat",
            "manifestdigest"
        ] {
            XCTAssertTrue(guideText.contains(required), "Missing proposal context guidance: \(required)")
        }
    }

    func testAgentGuideDefaultCustomPromptGuidanceNamesProposalJSONFieldTerminology() {
        let guidance = MindDeskAgentGuide.defaultGuide.customPromptGuidance
            .joined(separator: " ")
            .lowercased()

        for required in [
            "proposal json schema",
            "required proposal json fields",
            "accepted proposal json fields",
            "payloadfieldschemas",
            "not authorization",
            "not payload allowlists",
            "allowedpayloadfields"
        ] {
            XCTAssertTrue(guidance.contains(required), "Missing default custom prompt guidance: \(required)")
        }

        for forbidden in [
            "schema authorizes",
            "proposal json schema authorizes",
            "accepted proposal json fields are approved operations",
            "accepted proposal json fields are payload allowlists",
            "required proposal json fields permit execution",
            "authorization granted",
            "safe to execute",
            "ready to execute",
            "approval executes",
            "permission to execute"
        ] {
            XCTAssertFalse(guidance.contains(forbidden), "Forbidden default custom prompt guidance: \(forbidden)")
        }
    }

    func testAgentHelpTopicsUseValidationReportAsCanonicalDiagnostics() {
        let agentTopics = MindDeskHelpCatalog.defaultTopics.filter { $0.category == .agent }
        XCTAssertEqual(Set(agentTopics.map(\.id)), Set(["agent-readonly-mip", "agent-prompt-workflow", "agent-proposal-review", "agent-extension-capabilities"]))

        for topic in agentTopics {
            let topicText = normalizedText([topic.title, topic.summary, topic.bodyMarkdown])
            let keywordText = normalizedText(topic.keywords)
            XCTAssertTrue(topicText.contains("validationreport"), "Missing validationReport in \(topic.id)")
            for required in ["validationreport", "isvalid", "errorcount", "code", "source", "details", "redactionpolicy"] {
                XCTAssertTrue(keywordText.contains(required), "Missing help keyword \(required) in \(topic.id)")
            }
            for required in ["proposal.context.stale", "contract.context.mismatch", "mismatchedfields"] {
                XCTAssertTrue(keywordText.contains(required), "Missing help drift keyword \(required) in \(topic.id)")
            }
            for required in [
                "validationreport.redactionpolicy",
                "opaque token",
                "structured diagnostics",
                "raw manifest records remain",
                "non-manifest diagnostics",
                "package-local locator",
                "not a privacy boundary",
                "actualvaluetoken",
                "referenceidtoken",
                "proposalidtoken",
                "capabilityidtoken",
                "unexpectedbindingfieldstoken",
                "compatibility-only",
                "not authorization",
                "proposal context",
                "packageinstanceid",
                "packagecreatedat",
                "manifestexportedat",
                "manifestdigest",
                "proposal.context.stale",
                "contract.context.mismatch",
                "mismatchedfields"
            ] {
                XCTAssertTrue(topicText.contains(required), "Missing help text \(required) in \(topic.id)")
            }
        }

        let helpText = normalizedText(agentTopics.flatMap { [$0.bodyMarkdown] })
        XCTAssertTrue(helpText.contains("validationreport.summary.isvalid"))
        XCTAssertTrue(helpText.contains("validationreport.issues"))
        XCTAssertTrue(helpText.contains("validationreport.redactionpolicy"))
        XCTAssertTrue(helpText.contains("opaque token"))
        XCTAssertTrue(helpText.contains("path"))
        XCTAssertTrue(helpText.contains("structured diagnostics"))
        XCTAssertTrue(helpText.contains("raw manifest records remain"))
        XCTAssertTrue(helpText.contains("unknown manifest details"))
        XCTAssertTrue(helpText.contains("non-manifest diagnostics"))
        XCTAssertTrue(helpText.contains("actualvaluetoken"))
        XCTAssertTrue(helpText.contains("referenceidtoken"))
        XCTAssertTrue(helpText.contains("proposalidtoken"))
        XCTAssertTrue(helpText.contains("capabilityidtoken"))
        XCTAssertTrue(helpText.contains("unexpectedbindingfieldstoken"))
        XCTAssertTrue(helpText.contains("messages are static"))
        XCTAssertTrue(helpText.contains("sha256-prefix-16"))
        XCTAssertTrue(helpText.contains("validationissues"))
        XCTAssertTrue(helpText.contains("compatibility-only"))
        XCTAssertTrue(helpText.contains("legacy") || helpText.contains("deprecated"))
        XCTAssertTrue(helpText.contains("extensioncapabilities"))
        XCTAssertTrue(helpText.contains("extensioncapabilitycatalog"))
        XCTAssertTrue(helpText.contains("not authorization"))
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

    func testInterchangePackageWrapsManifestWithoutChangingManifestPayload() throws {
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
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Canvas")
            ],
            nodes: [],
            edges: [],
            aliases: [],
            todoGroups: [],
            todos: []
        )
        let package = MindDeskInterchangePackage(
            manifest: manifest,
            createdAt: Date(timeIntervalSince1970: 123),
            packageInstanceID: "package-instance"
        )

        let data = try JSONEncoder.minddesk.encode(package)
        let decoded = try JSONDecoder.minddesk.decode(MindDeskInterchangePackage.self, from: data)

        XCTAssertEqual(decoded.format, "minddesk.interchange.package")
        XCTAssertEqual(decoded.formatVersion, 1)
        XCTAssertEqual(decoded.packageInstanceID, "package-instance")
        XCTAssertEqual(decoded.manifest, manifest)
        XCTAssertEqual(decoded.summary.workspaces, 1)
        XCTAssertEqual(decoded.summary.resources, 1)
        XCTAssertTrue(String(data: data, encoding: .utf8)?.contains("\"manifest\"") == true)

        var missingPackageInstanceID = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        missingPackageInstanceID.removeValue(forKey: "packageInstanceID")
        XCTAssertThrowsError(
            try JSONDecoder.minddesk.decode(
                MindDeskInterchangePackage.self,
                from: JSONSerialization.data(withJSONObject: missingPackageInstanceID)
            )
        ) { error in
            let errorText = String(describing: error)
            XCTAssertFalse(errorText.contains("legacy"))
            XCTAssertFalse(errorText.contains("package-instance"))
        }
    }

    func testInterchangePackageIncludesAgentGuideAndSafetyPolicy() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )
        let package = MindDeskInterchangePackage(manifest: manifest, createdAt: Date(timeIntervalSince1970: 0))

        XCTAssertTrue(package.agentGuide.systemPrompt.contains("read-only"))
        XCTAssertTrue(package.agentGuide.workflowSteps.map(\.id).contains("search-help"))
        let searchHelpInstruction = package.agentGuide.workflowSteps.first { $0.id == "search-help" }?.instruction.lowercased()
        XCTAssertTrue(searchHelpInstruction?.contains("helptopics") == true)
        XCTAssertTrue(searchHelpInstruction?.contains("runtime-search") == true)
        XCTAssertTrue(searchHelpInstruction?.contains("not authorization") == true)
        XCTAssertTrue(package.agentGuide.workflowSteps.map(\.id).contains("propose-actions"))
        XCTAssertTrue(package.agentGuide.workflowSteps.first { $0.id == "inspect" }?.instruction.contains("validationReport") == true)
        let customPromptGuidance = package.agentGuide.customPromptGuidance.joined(separator: " ")
        XCTAssertTrue(customPromptGuidance.contains("validationReport"))
        XCTAssertTrue(customPromptGuidance.contains("MindDesk Proposal Review"))
        XCTAssertTrue(customPromptGuidance.contains("immediate in-app confirmation"))
        XCTAssertTrue(customPromptGuidance.contains("outside the proposal review sheet"))
        XCTAssertEqual(package.agentPolicy.allowedDefaultAgentActions, [.readAgentContext, .proposeAgentAction])
        XCTAssertTrue(package.agentPolicy.confirmationRequiredActions.contains(.runCommand))
        XCTAssertTrue(package.agentPolicy.confirmationRequiredActions.contains(.openTerminal))
        XCTAssertTrue(package.agentPolicy.deniedDefaultAgentActions.contains(.openURL))
        XCTAssertTrue(package.agentPolicy.deniedDefaultAgentActions.contains(.applyAgentAction))
    }

    func testInterchangePackageDescribesPrivacyBoundaries() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [
                ResourceRecord(id: "resource", workspaceId: nil, title: "Project", targetType: "folder", displayPath: "/Users/example/Project", lastResolvedPath: "/Users/example/Project", note: "", tags: [], scope: "global", status: "available", lastOpenedAt: Date(timeIntervalSince1970: 50))
            ],
            snippets: [
                SnippetRecord(id: "snippet", workspaceId: nil, title: "Prompt", kind: "prompt", body: "Summarize", details: "", tags: [], scope: "global", workingDirectoryRef: nil, requiresConfirmation: false, lastCopiedAt: Date(timeIntervalSince1970: 60), lastUsedAt: Date(timeIntervalSince1970: 70))
            ],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )
        let package = MindDeskInterchangePackage(manifest: manifest, createdAt: Date(timeIntervalSince1970: 0))

        XCTAssertTrue(package.privacy.includesPaths)
        XCTAssertTrue(package.privacy.includesPromptBodies)
        XCTAssertTrue(package.privacy.includesUsageDates)
        XCTAssertTrue(package.privacy.neverIncludes.contains("security-scoped bookmarks"))
        XCTAssertTrue(package.privacy.neverIncludes.contains("raw file contents"))
        XCTAssertTrue(package.privacy.redactionNotes.contains("Bookmark authorization data is never exported."))
        let privacyText = package.privacy.redactionNotes.joined(separator: " ").lowercased()
        for required in [
            "web urls",
            "alias paths",
            "task text",
            "canvas text",
            "command snippets",
            "search text",
            "validationreport redaction applies only to structured diagnostics",
            "raw manifest records remain"
        ] {
            XCTAssertTrue(privacyText.contains(required), "Missing privacy note for \(required)")
        }
    }

    func testInterchangePackageDecodingRecomputesDerivedAdvisoryFields() throws {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [
                ResourceRecord(id: "resource", workspaceId: nil, title: "Project", targetType: "folder", displayPath: "/Users/example/Project", lastResolvedPath: "/Users/example/Project", note: "", tags: [], scope: "global", status: "available")
            ],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )
        let package = MindDeskInterchangePackage(manifest: manifest, createdAt: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder.minddesk.encode(package)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var summary = try XCTUnwrap(json["summary"] as? [String: Any])
        summary["resources"] = 99
        summary["validationIssues"] = ["tampered"]
        json["summary"] = summary
        var privacy = try XCTUnwrap(json["privacy"] as? [String: Any])
        privacy["includesPaths"] = false
        json["privacy"] = privacy
        var agentPolicy = try XCTUnwrap(json["agentPolicy"] as? [String: Any])
        agentPolicy["allowedDefaultAgentActions"] = ["runCommand"]
        json["agentPolicy"] = agentPolicy
        let tamperedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder.minddesk.decode(MindDeskInterchangePackage.self, from: tamperedData)

        XCTAssertEqual(decoded.summary, MindDeskInterchangeSummary(manifest: manifest))
        XCTAssertTrue(decoded.privacy.includesPaths)
        XCTAssertEqual(decoded.agentPolicy.allowedDefaultAgentActions, [.readAgentContext, .proposeAgentAction])
        XCTAssertEqual(decoded.externalActionPolicy.decision(for: .runCommand, actor: .defaultAgent), .deny)
        XCTAssertEqual(decoded.validationIssues, [])
    }

    func testInterchangePackageSummarizesValidationIssuesForReview() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "missing-workspace", title: "Canvas")
            ],
            nodes: [],
            edges: [],
            aliases: []
        )
        let package = MindDeskInterchangePackage(manifest: manifest, createdAt: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(package.summary.canvases, 1)
        XCTAssertTrue(package.summary.validationIssues.contains("Canvas canvas references missing workspace missing-workspace."))
    }

    func testInterchangePackageValidationReportsStructuredManifestIssuesAndStaleSummary() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "missing-workspace", title: "Canvas")
            ],
            nodes: [],
            edges: [],
            aliases: []
        )
        var package = MindDeskInterchangePackage(manifest: manifest, createdAt: Date(timeIntervalSince1970: 0))
        package.summary.canvases = 0

        let issues = MindDeskInterchangePackageValidation.issues(in: package)

        XCTAssertTrue(
            issues.contains(
                MindDeskInterchangeValidationIssue(source: .package, severity: .warning, message: "Package summary does not match manifest contents.")
            )
        )
        XCTAssertTrue(
            issues.contains(
                MindDeskInterchangeValidationIssue(source: .manifest, severity: .error, message: "Canvas canvas references missing workspace missing-workspace.")
            )
        )
    }

    func testInterchangePackageValidationRejectsUnsupportedFormatVersion() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )
        var package = MindDeskInterchangePackage(manifest: manifest, createdAt: Date(timeIntervalSince1970: 0))
        package.formatVersion = 999

        XCTAssertTrue(
            MindDeskInterchangePackageValidation.issues(in: package).contains(
                MindDeskInterchangeValidationIssue(source: .package, severity: .error, message: "Unsupported interchange package format version 999.")
            )
        )
    }

    func testInterchangeExternalActionPolicySnapshotMatchesWorkbenchPolicy() {
        let policy = MindDeskInterchangeExternalActionPolicy.current

        for actor in WorkbenchExternalActor.allCases {
            for action in WorkbenchExternalAction.allCases {
                XCTAssertEqual(
                    policy.decision(for: action, actor: actor),
                    WorkbenchExternalActionPolicy.decision(for: action, actor: actor)
                )
            }
        }
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
                ResourceRecord(id: "resource", workspaceId: nil, title: "Shared", targetType: "folder", displayPath: "/tmp/Shared", lastResolvedPath: "/tmp/Shared", note: "", tags: [], scope: "global", status: "available"),
                ResourceRecord(id: "workspace-resource", workspaceId: "workspace", title: "Private", targetType: "folder", displayPath: "/tmp/Private", lastResolvedPath: "/tmp/Private", note: "", tags: [], scope: "workspace", status: "available")
            ],
            snippets: [
                SnippetRecord(id: "snippet", workspaceId: nil, title: "Shared Prompt", kind: "prompt", body: "Body", details: "", tags: [], scope: "global", workingDirectoryRef: "workspace-resource", requiresConfirmation: false),
                SnippetRecord(id: "workspace-snippet", workspaceId: "workspace", title: "Private Prompt", kind: "prompt", body: "Body", details: "", tags: [], scope: "workspace", workingDirectoryRef: nil, requiresConfirmation: false)
            ],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Canvas")
            ],
            nodes: [
                CanvasNodeRecord(id: "node", canvasId: "canvas", title: "Node", body: "", nodeType: "resource", objectType: "resourcePin", objectId: "workspace-resource", x: 0, y: 0, width: 180, height: 120)
            ],
            edges: [
                CanvasEdgeRecord(id: "edge", canvasId: "canvas", sourceNodeId: "node", targetNodeId: "node", label: "")
            ],
            aliases: [
                AliasRecord(id: "alias", sourceObjectType: "resourcePin", sourceObjectId: "workspace-resource", aliasDisplayPath: "/tmp/alias", status: "created")
            ],
            todoGroups: [
                TodoGroupRecord(id: "group", workspaceId: "workspace", title: "Tasks", isPinned: false, sortIndex: 0)
            ],
            todos: [
                TodoRecord(id: "todo", workspaceId: "workspace", groupId: "group", title: "Task", details: "", isCompleted: false, isPinned: false, sortIndex: 0, linkedResourceId: "resource")
            ]
        )

        let scoped = ExportManifestScopePolicy.manifest(from: manifest, scope: .globalLibraryOnly)

        XCTAssertEqual(scoped.resources.map(\.id), ["resource"])
        XCTAssertEqual(scoped.snippets.map(\.id), ["snippet"])
        XCTAssertNil(scoped.snippets.first?.workingDirectoryRef)
        XCTAssertTrue(scoped.workspaces.isEmpty)
        XCTAssertTrue(scoped.canvases.isEmpty)
        XCTAssertTrue(scoped.nodes.isEmpty)
        XCTAssertTrue(scoped.edges.isEmpty)
        XCTAssertTrue(scoped.aliases.isEmpty)
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

    func testManifestImportValidationReportsUnsupportedSchemaVersionConsistently() {
        let manifest = ExportManifest(
            schemaVersion: 3,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )

        XCTAssertEqual(
            ManifestImportValidation.issues(in: manifest),
            ["Unsupported manifest schema version 3."]
        )

        let diagnostics = ManifestImportValidation.diagnostics(in: manifest)
        XCTAssertEqual(diagnostics.map(\.code), ["manifest.schema.unsupported-version"])
        XCTAssertEqual(diagnostics.first?.legacyMessage, "Unsupported manifest schema version 3.")
    }

    func testManifestImportValidationDiagnosticsProvideStableMachineReadableReferences() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [
                ResourceRecord(id: "resource", workspaceId: "missing-workspace", title: "File", targetType: "file", displayPath: "/tmp/file", lastResolvedPath: "/tmp/file", note: "", tags: [], scope: "workspace", status: "available")
            ],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "missing-workspace", title: "Map")
            ],
            nodes: [],
            edges: [],
            aliases: []
        )

        let diagnostics = ManifestImportValidation.diagnostics(in: manifest)

        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.missing" &&
                diagnostic.ownerKind == "resource" &&
                diagnostic.ownerID == "resource" &&
                diagnostic.field == "workspaceId" &&
                diagnostic.path == "/manifest/resources/0/workspaceId" &&
                diagnostic.details["referencedOwnerKind"] == "workspace" &&
                diagnostic.details["referencedOwnerID"] == "missing-workspace" &&
                diagnostic.legacyMessage == "Resource resource references missing workspace missing-workspace."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.missing" &&
                diagnostic.ownerKind == "canvas" &&
                diagnostic.ownerID == "canvas" &&
                diagnostic.field == "workspaceId" &&
                diagnostic.path == "/manifest/canvases/0/workspaceId" &&
                diagnostic.details["referencedOwnerKind"] == "workspace" &&
                diagnostic.details["referencedOwnerID"] == "missing-workspace" &&
                diagnostic.legacyMessage == "Canvas canvas references missing workspace missing-workspace."
        })
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

    func testManifestImportValidationDiagnosticsProvideStableDuplicateIDs() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "One", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil),
                WorkspaceRecord(id: "workspace", title: "Two", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )

        let diagnostics = ManifestImportValidation.diagnostics(in: manifest)

        XCTAssertTrue(diagnostics.contains { diagnostic in
                diagnostic.code == "manifest.id.duplicate" &&
                diagnostic.ownerKind == "workspace" &&
                diagnostic.ownerID == "workspace" &&
                diagnostic.field == "id" &&
                diagnostic.path == "/manifest/workspaces/1/id" &&
                diagnostic.details["duplicateID"] == "workspace" &&
                diagnostic.details["count"] == "2" &&
                diagnostic.details["firstIndex"] == "0" &&
                diagnostic.details["duplicateIndex"] == "1" &&
                diagnostic.details["indexes"] == "0,1" &&
                diagnostic.legacyMessage == "Duplicate workspace id workspace."
        })
        XCTAssertEqual(ManifestImportValidation.issues(in: manifest), ["Duplicate workspace id workspace."])
    }

    func testManifestImportValidationDiagnosticsPreserveDuplicateSecondOccurrenceOrderAndIndexes() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "a", title: "A1", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil),
                WorkspaceRecord(id: "b", title: "B1", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil),
                WorkspaceRecord(id: "b", title: "B2", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil),
                WorkspaceRecord(id: "a", title: "A2", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [],
            snippets: [],
            canvases: [],
            nodes: [],
            edges: [],
            aliases: []
        )

        let issues = ManifestImportValidation.issues(in: manifest)
        let diagnostics = ManifestImportValidation.diagnostics(in: manifest)
            .filter { $0.code == "manifest.id.duplicate" }

        XCTAssertEqual(issues, [
            "Duplicate workspace id b.",
            "Duplicate workspace id a."
        ])
        XCTAssertEqual(diagnostics.map(\.legacyMessage), issues)
        XCTAssertEqual(diagnostics.map(\.path), [
            "/manifest/workspaces/2/id",
            "/manifest/workspaces/3/id"
        ])
        XCTAssertEqual(diagnostics.map { $0.details["firstIndex"] }, ["1", "0"])
        XCTAssertEqual(diagnostics.map { $0.details["duplicateIndex"] }, ["2", "3"])
        XCTAssertEqual(diagnostics.map { $0.details["indexes"] }, ["1,2", "0,3"])
    }

    func testManifestImportValidationDiagnosticsProvideStableCommonStructuralIssues() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "", workspaceId: nil, title: "Missing ID", targetType: "file", displayPath: "/tmp/missing-id", lastResolvedPath: "/tmp/missing-id", note: "", tags: [], scope: "global", status: "available"),
                ResourceRecord(id: "bad-type", workspaceId: nil, title: "Bad Type", targetType: "package", displayPath: "/tmp/bad", lastResolvedPath: "/tmp/bad", note: "", tags: [], scope: "global", status: "available"),
                ResourceRecord(id: "file-resource", workspaceId: "workspace", title: "File", targetType: "file", displayPath: "/tmp/file", lastResolvedPath: "/tmp/file", note: "", tags: [], scope: "workspace", status: "available")
            ],
            snippets: [
                SnippetRecord(id: "snippet", workspaceId: "workspace", title: "Command", kind: "command", body: "pwd", details: "", tags: [], scope: "workspace", workingDirectoryRef: "file-resource", requiresConfirmation: true)
            ],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Canvas")
            ],
            nodes: [
                CanvasNodeRecord(id: "small-node", canvasId: "canvas", title: "Small", body: "", nodeType: "note", objectType: nil, objectId: nil, x: 0, y: 0, width: 8, height: 120)
            ],
            edges: [],
            aliases: []
        )

        let diagnostics = ManifestImportValidation.diagnostics(in: manifest)

        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.id.empty" &&
                diagnostic.ownerKind == "resource" &&
                diagnostic.ownerID == nil &&
                diagnostic.field == "id" &&
                diagnostic.path == "/manifest/resources/0/id" &&
                diagnostic.legacyMessage == "Resource has empty id."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.field.unsupported-value" &&
                diagnostic.ownerKind == "resource" &&
                diagnostic.ownerID == "bad-type" &&
                diagnostic.field == "targetType" &&
                diagnostic.path == "/manifest/resources/1/targetType" &&
                diagnostic.details["actual"] == "package" &&
                diagnostic.details["allowedValues"] == "file,folder" &&
                diagnostic.legacyMessage == "Resource bad-type has unsupported target type package."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.unsupported-target" &&
                diagnostic.ownerKind == "snippet" &&
                diagnostic.ownerID == "snippet" &&
                diagnostic.field == "workingDirectoryRef" &&
                diagnostic.path == "/manifest/snippets/0/workingDirectoryRef" &&
                diagnostic.details["referencedOwnerKind"] == "resource" &&
                diagnostic.details["referencedOwnerID"] == "file-resource" &&
                diagnostic.details["expectedTargetType"] == "folder" &&
                diagnostic.details["actualTargetType"] == "file" &&
                diagnostic.legacyMessage == "Snippet snippet working directory file-resource is not a folder resource."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.range.out-of-bounds" &&
                diagnostic.ownerKind == "node" &&
                diagnostic.ownerID == "small-node" &&
                diagnostic.field == "width" &&
                diagnostic.path == "/manifest/nodes/0/width" &&
                diagnostic.details["actualNumber"] == "8.0" &&
                diagnostic.details["minimum"] == String(ManifestImportLimits.minimumNodeSize) &&
                diagnostic.details["maximum"] == String(ManifestImportLimits.maximumNodeSize) &&
                diagnostic.legacyMessage == "Node small-node has width outside the supported range."
        })

        let typedLegacyMessages = Set(diagnostics.filter { $0.code != "manifest.import.issue" }.map(\.legacyMessage))
        let fallbackMessages = Set(diagnostics.filter { $0.code == "manifest.import.issue" }.map(\.legacyMessage))
        for message in typedLegacyMessages {
            XCTAssertFalse(fallbackMessages.contains(message), "Typed diagnostic also fell back to manifest.import.issue: \(message)")
        }
    }

    func testManifestImportValidationDiagnosticsProvideStableObjectAliasAndParentSemanticIssues() {
        let manifest = ExportManifest(
            schemaVersion: 2,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "resource", workspaceId: "workspace", title: "Resource", targetType: "folder", displayPath: "/tmp/resource", lastResolvedPath: "/tmp/resource", note: "", tags: [], scope: "workspace", status: "available")
            ],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Canvas")
            ],
            nodes: [
                CanvasNodeRecord(id: "note-parent", canvasId: "canvas", title: "Parent", body: "", nodeType: "note", objectType: nil, objectId: nil, x: 0, y: 0, width: 180, height: 120),
                CanvasNodeRecord(id: "child", canvasId: "canvas", title: "Child", body: "", nodeType: "note", objectType: nil, objectId: nil, x: 0, y: 160, width: 180, height: 120, parentNodeId: "note-parent"),
                CanvasNodeRecord(id: "bad-web", canvasId: "canvas", title: "Bad Web", body: "javascript:alert(1)", nodeType: "snippet", objectType: "webURL", objectId: nil, x: 220, y: 0, width: 180, height: 120),
                CanvasNodeRecord(id: "bad-object", canvasId: "canvas", title: "Bad Object", body: "", nodeType: "note", objectType: "resourcePin", objectId: "resource", x: 440, y: 0, width: 180, height: 120),
                CanvasNodeRecord(id: "missing-object", canvasId: "canvas", title: "Missing Object", body: "", nodeType: "resource", objectType: "resourcePin", objectId: nil, x: 660, y: 0, width: 180, height: 120),
                CanvasNodeRecord(id: "frame-a", canvasId: "canvas", title: "Frame A", body: "", nodeType: "groupFrame", objectType: nil, objectId: nil, x: 0, y: 320, width: 260, height: 200, parentNodeId: "frame-b"),
                CanvasNodeRecord(id: "frame-b", canvasId: "canvas", title: "Frame B", body: "", nodeType: "groupFrame", objectType: nil, objectId: nil, x: 300, y: 320, width: 260, height: 200, parentNodeId: "frame-a"),
                CanvasNodeRecord(id: "whitespace-object", canvasId: "canvas", title: "Whitespace Object", body: "", nodeType: "resource", objectType: "resourcePin", objectId: " resource ", x: 600, y: 320, width: 180, height: 120),
                CanvasNodeRecord(id: "blank-object", canvasId: "canvas", title: "Blank Object", body: "", nodeType: "resource", objectType: "resourcePin", objectId: "   ", x: 820, y: 320, width: 180, height: 120)
            ],
            edges: [],
            aliases: [
                AliasRecord(id: "bad-alias", sourceObjectType: "workspace", sourceObjectId: "workspace", aliasDisplayPath: "/tmp/alias", status: "created"),
                AliasRecord(id: "empty-alias", sourceObjectType: "resourcePin", sourceObjectId: "", aliasDisplayPath: "/tmp/empty-alias", status: "created"),
                AliasRecord(id: "whitespace-alias", sourceObjectType: "resourcePin", sourceObjectId: " resource ", aliasDisplayPath: "/tmp/whitespace-alias", status: "created"),
                AliasRecord(id: "blank-alias", sourceObjectType: "resourcePin", sourceObjectId: "   ", aliasDisplayPath: "/tmp/blank-alias", status: "created")
            ]
        )

        let diagnostics = ManifestImportValidation.diagnostics(in: manifest)

        XCTAssertFalse(diagnostics.contains { $0.code == "manifest.import.issue" })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.unsupported-target" &&
                diagnostic.ownerKind == "node" &&
                diagnostic.ownerID == "child" &&
                diagnostic.field == "parentNodeId" &&
                diagnostic.path == "/manifest/nodes/1/parentNodeId" &&
                diagnostic.details["referencedOwnerKind"] == "node" &&
                diagnostic.details["referencedOwnerID"] == "note-parent" &&
                diagnostic.details["expectedTargetType"] == "groupFrame" &&
                diagnostic.details["actualTargetType"] == "note" &&
                diagnostic.legacyMessage == "Node child references parent node note-parent that is not a frame."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.invalid-url" &&
                diagnostic.ownerKind == "node" &&
                diagnostic.ownerID == "bad-web" &&
                diagnostic.field == "body" &&
                diagnostic.path == "/manifest/nodes/2/body" &&
                diagnostic.details["objectType"] == "webURL" &&
                diagnostic.details["sourceField"] == "body" &&
                diagnostic.details["allowedSchemes"] == "http,https" &&
                diagnostic.legacyMessage == "Node bad-web references invalid web URL."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.incompatible" &&
                diagnostic.ownerKind == "node" &&
                diagnostic.ownerID == "bad-object" &&
                diagnostic.field == "objectType" &&
                diagnostic.path == "/manifest/nodes/3/objectType" &&
                diagnostic.details["nodeType"] == "note" &&
                diagnostic.details["objectType"] == "resourcePin" &&
                diagnostic.legacyMessage == "Node bad-object with node type note cannot reference object type resourcePin."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.id-required" &&
                diagnostic.ownerKind == "node" &&
                diagnostic.ownerID == "missing-object" &&
                diagnostic.field == "objectId" &&
                diagnostic.path == "/manifest/nodes/4/objectId" &&
                diagnostic.details["objectType"] == "resourcePin" &&
                diagnostic.details["reason"] == "missing" &&
                diagnostic.legacyMessage == "Node missing-object has object type resourcePin without an object id."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.node.parent.cycle" &&
                diagnostic.ownerKind == "node" &&
                diagnostic.ownerID == "frame-a" &&
                diagnostic.field == "parentNodeId" &&
                diagnostic.path == "/manifest/nodes/5/parentNodeId" &&
                diagnostic.details["canvasID"] == "canvas" &&
                diagnostic.details["reportedNodeID"] == "frame-a" &&
                diagnostic.legacyMessage == "Canvas canvas has a cyclic frame parent relationship involving node frame-a."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.id-whitespace" &&
                diagnostic.ownerKind == "node" &&
                diagnostic.ownerID == "whitespace-object" &&
                diagnostic.field == "objectId" &&
                diagnostic.path == "/manifest/nodes/7/objectId" &&
                diagnostic.details["objectType"] == "resourcePin" &&
                diagnostic.details["normalizedReferenceIDLength"] == "8" &&
                diagnostic.legacyMessage == "Node whitespace-object has object id with leading or trailing whitespace."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.id-required" &&
                diagnostic.ownerKind == "node" &&
                diagnostic.ownerID == "whitespace-object" &&
                diagnostic.field == "objectId" &&
                diagnostic.path == "/manifest/nodes/7/objectId" &&
                diagnostic.details["objectType"] == "resourcePin" &&
                diagnostic.details["reason"] == "invalidWhitespace" &&
                diagnostic.legacyMessage == "Node whitespace-object has object type resourcePin without an object id."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.id-required" &&
                diagnostic.ownerKind == "node" &&
                diagnostic.ownerID == "blank-object" &&
                diagnostic.field == "objectId" &&
                diagnostic.path == "/manifest/nodes/8/objectId" &&
                diagnostic.details["objectType"] == "resourcePin" &&
                diagnostic.details["reason"] == "empty" &&
                diagnostic.legacyMessage == "Node blank-object has object type resourcePin without an object id."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.alias.source-type.unsupported" &&
                diagnostic.ownerKind == "alias" &&
                diagnostic.ownerID == "bad-alias" &&
                diagnostic.field == "sourceObjectType" &&
                diagnostic.path == "/manifest/aliases/0/sourceObjectType" &&
                diagnostic.details["allowedSourceObjectTypes"] == "resourcePin,snippet" &&
                diagnostic.legacyMessage == "Alias bad-alias has unsupported source object type workspace."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.id-required" &&
                diagnostic.ownerKind == "alias" &&
                diagnostic.ownerID == "empty-alias" &&
                diagnostic.field == "sourceObjectId" &&
                diagnostic.path == "/manifest/aliases/1/sourceObjectId" &&
                diagnostic.details["sourceObjectType"] == "resourcePin" &&
                diagnostic.details["reason"] == "empty" &&
                diagnostic.legacyMessage == "Alias empty-alias has empty source object id."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.id-whitespace" &&
                diagnostic.ownerKind == "alias" &&
                diagnostic.ownerID == "whitespace-alias" &&
                diagnostic.field == "sourceObjectId" &&
                diagnostic.path == "/manifest/aliases/2/sourceObjectId" &&
                diagnostic.details["sourceObjectType"] == "resourcePin" &&
                diagnostic.details["normalizedReferenceIDLength"] == "8" &&
                diagnostic.legacyMessage == "Alias whitespace-alias has source object id with leading or trailing whitespace."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.id-required" &&
                diagnostic.ownerKind == "alias" &&
                diagnostic.ownerID == "whitespace-alias" &&
                diagnostic.field == "sourceObjectId" &&
                diagnostic.path == "/manifest/aliases/2/sourceObjectId" &&
                diagnostic.details["sourceObjectType"] == "resourcePin" &&
                diagnostic.details["reason"] == "invalidWhitespace" &&
                diagnostic.legacyMessage == "Alias whitespace-alias has empty source object id."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.id-required" &&
                diagnostic.ownerKind == "alias" &&
                diagnostic.ownerID == "blank-alias" &&
                diagnostic.field == "sourceObjectId" &&
                diagnostic.path == "/manifest/aliases/3/sourceObjectId" &&
                diagnostic.details["sourceObjectType"] == "resourcePin" &&
                diagnostic.details["reason"] == "empty" &&
                diagnostic.legacyMessage == "Alias blank-alias has empty source object id."
        })

        let typedLegacyMessages = Set(diagnostics.filter { $0.code != "manifest.import.issue" }.map(\.legacyMessage))
        let fallbackMessages = Set(diagnostics.filter { $0.code == "manifest.import.issue" }.map(\.legacyMessage))
        for message in typedLegacyMessages {
            XCTAssertFalse(fallbackMessages.contains(message), "Typed diagnostic also fell back to manifest.import.issue: \(message)")
        }
    }

    func testManifestImportValidationDiagnosticsPreserveLegacyIssueOrderForMixedTypedAndFallbackIssues() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [],
            resources: [],
            snippets: [],
            canvases: [
                CanvasRecord(
                    id: "canvas",
                    workspaceId: "missing-workspace",
                    title: String(repeating: "x", count: ManifestImportLimits.maximumTextLength + 1)
                )
            ],
            nodes: [],
            edges: [],
            aliases: []
        )

        XCTAssertEqual(
            ManifestImportValidation.diagnostics(in: manifest).map(\.legacyMessage),
            ManifestImportValidation.issues(in: manifest)
        )
    }

    func testManifestImportValidationDiagnosticsUseRawObjectTypeCompatibility() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "resource", workspaceId: nil, title: "Resource", targetType: "file", displayPath: "/tmp/file", lastResolvedPath: "/tmp/file", note: "", tags: [], scope: "global", status: "available")
            ],
            snippets: [],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Canvas")
            ],
            nodes: [
                CanvasNodeRecord(id: "raw-object", canvasId: "canvas", title: "Raw Object", body: "", nodeType: "resource", objectType: " resourcePin ", objectId: "resource", x: 0, y: 0, width: 180, height: 120)
            ],
            edges: [],
            aliases: []
        )

        let issues = ManifestImportValidation.issues(in: manifest)
        let diagnostics = ManifestImportValidation.diagnostics(in: manifest)

        XCTAssertTrue(issues.contains("Node raw-object has unsupported object type  resourcePin ."))
        XCTAssertTrue(issues.contains("Node raw-object with node type resource cannot reference object type  resourcePin ."))
        XCTAssertFalse(diagnostics.contains { $0.code == "manifest.import.issue" })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.field.unsupported-value" &&
                diagnostic.ownerKind == "node" &&
                diagnostic.ownerID == "raw-object" &&
                diagnostic.field == "objectType" &&
                diagnostic.path == "/manifest/nodes/0/objectType" &&
                diagnostic.details["actual"] == " resourcePin " &&
                diagnostic.legacyMessage == "Node raw-object has unsupported object type  resourcePin ."
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.code == "manifest.reference.incompatible" &&
                diagnostic.ownerKind == "node" &&
                diagnostic.ownerID == "raw-object" &&
                diagnostic.field == "objectType" &&
                diagnostic.path == "/manifest/nodes/0/objectType" &&
                diagnostic.details["objectTypeStatus"] == "unsupported" &&
                diagnostic.legacyMessage == "Node raw-object with node type resource cannot reference object type  resourcePin ."
        })
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

    func testManifestImportValidationRejectsParentCycles() {
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
                CanvasNodeRecord(id: "frame-a", canvasId: "canvas", title: "A", body: "", nodeType: "groupFrame", objectType: nil, objectId: nil, x: 0, y: 0, width: 300, height: 240, parentNodeId: "frame-b"),
                CanvasNodeRecord(id: "frame-b", canvasId: "canvas", title: "B", body: "", nodeType: "groupFrame", objectType: nil, objectId: nil, x: 20, y: 20, width: 300, height: 240, parentNodeId: "frame-a")
            ],
            edges: [],
            aliases: []
        )

        XCTAssertTrue(
            ManifestImportValidation.issues(in: manifest).contains("Canvas canvas has a cyclic frame parent relationship involving node frame-a.")
        )
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

    func testManifestImportValidationRejectsNodeObjectTypeMismatches() {
        let manifest = ExportManifest(
            schemaVersion: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            workspaces: [
                WorkspaceRecord(id: "workspace", title: "Workspace", details: "", createdAt: .distantPast, updatedAt: .distantPast, lastOpenedAt: nil)
            ],
            resources: [
                ResourceRecord(id: "resource", workspaceId: nil, title: "Resource", targetType: "file", displayPath: "/tmp/file", lastResolvedPath: "/tmp/file", note: "", tags: [], scope: "global", status: "available")
            ],
            snippets: [
                SnippetRecord(id: "snippet", workspaceId: nil, title: "Snippet", kind: "prompt", body: "Body", details: "", tags: [], scope: "global", workingDirectoryRef: nil, requiresConfirmation: false)
            ],
            canvases: [
                CanvasRecord(id: "canvas", workspaceId: "workspace", title: "Canvas")
            ],
            nodes: [
                CanvasNodeRecord(id: "note-ref", canvasId: "canvas", title: "Note", body: "", nodeType: "note", objectType: "resourcePin", objectId: "resource", x: 0, y: 0, width: 180, height: 120),
                CanvasNodeRecord(id: "frame-ref", canvasId: "canvas", title: "Frame", body: "", nodeType: "groupFrame", objectType: "snippet", objectId: "snippet", x: 220, y: 0, width: 260, height: 200),
                CanvasNodeRecord(id: "resource-web", canvasId: "canvas", title: "Resource Web", body: "example.com", nodeType: "resource", objectType: "webURL", objectId: nil, x: 0, y: 160, width: 180, height: 120),
                CanvasNodeRecord(id: "snippet-resource", canvasId: "canvas", title: "Snippet Resource", body: "", nodeType: "snippet", objectType: "resourcePin", objectId: "resource", x: 220, y: 160, width: 180, height: 120)
            ],
            edges: [],
            aliases: []
        )

        let issues = ManifestImportValidation.issues(in: manifest)

        XCTAssertTrue(issues.contains("Node note-ref with node type note cannot reference object type resourcePin."))
        XCTAssertTrue(issues.contains("Node frame-ref with node type groupFrame cannot reference object type snippet."))
        XCTAssertTrue(issues.contains("Node resource-web with node type resource cannot reference object type webURL."))
        XCTAssertTrue(issues.contains("Node snippet-resource with node type snippet cannot reference object type resourcePin."))
    }

    func testWorkbenchObjectReferenceNormalizesLegacyCanvasReferences() {
        let reference = WorkbenchObjectReference.fromLegacy(objectType: " resourcePin ", objectId: " resource ", body: "")

        XCTAssertEqual(
            reference,
            WorkbenchObjectReference(kind: .resourcePin, id: "resource")
        )
        XCTAssertEqual(reference?.objectType, "resourcePin")
        XCTAssertEqual(reference?.objectId, "resource")
        XCTAssertNil(WorkbenchObjectReference(kind: .snippet, id: " "))
        XCTAssertEqual(
            WorkbenchObjectReference.fromLegacy(objectType: "webURL", objectId: nil, body: "example.com")?.id,
            "https://example.com"
        )
        XCTAssertNil(WorkbenchObjectReference.fromLegacy(objectType: "webURL", objectId: "javascript:alert(1)", body: ""))
        XCTAssertNil(WorkbenchObjectReference.fromLegacy(objectType: nil, objectId: "resource", body: ""))
        XCTAssertNil(WorkbenchObjectReference.fromLegacy(objectType: "resourcePin", objectId: " ", body: ""))
        XCTAssertNil(WorkbenchObjectReference.fromLegacy(objectType: "unknown", objectId: "object", body: ""))
    }

    func testWorkbenchObjectReferenceCompatibilityMatchesCanvasNodeRules() {
        XCTAssertEqual(
            WorkbenchObjectReferencePolicy.importableCanvasObjectTypes,
            Set(["resourcePin", "snippet", "workspace", "webURL"])
        )
        XCTAssertEqual(
            WorkbenchObjectReferencePolicy.importableAliasSourceTypes,
            Set(["resourcePin", "snippet"])
        )
        XCTAssertTrue(WorkbenchObjectReferencePolicy.isCompatible(nodeType: "resource", objectKind: .resourcePin))
        XCTAssertTrue(WorkbenchObjectReferencePolicy.isCompatible(nodeType: "snippet", objectKind: .snippet))
        XCTAssertTrue(WorkbenchObjectReferencePolicy.isCompatible(nodeType: "snippet", objectKind: .workspace))
        XCTAssertTrue(WorkbenchObjectReferencePolicy.isCompatible(nodeType: "snippet", objectKind: .webURL))

        XCTAssertFalse(WorkbenchObjectReferencePolicy.isCompatible(nodeType: "resource", objectKind: .webURL))
        XCTAssertFalse(WorkbenchObjectReferencePolicy.isCompatible(nodeType: "snippet", objectKind: .resourcePin))
        XCTAssertFalse(WorkbenchObjectReferencePolicy.isCompatible(nodeType: "note", objectKind: .resourcePin))
        XCTAssertFalse(WorkbenchObjectReferencePolicy.isCompatible(nodeType: "groupFrame", objectKind: .snippet))
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

    func testResourceRenamePolicyPreservesClearedCustomName() {
        let renamed = ResourceRenamePolicy.fields(
            titleInput: "  Project Docs  ",
            note: "Updated note",
            originalName: "Docs"
        )
        let cleared = ResourceRenamePolicy.fields(
            titleInput: "   ",
            note: "Keep note",
            originalName: "Docs"
        )

        XCTAssertEqual(renamed.title, "Project Docs")
        XCTAssertEqual(renamed.customName, "Project Docs")
        XCTAssertEqual(renamed.note, "Updated note")
        XCTAssertEqual(cleared.title, "Docs")
        XCTAssertEqual(cleared.customName, "")
        XCTAssertEqual(cleared.note, "Keep note")
    }

    func testAliasImportSourceMapperUsesSourceTypeWhenIdsOverlap() {
        let resourceMap = ["shared": "new-resource"]
        let snippetMap = ["shared": "new-snippet"]

        XCTAssertEqual(
            AliasImportSourceMapper.mappedSourceObjectId(
                sourceObjectType: "resourcePin",
                sourceObjectId: "shared",
                resourceMap: resourceMap,
                snippetMap: snippetMap
            ),
            "new-resource"
        )
        XCTAssertEqual(
            AliasImportSourceMapper.mappedSourceObjectId(
                sourceObjectType: "snippet",
                sourceObjectId: "shared",
                resourceMap: resourceMap,
                snippetMap: snippetMap
            ),
            "new-snippet"
        )
    }

    func testReferenceIndexBuildsWhereUsedAndCleanupPlanForResource() {
        let index = ReferenceIndex(
            workspaceResources: [
                WorkspaceResourceReference(resourceId: "resource", workspaceId: "workspace")
            ],
            canvasObjects: [
                CanvasObjectReference(nodeId: "node", canvasId: "canvas", workspaceId: "workspace", objectType: "resourcePin", objectId: "resource")
            ],
            canvasEdges: [
                CanvasEdgeReference(edgeId: "edge-from-resource", canvasId: "canvas", sourceNodeId: "node", targetNodeId: "note"),
                CanvasEdgeReference(edgeId: "edge-to-resource", canvasId: "canvas", sourceNodeId: "note", targetNodeId: "node"),
                CanvasEdgeReference(edgeId: "edge-unrelated", canvasId: "canvas", sourceNodeId: "note", targetNodeId: "other")
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
        XCTAssertEqual(plan.canvasEdgeIdsToDelete, ["edge-from-resource", "edge-to-resource"])
        XCTAssertEqual(plan.todoIdsClearingLinkedResource, ["todo"])
        XCTAssertEqual(plan.snippetIdsClearingWorkingDirectory, ["snippet"])
        XCTAssertEqual(plan.aliasIdsMarkingMissing, ["alias"])
    }

    func testReferenceIndexBuildsStableRelatedSearchTermsByResource() {
        let index = ReferenceIndex(
            workspaceResources: [
                WorkspaceResourceReference(resourceId: "unused", workspaceId: "workspace")
            ],
            canvasObjects: [
                CanvasObjectReference(nodeId: "node-b", canvasId: "canvas", workspaceId: "workspace", objectType: "resourcePin", objectId: "resource"),
                CanvasObjectReference(nodeId: "node-a", canvasId: "canvas", workspaceId: "workspace", objectType: "resourcePin", objectId: "resource")
            ],
            todoLinks: [
                TodoResourceReference(todoId: "todo", workspaceId: "workspace", linkedResourceId: "resource")
            ],
            snippetWorkingDirectories: [
                SnippetWorkingDirectoryReference(snippetId: "snippet", resourceId: "resource")
            ],
            aliases: [
                AliasObjectReference(aliasId: "alias", sourceObjectType: "resourcePin", sourceObjectId: "resource"),
                AliasObjectReference(aliasId: "snippet-alias", sourceObjectType: "snippet", sourceObjectId: "resource")
            ]
        )

        XCTAssertEqual(
            index.resourceRelatedSearchTermsByID()["resource"],
            [
                "canvas",
                "canvas card",
                "linked task",
                "todo",
                "snippet",
                "working directory",
                "finder alias",
                "alias"
            ]
        )
        XCTAssertNil(index.resourceRelatedSearchTermsByID()["unused"])
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

    func testExternalActionPolicyKeepsAgentDefaultsReadOnlyAndConfirmable() {
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserConfirmation(.applyAgentAction))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserConfirmation(.runCommand))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserConfirmation(.openTerminal))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserConfirmation(.openFileSystemItem))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserConfirmation(.revealInFinder))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserConfirmation(.createFinderAlias))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserConfirmation(.openURL))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserConfirmation(.copyPathToClipboard))

        XCTAssertFalse(WorkbenchExternalActionPolicy.requiresUserConfirmation(.readAgentContext))
        XCTAssertFalse(WorkbenchExternalActionPolicy.requiresUserConfirmation(.proposeAgentAction))

        XCTAssertTrue(WorkbenchExternalActionPolicy.isAllowedForDefaultAgent(.readAgentContext))
        XCTAssertTrue(WorkbenchExternalActionPolicy.isAllowedForDefaultAgent(.proposeAgentAction))
        XCTAssertFalse(WorkbenchExternalActionPolicy.isAllowedForDefaultAgent(.runCommand))
        XCTAssertFalse(WorkbenchExternalActionPolicy.isAllowedForDefaultAgent(.openFileSystemItem))
        XCTAssertFalse(WorkbenchExternalActionPolicy.isAllowedForDefaultAgent(.openTerminal))
        XCTAssertFalse(WorkbenchExternalActionPolicy.isAllowedForDefaultAgent(.revealInFinder))
        XCTAssertFalse(WorkbenchExternalActionPolicy.isAllowedForDefaultAgent(.createFinderAlias))
        XCTAssertFalse(WorkbenchExternalActionPolicy.isAllowedForDefaultAgent(.openURL))
        XCTAssertFalse(WorkbenchExternalActionPolicy.isAllowedForDefaultAgent(.copyPathToClipboard))
        XCTAssertFalse(WorkbenchExternalActionPolicy.isAllowedForDefaultAgent(.applyAgentAction))
    }

    func testExternalActionPolicySeparatesUserGesturesFromAgentActions() {
        XCTAssertEqual(
            WorkbenchExternalActionPolicy.decision(for: .openFileSystemItem, actor: .directUser),
            .requireExplicitUserIntent
        )
        XCTAssertEqual(
            WorkbenchExternalActionPolicy.decision(for: .runCommand, actor: .directUser),
            .requireModalConfirmation
        )
        XCTAssertEqual(
            WorkbenchExternalActionPolicy.decision(for: .runCommand, actor: .approvedAgent),
            .requireModalConfirmation
        )
        XCTAssertEqual(
            WorkbenchExternalActionPolicy.decision(for: .openTerminal, actor: .approvedAgent),
            .requireModalConfirmation
        )
        XCTAssertEqual(
            WorkbenchExternalActionPolicy.decision(for: .openURL, actor: .defaultAgent),
            .deny
        )
        XCTAssertEqual(
            WorkbenchExternalActionPolicy.decision(for: .readAgentContext, actor: .defaultAgent),
            .allow
        )
        XCTAssertEqual(
            WorkbenchExternalActionPolicy.decision(for: .proposeAgentAction, actor: .defaultAgent),
            .allow
        )
        XCTAssertEqual(
            WorkbenchExternalActionPolicy.decision(for: .applyAgentAction, actor: .defaultAgent),
            .deny
        )
    }

    func testExternalActionPolicyNamesModalConfirmationSeparatelyFromUserMediation() {
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresModalConfirmation(.runCommand, actor: .directUser))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresModalConfirmation(.openTerminal, actor: .directUser))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresModalConfirmation(.openURL, actor: .approvedAgent))

        XCTAssertFalse(WorkbenchExternalActionPolicy.requiresModalConfirmation(.openFileSystemItem, actor: .directUser))
        XCTAssertFalse(WorkbenchExternalActionPolicy.requiresModalConfirmation(.copyPathToClipboard, actor: .directUser))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserMediation(.openFileSystemItem, actor: .directUser))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserMediation(.copyPathToClipboard, actor: .directUser))
        XCTAssertFalse(WorkbenchExternalActionPolicy.requiresUserMediation(.readAgentContext, actor: .defaultAgent))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserMediation(.openURL, actor: .defaultAgent))
        XCTAssertTrue(WorkbenchExternalActionPolicy.requiresUserMediation(.runCommand, actor: .defaultAgent))
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

    func testCanvasEdgeDefaultTargetClearanceKeepsArrowTipOutsideTargetBorder() {
        let source = CanvasFrameRect(id: "left", x: 0, y: 0, width: 100, height: 80)
        let target = CanvasFrameRect(id: "right", x: 240, y: 0, width: 120, height: 80)

        let anchors = CanvasEdgeAnchoring.anchors(
            source: source,
            target: target,
            targetClearance: CanvasEdgeRouteDefaults.targetClearance
        )

        XCTAssertGreaterThanOrEqual(CanvasEdgeRouteDefaults.targetClearance, 4)
        XCTAssertLessThan(anchors.end.x, target.x)
        XCTAssertEqual(
            anchors.end,
            CanvasEdgePoint(x: target.x - CanvasEdgeRouteDefaults.targetClearance, y: 40)
        )
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

    func testCanvasEdgeArrowDirectionUsesFirstRouteSegmentForSourceArrow() {
        let direction = CanvasEdgeArrowDirectionPolicy.sourceDirection(
            start: CanvasEdgePoint(x: 100, y: 100),
            startDirection: CanvasEdgePoint(x: 1, y: 0),
            routePoints: [
                CanvasEdgePoint(x: 100, y: 160),
                CanvasEdgePoint(x: 260, y: 160)
            ]
        )

        XCTAssertEqual(direction.x, 0, accuracy: 0.0001)
        XCTAssertEqual(direction.y, -1, accuracy: 0.0001)
    }

    func testCanvasEdgeArrowDirectionUsesLastRouteSegmentForTargetArrow() {
        let direction = CanvasEdgeArrowDirectionPolicy.targetDirection(
            end: CanvasEdgePoint(x: 340, y: 100),
            endDirection: CanvasEdgePoint(x: 1, y: 0),
            routePoints: [
                CanvasEdgePoint(x: 100, y: 160),
                CanvasEdgePoint(x: 340, y: 160)
            ]
        )

        XCTAssertEqual(direction.x, 0, accuracy: 0.0001)
        XCTAssertEqual(direction.y, -1, accuracy: 0.0001)
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

    func testCanvasEdgeHitTargetPolicyKeepsScreenThresholdStableAcrossZoomExtremes() {
        let baseline = CanvasEdgeHitTargetPolicy.screenThreshold(zoom: CanvasZoomBaseline.standardBaseline)

        XCTAssertEqual(CanvasEdgeHitTargetPolicy.screenThreshold(zoom: 0.01), baseline, accuracy: 0.0001)
        XCTAssertEqual(CanvasEdgeHitTargetPolicy.screenThreshold(zoom: CanvasZoomBaseline.standardBaseline), baseline, accuracy: 0.0001)
        XCTAssertEqual(CanvasEdgeHitTargetPolicy.screenThreshold(zoom: 12), baseline, accuracy: 0.0001)
        XCTAssertEqual(CanvasEdgeHitTargetPolicy.screenThreshold(zoom: .nan), baseline, accuracy: 0.0001)
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

    func testCanvasEdgeDeletionUndoPolicyRestoresSelectedLinksWithControlPoints() {
        let plan = CanvasEdgeDeletionUndoPolicy.restorePlan(edges: [
            CanvasEdgeDeletionUndoRecord(id: "edge-with-bend", controlPointX: 320, controlPointY: 180),
            CanvasEdgeDeletionUndoRecord(id: "edge-without-bend", controlPointX: nil, controlPointY: nil)
        ])

        XCTAssertEqual(plan.steps, [
            .restoreEdge(id: "edge-with-bend", controlPointX: 320, controlPointY: 180),
            .restoreEdge(id: "edge-without-bend", controlPointX: nil, controlPointY: nil)
        ])
        XCTAssertEqual(plan.successStatus, "Restored deleted links")
        XCTAssertEqual(CanvasEdgeDeletionUndoPolicy.actionName(deletedEdgeCount: 1), "Delete Link")
        XCTAssertEqual(CanvasEdgeDeletionUndoPolicy.actionName(deletedEdgeCount: 2), "Delete Links")
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

    func testCanvasNodeDeletionUndoPolicyRestoresCardsBeforeDetachedChildrenAndIncidentEdges() {
        let plan = CanvasNodeDeletionUndoPolicy.restorePlan(
            deletedNodeIDs: ["node-b", "node-a"],
            detachedChildNodeIDs: ["child"],
            deletedEdgeIDs: ["edge-ab", "edge-bc"]
        )

        XCTAssertEqual(plan.steps, [
            .restoreNode(id: "node-b"),
            .restoreNode(id: "node-a"),
            .restoreDetachedChildParent(id: "child"),
            .restoreEdge(id: "edge-ab"),
            .restoreEdge(id: "edge-bc")
        ])
        XCTAssertEqual(plan.successStatus, "Restored deleted cards")
        XCTAssertEqual(CanvasNodeDeletionUndoPolicy.actionName(deletedNodeCount: 1), "Delete Card")
        XCTAssertEqual(CanvasNodeDeletionUndoPolicy.actionName(deletedNodeCount: 2), "Delete Cards")
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

    func testCanvasResizeHandleHitRectStaysReachableAtExtremeZooms() {
        let lowZoomRect = CanvasFrameRect(id: "card", x: 120, y: 80, width: 214 * 0.12, height: 132 * 0.12)
        let lowZoomCenter = CanvasResizeHandleGeometry.center(in: lowZoomRect, zoom: 0.12)
        let lowZoomHitRect = CanvasResizeHandleGeometry.hitRect(center: lowZoomCenter, zoom: 0.12)

        XCTAssertEqual(lowZoomHitRect.width, CanvasResizeHandleGeometry.minimumHitSize, accuracy: 0.0001)
        XCTAssertTrue(CanvasResizeHandleGeometry.contains(CanvasEdgePoint(x: lowZoomRect.x + lowZoomRect.width - 1, y: lowZoomRect.y + lowZoomRect.height - 1), in: lowZoomHitRect))

        let highZoomRect = CanvasFrameRect(id: "frame", x: 120, y: 80, width: 316 * 4, height: 226 * 4)
        let highZoomCenter = CanvasResizeHandleGeometry.center(in: highZoomRect, zoom: 4.0)
        let highZoomHitRect = CanvasResizeHandleGeometry.hitRect(center: highZoomCenter, zoom: 4.0)

        XCTAssertEqual(highZoomHitRect.width, CanvasResizeHandleGeometry.maximumHitSize, accuracy: 0.0001)
        XCTAssertTrue(CanvasResizeHandleGeometry.contains(CanvasEdgePoint(x: highZoomRect.x + highZoomRect.width - 1, y: highZoomRect.y + highZoomRect.height - 1), in: highZoomHitRect))
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

    func testCanvasEdgeControlPointDragPolicyConvertsDragToPersistentCanvasPoint() {
        let canvasPoint = CanvasEdgeControlPointDragPolicy.persistentControlPoint(
            startScreenPoint: CanvasEdgePoint(x: 200, y: 140),
            translation: CanvasEdgePoint(x: 30, y: -20),
            zoom: 2,
            viewportX: 10,
            viewportY: 30
        )

        XCTAssertEqual(canvasPoint, CanvasEdgePoint(x: 110, y: 45))
        XCTAssertNil(CanvasEdgeControlPointDragPolicy.persistentControlPoint(
            startScreenPoint: CanvasEdgePoint(x: 200, y: 140),
            translation: CanvasEdgePoint(x: 3, y: 0),
            zoom: 2,
            viewportX: 10,
            viewportY: 30
        ))
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

    func testCanvasEdgeFlowStrokeStaysInsideVisibleLineChannel() {
        let lowZoomBaseWidth = CanvasEdgeVisualMetrics.strokeWidth(
            zoom: 0.12,
            baseWidth: 1.7,
            minimumWidth: 0.9,
            maximumWidth: 2.0
        )
        let normalZoomBaseWidth = CanvasEdgeVisualMetrics.strokeWidth(
            zoom: 1,
            baseWidth: 1.7,
            minimumWidth: 0.9,
            maximumWidth: 2.0
        )

        XCTAssertEqual(CanvasEdgeFlowStrokePolicy.strokeWidth(baseStrokeWidth: lowZoomBaseWidth), lowZoomBaseWidth)
        XCTAssertLessThanOrEqual(CanvasEdgeFlowStrokePolicy.strokeWidth(baseStrokeWidth: normalZoomBaseWidth), normalZoomBaseWidth)
        XCTAssertEqual(CanvasEdgeFlowStrokePolicy.lineCap, .butt)
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

    func testCanvasNodeScaledContentLayoutKeepsCardSurfaceUnscaledAndScalesOuterFrame() {
        let zoomedOut = CanvasNodeScaledContentLayoutPolicy.layout(width: 214, height: 132, zoom: 0.5)

        XCTAssertEqual(zoomedOut.contentWidth, 214)
        XCTAssertEqual(zoomedOut.contentHeight, 132)
        XCTAssertEqual(zoomedOut.layoutWidth, 107)
        XCTAssertEqual(zoomedOut.layoutHeight, 66)

        let zoomedIn = CanvasNodeScaledContentLayoutPolicy.layout(width: 214, height: 132, zoom: 2)

        XCTAssertEqual(zoomedIn.contentWidth, 214)
        XCTAssertEqual(zoomedIn.contentHeight, 132)
        XCTAssertEqual(zoomedIn.layoutWidth, 428)
        XCTAssertEqual(zoomedIn.layoutHeight, 264)
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

    func testCanvasScrollZoomRuntimePolicyUsesLatestRawDirectionForEachEvent() {
        let current = 1.0
        let defaultDirectionZoom = CanvasScrollZoomRuntimePolicy.zoom(
            forScrollDeltaY: 20,
            current: current,
            minimum: 0.12,
            maximum: 2.4,
            directionRawValue: CanvasScrollZoomDirection.scrollDownZoomsOut.rawValue
        )
        let changedDirectionZoom = CanvasScrollZoomRuntimePolicy.zoom(
            forScrollDeltaY: 20,
            current: current,
            minimum: 0.12,
            maximum: 2.4,
            directionRawValue: CanvasScrollZoomDirection.scrollDownZoomsIn.rawValue
        )

        XCTAssertLessThan(defaultDirectionZoom, current)
        XCTAssertGreaterThan(changedDirectionZoom, current)
        XCTAssertNotEqual(defaultDirectionZoom, changedDirectionZoom)
        XCTAssertEqual(
            CanvasScrollZoomRuntimePolicy.zoom(
                forScrollDeltaY: 20,
                current: current,
                minimum: 0.12,
                maximum: 2.4,
                directionRawValue: "stale-value"
            ),
            defaultDirectionZoom,
            accuracy: 0.0001
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

    func testCanvasPinchZoomPolicyScalesFromGestureStartAndKeepsAnchorStable() {
        let anchor = CanvasViewportProjection.canvasPoint(
            screenX: 300,
            screenY: 200,
            zoom: 0.5,
            viewportX: -50,
            viewportY: 20
        )

        let update = CanvasPinchZoomPolicy.update(
            startZoom: 0.5,
            magnification: 1.8,
            screenX: 300,
            screenY: 200,
            anchorCanvasX: anchor.x,
            anchorCanvasY: anchor.y,
            minimumZoom: 0.12,
            maximumZoom: 2.4
        )

        XCTAssertEqual(update.zoom, 0.9, accuracy: 0.0001)

        let projectedAnchor = CanvasViewportProjection.screenPoint(
            x: anchor.x,
            y: anchor.y,
            zoom: update.zoom,
            viewportX: update.viewportX,
            viewportY: update.viewportY
        )
        XCTAssertEqual(projectedAnchor.x, 300, accuracy: 0.0001)
        XCTAssertEqual(projectedAnchor.y, 200, accuracy: 0.0001)
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

    func testWorkspaceReentryBriefAggregatesCurrentWorkspaceOnly() {
        let now = Date(timeIntervalSince1970: 1_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace-a", title: "A", lastOpenedAt: nil, updatedAt: now)
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [
                WorkspaceReentryResourceRecord(id: "global-used", workspaceId: nil, title: "Global Used", status: "available", scope: "global", updatedAt: now, lastOpenedAt: now),
                WorkspaceReentryResourceRecord(id: "workspace-issue", workspaceId: "workspace-a", title: "Workspace Issue", status: "missingVolume", scope: "workspace", updatedAt: now, lastOpenedAt: nil),
                WorkspaceReentryResourceRecord(id: "other-private", workspaceId: "workspace-b", title: "Other", status: "missingVolume", scope: "workspace", updatedAt: now, lastOpenedAt: nil)
            ],
            snippets: [
                WorkspaceReentrySnippetRecord(id: "workspace-snippet", workspaceId: "workspace-a", title: "Workspace Snippet", scope: "workspace", updatedAt: now, lastCopiedAt: now, lastUsedAt: nil),
                WorkspaceReentrySnippetRecord(id: "other-snippet", workspaceId: "workspace-b", title: "Other Snippet", scope: "workspace", updatedAt: now, lastCopiedAt: now, lastUsedAt: nil)
            ],
            todos: [
                WorkspaceReentryTodoRecord(id: "todo-a", workspaceId: "workspace-a", title: "Todo A", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: nil, linkedResourceId: "workspace-issue"),
                WorkspaceReentryTodoRecord(id: "todo-b", workspaceId: "workspace-b", title: "Todo B", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: nil, linkedResourceId: "other-private")
            ],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas-a", workspaceId: "workspace-a", updatedAt: now),
                WorkspaceReentryCanvasRecord(id: "canvas-b", workspaceId: "workspace-b", updatedAt: now)
            ],
            nodes: [
                WorkspaceReentryCanvasNodeRecord(id: "node-a", canvasId: "canvas-a", objectType: "resourcePin", objectId: "global-used", updatedAt: now),
                WorkspaceReentryCanvasNodeRecord(id: "node-b", canvasId: "canvas-b", objectType: "resourcePin", objectId: "other-private", updatedAt: now)
            ],
            edges: [],
            now: now
        )

        XCTAssertEqual(brief.workspaceId, "workspace-a")
        XCTAssertEqual(brief.nextTaskIds, ["todo-a"])
        XCTAssertEqual(brief.resourceIssueIds, ["workspace-issue"])
        XCTAssertEqual(brief.recentSnippetIds, ["workspace-snippet"])
        XCTAssertEqual(brief.canvasSummary.cardCount, 1)
    }

    func testWorkspaceReentryBriefBadgePriorityUsesOverdueDueOpenAndResourceIssues() {
        let now = Date(timeIntervalSince1970: 10_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [
                WorkspaceReentryResourceRecord(id: "issue", workspaceId: "workspace", title: "Issue", status: "unavailable", scope: "workspace", updatedAt: now, lastOpenedAt: nil)
            ],
            snippets: [],
            todos: [
                WorkspaceReentryTodoRecord(id: "overdue", workspaceId: "workspace", title: "Overdue", isCompleted: false, isPinned: false, sortIndex: 3, updatedAt: now, dueAt: now.addingTimeInterval(-86_400), linkedResourceId: nil),
                WorkspaceReentryTodoRecord(id: "due", workspaceId: "workspace", title: "Due", isCompleted: false, isPinned: false, sortIndex: 2, updatedAt: now, dueAt: now.addingTimeInterval(2_000), linkedResourceId: nil),
                WorkspaceReentryTodoRecord(id: "open", workspaceId: "workspace", title: "Open", isCompleted: false, isPinned: false, sortIndex: 1, updatedAt: now, dueAt: nil, linkedResourceId: nil)
            ],
            canvases: [],
            nodes: [],
            edges: [],
            now: now
        )

        XCTAssertEqual(brief.openTaskCount, 3)
        XCTAssertEqual(brief.overdueTaskCount, 1)
        XCTAssertEqual(brief.dueSoonTaskCount, 1)
        XCTAssertEqual(brief.badges.map(\.kind), [.overdueTasks, .resourceIssues])
        XCTAssertEqual(brief.badges.map(\.count), [1, 1])
    }

    func testWorkspaceReentryBriefCapsAndOrdersItemsDeterministically() {
        let now = Date(timeIntervalSince1970: 20_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let todos = [
            WorkspaceReentryTodoRecord(id: "z", workspaceId: "workspace", title: "Same", isCompleted: false, isPinned: true, sortIndex: 2, updatedAt: now, dueAt: nil, linkedResourceId: nil),
            WorkspaceReentryTodoRecord(id: "a", workspaceId: "workspace", title: "Same", isCompleted: false, isPinned: true, sortIndex: 2, updatedAt: now, dueAt: nil, linkedResourceId: nil),
            WorkspaceReentryTodoRecord(id: "due", workspaceId: "workspace", title: "Due", isCompleted: false, isPinned: false, sortIndex: 9, updatedAt: now, dueAt: now.addingTimeInterval(100), linkedResourceId: nil),
            WorkspaceReentryTodoRecord(id: "later", workspaceId: "workspace", title: "Later", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: nil, linkedResourceId: nil)
        ]
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [],
            todos: todos,
            canvases: [],
            nodes: [],
            edges: [],
            now: now,
            taskLimit: 3
        )

        XCTAssertEqual(brief.nextTaskIds, ["due", "a", "z"])
    }

    func testWorkspaceReentryBriefTodoTieBreakIgnoresUpdatedAt() {
        let now = Date(timeIntervalSince1970: 25_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [],
            todos: [
                WorkspaceReentryTodoRecord(id: "newer", workspaceId: "workspace", title: "Zeta", isCompleted: false, isPinned: false, sortIndex: 1, updatedAt: now.addingTimeInterval(100), dueAt: nil, linkedResourceId: nil),
                WorkspaceReentryTodoRecord(id: "older", workspaceId: "workspace", title: "Alpha", isCompleted: false, isPinned: false, sortIndex: 1, updatedAt: now, dueAt: nil, linkedResourceId: nil)
            ],
            canvases: [],
            nodes: [],
            edges: [],
            now: now
        )

        XCTAssertEqual(brief.nextTaskIds, ["older", "newer"])
    }

    func testWorkspaceReentryBriefIgnoresCompletedAndDanglingReferences() {
        let now = Date(timeIntervalSince1970: 30_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [],
            todos: [
                WorkspaceReentryTodoRecord(id: "done", workspaceId: "workspace", title: "Done", isCompleted: true, isPinned: true, sortIndex: 0, updatedAt: now, dueAt: now.addingTimeInterval(-1), linkedResourceId: "missing-completed-resource"),
                WorkspaceReentryTodoRecord(id: "open", workspaceId: "workspace", title: "Open", isCompleted: false, isPinned: false, sortIndex: 1, updatedAt: now, dueAt: nil, linkedResourceId: "missing-todo-resource")
            ],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas", workspaceId: "workspace", updatedAt: now)
            ],
            nodes: [
                WorkspaceReentryCanvasNodeRecord(id: "node", canvasId: "canvas", objectType: "resourcePin", objectId: "missing-node-resource", updatedAt: now)
            ],
            edges: [
                WorkspaceReentryCanvasEdgeRecord(id: "edge", canvasId: "canvas", sourceNodeId: "node", targetNodeId: "missing-node", updatedAt: now)
            ],
            now: now
        )

        XCTAssertEqual(brief.nextTaskIds, ["open"])
        XCTAssertTrue(brief.resourceIssueIds.isEmpty)
        XCTAssertEqual(brief.canvasSummary.cardCount, 1)
        XCTAssertEqual(brief.canvasSummary.validLinkCount, 0)
        XCTAssertEqual(brief.unresolvedReferenceCount, 3)
    }

    func testWorkspaceReentryBriefCountsUnresolvedSnippetNodeReferences() {
        let now = Date(timeIntervalSince1970: 35_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [
                WorkspaceReentrySnippetRecord(id: "workspace-snippet", workspaceId: "workspace", title: "Workspace", scope: "workspace", updatedAt: now, lastCopiedAt: now, lastUsedAt: nil),
                WorkspaceReentrySnippetRecord(id: "global-snippet", workspaceId: nil, title: "Global", scope: "global", updatedAt: now, lastCopiedAt: now, lastUsedAt: nil),
                WorkspaceReentrySnippetRecord(id: "private-snippet", workspaceId: "other-workspace", title: "Private", scope: "workspace", updatedAt: now, lastCopiedAt: now, lastUsedAt: nil),
                WorkspaceReentrySnippetRecord(id: "unknown-snippet", workspaceId: nil, title: "Unknown", scope: "shared", updatedAt: now, lastCopiedAt: now, lastUsedAt: nil)
            ],
            todos: [],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas", workspaceId: "workspace", updatedAt: now)
            ],
            nodes: [
                WorkspaceReentryCanvasNodeRecord(id: "workspace-snippet-node", canvasId: "canvas", objectType: "snippet", objectId: "workspace-snippet", updatedAt: now),
                WorkspaceReentryCanvasNodeRecord(id: "global-snippet-node", canvasId: "canvas", objectType: "snippet", objectId: "global-snippet", updatedAt: now),
                WorkspaceReentryCanvasNodeRecord(id: "missing-snippet-node", canvasId: "canvas", objectType: "snippet", objectId: "missing-snippet", updatedAt: now),
                WorkspaceReentryCanvasNodeRecord(id: "private-snippet-node", canvasId: "canvas", objectType: "snippet", objectId: "private-snippet", updatedAt: now),
                WorkspaceReentryCanvasNodeRecord(id: "unknown-snippet-node", canvasId: "canvas", objectType: "snippet", objectId: "unknown-snippet", updatedAt: now)
            ],
            edges: [],
            now: now
        )

        XCTAssertEqual(brief.unresolvedReferenceCount, 3)
    }

    func testWorkspaceReentryBriefHandlesEmptyWorkspace() {
        let now = Date(timeIntervalSince1970: 40_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [],
            todos: [],
            canvases: [],
            nodes: [],
            edges: [],
            now: now
        )

        XCTAssertEqual(brief.workspaceId, "workspace")
        XCTAssertTrue(brief.badges.isEmpty)
        XCTAssertTrue(brief.nextTaskIds.isEmpty)
        XCTAssertTrue(brief.resourceIssueIds.isEmpty)
        XCTAssertTrue(brief.recentSnippetIds.isEmpty)
        XCTAssertEqual(brief.canvasSummary.cardCount, 0)
        XCTAssertFalse(brief.isLargeDataDegraded)
    }

    func testWorkspaceReentryBriefCanvasLastUpdateIgnoresWorkspaceUpdatedAt() {
        let workspaceUpdatedAt = Date(timeIntervalSince1970: 60_000)
        let canvasUpdatedAt = Date(timeIntervalSince1970: 10_000)
        let nodeUpdatedAt = Date(timeIntervalSince1970: 20_000)
        let edgeUpdatedAt = Date(timeIntervalSince1970: 30_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: workspaceUpdatedAt)

        let emptyBrief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [],
            todos: [],
            canvases: [],
            nodes: [],
            edges: [],
            now: workspaceUpdatedAt
        )
        XCTAssertNil(emptyBrief.canvasSummary.lastUpdatedAt)

        let canvasBrief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [],
            todos: [],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas", workspaceId: "workspace", updatedAt: canvasUpdatedAt)
            ],
            nodes: [
                WorkspaceReentryCanvasNodeRecord(id: "source", canvasId: "canvas", objectType: nil, objectId: nil, updatedAt: nodeUpdatedAt),
                WorkspaceReentryCanvasNodeRecord(id: "target", canvasId: "canvas", objectType: nil, objectId: nil, updatedAt: canvasUpdatedAt)
            ],
            edges: [
                WorkspaceReentryCanvasEdgeRecord(id: "edge", canvasId: "canvas", sourceNodeId: "source", targetNodeId: "target", updatedAt: edgeUpdatedAt)
            ],
            now: workspaceUpdatedAt
        )

        XCTAssertEqual(canvasBrief.canvasSummary.lastUpdatedAt, edgeUpdatedAt)
    }

    func testWorkspaceReentryBriefFailsClosedForUnknownResourceAndSnippetScopes() {
        let now = Date(timeIntervalSince1970: 70_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [
                WorkspaceReentryResourceRecord(id: "unknown-resource", workspaceId: nil, title: "Unknown", status: "unavailable", scope: "shared", updatedAt: now.addingTimeInterval(10), lastOpenedAt: nil),
                WorkspaceReentryResourceRecord(id: "workspace-resource", workspaceId: "workspace", title: "Workspace", status: "unavailable", scope: "workspace", updatedAt: now, lastOpenedAt: nil)
            ],
            snippets: [
                WorkspaceReentrySnippetRecord(id: "unknown-snippet", workspaceId: nil, title: "Unknown", scope: "shared", updatedAt: now.addingTimeInterval(10), lastCopiedAt: now.addingTimeInterval(10), lastUsedAt: nil),
                WorkspaceReentrySnippetRecord(id: "workspace-snippet", workspaceId: "workspace", title: "Workspace", scope: "workspace", updatedAt: now, lastCopiedAt: now, lastUsedAt: nil)
            ],
            todos: [
                WorkspaceReentryTodoRecord(id: "todo", workspaceId: "workspace", title: "Todo", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: nil, linkedResourceId: "unknown-resource")
            ],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas", workspaceId: "workspace", updatedAt: now)
            ],
            nodes: [
                WorkspaceReentryCanvasNodeRecord(id: "resource-node", canvasId: "canvas", objectType: "resourcePin", objectId: "workspace-resource", updatedAt: now),
                WorkspaceReentryCanvasNodeRecord(id: "snippet-node", canvasId: "canvas", objectType: "snippet", objectId: "unknown-snippet", updatedAt: now)
            ],
            edges: [],
            now: now
        )

        XCTAssertEqual(brief.resourceIssueIds, ["workspace-resource"])
        XCTAssertEqual(brief.recentSnippetIds, ["workspace-snippet"])
        XCTAssertEqual(brief.resourceIssueCount, 1)
    }

    func testWorkspaceReentryBriefBudgetPolicyUsesStrictThresholdsAndSkipFlags() {
        let detailedDecision = WorkspaceReentryBriefBudgetPolicy.decision(
            stats: WorkspaceReentryBriefInputStats(
                nodeCount: WorkspaceReentryBriefPolicy.maximumDetailedNodeCount,
                edgeCount: WorkspaceReentryBriefPolicy.maximumDetailedEdgeCount,
                todoCount: WorkspaceReentryBriefPolicy.maximumDetailedTodoCount
            )
        )

        XCTAssertEqual(detailedDecision.mode, .detailed)
        XCTAssertTrue(detailedDecision.reasons.isEmpty)
        XCTAssertTrue(detailedDecision.shouldResolveReferences)
        XCTAssertTrue(detailedDecision.shouldBuildDetailLists)
        XCTAssertTrue(detailedDecision.shouldSortDetailLists)

        let countsOnlyDecision = WorkspaceReentryBriefBudgetPolicy.decision(
            stats: WorkspaceReentryBriefInputStats(
                nodeCount: WorkspaceReentryBriefPolicy.maximumDetailedNodeCount + 1,
                edgeCount: WorkspaceReentryBriefPolicy.maximumDetailedEdgeCount + 1,
                todoCount: WorkspaceReentryBriefPolicy.maximumDetailedTodoCount + 1
            )
        )

        XCTAssertEqual(countsOnlyDecision.mode, .countsOnly)
        XCTAssertEqual(
            countsOnlyDecision.reasons,
            [.nodeLimitExceeded, .edgeLimitExceeded, .todoLimitExceeded]
        )
        XCTAssertEqual(countsOnlyDecision.stats.nodeCount, WorkspaceReentryBriefPolicy.maximumDetailedNodeCount + 1)
        XCTAssertEqual(countsOnlyDecision.nodeLimit, WorkspaceReentryBriefPolicy.maximumDetailedNodeCount)
        XCTAssertEqual(countsOnlyDecision.edgeLimit, WorkspaceReentryBriefPolicy.maximumDetailedEdgeCount)
        XCTAssertEqual(countsOnlyDecision.todoLimit, WorkspaceReentryBriefPolicy.maximumDetailedTodoCount)
        XCTAssertFalse(countsOnlyDecision.shouldResolveReferences)
        XCTAssertFalse(countsOnlyDecision.shouldBuildDetailLists)
        XCTAssertFalse(countsOnlyDecision.shouldSortDetailLists)
        XCTAssertTrue(countsOnlyDecision.skipReferenceResolution)
        XCTAssertTrue(countsOnlyDecision.skipDetailedLists)
        XCTAssertTrue(countsOnlyDecision.skipCanvasRouting)
        XCTAssertTrue(countsOnlyDecision.skipLayout)
    }

    func testWorkspaceReentryBriefBudgetDecisionContainsOnlyAggregateDiagnostics() {
        let decision = WorkspaceReentryBriefBudgetPolicy.decision(
            stats: WorkspaceReentryBriefInputStats(
                nodeCount: WorkspaceReentryBriefPolicy.maximumDetailedNodeCount + 1,
                edgeCount: 0,
                todoCount: 0
            )
        )
        XCTAssertEqual(
            Set(Mirror(reflecting: decision).children.compactMap(\.label)),
            ["mode", "reasons", "stats", "nodeLimit", "edgeLimit", "todoLimit"]
        )
        XCTAssertEqual(
            Set(Mirror(reflecting: decision.stats).children.compactMap(\.label)),
            ["nodeCount", "edgeCount", "todoCount"]
        )
        let diagnosticText = [
            decision.mode.rawValue,
            decision.reasons.map(\.rawValue).joined(separator: " "),
            String(decision.stats.nodeCount),
            String(decision.stats.edgeCount),
            String(decision.stats.todoCount),
            String(decision.nodeLimit),
            String(decision.edgeLimit),
            String(decision.todoLimit),
            String(decision.shouldResolveReferences),
            String(decision.shouldBuildDetailLists),
            String(decision.shouldSortDetailLists)
        ].joined(separator: " ")

        XCTAssertFalse(diagnosticText.contains("node-"))
        XCTAssertFalse(diagnosticText.contains("edge-"))
        XCTAssertFalse(diagnosticText.contains("/Users/"))
        XCTAssertFalse(diagnosticText.contains("https://"))
        XCTAssertFalse(diagnosticText.contains("secret"))
    }

    func testWorkspaceReentryBriefLargeDataFlagIsDerivedFromBudgetDecision() {
        let brief = WorkspaceReentryBrief(
            workspaceId: "workspace",
            badges: [],
            nextTaskIds: [],
            resourceIssueIds: [],
            recentSnippetIds: [],
            canvasSummary: WorkspaceReentryCanvasSummary(
                canvasCount: 1,
                cardCount: 0,
                validLinkCount: 0,
                lastUpdatedAt: nil
            ),
            openTaskCount: 0,
            overdueTaskCount: 0,
            dueSoonTaskCount: 0,
            resourceIssueCount: 0,
            unresolvedReferenceCount: 0,
            isLargeDataDegraded: false,
            budgetDecision: WorkspaceReentryBriefBudgetDecision(
                mode: .countsOnly,
                reasons: [.nodeLimitExceeded],
                stats: WorkspaceReentryBriefInputStats(
                    nodeCount: WorkspaceReentryBriefPolicy.maximumDetailedNodeCount + 1,
                    edgeCount: 0,
                    todoCount: 0
                )
            )
        )

        XCTAssertTrue(brief.isLargeDataDegraded)
    }

    func testWorkspaceReentryBriefDegradesLargeInputsToCountsOnly() {
        let now = Date(timeIntervalSince1970: 50_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let nodes = (0...WorkspaceReentryBriefPolicy.maximumDetailedNodeCount).map { index in
            WorkspaceReentryCanvasNodeRecord(id: "node-\(index)", canvasId: "canvas", objectType: nil, objectId: nil, updatedAt: now)
        }
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [
                WorkspaceReentryResourceRecord(id: "issue", workspaceId: "workspace", title: "Issue", status: "unavailable", scope: "workspace", updatedAt: now, lastOpenedAt: nil)
            ],
            snippets: [
                WorkspaceReentrySnippetRecord(id: "recent-snippet", workspaceId: "workspace", title: "Recent Snippet", scope: "workspace", updatedAt: now, lastCopiedAt: now, lastUsedAt: nil)
            ],
            todos: [
                WorkspaceReentryTodoRecord(id: "open", workspaceId: "workspace", title: "Open", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: nil, linkedResourceId: nil)
            ],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas", workspaceId: "workspace", updatedAt: now)
            ],
            nodes: nodes,
            edges: [],
            now: now
        )

        XCTAssertTrue(brief.isLargeDataDegraded)
        XCTAssertEqual(brief.budgetDecision.mode, .countsOnly)
        XCTAssertEqual(brief.budgetDecision.reasons, [.nodeLimitExceeded])
        XCTAssertFalse(brief.budgetDecision.shouldBuildDetailLists)
        XCTAssertFalse(brief.budgetDecision.shouldSortDetailLists)
        XCTAssertTrue(brief.nextTaskIds.isEmpty)
        XCTAssertTrue(brief.resourceIssueIds.isEmpty)
        XCTAssertTrue(brief.recentSnippetIds.isEmpty)
        XCTAssertEqual(brief.openTaskCount, 1)
        XCTAssertEqual(brief.resourceIssueCount, 1)
        XCTAssertFalse(brief.badges.isEmpty)
        XCTAssertEqual(brief.canvasSummary.cardCount, nodes.count)
    }

    func testWorkspaceReentryBriefSkipsReferenceResolutionWhenLargeDataDegraded() {
        let now = Date(timeIntervalSince1970: 55_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let nodes = (0...WorkspaceReentryBriefPolicy.maximumDetailedNodeCount).map { index in
            WorkspaceReentryCanvasNodeRecord(
                id: "node-\(index)",
                canvasId: "canvas",
                objectType: index.isMultiple(of: 2) ? "resourcePin" : "snippet",
                objectId: "dangling-\(index)",
                updatedAt: now
            )
        }
        var referenceResolutionPassCount = 0

        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [
                WorkspaceReentryResourceRecord(id: "issue", workspaceId: "workspace", title: "Issue", status: "unavailable", scope: "workspace", updatedAt: now, lastOpenedAt: nil)
            ],
            snippets: [],
            todos: [
                WorkspaceReentryTodoRecord(id: "open", workspaceId: "workspace", title: "Open", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: now.addingTimeInterval(10), linkedResourceId: "dangling-todo-resource")
            ],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas", workspaceId: "workspace", updatedAt: now)
            ],
            nodes: nodes,
            edges: [
                WorkspaceReentryCanvasEdgeRecord(id: "dangling-edge", canvasId: "canvas", sourceNodeId: "node-0", targetNodeId: "missing-node", updatedAt: now)
            ],
            now: now,
            referenceResolutionProbe: { referenceResolutionPassCount += 1 }
        )

        XCTAssertTrue(brief.isLargeDataDegraded)
        XCTAssertEqual(referenceResolutionPassCount, 0)
        XCTAssertEqual(brief.unresolvedReferenceCount, 0)
        XCTAssertEqual(brief.canvasSummary.validLinkCount, 0)
        XCTAssertTrue(brief.nextTaskIds.isEmpty)
        XCTAssertTrue(brief.resourceIssueIds.isEmpty)
        XCTAssertTrue(brief.recentSnippetIds.isEmpty)
        XCTAssertEqual(brief.openTaskCount, 1)
        XCTAssertEqual(brief.dueSoonTaskCount, 1)
        XCTAssertEqual(brief.resourceIssueCount, 1)
        XCTAssertEqual(brief.canvasSummary.cardCount, nodes.count)
    }

    func testWorkspaceReentryBriefCountsTodoLinkedGlobalResourceIssuesWhenLargeDataDegraded() {
        let now = Date(timeIntervalSince1970: 55_500)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let nodes = (0...WorkspaceReentryBriefPolicy.maximumDetailedNodeCount).map { index in
            WorkspaceReentryCanvasNodeRecord(id: "node-\(index)", canvasId: "canvas", objectType: nil, objectId: nil, updatedAt: now)
        }

        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [
                WorkspaceReentryResourceRecord(id: "global-issue", workspaceId: nil, title: "Global Issue", status: "staleAuthorization", scope: "global", updatedAt: now, lastOpenedAt: nil)
            ],
            snippets: [],
            todos: [
                WorkspaceReentryTodoRecord(id: "open-linked", workspaceId: workspace.id, title: "Review linked issue", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: nil, linkedResourceId: "global-issue"),
                WorkspaceReentryTodoRecord(id: "done-linked", workspaceId: workspace.id, title: "Done linked issue", isCompleted: true, isPinned: false, sortIndex: 1, updatedAt: now, dueAt: nil, linkedResourceId: "global-issue")
            ],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas", workspaceId: workspace.id, updatedAt: now)
            ],
            nodes: nodes,
            edges: [],
            now: now
        )

        XCTAssertTrue(brief.isLargeDataDegraded)
        XCTAssertEqual(brief.resourceIssueCount, 1)
        XCTAssertEqual(brief.badges.map(\.kind), [.openTasks, .resourceIssues])
        XCTAssertTrue(brief.resourceIssueIds.isEmpty)
    }

    func testWorkspaceReentryBriefRunsReferenceResolutionWhenBelowLargeDataLimit() {
        let now = Date(timeIntervalSince1970: 56_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        var referenceResolutionPassCount = 0

        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [],
            todos: [
                WorkspaceReentryTodoRecord(id: "open", workspaceId: "workspace", title: "Open", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: nil, linkedResourceId: "dangling-todo-resource")
            ],
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas", workspaceId: "workspace", updatedAt: now)
            ],
            nodes: [
                WorkspaceReentryCanvasNodeRecord(id: "resource-node", canvasId: "canvas", objectType: "resourcePin", objectId: "dangling-node-resource", updatedAt: now),
                WorkspaceReentryCanvasNodeRecord(id: "snippet-node", canvasId: "canvas", objectType: "snippet", objectId: "dangling-node-snippet", updatedAt: now)
            ],
            edges: [
                WorkspaceReentryCanvasEdgeRecord(id: "dangling-edge", canvasId: "canvas", sourceNodeId: "resource-node", targetNodeId: "missing-node", updatedAt: now)
            ],
            now: now,
            referenceResolutionProbe: { referenceResolutionPassCount += 1 }
        )

        XCTAssertFalse(brief.isLargeDataDegraded)
        XCTAssertEqual(brief.budgetDecision.mode, .detailed)
        XCTAssertTrue(brief.budgetDecision.reasons.isEmpty)
        XCTAssertTrue(brief.budgetDecision.shouldResolveReferences)
        XCTAssertGreaterThan(referenceResolutionPassCount, 0)
        XCTAssertEqual(brief.unresolvedReferenceCount, 4)
        XCTAssertEqual(brief.canvasSummary.validLinkCount, 0)
    }

    func testWorkspaceReentryBriefDoesNotDegradeForUnrelatedLargeWorkspaceInputs() {
        let now = Date(timeIntervalSince1970: 80_000)
        let workspace = WorkspaceReentryWorkspaceRecord(id: "workspace", title: "Workspace", lastOpenedAt: nil, updatedAt: now)
        let otherNodes = (0...WorkspaceReentryBriefPolicy.maximumDetailedNodeCount).map { index in
            WorkspaceReentryCanvasNodeRecord(id: "other-node-\(index)", canvasId: "other-canvas", objectType: nil, objectId: nil, updatedAt: now)
        }
        let otherEdges = (0...WorkspaceReentryBriefPolicy.maximumDetailedEdgeCount).map { index in
            WorkspaceReentryCanvasEdgeRecord(id: "other-edge-\(index)", canvasId: "other-canvas", sourceNodeId: "missing-a", targetNodeId: "missing-b", updatedAt: now)
        }
        let otherTodos = (0...WorkspaceReentryBriefPolicy.maximumDetailedTodoCount).map { index in
            WorkspaceReentryTodoRecord(id: "other-todo-\(index)", workspaceId: "other-workspace", title: "Other", isCompleted: false, isPinned: false, sortIndex: index, updatedAt: now, dueAt: nil, linkedResourceId: nil)
        }
        let brief = WorkspaceReentryBriefPolicy.brief(
            for: workspace,
            resources: [],
            snippets: [
                WorkspaceReentrySnippetRecord(id: "snippet", workspaceId: "workspace", title: "Snippet", scope: "workspace", updatedAt: now, lastCopiedAt: now, lastUsedAt: nil)
            ],
            todos: [
                WorkspaceReentryTodoRecord(id: "todo", workspaceId: "workspace", title: "Todo", isCompleted: false, isPinned: false, sortIndex: 0, updatedAt: now, dueAt: nil, linkedResourceId: nil)
            ] + otherTodos,
            canvases: [
                WorkspaceReentryCanvasRecord(id: "canvas", workspaceId: "workspace", updatedAt: now),
                WorkspaceReentryCanvasRecord(id: "other-canvas", workspaceId: "other-workspace", updatedAt: now)
            ],
            nodes: [
                WorkspaceReentryCanvasNodeRecord(id: "node", canvasId: "canvas", objectType: nil, objectId: nil, updatedAt: now)
            ] + otherNodes,
            edges: otherEdges,
            now: now
        )

        XCTAssertFalse(brief.isLargeDataDegraded)
        XCTAssertEqual(brief.nextTaskIds, ["todo"])
        XCTAssertEqual(brief.recentSnippetIds, ["snippet"])
        XCTAssertEqual(brief.canvasSummary.cardCount, 1)
    }

    private func makeSparseCanvasEdgeViewportFixture(
        edgeCount: Int
    ) -> (nodes: [CanvasFrameRect], edges: [CanvasEdgeViewportRecord]) {
        var nodes: [CanvasFrameRect] = []
        var edges: [CanvasEdgeViewportRecord] = []
        for index in 0..<edgeCount {
            let x = Double(index) * 1_000
            let sourceID = "source-\(index)"
            let targetID = "target-\(index)"
            nodes.append(CanvasFrameRect(id: sourceID, x: x, y: 0, width: 80, height: 80))
            nodes.append(CanvasFrameRect(id: targetID, x: x + 160, y: 0, width: 80, height: 80))
            edges.append(CanvasEdgeViewportRecord(id: "edge-\(index)", sourceNodeID: sourceID, targetNodeID: targetID))
        }
        return (nodes, edges)
    }

    private func normalizedText(_ parts: [String]) -> String {
        parts
            .joined(separator: " ")
            .lowercased()
    }

    private func containsWholeWord(_ word: String, in text: String) -> Bool {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .contains(word.lowercased())
    }
}
