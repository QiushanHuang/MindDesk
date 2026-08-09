import XCTest
@testable import MindDeskCore

final class ProposalReviewTests: XCTestCase {




    func testProposalEnvelopeValidationAcceptsValidEnvelope() throws {
        let envelope = try makeProposalEnvelope()

        XCTAssertEqual(MindDeskProposalEnvelopeValidation.issues(in: envelope), [])
        XCTAssertEqual(MindDeskProposalEnvelopeValidation.issues(in: envelope, currentContext: envelope.context), [])
    }








    func testProposalEnvelopeValidationRejectsEmptyProposalAndMissingOperationPayload() throws {
        var envelope = try makeProposalEnvelope()
        envelope.id = " "
        envelope.proposals = [
            MindDeskProposal(
                id: "proposal",
                title: " ",
                rationale: "",
                evidenceReferences: [],
                operations: [
                    MindDeskProposalOperation(
                        id: "operation",
                        kind: .openURL,
                        title: "Open",
                        target: nil,
                        affectedObjects: [],
                        payload: MindDeskProposalOperationPayload()
                    )
                ]
            )
        ]

        let issues = MindDeskProposalEnvelopeValidation.issues(in: envelope)

        XCTAssertTrue(issues.contains(.emptyEnvelopeID))
        XCTAssertTrue(issues.contains(.emptyProposalTitle(proposalID: "proposal")))
        XCTAssertTrue(issues.contains(.missingProposalEvidence(proposalID: "proposal")))
        XCTAssertTrue(issues.contains(.missingOperationPayload(operationID: "operation", kind: .openURL)))
    }

    func testProposalEnvelopeValidationReportsMissingRequiredIDsAndCollections() throws {
        var envelope = try makeProposalEnvelope()
        envelope.proposals = []

        XCTAssertTrue(MindDeskProposalEnvelopeValidation.issues(in: envelope).contains(.missingProposals))

        let reference = try makeReference()
        envelope.proposals = [
            MindDeskProposal(
                id: " ",
                title: "Missing IDs",
                rationale: "",
                evidenceReferences: [reference],
                operations: [
                    makeOperation(id: " ", kind: .openURL, payload: MindDeskProposalOperationPayload(url: "https://example.com"))
                ]
            ),
            MindDeskProposal(
                id: "empty-ops",
                title: "No operations",
                rationale: "",
                evidenceReferences: [reference],
                operations: []
            )
        ]

        let issues = MindDeskProposalEnvelopeValidation.issues(in: envelope)

        XCTAssertTrue(issues.contains(.emptyProposalID))
        XCTAssertTrue(issues.contains(.emptyOperationID))
        XCTAssertTrue(issues.contains(.missingProposalOperations(proposalID: "empty-ops")))
    }

    func testProposalEnvelopeValidationRequiresKindSpecificOperationPayloads() throws {
        let reference = try makeReference()
        var envelope = try makeProposalEnvelope()
        envelope.proposals[0].operations = [
            makeOperation(id: "bad-url", kind: .openURL, target: nil, payload: MindDeskProposalOperationPayload(url: "javascript:alert(1)")),
            makeOperation(id: "blank-command", kind: .runCommand, target: nil, payload: MindDeskProposalOperationPayload(command: " ")),
            makeOperation(id: "missing-directory", kind: .openTerminal, target: nil, payload: MindDeskProposalOperationPayload()),
            makeOperation(id: "blank-change", kind: .applyMindDeskChange, target: reference, payload: MindDeskProposalOperationPayload(proposedText: " "))
        ]

        let issues = MindDeskProposalEnvelopeValidation.issues(in: envelope)

        XCTAssertTrue(issues.contains(.missingOperationPayload(operationID: "bad-url", kind: .openURL)))
        XCTAssertTrue(issues.contains(.missingOperationPayload(operationID: "blank-command", kind: .runCommand)))
        XCTAssertTrue(issues.contains(.missingOperationPayload(operationID: "missing-directory", kind: .openTerminal)))
        XCTAssertTrue(issues.contains(.missingOperationPayload(operationID: "blank-change", kind: .applyMindDeskChange)))
    }

