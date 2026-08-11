import Foundation
import MindDeskCore
import XCTest
@testable import MindDesk

final class S0SurfaceAbsenceTests: XCTestCase {
    func testCanvasReviewOffNoticeIsAbsentFromProductSourcesDefaultHelpOnboardingMenusAndRails() throws {
        let rule = "A122"
        let root = try repositoryRoot(rule: rule)
        let productDocuments = try productionSwiftDocuments(root: root, rule: rule)
            + resourceDocuments(root: root, rule: rule)
        let notices = [
            "**Canvas Review is currently off.** This version does not start an Agent or review helper, generate an AI context package, or provide Canvas content to a model through this feature. MindDesk's normal storage, system backup, sync, and any external services you use remain subject to their own privacy settings.",
            "**Canvas Review 当前处于关闭状态。** 此版本不会通过该功能启动 Agent 或审阅助手、生成 AI 上下文包，也不会向模型提供 Canvas 内容。MindDesk 的常规存储、系统备份、同步以及您使用的任何外部服务，仍受其各自隐私设置约束。"
        ]

        for notice in notices {
            XCTAssertTrue(
                sourceOccurrences(of: notice, in: productDocuments).isEmpty,
                "[\(rule)] current privacy documentation must not appear in product UI, default Help, onboarding, menus, or rails."
            )
        }
    }