    func testProposalEnvelopeValidationRequiresTargetsForTargetBasedOperations() throws {
        var envelope = try makeProposalEnvelope()
        envelope.proposals[0].operations = [
            makeOperation(id: "open-object", kind: .openObject),
            makeOperation(id: "reveal-object", kind: .revealObject),
            makeOperation(id: "copy-path", kind: .copyPath),
            makeOperation(id: "alias", kind: .createFinderAlias)
        ]

        let issues = MindDeskProposalEnvelopeValidation.issues(in: envelope)

        XCTAssertTrue(issues.contains(.missingOperationTarget(operationID: "open-object", kind: .openObject)))
        XCTAssertTrue(issues.contains(.missingOperationTarget(operationID: "reveal-object", kind: .revealObject)))
        XCTAssertTrue(issues.contains(.missingOperationTarget(operationID: "copy-path", kind: .copyPath)))
        XCTAssertTrue(issues.contains(.missingOperationTarget(operationID: "alias", kind: .createFinderAlias)))

        let workspace = try XCTUnwrap(WorkbenchObjectReference(kind: .workspace, id: "workspace"))
        envelope.proposals[0].operations = [
            makeOperation(id: "alias", kind: .createFinderAlias, target: workspace)
        ]

        XCTAssertTrue(
            MindDeskProposalEnvelopeValidation.issues(in: envelope).contains(
                .unsupportedOperationTarget(operationID: "alias", kind: .createFinderAlias, targetKind: .workspace)
            )
        )
    }

    func testProposalEnvelopeValidationAllowsCopyPathTargetsOnlyForResourcePins() {
        XCTAssertTrue(MindDeskProposalOperationKind.copyPath.supportsTargetKind(.resourcePin))
        XCTAssertFalse(MindDeskProposalOperationKind.copyPath.supportsTargetKind(.snippet))
        XCTAssertFalse(MindDeskProposalOperationKind.copyPath.supportsTargetKind(.workspace))
        XCTAssertFalse(MindDeskProposalOperationKind.copyPath.supportsTargetKind(.webURL))
    }

    func testProposalEnvelopeValidationRejectsCopyPathTargetsThatAreNotResourcePins() throws {
        let snippet = try makeReference(kind: .snippet, id: "snippet")
        var envelope = try makeProposalEnvelope()
        envelope.proposals[0].operations = [
            makeOperation(id: "copy-snippet", kind: .copyPath, target: snippet)
        ]

        XCTAssertTrue(
            MindDeskProposalEnvelopeValidation.issues(in: envelope).contains(
                .unsupportedOperationTarget(operationID: "copy-snippet", kind: .copyPath, targetKind: .snippet)
            )
        )
    }



    func testProposalEnvelopeValidationRejectsMetaActionsAndApprovedAgentCreators() throws {
        var envelope = try makeProposalEnvelope(proposedBy: .approvedAgent)
        envelope.proposals[0].operations[0].kind = .readAgentContext

        let issues = MindDeskProposalEnvelopeValidation.issues(in: envelope)

        XCTAssertTrue(issues.contains(.invalidProposer(.approvedAgent)))
        XCTAssertTrue(issues.contains(.metaActionCannotBeProposed(operationID: "operation", action: .readAgentContext)))

        let directUserEnvelope = try makeProposalEnvelope(proposedBy: .directUser)
        XCTAssertTrue(MindDeskProposalEnvelopeValidation.issues(in: directUserEnvelope).contains(.invalidProposer(.directUser)))

        envelope = try makeProposalEnvelope()
        envelope.proposals[0].operations[0].kind = .proposeAgentAction
        XCTAssertTrue(
            MindDeskProposalEnvelopeValidation.issues(in: envelope).contains(
                .metaActionCannotBeProposed(operationID: "operation", action: .proposeAgentAction)
            )
        )
    }