    func testDeletedReviewRuntimePathsAndResourceMarkersAreAbsent() throws {
        let rule = "A024"
        let root = try repositoryRoot(rule: rule)
        let deletedPaths = [
            "Sources/MindDesk/Canvas/CanvasCodexAgentSidebar.swift",
            "Sources/MindDesk/Canvas/CanvasCodexSessionController.swift",
            "Sources/MindDesk/Canvas/CanvasCodexTerminalView.swift",
            "Sources/MindDesk/Services/CodexTerminalService.swift",
            "Sources/MindDesk/Views/ProposalReviewSheet.swift",
            "Sources/MindDeskCore/CanvasCodexPrompt.swift",
            "Sources/MindDeskCore/MindDeskAgentHandoffPrompt.swift",
            "Sources/MindDeskCore/MindDeskAgentReviewCustomGuidancePresentation.swift",
            "Sources/MindDeskCore/MindDeskAgentReviewPackageReadiness.swift",
            "Sources/MindDeskCore/MindDeskAgentWorkflowSearch.swift",
            "Sources/MindDeskCore/MindDeskProposalCopyPathPlanner.swift",
            "Sources/MindDeskCore/MindDeskProposalEnvelopeExtractor.swift",
            "Sources/MindDeskCore/MindDeskProposalEnvelopeTemplate.swift",
            "Sources/MindDeskCore/MindDeskProposalReviewGate.swift",
            "Sources/MindDeskCore/MindDeskProposalSourcePackageRawValidation.swift",
            "Tests/MindDeskTests/ProposalReviewPresentationTests.swift"
        ]
        for relativePath in deletedPaths.sorted() {
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path),
                "[\(rule)] \(relativePath):1: deleted Gate 2B path still exists"
            )
        }

        let productionAndResources = try productionSwiftDocuments(root: root, rule: rule)
            + resourceDocuments(root: root, rule: rule)
        assertTokensAbsent(
            rule: rule,
            tokens: [
                "minddesk-canvas-prompt.txt",
                "minddesk-agent-review-source.mip.json",
                "minddesk-proposal-template.json",
                "minddesk-open-codex",
                "minddesk-open-codex.sh",
                "minddesk-open-codex-with-prompt.sh",
                "minddesk-codex-terminal-",
                "Review Agent Proposal",
                "Export Agent Review Package",
                "Start Shell",
                "+ Prompt Run"
            ],
            in: productionAndResources
        )

        let edgePolicyPath = "Sources/MindDeskCore/CanvasEdgeAnimationInteractionPolicy.swift"
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: root.appendingPathComponent(edgePolicyPath).path),
            "[\(rule)] \(edgePolicyPath):1: ordinary Canvas edge interaction policy was removed"
        )
    }

    func testPackageManifestAndResolutionContainNoSwiftTermOrExternalPackageDependency() throws {
        let rule = "A025"
        let root = try repositoryRoot(rule: rule)
        let package = try sourceDocument("Package.swift", root: root, rule: rule)
        let compactPackage = compactWhitespace(package.contents)

        XCTAssertEqual(
            occurrenceCount(of: "dependencies:[],targets:[", in: compactPackage),
            1,
            "[\(rule)] Package.swift:1: package-level dependencies must be structurally empty"
        )
        let executableTarget = try balancedSlice(
            startingWith: ".executableTarget(",
            opening: "(",
            closing: ")",
            in: package,
            rule: rule
        )
        XCTAssertTrue(
            compactWhitespace(executableTarget).contains("name:\"MindDesk\",dependencies:[\"MindDeskCore\"]"),
            "[\(rule)] Package.swift:1: MindDesk executable dependencies must contain only MindDeskCore"
        )

        assertRegexAbsent(
            rule: rule,
            patterns: [#"\.\s*package\s*\("#, #"\.\s*product\s*\("#],
            in: [package]
        )
        assertRegexAbsent(
            rule: rule,
            patterns: [#"(?i)swift[\s_-]*term"#, #"(?i)swift[\s_-]*argument[\s_-]*parser"#, #"https?://"#],
            in: [package]
        )

        let resolvedPath = "Package.resolved"
        let resolvedURL = root.appendingPathComponent(resolvedPath)
        if FileManager.default.fileExists(atPath: resolvedURL.path) {
            let resolved = try sourceDocument(resolvedPath, root: root, rule: rule)
            assertRegexAbsent(
                rule: rule,
                patterns: [#"(?i)swift[\s_-]*term"#, #"(?i)swift[\s_-]*argument[\s_-]*parser"#, #"https?://"#],
                in: [resolved]
            )
        }
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: resolvedURL.path),
            "[\(rule)] \(resolvedPath):1: dependency resolution file must be absent"
        )
    }

    func testApplicationMenusCommandsFocusedValuesAndShortcutsContainNoReviewEntryPoints() throws {
        let rule = "A026"
        let root = try repositoryRoot(rule: rule)
        let app = try sourceDocument("Sources/MindDesk/App/MindDeskApp.swift", root: root, rule: rule)
        let content = try sourceDocument("Sources/MindDesk/Views/ContentView.swift", root: root, rule: rule)
        assertTokensAbsent(
            rule: rule,
            tokens: [
                "exportAgentReviewPackage",
                "importProposalReview",
                "Export Agent Review Package",
                "Review Agent Proposal",
                "saveAgentReviewPackage",
                "openProposalEnvelope",
                "openProposalSourcePackage"
            ],
            in: [app, content]
        )

        for token in [
            "struct MindDeskMenuCommands: Commands",
            "@FocusedValue(\\.mindDeskCommands) private var commands",
            "commands?.newWorkspace()",
            "commands?.quickOpen()",
            "commands?.importManifest()",
            "commands?.exportManifest()",
            ".keyboardShortcut(\"n\", modifiers: .command)",
            ".keyboardShortcut(\"k\", modifiers: .command)",
            ".keyboardShortcut(\"i\", modifiers: [.command, .shift])",
            ".keyboardShortcut(\"e\", modifiers: [.command, .shift])"
        ] {
            assertSourceContains(rule: rule, token: token, in: app)
        }
        for token in [
            "struct MindDeskFocusedCommands",
            "private struct MindDeskFocusedCommandsKey: FocusedValueKey",
            "extension FocusedValues",
            ".focusedValue(\\.mindDeskCommands, MindDeskFocusedCommands(",
            "var newWorkspace: () -> Void",
            "var quickOpen: () -> Void",
            "var importManifest: () -> Void",
            "var exportManifest: () -> Void",
            "newWorkspace: addWorkspace",
            "quickOpen: openQuickOpen",
            "importManifest: importManifest",
            "exportManifest: exportManifest"
        ] {
            assertSourceContains(rule: rule, token: token, in: content)
        }
    }

    func testCanvasRailToolbarSheetBannerAndSessionPlumbingContainNoReviewEntryPoints() throws {
        let rule = "A027"
        let root = try repositoryRoot(rule: rule)
        let content = try sourceDocument("Sources/MindDesk/Views/ContentView.swift", root: root, rule: rule)
        let canvas = try sourceDocument("Sources/MindDesk/Canvas/WorkspaceCanvasView.swift", root: root, rule: rule)
        let ordering = try sourceDocument("Sources/MindDeskCore/WorkbenchOrdering.swift", root: root, rule: rule)
        assertTokensAbsent(
            rule: rule,
            tokens: [
                "CanvasCodexAgentSidebar",
                "CanvasCodexSessionController",
                "CanvasCodexPrompt",
                "CanvasCodexPromptTemplateLibrary",
                "CanvasCodexSidebarContextSummary",
                "CanvasCodexPromptBuilder",
                "CanvasCodexPromptContext",
                "CanvasCodexPromptNodeRecord",
                "CanvasCodexPromptEdgeRecord",
                "canvasCodexAgentRail",
                "case codexAgent",
                ".codexAgent",
                "codexSession",
                "codexTemplate",
                "selectedCodexTemplate",
                "currentCodex",
                "startCodexSession",
                "runCodexTerminalCommand",
                "interruptCodexTerminalSession",
                "closeCodexTerminalSession",
                "copyCodexPrompt",
                "resetCodexTemplates",
                "previewCodexProposal",
                "reviseCodexProposal",
                "discardCodexProposalPreview",
                "reviewCodexProposal",
                "ensureCodexSessionStarted",
                "runCodexTerminalCommandWithPrompt",
                "onReviewAgentProposal",
                "ProposalReviewSheet",
                "proposalReviewSheet",
                "ProposalReviewPresentationModel",
                "MindDeskProposalReviewGateResult",
                "loadProposalReviewImport",
                "importProposalReview",
                "exportAgentReviewPackage",
                "AgentReviewHandoffPromptPresentation",
                "AgentReviewHandoffPromptPresentationPolicy",
                "copyAgentReviewHandoffPrompt",
                "copyAgentReviewProposalTemplate",
                "agentReviewHandoffPrompt",
                "approvedProposalCopyPath",
                "pendingApprovedProposalCopyPathPlans",
                "codexRailMinimumWidth",
                "codexRailIdealWidth",
                "codexRailWidth"
            ],
            in: [content, canvas, ordering]
        )

        for token in [
            "case inspector",
            "toggleRightRailPanel(.inspector)",
            "canvasInspectorRail",
            "let allResources: [ResourcePinModel]",
            "snapshot.resource(for: node)",
            "resources: allResources"
        ] {
            assertSourceContains(rule: rule, token: token, in: canvas)
        }
        assertSourceContains(rule: rule, token: "allResources: resources", in: content)
        for token in ["rightRailWidth(availableWidth:", "rightRailScrollableContentWidth(railWidth:"] {
            assertSourceContains(rule: rule, token: token, in: ordering)
        }
    }

    func testSettingsHelpAndResourceSurfacesContainNoReviewDefaultsOrActions() throws {
        let rule = "A028"
        let root = try repositoryRoot(rule: rule)
        let production = try productionSwiftDocuments(root: root, rule: rule)
        let appSources = production.filter { $0.relativePath.hasPrefix("Sources/MindDesk/") }
        let help = try sourceDocument("Sources/MindDeskCore/MindDeskHelpCatalog.swift", root: root, rule: rule)
        let interchangePath = "Sources/MindDeskCore/MindDeskInterchangePackage.swift"
        let interchangeDocuments = production.filter { $0.relativePath == interchangePath }
        let settings = try sourceDocument("Sources/MindDesk/Views/AppSettingsView.swift", root: root, rule: rule)
        let services = try sourceDocument("Sources/MindDesk/Services/SystemServices.swift", root: root, rule: rule)
        let productionAndResources = production + (try resourceDocuments(root: root, rule: rule))

        XCTAssertEqual(
            MindDeskHelpCatalog.defaultTopics.map(\.id),
            ["settings-defaults", "canvas-performance", "import-export"],
            "[\(rule)] runtime defaultTopics must contain exactly the three ordinary topics in order"
        )
        XCTAssertFalse(
            MindDeskHelpCatalog.defaultTopics.contains { $0.category == .agent },
            "[\(rule)] runtime defaultTopics still exposes an Agent category"
        )
        assertTokensAbsent(
            rule: rule,
            tokens: [
                "agent-proposal-review",
                "agent-extension-capabilities",
                "agent-readonly-mip",
                "agent-prompt-workflow",
                "agentReviewPackageTopicIDs"
            ],
            in: productionAndResources
        )

        let alias = "agentReviewPackageTopics"
        let aliasOccurrences = identifierOccurrences(of: alias, in: production)
        if aliasOccurrences.count == 4 {
            XCTAssertEqual(
                aliasOccurrences.filter { $0.relativePath == help.relativePath }.count,
                1,
                "[\(rule)] \(help.relativePath):1: transitional alias must have one declaration"
            )
            XCTAssertEqual(
                aliasOccurrences.filter { $0.relativePath == interchangePath }.count,
                3,
                "[\(rule)] \(interchangePath):1: transitional alias must have exactly three pre-Gate-3 call sites"
            )
            XCTAssertTrue(
                aliasOccurrences.allSatisfy {
                    $0.relativePath == help.relativePath || $0.relativePath == interchangePath
                },
                "[\(rule)] transitional alias escaped its two approved Core files: \(formatted(aliasOccurrences))"
            )
            let aliasSource = try balancedSlice(
                startingWith: "public static var agentReviewPackageTopics",
                opening: "{",
                closing: "}",
                in: help,
                rule: rule
            )
            let body = try contentsInsideBraces(aliasSource, path: help.relativePath, rule: rule)
            XCTAssertEqual(
                compactWhitespace(body),
                "defaultTopics",
                "[\(rule)] \(help.relativePath):1: transitional alias body must be exactly defaultTopics"
            )
        } else if aliasOccurrences.isEmpty {
            XCTAssertEqual(
                interchangeDocuments.count,
                1,
                "[\(rule)] \(interchangePath):1: Gate 3+ must retain exactly one stored-wire MIP source without Help defaults"
            )
        } else {
            XCTFail(
                "[\(rule)] transitional alias must be phase-monotone at exactly four or zero occurrences; found \(formatted(aliasOccurrences))"
            )
        }
        assertTokensAbsent(
            rule: rule,
            tokens: ["MindDeskHelpCatalog.defaultTopics"],
            in: interchangeDocuments
        )

        let preferences = try sourceDocument("Sources/MindDeskCore/AppPreferences.swift", root: root, rule: rule)
        assertTokensAbsent(
            rule: rule,
            tokens: [
                "agentReviewPackageDescription",
                "agentReviewPackageBoundaryRows",
                "agentReviewCustomGuidance",
                "AppPreferenceKeys.agentReviewCustomPromptGuidance",
                "MindDeskAgentReviewCustomGuidance",
                "Agent Review Package",
                "Text(\"Agent Review\")",
                "case .agent:"
            ],
            in: [settings]
        )
        assertTokensAbsent(
            rule: rule,
            tokens: ["Canvas Codex prompt templates", "Custom Agent Review Guidance"],
            in: [preferences]
        )
        assertTokensAbsent(
            rule: rule,
            tokens: [
                "agentReviewPackageDefaultFilename",
                "agentReviewPackagePanelMessage",
                "proposalEnvelopeOpenPanelMessage",
                "proposalSourcePackageOpenPanelMessage",
                "agentReviewPackageConfirmationMessage",
                "agentReviewPackagePrivacyDisclosure",
                "makeAgentReviewPackage",
                "encodeAgentReviewPackage",
                "decodeProposalReviewImport",
                "decodeProposalEnvelope",
                "decodeProposalSourcePackage",
                "proposalReviewImportBlockedStatus",
                "proposalReviewImportReadyStatus",
                "agentReviewPackageExportStatus"
            ],
            in: [services]
        )
        assertTokensAbsent(
            rule: rule,
            tokens: ["AgentReview", "CanvasCodex", "CodexTerminal"],
            in: appSources.filter { $0.relativePath.hasSuffix("ResourceSnippetViews.swift") }
                + (try resourceDocuments(root: root, rule: rule))
        )
    }

    func testReviewDeepLinksAndRestoreConsumersAreAbsent() throws {
        let rule = "A029"
        let root = try repositoryRoot(rule: rule)
        let production = try productionSwiftDocuments(root: root, rule: rule)
        assertTokensAbsent(
            rule: rule,
            tokens: [
                "minddesk-open-codex.sh",
                "minddesk-open-codex-with-prompt.sh",
                "openCodexCommand",
                "openCodexWithPromptCommand",
                "ProposalReviewOpenStep",
                "proposalEnvelopeOpenStep",
                "proposalSourcePackageOpenStep",
                "openProposalEnvelope",
                "openProposalSourcePackage",
                "openProposalReviewFile",
                "onReviewAgentProposal",
                "openInlineProposalReview",
                "reviewCodexProposal",
                "proposalReviewSheet",
                "pendingApprovedProposalCopyPathPlans",
                "approvedProposalCopyPathConfirmation",
                "agentReviewHandoffPromptPresentation",
                "codexSession.reset()",
                "codexTemplateLibraryRaw",
                "selectedCodexTemplateGroupID",
                "selectedCodexTemplateID"
            ],
            in: production
        )

        for retiredID in [
            "agent-proposal-review",
            "agent-extension-capabilities",
            "agent-readonly-mip",
            "agent-prompt-workflow"
        ] {
            XCTAssertEqual(
                MindDeskHelpCenterSelectionPolicy.normalizedSelection(
                    retiredID,
                    visibleTopics: MindDeskHelpCatalog.defaultTopics
                ),
                "settings-defaults",
                "[\(rule)] retired Help selection \(retiredID) did not normalize to settings-defaults"
            )
            XCTAssertEqual(
                MindDeskHelpCenterSelectionPolicy.selectedTopic(
                    selectedTopicID: retiredID,
                    visibleTopics: MindDeskHelpCatalog.defaultTopics
                )?.id,
                "settings-defaults",
                "[\(rule)] selectedTopic returned retired Help topic \(retiredID)"
            )
        }

        let settings = try sourceDocument("Sources/MindDesk/Views/AppSettingsView.swift", root: root, rule: rule)
        let content = try sourceDocument("Sources/MindDesk/Views/ContentView.swift", root: root, rule: rule)
        for token in [
            "@SceneStorage(\"minddesk.help.searchText\")",
            "@SceneStorage(\"minddesk.help.selectedTopicID\")",
            "MindDeskHelpCenterSelectionPolicy.selectedTopic("
        ] {
            assertSourceContains(rule: rule, token: token, in: settings)
        }
        assertSourceContains(rule: rule, token: "enum QuickOpenWebCardDeepLinkPolicy", in: content)
    }

    func testObsoleteReviewPreferenceKeysAppearOnlyInCleanupData() throws {
        let rule = "A030"
        let root = try repositoryRoot(rule: rule)
        let production = try productionSwiftDocuments(root: root, rule: rule)
        let preferences = try sourceDocument("Sources/MindDeskCore/AppPreferences.swift", root: root, rule: rule)
        let obsoleteRange = try obsoleteKeysLineRange(in: preferences, rule: rule)
        let obsoleteKeys = [
            "agentReviewCustomPromptGuidance",
            "canvasCodexPromptTemplateLibrary",
            "canvasCodexPromptTemplateGroup",
            "canvasCodexPromptTemplateOption"
        ]

        for key in obsoleteKeys.sorted() {
            let literalOccurrences = sourceOccurrences(of: "\"\(key)\"", in: production)
            XCTAssertEqual(
                literalOccurrences.count,
                1,
                "[\(rule)] obsolete raw key \(key) must have one production owner; found \(formatted(literalOccurrences))"
            )
            for occurrence in literalOccurrences {
                XCTAssertEqual(
                    occurrence.relativePath,
                    preferences.relativePath,
                    "[\(rule)] \(occurrence.relativePath):\(occurrence.lineNumber): obsolete raw key \(key) escaped AppPreferences cleanup"
                )
                XCTAssertTrue(
                    obsoleteRange.contains(occurrence.lineNumber),
                    "[\(rule)] \(occurrence.relativePath):\(occurrence.lineNumber): obsolete raw key \(key) is outside obsoleteKeys"
                )
            }
        }
        assertTokensAbsent(
            rule: rule,
            tokens: obsoleteKeys.flatMap {
                ["AppPreferenceKeys.\($0)", "AppPreferenceDefaults.\($0)"]
            },
            in: production
        )

        let suiteName = "S0SurfaceAbsenceTests.A030.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("[\(rule)] UserDefaults:1: could not create isolated suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        for key in obsoleteKeys {
            defaults.set("legacy-value", forKey: key)
        }
        AppPreferenceDefaults.restore(in: defaults)
        for key in obsoleteKeys {
            XCTAssertNil(
                defaults.object(forKey: key),
                "[\(rule)] AppPreferenceDefaults.restore:1: obsolete key \(key) was not removed"
            )
        }
        let resetItemKeys = Set(AppSettingsResetDescriptor.resetItems.map(\.key))
        let resettableKeys = Set(AppPreferenceDefaults.resettableKeys)
        for key in obsoleteKeys {
            XCTAssertFalse(resetItemKeys.contains(key), "[\(rule)] resetItems:1: obsolete key remains active: \(key)")
            XCTAssertFalse(resettableKeys.contains(key), "[\(rule)] resettableKeys:1: obsolete key remains active: \(key)")
        }
    }

    func testProductionSourcesContainNoSwiftTermOpenPTYOrProcessStartTokens() throws {
        let rule = "A031"
        let root = try repositoryRoot(rule: rule)
        let production = try productionSwiftDocuments(root: root, rule: rule)
        assertTokensAbsent(
            rule: rule,
            tokens: [
                "import SwiftTerm",
                "LocalProcessTerminalView",
                "CodexLocalProcessTerminalView",
                "CodexTerminalScreen",
                "CodexTerminalHostView",
                "CodexTerminalOutput",
                "CodexTerminalLaunchPlan",
                "CodexTerminalPreparedSession",
                "CodexTerminalPendingInput",
                "CodexTerminalSession",
                "CodexTerminalService",
                "CodexTerminalOutputSink",
                "openpty(",
                ".startProcess("
            ],
            in: production
        )
        assertRegexAbsent(rule: rule, patterns: [#"(?<![A-Za-z0-9_])startProcess\s*\("#], in: production)

        let services = try sourceDocument("Sources/MindDesk/Services/SystemServices.swift", root: root, rule: rule)
        let resources = try sourceDocument("Sources/MindDesk/Views/ResourceSnippetViews.swift", root: root, rule: rule)
        for token in ["struct AppleScriptRunner", "struct TerminalService", "func prefill(command:", "func run(command:"] {
            assertSourceContains(rule: rule, token: token, in: services)
        }
        for token in [
            "try TerminalService().prefill(command: snippet.body",
            "try TerminalService().run(command: snippet.body",
            "try TerminalService().open(at: request.workingDirectory)"
        ] {
            assertSourceContains(rule: rule, token: token, in: resources)
        }
    }

    func testAppSourcesReferenceHistoricalReviewTypesOnlyThroughClassifierAndPermanentLock() throws {
        let rule = "A032"
        let root = try repositoryRoot(rule: rule)
        let appSources = try swiftDocuments(in: "Sources/MindDesk", root: root, rule: rule)
        for identifier in historicalReviewTypeIdentifiers.sorted() {
            assertIdentifierAbsent(rule: rule, identifier: identifier, in: appSources)
        }

        let service = try sourceDocument("Sources/MindDesk/Services/SystemServices.swift", root: root, rule: rule)
        let decoderRange = try lineRange(
            startingWith: "func decodeManifest(from data: Data)",
            endingBefore: "private func rejectLegacyReviewDocument()",
            in: service,
            rule: rule
        )
        let rejectionRange = try braceBlockLineRange(
            startingWith: "private func rejectLegacyReviewDocument()",
            in: service,
            rule: rule
        )
        let allowedIdentifierCounts = [
            "MindDeskJSONDocumentClassifier": 1,
            "MindDeskJSONDocumentClassification": 0,
            "MindDeskJSONDocumentKind": 0,
            "CanvasReviewCapabilityLock": 1,
            "CanvasReviewCapabilityError": 1
        ]
        for identifier in allowedIdentifierCounts.keys.sorted() {
            for occurrence in identifierOccurrences(of: identifier, in: appSources) {
                XCTAssertEqual(
                    occurrence.relativePath,
                    service.relativePath,
                    "[\(rule)] \(occurrence.relativePath):\(occurrence.lineNumber): allowed classifier/lock type escaped SystemServices: \(identifier)"
                )
                XCTAssertTrue(
                    decoderRange.contains(occurrence.lineNumber) || rejectionRange.contains(occurrence.lineNumber),
                    "[\(rule)] \(occurrence.relativePath):\(occurrence.lineNumber): allowed type is outside bounded rejection branch: \(identifier)"
                )
            }
            assertIdentifierCount(
                rule: rule,
                identifier: identifier,
                expected: allowedIdentifierCounts[identifier]!,
                in: appSources
            )
        }
        assertTokensAbsent(rule: rule, tokens: ["MindDeskJSONDocumentKind.classify"], in: appSources)
        for token in [
            "let classification = MindDeskJSONDocumentClassifier.classify(data)",
            "catch CanvasReviewCapabilityError.unavailable",
            "try CanvasReviewCapabilityLock.requireEnabled()"
        ] {
            assertSourceContains(rule: rule, token: token, in: service)
        }
        assertSourceContains(rule: rule, token: "MindDeskManifestValidationReport", in: service)
    }

    func testValidationDisplayTextSanitizerUsesOnlyNeutralPlainStringContracts() throws {
        let rule = "A033"
        let root = try repositoryRoot(rule: rule)
        let sanitizer = try sourceDocument(
            "Sources/MindDesk/Services/ValidationDisplayTextSanitizer.swift",
            root: root,
            rule: rule
        )
        assertSourceContains(rule: rule, token: "enum ValidationDisplayTextSanitizer", in: sanitizer)
        assertTokensAbsent(
            rule: rule,
            tokens: [
                "ProposalReviewSafeDisplayText",
                "safeAgentText",
                "import MindDeskCore",
                "MindDeskValidationReportSource",
                "Validation issue blocked review."
            ],
            in: [sanitizer]
        )
        for identifier in historicalReviewTypeIdentifiers.sorted() {
            assertIdentifierAbsent(rule: rule, identifier: identifier, in: [sanitizer])
        }

        let headers = nonPrivateStaticFunctionHeaders(in: sanitizer.contents)
        XCTAssertEqual(
            headers.count,
            3,
            "[\(rule)] \(sanitizer.relativePath):1: neutral callable declaration count drifted: \(headers.sorted())"
        )
        XCTAssertEqual(
            Set(headers.map { functionName(in: $0) }),
            Set(["safeDiagnosticMessage", "safeIssueLocation", "containsUnsafeText"]),
            "[\(rule)] \(sanitizer.relativePath):1: neutral callable declaration inventory drifted: \(headers.sorted())"
        )
        for header in headers.sorted() {
            let capitalizedTypes = Set(regexMatches(pattern: #"\b[A-Z][A-Za-z0-9_]*\b"#, in: header))
            XCTAssertTrue(
                capitalizedTypes.isSubset(of: Set(["String", "Bool"])),
                "[\(rule)] \(sanitizer.relativePath):1: callable contract is not plain String/String?/Bool: \(header)"
            )
            let typeMarkerCount = regexMatches(pattern: #"(?::|->)"#, in: header).count
            let allowedTypeCount = regexMatches(
                pattern: #"(?::|->)\s*(?:String\?|String|Bool)(?=\s*(?:[,)]|$))"#,
                in: header
            ).count
            XCTAssertEqual(
                allowedTypeCount,
                typeMarkerCount,
                "[\(rule)] \(sanitizer.relativePath):1: callable contract contains a non-primitive parameter or result: \(header)"
            )
            XCTAssertFalse(
                header.replacingOccurrences(of: "->", with: "").contains(where: { $0 == "<" || $0 == ">" }),
                "[\(rule)] \(sanitizer.relativePath):1: generic callable contracts are forbidden: \(header)"
            )
        }

        assertTokensAbsent(
            rule: rule,
            tokens: [
                "\"package\"",
                "\"packageInstanceID\"",
                "\"validationReport\"",
                "\"agentIntegrationContract\"",
                "\"extensionCapabilities\"",
                "\"agentGuide\"",
                "\"agentPolicy\"",
                "\"externalActionPolicy\"",
                "\"proposalEnvelope\"",
                "\"proposedBy\"",
                "\"context\"",
                "\"proposals\"",
                "\"operationContracts\"",
                "\"reviewGate\"",
                "\"capabilities\""
            ],
            in: [sanitizer]
        )
        for rootName in [
            "manifest", "format", "formatVersion", "schemaVersion", "exportedAt", "workspaces", "resources",
            "snippets", "canvases", "nodes", "edges", "aliases", "todoGroups", "todos"
        ] {
            assertSourceContains(rule: rule, token: "\"\(rootName)\"", in: sanitizer)
        }

        let diagnosticBody = try balancedSlice(
            startingWith: "static func safeDiagnosticMessage",
            opening: "{",
            closing: "}",
            in: sanitizer,
            rule: rule
        ).lowercased()
        for forbiddenWord in ["agent", "proposal", "review"] {
            XCTAssertFalse(
                diagnosticBody.contains(forbiddenWord),
                "[\(rule)] \(sanitizer.relativePath):1: diagnostic fallback is not neutral: \(forbiddenWord)"
            )
        }
    }

    func testOrdinaryManifestClipboardFinderTerminalInspectorHelpOverviewAndCanvasSurfacesRemain() throws {
        let rule = "A034"
        let root = try repositoryRoot(rule: rule)
        let app = try sourceDocument("Sources/MindDesk/App/MindDeskApp.swift", root: root, rule: rule)
        let content = try sourceDocument("Sources/MindDesk/Views/ContentView.swift", root: root, rule: rule)
        let services = try sourceDocument("Sources/MindDesk/Services/SystemServices.swift", root: root, rule: rule)
        let importService = try sourceDocument("Sources/MindDesk/Services/ManifestImportService.swift", root: root, rule: rule)
        let resources = try sourceDocument("Sources/MindDesk/Views/ResourceSnippetViews.swift", root: root, rule: rule)
        let canvas = try sourceDocument("Sources/MindDesk/Canvas/WorkspaceCanvasView.swift", root: root, rule: rule)
        let edgePolicy = try sourceDocument("Sources/MindDeskCore/CanvasEdgeAnimationInteractionPolicy.swift", root: root, rule: rule)
        let help = try sourceDocument("Sources/MindDeskCore/MindDeskHelpCatalog.swift", root: root, rule: rule)
        let settings = try sourceDocument("Sources/MindDesk/Views/AppSettingsView.swift", root: root, rule: rule)
        let detailTab = try sourceDocument("Sources/MindDesk/Models/WorkspaceDetailTab.swift", root: root, rule: rule)
        let ordering = try sourceDocument("Sources/MindDeskCore/WorkbenchOrdering.swift", root: root, rule: rule)

        for token in [
            "func makeManifest(",
            "func decodeManifest(from url: URL) throws -> ExportManifest",
            "func decodeManifest(from data: Data) throws -> ExportManifest",
            "static func saveJSON() -> URL?",
            "static func openJSON() -> URL?",
            "struct ClipboardService",
            "init(writer:",
            "struct FinderService",
            "struct AppleScriptRunner",
            "struct TerminalService"
        ] {
            assertSourceContains(rule: rule, token: token, in: services)
        }
        assertSourceContains(rule: rule, token: "struct ManifestImportService", in: importService)
        for token in [
            "private func exportManifest()",
            "private func importManifest()",
            "JSONEncoder.minddesk.encode(manifest)",
            "ManifestImportService().importRecords",
            "clipboardService.copy(snippet.body)",
            "private func copyResourcePath(_ resource: ResourcePinModel)",
            "clipboardService.copy(resource.displayPath)",
            "try FinderService().open(url)",
            "try FinderService().reveal(url)",
            "case .overview:",
            "WorkspaceResumeBriefView(",
            "case .tasks:",
            "WorkspaceTodoBoardView(",
            "case .resources:",
            "case .snippets:",
            "case .canvas:",
            "WorkspaceCanvasView(",
            "enum QuickOpenWebCardDeepLinkPolicy"
        ] {
            assertSourceContains(rule: rule, token: token, in: content)
        }
        for token in [
            "struct MindDeskMenuCommands: Commands", "@FocusedValue(\\.mindDeskCommands) private var commands",
            "commands?.newWorkspace()", "commands?.quickOpen()", "commands?.importManifest()", "commands?.exportManifest()",
            ".keyboardShortcut(\"n\", modifiers: .command)", ".keyboardShortcut(\"k\", modifiers: .command)",
            ".keyboardShortcut(\"i\", modifiers: [.command, .shift])", ".keyboardShortcut(\"e\", modifiers: [.command, .shift])",
            "struct MindDeskHelpCommands: Commands", "MindDeskHelpCenterView()",
            "Window(MindDeskHelpCommandDescriptor.title, id: MindDeskHelpCommandDescriptor.windowID)"
        ] {
            assertSourceContains(rule: rule, token: token, in: app)
        }
        for token in [
            "struct MindDeskFocusedCommands", "private struct MindDeskFocusedCommandsKey: FocusedValueKey",
            "extension FocusedValues", ".focusedValue(\\.mindDeskCommands, MindDeskFocusedCommands(",
            "QuickOpenPanel(", "private func openQuickOpen()", "private func openQuickOpenRecord(_ record: QuickOpenRecord)"
        ] {
            assertSourceContains(rule: rule, token: token, in: content)
        }
        for token in ["public enum QuickOpenRecordKind", "public struct QuickOpenRecord", "public enum QuickOpenIndex"] {
            assertSourceContains(rule: rule, token: token, in: ordering)
        }
        for token in [
            "clipboardService.copy(item.path)", "clipboardService.copy(snippet.body)",
            "try FinderService().open", "try FinderService().reveal",
            "try TerminalService().prefill(command: snippet.body", "try TerminalService().run(command: snippet.body"
        ] {
            assertSourceContains(rule: rule, token: token, in: resources)
        }
        for token in [
            "case inspector", "toggleRightRailPanel(.inspector)", "canvasInspectorRail",
            "let allResources: [ResourcePinModel]", "snapshot.resource(for: node)", "resources: allResources",
            "private func beginNodeDrag(for node: CanvasNodeModel)", "private func resizeNode(_ node: CanvasNodeModel",
            "private func connectByTap(_ node: CanvasNodeModel)", "private func addNoteNode()",
            "private func createEdge(from sourceId: String, to targetId: String)",
            "private func copyNodePayload(_ node: CanvasNodeModel)",
            "clipboardService.copy(resource.displayPath)", "clipboardService.copy(snippet.body)",
            "clipboardService.copy(workspace.title)", "clipboardService.copy(affordances.copyValue)",
            "try FinderService().open(resolved.url)", "try FinderService().reveal(resolved.url)",
            "CanvasEdgeAnimationInteractionPolicy.shouldDeferGlowAnimation("
        ] {
            assertSourceContains(rule: rule, token: token, in: canvas)
        }
        assertSourceContains(rule: rule, token: "enum CanvasEdgeAnimationInteractionPolicy", in: edgePolicy)
        for token in [
            "public enum MindDeskHelpSearch", "public struct MindDeskHelpSearchRequest", "public struct MindDeskHelpSearchResponse",
            "id: \"settings-defaults\"", "id: \"canvas-performance\"", "id: \"import-export\""
        ] {
            assertSourceContains(rule: rule, token: token, in: help)
        }
        for token in [
            "enum MindDeskHelpCenterWindow", "@SceneStorage(\"minddesk.help.searchText\")",
            "@SceneStorage(\"minddesk.help.selectedTopicID\")", "MindDeskHelpCenterSelectionPolicy.selectedTopic(",
            "MindDeskHelpCenterWindow.readerSections(for: topic)",
            "MindDeskHelpTopicReaderPolicy.sections(for: topic)"
        ] {
            assertSourceContains(rule: rule, token: token, in: settings)
        }
        for token in ["case overview", "case tasks", "case canvas", "case resources", "case snippets"] {
            assertSourceContains(rule: rule, token: token, in: detailTab)
        }

        let ordinaryIDs = Set(["settings-defaults", "canvas-performance", "import-export"])
        XCTAssertTrue(
            ordinaryIDs.isSubset(of: Set(MindDeskHelpCatalog.defaultTopics.map(\.id))),
            "[\(rule)] runtime ordinary Help topics are incomplete"
        )
        XCTAssertEqual(WorkspaceDetailTab.defaultTab, .canvas, "[\(rule)] ordinary workspace default tab changed")
        XCTAssertFalse(
            MindDeskHelpSearch.results(for: "settings", in: MindDeskHelpCatalog.defaultTopics, limit: 24).isEmpty,
            "[\(rule)] ordinary Help search no longer returns settings results"
        )
    }
}

private struct SourceDocument {
    let relativePath: String
    let contents: String
}

private struct SourceOccurrence: Equatable {
    let relativePath: String
    let lineNumber: Int
    let token: String
}

private enum S0SurfaceSourceTestError: Error {
    case failure(String)
}

private let historicalReviewTypeIdentifiers: Set<String> = [
    "MindDeskInterchangePackageFormat", "MindDeskInterchangePackage", "MindDeskInterchangeSummary",
    "MindDeskInterchangeValidationSeverity", "MindDeskValidationSeverity", "MindDeskInterchangeValidationSource",
    "MindDeskInterchangeValidationIssue", "MindDeskInterchangePackageValidation", "MindDeskInterchangePrivacy",
    "MindDeskAgentGuide", "MindDeskAgentReviewCustomGuidancePolicy", "MindDeskInterchangeExternalActionPolicy", "MindDeskInterchangeExternalActorPolicy",
    "MindDeskInterchangeExternalActionDecision", "MindDeskAgentWorkflowStep", "MindDeskAgentPolicy",
    "MindDeskAgentAudience", "MindDeskAgentAuthorityMode", "MindDeskAgentReferenceKind",
    "MindDeskAgentOperationPayloadField", "MindDeskAgentOperationPayloadValueShape",
    "MindDeskAgentOperationPayloadFieldSchema", "MindDeskAgentAuthorityContract", "MindDeskAgentFileFormatContract",
    "MindDeskAgentProposalEnvelopeContract", "MindDeskAgentReferenceSchemas", "MindDeskAgentOperationRiskContract",
    "MindDeskAgentOperationContract", "MindDeskAgentPromptTemplate", "MindDeskAgentReviewGateContract",
    "MindDeskAgentIntegrationContract", "MindDeskAgentIntegrationContractValidationIssue",
    "MindDeskAgentIntegrationContractValidation", "WorkbenchObjectReferenceIndex", "MindDeskExtensionCapabilityCatalog",
    "MindDeskExtensionCapabilitySearchMatchField", "MindDeskExtensionCapabilitySearchResult",
    "MindDeskExtensionCapabilitySearchSummary", "MindDeskExtensionCapabilitySearchResponse",
    "MindDeskExtensionCapabilitySearchRequest",
    "MindDeskExtensionCapability", "MindDeskExtensionCapabilityPolicyDecision",
    "MindDeskExtensionCapabilityCatalogValidationIssue", "MindDeskExtensionCapabilityCatalogValidation",
    "ProposalImportLimits", "MindDeskProposalEnvelope", "MindDeskProposalEnvelopeDecodeLimitError",
    "MindDeskProposalContextSnapshot", "MindDeskProposalContextDigest", "MindDeskProposal",
    "MindDeskProposalOperation", "MindDeskProposalOperationKind", "MindDeskProposalOperationRiskTier",
    "MindDeskProposalOperationPayload", "MindDeskProposalValidationIssue", "MindDeskProposalValidationDiagnostic",
    "MindDeskProposalEnvelopeValidation", "MindDeskProposalReviewState", "MindDeskProposalReviewEvent",
    "MindDeskProposalContextFreshness", "MindDeskValidationReportSource", "MindDeskValidationReportIssue",
    "MindDeskValidationReportSummary", "MindDeskValidationReportRedactionPolicy", "MindDeskValidationReport",
    "MindDeskAnyCodingKey", "MindDeskProposalDecodeLimitGuards", "MindDeskValidationReportToken",
    "CanvasCodexPrompt", "MindDeskAgentHandoffPrompt", "MindDeskAgentReviewCustomGuidancePresentation",
    "MindDeskAgentReviewPackageReadiness", "MindDeskAgentWorkflowSearch", "MindDeskProposalCopyPathPlanner",
    "MindDeskProposalEnvelopeExtractor", "MindDeskProposalEnvelopeTemplate", "MindDeskProposalReviewGate",
    "MindDeskProposalSourcePackageRawValidation", "MindDeskProposalReviewSession", "MindDeskProposalReviewPolicy",
    "MindDeskInterchangePackageValidationReport", "MindDeskProposalValidationReport",
    "MindDeskExtensionCapabilityCatalogValidationReport", "MindDeskAgentIntegrationContractValidationReport",
    "MindDeskProposalManifestDigest", "MindDeskExtensionCapabilitySearch", "WorkbenchExternalActionPolicy",
    "WorkbenchExternalActor", "WorkbenchExternalActionDecision", "WorkbenchExternalAction"
]

private func repositoryRoot(file: StaticString = #filePath, rule: String) throws -> URL {
    var candidate = URL(fileURLWithPath: String(describing: file)).deletingLastPathComponent()
    let fileManager = FileManager.default
    while candidate.path != "/" {
        var isDirectory = ObjCBool(false)
        if fileManager.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path),
           fileManager.fileExists(atPath: candidate.appendingPathComponent("Sources").path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return candidate
        }
        candidate.deleteLastPathComponent()
    }
    throw S0SurfaceSourceTestError.failure("[\(rule)] \(file):1: repository root not found")
}

private func sourceDocument(_ relativePath: String, root: URL, rule: String) throws -> SourceDocument {
    let url = root.appendingPathComponent(relativePath)
    do {
        return SourceDocument(relativePath: relativePath, contents: try String(contentsOf: url, encoding: .utf8))
    } catch {
        throw S0SurfaceSourceTestError.failure("[\(rule)] \(relativePath):1: UTF-8 source read failed: \(error)")
    }
}

private func productionSwiftDocuments(root: URL, rule: String) throws -> [SourceDocument] {
    try swiftDocuments(in: "Sources/MindDesk", root: root, rule: rule)
        + swiftDocuments(in: "Sources/MindDeskCore", root: root, rule: rule)
}

private func swiftDocuments(in relativeDirectory: String, root: URL, rule: String) throws -> [SourceDocument] {
    let directory = root.appendingPathComponent(relativeDirectory, isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
        throw S0SurfaceSourceTestError.failure("[\(rule)] \(relativeDirectory):1: source enumeration failed")
    }
    var documents: [SourceDocument] = []
    for case let url as URL in enumerator {
        guard url.pathExtension == "swift" else { continue }
        do {
            guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let relativePath = relativePath(for: url, root: root)
            let contents = try String(contentsOf: url, encoding: .utf8)
            documents.append(SourceDocument(relativePath: relativePath, contents: contents))
        } catch {
            throw S0SurfaceSourceTestError.failure("[\(rule)] \(relativePath(for: url, root: root)):1: Swift source read failed: \(error)")
        }
    }
    return documents.sorted { $0.relativePath < $1.relativePath }
}

private func resourceDocuments(root: URL, rule: String) throws -> [SourceDocument] {
    let relativeDirectory = "Sources/MindDesk/Resources"
    let directory = root.appendingPathComponent(relativeDirectory, isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) else {
        throw S0SurfaceSourceTestError.failure("[\(rule)] \(relativeDirectory):1: resource enumeration failed")
    }
    var documents: [SourceDocument] = []
    for case let url as URL in enumerator {
        do {
            guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let data = try Data(contentsOf: url)
            documents.append(
                SourceDocument(
                    relativePath: relativePath(for: url, root: root),
                    contents: String(decoding: data, as: UTF8.self)
                )
            )
        } catch {
            throw S0SurfaceSourceTestError.failure("[\(rule)] \(relativePath(for: url, root: root)):1: resource byte read failed: \(error)")
        }
    }
    return documents.sorted { $0.relativePath < $1.relativePath }
}

private func relativePath(for url: URL, root: URL) -> String {
    let prefixCount = root.path.hasSuffix("/") ? root.path.count : root.path.count + 1
    return String(url.path.dropFirst(prefixCount))
}

private func sourceOccurrences(of token: String, in documents: [SourceDocument]) -> [SourceOccurrence] {
    documents.flatMap { document in
        document.contents.components(separatedBy: .newlines).enumerated().flatMap { index, sourceLine in
            Array(
                repeating: SourceOccurrence(relativePath: document.relativePath, lineNumber: index + 1, token: token),
                count: occurrenceCount(of: token, in: sourceLine)
            )
        }
    }.sorted(by: occurrenceOrder)
}

private func regexOccurrences(pattern: String, in documents: [SourceDocument]) -> [SourceOccurrence] {
    guard let expression = try? NSRegularExpression(pattern: pattern) else {
        preconditionFailure("invalid source-test regex: \(pattern)")
    }
    return documents.flatMap { document in
        document.contents.components(separatedBy: .newlines).enumerated().flatMap { index, sourceLine in
            let range = NSRange(sourceLine.startIndex..<sourceLine.endIndex, in: sourceLine)
            return expression.matches(in: sourceLine, range: range).map { _ in
                SourceOccurrence(relativePath: document.relativePath, lineNumber: index + 1, token: pattern)
            }
        }
    }.sorted(by: occurrenceOrder)
}

private func identifierOccurrences(of identifier: String, in documents: [SourceDocument]) -> [SourceOccurrence] {
    let escaped = NSRegularExpression.escapedPattern(for: identifier)
    return regexOccurrences(pattern: "(?<![A-Za-z0-9_])\(escaped)(?![A-Za-z0-9_])", in: documents)
        .map { SourceOccurrence(relativePath: $0.relativePath, lineNumber: $0.lineNumber, token: identifier) }
}

private func occurrenceOrder(_ lhs: SourceOccurrence, _ rhs: SourceOccurrence) -> Bool {
    if lhs.token != rhs.token { return lhs.token < rhs.token }
    if lhs.relativePath != rhs.relativePath { return lhs.relativePath < rhs.relativePath }
    return lhs.lineNumber < rhs.lineNumber
}

private func formatted(_ occurrences: [SourceOccurrence]) -> String {
    occurrences.sorted(by: occurrenceOrder).map { "\($0.relativePath):\($0.lineNumber):\($0.token)" }.joined(separator: ", ")
}

private func assertTokensAbsent(
    rule: String,
    tokens: [String],
    in documents: [SourceDocument],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    for token in tokens.sorted() {
        for occurrence in sourceOccurrences(of: token, in: documents) {
            XCTFail("[\(rule)] \(occurrence.relativePath):\(occurrence.lineNumber): forbidden token: \(token)", file: file, line: line)
        }
    }
}

private func assertRegexAbsent(
    rule: String,
    patterns: [String],
    in documents: [SourceDocument],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    for pattern in patterns.sorted() {
        for occurrence in regexOccurrences(pattern: pattern, in: documents) {
            XCTFail("[\(rule)] \(occurrence.relativePath):\(occurrence.lineNumber): forbidden pattern: \(pattern)", file: file, line: line)
        }
    }
}

private func assertIdentifierAbsent(
    rule: String,
    identifier: String,
    in documents: [SourceDocument],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    for occurrence in identifierOccurrences(of: identifier, in: documents) {
        XCTFail("[\(rule)] \(occurrence.relativePath):\(occurrence.lineNumber): forbidden historical identifier: \(identifier)", file: file, line: line)
    }
}

private func assertIdentifierCount(
    rule: String,
    identifier: String,
    expected: Int,
    in documents: [SourceDocument],
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let occurrences = identifierOccurrences(of: identifier, in: documents)
    XCTAssertEqual(occurrences.count, expected, "[\(rule)] identifier inventory drift for \(identifier): \(formatted(occurrences))", file: file, line: line)
}

private func assertSourceContains(
    rule: String,
    token: String,
    in document: SourceDocument,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(
        document.contents.contains(token),
        "[\(rule)] \(document.relativePath):1: required source anchor missing: \(token)",
        file: file,
        line: line
    )
}

private func compactWhitespace(_ source: String) -> String {
    source.filter { !$0.isWhitespace }
}

private func occurrenceCount(of token: String, in source: String) -> Int {
    source.components(separatedBy: token).count - 1
}

private func balancedSlice(
    startingWith marker: String,
    opening: Character,
    closing: Character,
    in document: SourceDocument,
    rule: String
) throws -> String {
    guard let markerRange = document.contents.range(of: marker),
          let openingIndex = document.contents[markerRange.lowerBound...].firstIndex(of: opening) else {
        throw S0SurfaceSourceTestError.failure("[\(rule)] \(document.relativePath):1: declaration marker missing: \(marker)")
    }
    var depth = 0
    var index = openingIndex
    while index < document.contents.endIndex {
        let character = document.contents[index]
        if character == opening { depth += 1 }
        if character == closing {
            depth -= 1
            if depth == 0 {
                let end = document.contents.index(after: index)
                return String(document.contents[markerRange.lowerBound..<end])
            }
        }
        index = document.contents.index(after: index)
    }
    throw S0SurfaceSourceTestError.failure("[\(rule)] \(document.relativePath):1: unbalanced declaration: \(marker)")
}

private func contentsInsideBraces(_ source: String, path: String, rule: String) throws -> String {
    guard let opening = source.firstIndex(of: "{"), let closing = source.lastIndex(of: "}"), opening < closing else {
        throw S0SurfaceSourceTestError.failure("[\(rule)] \(path):1: expected braced declaration")
    }
    return String(source[source.index(after: opening)..<closing])
}

private func obsoleteKeysLineRange(in document: SourceDocument, rule: String) throws -> ClosedRange<Int> {
    let lines = document.contents.components(separatedBy: .newlines)
    guard let start = lines.firstIndex(where: { $0.contains("public static let obsoleteKeys") }),
          let end = lines.indices.dropFirst(start + 1).first(where: {
              lines[$0].trimmingCharacters(in: .whitespacesAndNewlines) == "]"
          }) else {
        throw S0SurfaceSourceTestError.failure("[\(rule)] \(document.relativePath):1: obsoleteKeys block missing")
    }
    return (start + 1)...(end + 1)
}

private func lineRange(
    startingWith startMarker: String,
    endingBefore endMarker: String,
    in document: SourceDocument,
    rule: String
) throws -> ClosedRange<Int> {
    let lines = document.contents.components(separatedBy: .newlines)
    guard let start = lines.firstIndex(where: { $0.contains(startMarker) }),
          let end = lines.indices.dropFirst(start + 1).first(where: { lines[$0].contains(endMarker) }) else {
        throw S0SurfaceSourceTestError.failure("[\(rule)] \(document.relativePath):1: bounded range missing: \(startMarker)")
    }
    return (start + 1)...end
}

private func braceBlockLineRange(
    startingWith marker: String,
    in document: SourceDocument,
    rule: String
) throws -> ClosedRange<Int> {
    let lines = document.contents.components(separatedBy: .newlines)
    guard let start = lines.firstIndex(where: { $0.contains(marker) }) else {
        throw S0SurfaceSourceTestError.failure("[\(rule)] \(document.relativePath):1: block marker missing: \(marker)")
    }
    var depth = 0
    var sawOpening = false
    for index in start..<lines.count {
        for character in lines[index] {
            if character == "{" { depth += 1; sawOpening = true }
            if character == "}" { depth -= 1 }
        }
        if sawOpening, depth == 0 { return (start + 1)...(index + 1) }
    }
    throw S0SurfaceSourceTestError.failure("[\(rule)] \(document.relativePath):1: unbalanced block: \(marker)")
}

private func nonPrivateStaticFunctionHeaders(in source: String) -> [String] {
    let lines = source.components(separatedBy: .newlines)
    var headers: [String] = []
    var index = 0
    while index < lines.count {
        let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("static func "), !trimmed.contains("private") else {
            index += 1
            continue
        }
        var header = trimmed
        while !header.contains("{") && index + 1 < lines.count {
            index += 1
            header += " " + lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        headers.append(header.components(separatedBy: "{").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? header)
        index += 1
    }
    return headers
}

private func functionName(in header: String) -> String {
    guard let start = header.range(of: "static func ")?.upperBound,
          let end = header[start...].firstIndex(of: "(") else { return header }
    return String(header[start..<end])
}

private func regexMatches(pattern: String, in source: String) -> [String] {
    guard let expression = try? NSRegularExpression(pattern: pattern) else {
        preconditionFailure("invalid source-test regex: \(pattern)")
    }
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    return expression.matches(in: source, range: range).compactMap { match in
        Range(match.range, in: source).map { String(source[$0]) }
    }
}