    func testProposalEnvelopeValidationRejectsDuplicateExternalIDs() throws {
        var envelope = try makeProposalEnvelope()
        envelope.proposals.append(envelope.proposals[0])
        envelope.proposals[0].operations.append(envelope.proposals[0].operations[0])

        let issues = MindDeskProposalEnvelopeValidation.issues(in: envelope)

        XCTAssertTrue(issues.contains(.duplicateProposalID("proposal")))
        XCTAssertTrue(issues.contains(.duplicateOperationID(proposalID: "proposal", operationID: "operation")))
    }

    func testProposalEnvelopeValidationNormalizesIDsBeforeDuplicateChecks() throws {
        var envelope = try makeProposalEnvelope()
        let reference = try makeReference()
        envelope.proposals = [
            MindDeskProposal(
                id: " proposal ",
                title: "First",
                rationale: "",
                evidenceReferences: [reference],
                operations: [
                    makeOperation(id: " operation ", kind: .openURL, payload: MindDeskProposalOperationPayload(url: "https://example.com")),
                    makeOperation(id: "operation", kind: .openURL, payload: MindDeskProposalOperationPayload(url: "https://example.com"))
                ]
            ),
            MindDeskProposal(
                id: "proposal",
                title: "Second",
                rationale: "",
                evidenceReferences: [reference],
                operations: [
                    makeOperation(id: "other", kind: .openURL, payload: MindDeskProposalOperationPayload(url: "https://example.com"))
                ]
            )
        ]

        let issues = MindDeskProposalEnvelopeValidation.issues(in: envelope)

        XCTAssertTrue(issues.contains(.duplicateProposalID("proposal")))
        XCTAssertTrue(issues.contains(.duplicateOperationID(proposalID: " proposal ", operationID: "operation")))
    }

    func testProposalEnvelopeValidationRejectsOversizedCollections() throws {
        let reference = try makeReference()
        var envelope = try makeProposalEnvelope()
        envelope.proposals = (0...MindDeskProposalEnvelopeValidation.maximumProposalCount).map { index in
            MindDeskProposal(
                id: "proposal-\(index)",
                title: "Proposal \(index)",
                rationale: "",
                evidenceReferences: [reference],
                operations: [
                    makeOperation(
                        id: "operation-\(index)",
                        kind: .openURL,
                        payload: MindDeskProposalOperationPayload(url: "https://example.com/\(index)")
                    )
                ]
            )
        }
        envelope.proposals[0].evidenceReferences = Array(
            repeating: reference,
            count: MindDeskProposalEnvelopeValidation.maximumProposalEvidenceReferenceCount + 1
        )
        envelope.proposals[0].operations = (0...MindDeskProposalEnvelopeValidation.maximumProposalOperationCount).map { index in
            makeOperation(
                id: "oversized-operation-\(index)",
                kind: .openURL,
                payload: MindDeskProposalOperationPayload(url: "https://example.com/oversized/\(index)")
            )
        }
        envelope.proposals[0].operations[0].affectedObjects = Array(
            repeating: reference,
            count: MindDeskProposalEnvelopeValidation.maximumOperationAffectedObjectCount + 1
        )

        let diagnostics = MindDeskProposalEnvelopeValidation.diagnostics(in: envelope)

        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.issue == .tooManyProposals(
                count: MindDeskProposalEnvelopeValidation.maximumProposalCount + 1,
                maximum: MindDeskProposalEnvelopeValidation.maximumProposalCount
            ) &&
            diagnostic.path == "/proposals" &&
            diagnostic.details["count"] == String(MindDeskProposalEnvelopeValidation.maximumProposalCount + 1) &&
            diagnostic.details["maximum"] == String(MindDeskProposalEnvelopeValidation.maximumProposalCount)
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.issue == .tooManyProposalEvidenceReferences(
                proposalID: "proposal-0",
                count: MindDeskProposalEnvelopeValidation.maximumProposalEvidenceReferenceCount + 1,
                maximum: MindDeskProposalEnvelopeValidation.maximumProposalEvidenceReferenceCount
            ) &&
            diagnostic.path == "/proposals/0/evidenceReferences" &&
            diagnostic.details["proposalIndex"] == "0"
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.issue == .tooManyProposalOperations(
                proposalID: "proposal-0",
                count: MindDeskProposalEnvelopeValidation.maximumProposalOperationCount + 1,
                maximum: MindDeskProposalEnvelopeValidation.maximumProposalOperationCount
            ) &&
            diagnostic.path == "/proposals/0/operations" &&
            diagnostic.details["proposalIndex"] == "0"
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.issue == .tooManyOperationAffectedObjects(
                operationID: "oversized-operation-0",
                count: MindDeskProposalEnvelopeValidation.maximumOperationAffectedObjectCount + 1,
                maximum: MindDeskProposalEnvelopeValidation.maximumOperationAffectedObjectCount
            ) &&
            diagnostic.path == "/proposals/0/operations/0/affectedObjects" &&
            diagnostic.details["operationIndex"] == "0"
        })
    }

    func testProposalEnvelopeValidationRejectsOversizedTextWithoutReportingRawPayload() throws {
        let secret = "IGNORE_AGENT_INSTRUCTIONS token=proposal-limit-secret"
        var envelope = try makeProposalEnvelope()
        envelope.proposals[0].title = String(
            repeating: "T",
            count: MindDeskProposalEnvelopeValidation.maximumProposalTitleLength + 1
        )
        envelope.proposals[0].rationale = String(
            repeating: "R",
            count: MindDeskProposalEnvelopeValidation.maximumProposalRationaleLength + 1
        )
        envelope.proposals[0].operations[0].kind = .runCommand
        envelope.proposals[0].operations[0].title = String(
            repeating: "O",
            count: MindDeskProposalEnvelopeValidation.maximumOperationTitleLength + 1
        )
        envelope.proposals[0].operations[0].payload = MindDeskProposalOperationPayload(
            command: String(
                repeating: "x",
                count: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength + 1
            ) + secret
        )

        let diagnostics = MindDeskProposalEnvelopeValidation.diagnostics(in: envelope)

        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.issue == .proposalTitleTooLong(
                proposalID: "proposal",
                actualLength: MindDeskProposalEnvelopeValidation.maximumProposalTitleLength + 1,
                maximum: MindDeskProposalEnvelopeValidation.maximumProposalTitleLength
            ) &&
            diagnostic.path == "/proposals/0/title"
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.issue == .proposalRationaleTooLong(
                proposalID: "proposal",
                actualLength: MindDeskProposalEnvelopeValidation.maximumProposalRationaleLength + 1,
                maximum: MindDeskProposalEnvelopeValidation.maximumProposalRationaleLength
            ) &&
            diagnostic.path == "/proposals/0/rationale"
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.issue == .operationTitleTooLong(
                operationID: "operation",
                actualLength: MindDeskProposalEnvelopeValidation.maximumOperationTitleLength + 1,
                maximum: MindDeskProposalEnvelopeValidation.maximumOperationTitleLength
            ) &&
            diagnostic.path == "/proposals/0/operations/0/title"
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.issue == .operationPayloadTooLong(
                operationID: "operation",
                field: "command",
                actualLength: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength + 1 + secret.count,
                maximum: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength
            ) &&
            diagnostic.path == "/proposals/0/operations/0/payload/command" &&
            diagnostic.details["payloadField"] == "command"
        })

        XCTAssertEqual(
            diagnostics.map(\.path),
            [
                "/proposals/0/title",
                "/proposals/0/rationale",
                "/proposals/0/operations/0/title",
                "/proposals/0/operations/0/payload/command"
            ]
        )
        XCTAssertFalse(String(describing: diagnostics).contains(secret))
    }

    func testProposalEnvelopeValidationRejectsUnexpectedOperationPayloadFieldsWithoutReportingRawPayload() throws {
        let secret = "IGNORE_AGENT_INSTRUCTIONS token=unexpected-payload-secret"
        var envelope = try makeProposalEnvelope()
        envelope.proposals[0].operations = [
            makeOperation(
                id: "open-url",
                kind: .openURL,
                payload: MindDeskProposalOperationPayload(
                    url: "https://example.com",
                    command: "rm -rf ~/Documents \(secret)",
                    proposedText: "Change note \(secret)"
                )
            ),
            makeOperation(
                id: "open-object",
                kind: .openObject,
                target: try makeReference(),
                payload: MindDeskProposalOperationPayload(url: "https://example.com/\(secret)")
            )
        ]

        let diagnostics = MindDeskProposalEnvelopeValidation.diagnostics(in: envelope)

        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.issue == .unexpectedOperationPayload(
                operationID: "open-url",
                kind: .openURL,
                field: "command"
            ) &&
            diagnostic.path == "/proposals/0/operations/0/payload/command" &&
            diagnostic.details["payloadField"] == "command"
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.issue == .unexpectedOperationPayload(
                operationID: "open-url",
                kind: .openURL,
                field: "proposedText"
            ) &&
            diagnostic.path == "/proposals/0/operations/0/payload/proposedText" &&
            diagnostic.details["payloadField"] == "proposedText"
        })
        XCTAssertTrue(diagnostics.contains { diagnostic in
            diagnostic.issue == .unexpectedOperationPayload(
                operationID: "open-object",
                kind: .openObject,
                field: "url"
            ) &&
            diagnostic.path == "/proposals/0/operations/1/payload/url" &&
            diagnostic.details["payloadField"] == "url"
        })

        XCTAssertEqual(
            diagnostics.map(\.path),
            [
                "/proposals/0/operations/0/payload/command",
                "/proposals/0/operations/0/payload/proposedText",
                "/proposals/0/operations/1/payload/url"
            ]
        )
        XCTAssertFalse(String(describing: diagnostics).contains(secret))
    }

    func testProposalEnvelopeValidationRejectsUnknownRawPayloadKeysWithoutReportingRawPayload() throws {
        let secret = "IGNORE_AGENT_INSTRUCTIONS token=unknown-payload-secret"
        var object = try makeEncodedEnvelopeObject()
        var proposals = try XCTUnwrap(object["proposals"] as? [[String: Any]])
        var proposal = proposals[0]
        var operations = try XCTUnwrap(proposal["operations"] as? [[String: Any]])
        var operation = operations[0]
        var payload = try XCTUnwrap(operation["payload"] as? [String: Any])
        let unknownKey = "rawCommand\(secret)"
        payload[unknownKey] = "rm -rf ~/Documents \(secret)"
        operation["payload"] = payload
        operations[0] = operation
        proposal["operations"] = operations
        proposals[0] = proposal
        object["proposals"] = proposals

        let envelope = try decodeEnvelope(from: object)
        let diagnostics = MindDeskProposalEnvelopeValidation.diagnostics(in: envelope)

        let diagnostic = try XCTUnwrap(diagnostics.first(where: { diagnostic in
            guard case .unknownOperationPayloadField(
                operationID: "operation",
                kind: .openURL,
                fieldToken: let fieldToken,
                fieldLength: let fieldLength
            ) = diagnostic.issue else {
                return false
            }
            return fieldLength == unknownKey.count &&
                fieldToken.hasPrefix("sha256:") &&
                diagnostic.path == "/proposals/0/operations/0/payload" &&
                diagnostic.details["payloadFieldToken"] == fieldToken &&
                diagnostic.details["payloadFieldLength"] == String(unknownKey.count)
        }))
        XCTAssertFalse(String(describing: diagnostic).contains(secret))

        XCTAssertEqual(diagnostics.map(\.path), ["/proposals/0/operations/0/payload"])
        XCTAssertFalse(String(describing: diagnostics).contains(secret))
    }

    func testProposalEnvelopeValidationAllowsOnlyKindSpecificPayloadFields() throws {
        let reference = try makeReference()
        var envelope = try makeProposalEnvelope()
        envelope.proposals[0].operations = [
            makeOperation(
                id: "open-url",
                kind: .openURL,
                payload: MindDeskProposalOperationPayload(url: "https://example.com")
            ),
            makeOperation(
                id: "run-command",
                kind: .runCommand,
                payload: MindDeskProposalOperationPayload(command: "echo hello", workingDirectory: reference)
            ),
            makeOperation(
                id: "open-terminal",
                kind: .openTerminal,
                payload: MindDeskProposalOperationPayload(workingDirectory: reference)
            ),
            makeOperation(
                id: "apply-change",
                kind: .applyMindDeskChange,
                target: reference,
                payload: MindDeskProposalOperationPayload(proposedText: "Updated note")
            )
        ]

        let issues = MindDeskProposalEnvelopeValidation.issues(in: envelope)

        XCTAssertFalse(issues.contains { issue in
            if case .unexpectedOperationPayload = issue {
                return true
            }
            return false
        })
    }

    func testProposalEnvelopeValidationReportsCurrentContextMismatches() throws {
        let current = try makeContextSnapshot()
        var envelope = try makeProposalEnvelope()
        var staleContext = current
        staleContext.manifestDigest = try XCTUnwrap(
            MindDeskProposalContextDigest(algorithm: "sha256", value: String(repeating: "1", count: 64))
        )
        envelope.context = staleContext

        let issues = MindDeskProposalEnvelopeValidation.issues(in: envelope, currentContext: current)

        XCTAssertTrue(issues.contains(.staleProposalContext))

        envelope.context = current
        envelope.context.packageFormat = "foreign.package"
        let unsupportedIssues = MindDeskProposalEnvelopeValidation.issues(in: envelope, currentContext: current)

        XCTAssertTrue(unsupportedIssues.contains(.unsupportedContextPackageFormat("foreign.package")))
        XCTAssertTrue(unsupportedIssues.contains(.staleProposalContext))

        envelope.context = current
        envelope.context.packageFormatVersion += 1
        let versionIssues = MindDeskProposalEnvelopeValidation.issues(in: envelope, currentContext: current)

        XCTAssertTrue(versionIssues.contains(.unsupportedContextPackageFormatVersion(MindDeskInterchangePackage.currentFormatVersion + 1)))
        XCTAssertTrue(versionIssues.contains(.staleProposalContext))

        envelope.context = current
        envelope.context.packageInstanceID = "different-package-instance"
        let instanceIssues = MindDeskProposalEnvelopeValidation.issues(in: envelope, currentContext: current)

        XCTAssertTrue(instanceIssues.contains(.staleProposalContext))
    }

    func testProposalEnvelopeValidationRejectsCreatedBeforeCurrentPackage() throws {
        let current = try makeContextSnapshot()
        var envelope = try makeProposalEnvelope()
        envelope.createdAt = Date(timeIntervalSince1970: -301)

        let issues = MindDeskProposalEnvelopeValidation.issues(in: envelope, currentContext: current)

        XCTAssertTrue(
            issues.contains(
                .proposalCreatedBeforePackage(
                    proposalCreatedAt: Date(timeIntervalSince1970: -301),
                    packageCreatedAt: Date(timeIntervalSince1970: 100)
                )
            )
        )
    }

    func testProposalContextDigestValidationAndFreshness() throws {
        XCTAssertNil(MindDeskProposalContextDigest(algorithm: "md5", value: validDigestValue))
        XCTAssertNil(MindDeskProposalContextDigest(algorithm: "sha256", value: "abc"))
        XCTAssertNil(MindDeskProposalContextDigest(algorithm: "sha256", value: String(repeating: "g", count: 64)))
        XCTAssertNil(MindDeskProposalContextDigest(algorithm: "sha256", value: String(repeating: "１", count: 64)))

        let digest = try XCTUnwrap(MindDeskProposalContextDigest(algorithm: "sha256", value: validDigestValue.uppercased()))
        XCTAssertEqual(digest.algorithm, "sha256")
        XCTAssertEqual(digest.value, validDigestValue)

        let current = try makeContextSnapshot(digest: digest)
        var stale = current
        stale.manifestDigest = try XCTUnwrap(MindDeskProposalContextDigest(algorithm: "sha256", value: String(repeating: "1", count: 64)))

        XCTAssertFalse(MindDeskProposalContextFreshness.isStale(proposal: current, current: current))
        XCTAssertTrue(MindDeskProposalContextFreshness.isStale(proposal: stale, current: current))
    }

    func testProposalContextFreshnessDetectsPackageAndSchemaMismatches() throws {
        let current = try makeContextSnapshot()

        var formatMismatch = current
        formatMismatch.packageFormat = "foreign.package"
        XCTAssertTrue(MindDeskProposalContextFreshness.isStale(proposal: formatMismatch, current: current))

        var packageVersionMismatch = current
        packageVersionMismatch.packageFormatVersion += 1
        XCTAssertTrue(MindDeskProposalContextFreshness.isStale(proposal: packageVersionMismatch, current: current))

        var schemaVersionMismatch = current
        schemaVersionMismatch.manifestSchemaVersion += 1
        XCTAssertTrue(MindDeskProposalContextFreshness.isStale(proposal: schemaVersionMismatch, current: current))

        var packageCreatedAtMismatch = current
        packageCreatedAtMismatch.packageCreatedAt = Date(timeIntervalSince1970: 999)
        XCTAssertTrue(MindDeskProposalContextFreshness.isStale(proposal: packageCreatedAtMismatch, current: current))

        var exportedAtMismatch = current
        exportedAtMismatch.manifestExportedAt = Date(timeIntervalSince1970: 999)
        XCTAssertTrue(MindDeskProposalContextFreshness.isStale(proposal: exportedAtMismatch, current: current))
        XCTAssertEqual(
            MindDeskProposalContextFreshness.mismatchedBindingFields(
                proposal: exportedAtMismatch,
                current: current
            ),
            ["manifestExportedAt"]
        )
    }











    private var validDigestValue: String {
        String(repeating: "a", count: 64)
    }

    private func makeProposalEnvelope(
        proposedBy: WorkbenchExternalActor = .defaultAgent,
        context: MindDeskProposalContextSnapshot? = nil
    ) throws -> MindDeskProposalEnvelope {
        let reference = try makeReference()
        return MindDeskProposalEnvelope(
            id: "envelope",
            createdAt: Date(timeIntervalSince1970: 123),
            proposedBy: proposedBy,
            context: try context ?? makeContextSnapshot(),
            proposals: [
                MindDeskProposal(
                    id: "proposal",
                    title: "Review URL",
                    rationale: "Agent found a linked reference that may be useful.",
                    evidenceReferences: [reference],
                    operations: [
                        MindDeskProposalOperation(
                            id: "operation",
                            kind: .openURL,
                            title: "Open supporting URL",
                            target: nil,
                            affectedObjects: [reference],
                            payload: MindDeskProposalOperationPayload(url: "https://example.com")
                        )
                    ]
                )
            ]
        )
    }

    private func makeEncodedEnvelopeObject() throws -> [String: Any] {
        let data = try JSONEncoder.minddesk.encode(makeProposalEnvelope())
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decodeEnvelope(from object: [String: Any]) throws -> MindDeskProposalEnvelope {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder.minddesk.decode(MindDeskProposalEnvelope.self, from: data)
    }

    private func makeContextSnapshot(
        digest: MindDeskProposalContextDigest? = nil
    ) throws -> MindDeskProposalContextSnapshot {
        let resolvedDigest = try digest ?? XCTUnwrap(MindDeskProposalContextDigest(algorithm: "sha256", value: validDigestValue))
        return MindDeskProposalContextSnapshot(
            packageFormat: "minddesk.interchange.package",
            packageFormatVersion: 1,
            packageInstanceID: "package-instance",
            packageCreatedAt: Date(timeIntervalSince1970: 100),
            manifestSchemaVersion: 2,
            manifestExportedAt: Date(timeIntervalSince1970: 0),
            manifestDigest: resolvedDigest
        )
    }

    private func makeReference(
        kind: WorkbenchObjectKind = .resourcePin,
        id: String = "resource"
    ) throws -> WorkbenchObjectReference {
        try XCTUnwrap(WorkbenchObjectReference(kind: kind, id: id))
    }

    private func makeOperation(
        id: String,
        kind: MindDeskProposalOperationKind,
        target: WorkbenchObjectReference? = nil,
        payload: MindDeskProposalOperationPayload = MindDeskProposalOperationPayload()
    ) -> MindDeskProposalOperation {
        MindDeskProposalOperation(
            id: id,
            kind: kind,
            title: id,
            target: target,
            affectedObjects: target.map { [$0] } ?? [],
            payload: payload
        )
    }
}
