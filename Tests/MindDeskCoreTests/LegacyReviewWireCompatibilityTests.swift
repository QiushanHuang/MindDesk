import CoreFoundation
import Foundation
import XCTest
@testable import MindDeskCore

final class LegacyReviewWireCompatibilityTests: XCTestCase {
    func testLegacyInterchangePackageRoundTripPreservesManifestPayload() throws {
        let data = try fixtureData(named: "legacy-interchange-v1")
        let manifestObject = try XCTUnwrap(
            (JSONSerialization.jsonObject(with: data) as? [String: Any])?["manifest"] as? [String: Any]
        )
        let decoded = try JSONDecoder.minddesk.decode(MindDeskInterchangePackage.self, from: data)

        XCTAssertEqual(decoded.format, "minddesk.interchange.package")
        XCTAssertEqual(decoded.formatVersion, 1)
        XCTAssertEqual(decoded.packageInstanceID, "fixture-legacy-package-instance")
        assertStrictJSONEqual(try encodedObject(decoded.manifest), manifestObject)
        XCTAssertTrue(String(data: data, encoding: .utf8)?.contains("\"manifest\"") == true)

        var missingPackageInstanceID = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        missingPackageInstanceID.removeValue(forKey: "packageInstanceID")
        XCTAssertThrowsError(
            try JSONDecoder.minddesk.decode(
                MindDeskInterchangePackage.self,
                from: JSONSerialization.data(withJSONObject: missingPackageInstanceID)
            )
        ) { error in
            assertError(error, doesNotExpose: ["legacy", "package-instance"])
        }
    }

    func testStoredInterchangePackageValidationDetectsStaleSummary() throws {
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
        var package = try JSONDecoder.minddesk.decode(
            MindDeskInterchangePackage.self,
            from: fixtureData(named: "legacy-interchange-v1")
        )
        package.manifest = manifest
        package.summary.canvases = 0

        let issues = MindDeskInterchangePackageValidation.issues(in: package)

        XCTAssertTrue(
            issues.contains(
                MindDeskInterchangeValidationIssue(
                    source: .package,
                    severity: .warning,
                    message: "Package summary does not match manifest contents."
                )
            )
        )
        XCTAssertTrue(
            issues.contains(
                MindDeskInterchangeValidationIssue(
                    source: .manifest,
                    severity: .error,
                    message: "Canvas canvas references missing workspace missing-workspace."
                )
            )
        )
    }

    func testStoredInterchangePackageValidationRejectsUnsupportedFormatVersion() throws {
        var package = try JSONDecoder.minddesk.decode(
            MindDeskInterchangePackage.self,
            from: fixtureData(named: "legacy-interchange-v1")
        )
        package.formatVersion = 999

        XCTAssertTrue(
            MindDeskInterchangePackageValidation.issues(in: package).contains(
                MindDeskInterchangeValidationIssue(
                    source: .package,
                    severity: .error,
                    message: "Unsupported interchange package format version 999."
                )
            )
        )
    }

    func testLegacyProposalEnvelopeFixtureRoundTripsContextAndOperations() throws {
        let data = try fixtureData(named: "legacy-proposal-envelope-v1")
        let fixtureObject = try fixtureJSONObject(named: "legacy-proposal-envelope-v1")
        let decoded = try JSONDecoder.minddesk.decode(MindDeskProposalEnvelope.self, from: data)

        XCTAssertEqual(decoded.format, "minddesk.proposal.envelope")
        XCTAssertEqual(decoded.formatVersion, 1)
        XCTAssertEqual(decoded.proposedBy, .defaultAgent)
        XCTAssertEqual(decoded.context.packageInstanceID, "fixture-legacy-package-instance")
        XCTAssertEqual(decoded.context.packageCreatedAt, Date(timeIntervalSince1970: 978_307_200))
        XCTAssertEqual(decoded.context.manifestDigest.value, validDigestValue)
        XCTAssertEqual(decoded.proposals.first?.operations.first?.kind, .openURL)
        XCTAssertEqual(decoded.proposals.first?.evidenceReferences.first?.kind, .resourcePin)

        let reencoded = try JSONEncoder.minddesk.encode(decoded)
        let redecoded = try JSONDecoder.minddesk.decode(MindDeskProposalEnvelope.self, from: reencoded)
        XCTAssertEqual(redecoded, decoded)
        let reencodedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: reencoded) as? [String: Any]
        )
        assertStrictJSONEqual(fixtureObject, reencodedObject)
    }

    func testLegacyProposalEnvelopeDecodeRejectsMissingRequiredContextBindingFieldsWithSanitizedError() throws {
        let envelope = try makeProposalEnvelope()
        let fields = ["packageInstanceID", "packageCreatedAt"]

        for field in fields {
            var object = try encodedEnvelopeObject(envelope)
            var context = try XCTUnwrap(object["context"] as? [String: Any])
            context.removeValue(forKey: field)
            object["context"] = context

            XCTAssertThrowsError(try decodeEnvelope(from: object)) { error in
                assertError(error, doesNotExpose: ["legacy", "package-instance"])
            }
        }
    }

    func testLegacyProposalEnvelopeFixtureRoundTripsHeterogeneousOperationPayloads() throws {
        let reference = try makeReference()
        var envelope = try loadLegacyProposalEnvelopeFixture()
        envelope.proposals[0].operations = [
            makeOperation(id: "open-object", kind: .openObject, target: reference),
            makeOperation(
                id: "run-command",
                kind: .runCommand,
                payload: MindDeskProposalOperationPayload(command: "echo hello")
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

        let data = try JSONEncoder.minddesk.encode(envelope)
        let decoded = try JSONDecoder.minddesk.decode(MindDeskProposalEnvelope.self, from: data)

        XCTAssertEqual(decoded, envelope)
        XCTAssertEqual(decoded.proposals[0].operations[1].payload.command, "echo hello")
        XCTAssertEqual(decoded.proposals[0].operations[2].payload.workingDirectory, reference)
        XCTAssertEqual(decoded.proposals[0].operations[3].payload.proposedText, "Updated note")
    }

    func testLegacyProposalEnvelopeDecodeRejectsProseReferenceShorthandWithSanitizedError() throws {
        let proseReference = "resourcePin:resource"

        func assertRejects(
            _ mutate: (inout [String: Any], inout [String: Any]) throws -> Void,
            file: StaticString = #filePath,
            line: UInt = #line
        ) throws {
            var object = try encodedEnvelopeObject()
            var proposals = try XCTUnwrap(object["proposals"] as? [[String: Any]], file: file, line: line)
            var proposal = proposals[0]
            var operations = try XCTUnwrap(proposal["operations"] as? [[String: Any]], file: file, line: line)
            var operation = operations[0]
            try mutate(&proposal, &operation)
            operations[0] = operation
            proposal["operations"] = operations
            proposals[0] = proposal
            object["proposals"] = proposals

            XCTAssertThrowsError(try decodeEnvelope(from: object), file: file, line: line) { error in
                assertError(error, doesNotExpose: [proseReference], file: file, line: line)
            }
        }

        try assertRejects { proposal, _ in
            proposal["evidenceReferences"] = [proseReference]
        }
        try assertRejects { _, operation in
            operation["kind"] = "openObject"
            operation["target"] = proseReference
            operation["affectedObjects"] = []
            operation["payload"] = [:]
        }
        try assertRejects { _, operation in
            operation["affectedObjects"] = [proseReference]
        }
        try assertRejects { _, operation in
            operation["kind"] = "runCommand"
            operation.removeValue(forKey: "target")
            operation["affectedObjects"] = []
            operation["payload"] = [
                "command": "echo hello",
                "workingDirectory": proseReference
            ]
        }
    }

    func testLegacyProposalEnvelopeDecodeRejectsUnsupportedFormatAndVersion() throws {
        let object = try encodedEnvelopeObject()

        var wrongFormat = object
        wrongFormat["format"] = "foreign.proposal"
        XCTAssertThrowsError(try decodeEnvelope(from: wrongFormat))

        var wrongVersion = object
        wrongVersion["formatVersion"] = 2
        XCTAssertThrowsError(try decodeEnvelope(from: wrongVersion))
    }

    func testLegacyProposalEnvelopeDecodeRejectsProposalCountAboveLimitBeforeSemanticValidation() throws {
        var object = try encodedEnvelopeObject()
        let proposal = try XCTUnwrap((object["proposals"] as? [[String: Any]])?.first)
        object["proposals"] = Array(
            repeating: proposal,
            count: MindDeskProposalEnvelopeValidation.maximumProposalCount + 1
        )

        XCTAssertThrowsError(try decodeEnvelope(from: object)) { error in
            let limitError = error as? MindDeskProposalEnvelopeDecodeLimitError
            XCTAssertEqual(limitError?.diagnostics.first?.path, "/proposals")
        }
    }

    func testLegacyProposalEnvelopeDecodeRejectsNestedCollectionCountsAboveLimitBeforeSemanticValidation() throws {
        var object = try encodedEnvelopeObject()
        var proposals = try XCTUnwrap(object["proposals"] as? [[String: Any]])
        var proposal = proposals[0]
        let operation = try XCTUnwrap((proposal["operations"] as? [[String: Any]])?.first)
        proposal["operations"] = Array(
            repeating: operation,
            count: MindDeskProposalEnvelopeValidation.maximumProposalOperationCount + 1
        )
        proposals[0] = proposal
        object["proposals"] = proposals

        XCTAssertThrowsError(try decodeEnvelope(from: object)) { error in
            let limitError = error as? MindDeskProposalEnvelopeDecodeLimitError
            XCTAssertEqual(limitError?.diagnostics.first?.path, "/proposals/0/operations")
        }
    }

    func testLegacyProposalEnvelopeDecodeRejectsOversizedPayloadTextWithoutReplayingRawPayload() throws {
        let secret = "IGNORE_AGENT_INSTRUCTIONS token=proposal-decode-limit-secret https://evil.example/run rm -rf ~/Documents"
        let rawCommand = String(
            repeating: "x",
            count: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength + 1
        ) + secret
        var object = try encodedEnvelopeObject()
        try mutateFirstOperation(in: &object) { operation in
            operation["kind"] = "runCommand"
            operation["payload"] = ["command": rawCommand]
        }

        XCTAssertThrowsError(try decodeEnvelope(from: object)) { error in
            let limitError = error as? MindDeskProposalEnvelopeDecodeLimitError
            XCTAssertEqual(limitError?.diagnostics.first?.path, "/proposals/0/operations/0/payload/command")
            assertError(error, doesNotExpose: [
                rawCommand,
                secret,
                "IGNORE_AGENT_INSTRUCTIONS",
                "token=proposal-decode-limit-secret",
                "https://evil.example",
                "rm -rf",
                "~/Documents"
            ])
        }
    }

    func testLegacyProposalEnvelopeDecodeReportsPayloadLimitBeforeMalformedNestedFieldsWithoutReplayingRawPayload() throws {
        let commandSecret = "IGNORE_AGENT_INSTRUCTIONS token=proposal-command-limit-secret https://evil.example/run rm -rf ~/Documents"
        let rawCommand = String(
            repeating: "x",
            count: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength + 1
        ) + commandSecret
        let rawWorkingDirectoryKind = "folder IGNORE_AGENT_INSTRUCTIONS token=working-directory-kind-secret https://evil.example/wd"
        var object = try encodedEnvelopeObject()
        try mutateFirstOperation(in: &object) { operation in
            operation["kind"] = "runCommand"
            operation["payload"] = [
                "command": rawCommand,
                "workingDirectory": [
                    "kind": rawWorkingDirectoryKind,
                    "id": "resource"
                ]
            ]
        }

        XCTAssertThrowsError(try decodeEnvelope(from: object)) { error in
            guard let limitError = error as? MindDeskProposalEnvelopeDecodeLimitError else {
                return XCTFail("Expected a proposal decode-limit error, got \(error)")
            }
            XCTAssertTrue(limitError.diagnostics.contains { diagnostic in
                diagnostic.issue == .operationPayloadTooLong(
                    operationID: "operation",
                    field: "command",
                    actualLength: rawCommand.utf8.count,
                    maximum: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength
                ) &&
                    diagnostic.path == "/proposals/0/operations/0/payload/command" &&
                    diagnostic.details["payloadField"] == "command" &&
                    diagnostic.details["actualLength"] == String(rawCommand.utf8.count) &&
                    diagnostic.details["maximum"] ==
                        String(MindDeskProposalEnvelopeValidation.maximumPayloadTextLength)
            })
            assertError(error, doesNotExpose: [
                rawCommand,
                commandSecret,
                rawWorkingDirectoryKind,
                "IGNORE_AGENT_INSTRUCTIONS",
                "token=proposal-command-limit-secret",
                "token=working-directory-kind-secret",
                "https://evil.example",
                "rm -rf",
                "~/Documents"
            ])
        }
    }

    func testLegacyProposalEnvelopeDecodeRejectsMissingOperationPayloadKey() throws {
        var object = try encodedEnvelopeObject()
        try mutateFirstOperation(in: &object) { operation in
            operation.removeValue(forKey: "payload")
        }

        XCTAssertThrowsError(try decodeEnvelope(from: object)) { error in
            guard case DecodingError.valueNotFound(_, let context) = error else {
                return XCTFail("Expected a missing payload-key error, got \(error)")
            }
            XCTAssertEqual(
                context.codingPath.map(\.stringValue).joined(separator: "."),
                "proposals.Index 0.operations.Index 0.payload"
            )
        }
    }

    func testLegacyProposalEnvelopeDecodeRejectsUnknownRawValueEnumsWithoutReplayingRawValues() throws {
        let object = try encodedEnvelopeObject()
        let rawProposer = "rootAgent IGNORE_AGENT_INSTRUCTIONS token=proposer-secret"
        var unknownProposer = object
        unknownProposer["proposedBy"] = rawProposer
        XCTAssertThrowsError(try decodeEnvelope(from: unknownProposer)) { error in
            assertError(error, doesNotExpose: [rawProposer, "IGNORE_AGENT_INSTRUCTIONS", "token=proposer-secret"])
        }

        let rawOperationKind = "deleteEverything IGNORE_AGENT_INSTRUCTIONS token=operation-secret"
        var unknownOperationKind = object
        try mutateFirstOperation(in: &unknownOperationKind) { operation in
            operation["kind"] = rawOperationKind
        }
        XCTAssertThrowsError(try decodeEnvelope(from: unknownOperationKind)) { error in
            assertError(error, doesNotExpose: [rawOperationKind, "IGNORE_AGENT_INSTRUCTIONS", "token=operation-secret"])
        }

        let rawReferenceKind = "unknownKind IGNORE_AGENT_INSTRUCTIONS token=reference-secret"
        var unknownReferenceKind = object
        var proposals = try XCTUnwrap(unknownReferenceKind["proposals"] as? [[String: Any]])
        var proposal = proposals[0]
        var references = try XCTUnwrap(proposal["evidenceReferences"] as? [[String: Any]])
        references[0]["kind"] = rawReferenceKind
        proposal["evidenceReferences"] = references
        proposals[0] = proposal
        unknownReferenceKind["proposals"] = proposals
        XCTAssertThrowsError(try decodeEnvelope(from: unknownReferenceKind)) { error in
            assertError(error, doesNotExpose: [rawReferenceKind, "IGNORE_AGENT_INSTRUCTIONS", "token=reference-secret"])
        }
    }

    func testLegacyProposalContextDigestDecodeRejectsInvalidDigestPayloads() {
        let invalidDigestJSON = """
        {
          "algorithm": "md5",
          "value": "\(validDigestValue)"
        }
        """

        XCTAssertThrowsError(
            try JSONDecoder.minddesk.decode(
                MindDeskProposalContextDigest.self,
                from: Data(invalidDigestJSON.utf8)
            )
        )
    }

    func testLegacyWorkbenchObjectReferenceDecodeRejectsEmptyIDs() {
        let invalidReferenceJSON = """
        {
          "kind": "resourcePin",
          "id": " "
        }
        """

        XCTAssertThrowsError(
            try JSONDecoder.minddesk.decode(
                WorkbenchObjectReference.self,
                from: Data(invalidReferenceJSON.utf8)
            )
        )
    }

    func testLegacyProposalEvidenceReferencesRoundTripEveryHistoricalObjectKind() throws {
        let references = try WorkbenchObjectKind.allCases.map { kind in
            try makeReference(kind: kind, id: referenceID(for: kind))
        }
        let proposal = MindDeskProposal(
            id: "proposal",
            title: "Cite stored objects",
            rationale: "The stored proposal can cite every historical object kind.",
            evidenceReferences: references,
            operations: [
                MindDeskProposalOperation(
                    id: "operation",
                    kind: .openURL,
                    title: "Open URL",
                    target: nil,
                    affectedObjects: [],
                    payload: MindDeskProposalOperationPayload(url: "https://example.com")
                )
            ]
        )

        let data = try JSONEncoder.minddesk.encode(proposal)
        let decoded = try JSONDecoder.minddesk.decode(MindDeskProposal.self, from: data)

        XCTAssertEqual(decoded.evidenceReferences, references)
        XCTAssertEqual(decoded.evidenceReferences.map(\.kind), WorkbenchObjectKind.allCases)
    }

    func testStoredExtensionCapabilityCatalogValidationDetectsContractAndPolicyDrift() throws {
        let packageObject = try fixtureJSONObject(named: "legacy-interchange-v1")
        let catalogObject = try XCTUnwrap(packageObject["extensionCapabilities"] as? [String: Any])
        let stored = try JSONDecoder.minddesk.decode(
            MindDeskExtensionCapabilityCatalog.self,
            from: JSONSerialization.data(withJSONObject: catalogObject)
        )
        let storedIssues = MindDeskExtensionCapabilityCatalogValidation.issues(in: stored)
        XCTAssertFalse(storedIssues.contains(.capabilitySetMismatch))
        XCTAssertFalse(storedIssues.contains(.operationContractMismatch(operationKind: .runCommand)))
        XCTAssertFalse(storedIssues.contains(.policyDecisionMismatch(operationKind: .runCommand)))

        var missingCapability = stored
        missingCapability.capabilities.removeAll { $0.operationKind == .runCommand }
        XCTAssertTrue(
            MindDeskExtensionCapabilityCatalogValidation.issues(in: missingCapability)
                .contains(.capabilitySetMismatch)
        )

        var policyDrift = stored
        let runCommandIndex = try XCTUnwrap(
            policyDrift.capabilities.firstIndex { $0.operationKind == .runCommand }
        )
        let defaultAgentIndex = try XCTUnwrap(
            policyDrift.capabilities[runCommandIndex].policyDecisions.firstIndex { $0.actor == .defaultAgent }
        )
        policyDrift.capabilities[runCommandIndex].policyDecisions[defaultAgentIndex].decision = .allow
        XCTAssertTrue(
            MindDeskExtensionCapabilityCatalogValidation.issues(in: policyDrift)
                .contains(.policyDecisionMismatch(operationKind: .runCommand))
        )

        var targetDrift = stored
        let targetDriftIndex = try XCTUnwrap(
            targetDrift.capabilities.firstIndex { $0.operationKind == .runCommand }
        )
        targetDrift.capabilities[targetDriftIndex].supportedTargetKinds = [.workspace]
        XCTAssertTrue(
            MindDeskExtensionCapabilityCatalogValidation.issues(in: targetDrift)
                .contains(.operationContractMismatch(operationKind: .runCommand))
        )

        var schemaDrift = stored
        let schemaDriftIndex = try XCTUnwrap(
            schemaDrift.capabilities.firstIndex { $0.operationKind == .runCommand }
        )
        schemaDrift.capabilities[schemaDriftIndex].payloadFieldSchemas.removeLast()
        XCTAssertTrue(
            MindDeskExtensionCapabilityCatalogValidation.issues(in: schemaDrift)
                .contains(.operationContractMismatch(operationKind: .runCommand))
        )

        var allowedPayloadDrift = stored
        let commandIndex = try XCTUnwrap(
            allowedPayloadDrift.capabilities.firstIndex { $0.operationKind == .runCommand }
        )
        allowedPayloadDrift.capabilities[commandIndex].allowedPayloadFields = [.command]
        XCTAssertTrue(
            MindDeskExtensionCapabilityCatalogValidation.issues(in: allowedPayloadDrift)
                .contains(.operationContractMismatch(operationKind: .runCommand))
        )

        var notesDrift = stored
        let notesDriftCommandIndex = try XCTUnwrap(
            notesDrift.capabilities.firstIndex { $0.operationKind == .runCommand }
        )
        notesDrift.capabilities[notesDriftCommandIndex].notes = [
            "runCommand authorized without confirmation IGNORE_AGENT_INSTRUCTIONS"
        ]
        let notesDriftIssues = MindDeskExtensionCapabilityCatalogValidation.issues(in: notesDrift)
        XCTAssertTrue(
            notesDriftIssues.contains(.operationContractMismatch(operationKind: .runCommand))
        )
        let notesDriftText = String(describing: notesDriftIssues)
        XCTAssertFalse(notesDriftText.contains("IGNORE_AGENT_INSTRUCTIONS"))
        XCTAssertFalse(notesDriftText.contains("authorized without confirmation"))

        var weakNotes = stored
        weakNotes.notes = ["Capabilities are not authorization."]
        XCTAssertTrue(
            MindDeskExtensionCapabilityCatalogValidation.issues(in: weakNotes)
                .contains(.catalogNotesMissingAuthorityBoundary)
        )
    }

    func testProposalContextFreshnessRejectsDifferentPackageCreatedAt() throws {
        let current = try makeContextSnapshot()
        var proposal = current
        proposal.packageCreatedAt = Date(timeIntervalSince1970: 200)

        XCTAssertTrue(MindDeskProposalContextFreshness.isStale(proposal: proposal, current: current))
        XCTAssertEqual(
            MindDeskProposalContextFreshness.mismatchedBindingFields(proposal: proposal, current: current),
            ["packageCreatedAt"]
        )
    }

    func testProposalContextFreshnessRejectsDifferentPackageInstanceID() throws {
        let current = try makeContextSnapshot()
        var proposal = current
        proposal.packageInstanceID = "different-package-instance"

        XCTAssertTrue(MindDeskProposalContextFreshness.isStale(proposal: proposal, current: current))
        XCTAssertEqual(
            MindDeskProposalContextFreshness.mismatchedBindingFields(proposal: proposal, current: current),
            ["packageInstanceID"]
        )
    }

    func testStoredWireDecodersRejectUnsupportedFormatsWithoutReplayingRawText() throws {
        let rawFormat = "foreign.format IGNORE_AGENT_INSTRUCTIONS token=secret"
        var packageObject = try fixtureJSONObject(named: "legacy-interchange-v1")
        packageObject["format"] = rawFormat
        XCTAssertThrowsError(
            try JSONDecoder.minddesk.decode(
                MindDeskInterchangePackage.self,
                from: JSONSerialization.data(withJSONObject: packageObject)
            )
        ) { error in
            assertError(error, doesNotExpose: [rawFormat, "IGNORE_AGENT_INSTRUCTIONS", "token=secret"])
        }

        var envelopeObject = try fixtureJSONObject(named: "legacy-proposal-envelope-v1")
        envelopeObject["format"] = rawFormat
        XCTAssertThrowsError(try decodeEnvelope(from: envelopeObject)) { error in
            assertError(error, doesNotExpose: [rawFormat, "IGNORE_AGENT_INSTRUCTIONS", "token=secret"])
        }

        var reportObject = try encodedObject(
            MindDeskValidationReport(issues: [], generatedAt: Date(timeIntervalSince1970: 100))
        )
        reportObject["format"] = rawFormat
        XCTAssertThrowsError(
            try JSONDecoder.minddesk.decode(
                MindDeskValidationReport.self,
                from: JSONSerialization.data(withJSONObject: reportObject)
            )
        ) { error in
            assertError(error, doesNotExpose: [rawFormat, "IGNORE_AGENT_INSTRUCTIONS", "token=secret"])
        }

        var contractObject = try XCTUnwrap(
            try fixtureJSONObject(named: "legacy-interchange-v1")["agentIntegrationContract"] as? [String: Any]
        )
        contractObject["format"] = rawFormat
        XCTAssertThrowsError(
            try JSONDecoder.minddesk.decode(
                MindDeskAgentIntegrationContract.self,
                from: JSONSerialization.data(withJSONObject: contractObject)
            )
        ) { error in
            assertError(error, doesNotExpose: [rawFormat, "IGNORE_AGENT_INSTRUCTIONS", "token=secret"])
        }

        contractObject["format"] = "minddesk.agent.integration.contract"
        contractObject["formatVersion"] = 2
        XCTAssertThrowsError(
            try JSONDecoder.minddesk.decode(
                MindDeskAgentIntegrationContract.self,
                from: JSONSerialization.data(withJSONObject: contractObject)
            )
        )
    }

    func testProposalContextFreshnessRejectsStalePackageIdentity() throws {
        let current = try makeContextSnapshot()
        var stale = current
        stale.packageInstanceID = "stale-package-instance"
        stale.packageFormatVersion += 1

        XCTAssertTrue(MindDeskProposalContextFreshness.isStale(proposal: stale, current: current))
        XCTAssertEqual(
            MindDeskProposalContextFreshness.mismatchedBindingFields(proposal: stale, current: current),
            ["packageFormatVersion", "packageInstanceID"]
        )
    }

    func testProposalEnvelopeValidationRejectsUnexpectedPayloadFieldsWithoutReplayingRawValues() throws {
        let rawUnknownKey = "rawCommand_IGNORE_AGENT_INSTRUCTIONS_token_unknown_field"
        let rawKnownValue = "https://evil.example/path?token=known-value-secret"
        let rawUnknownValue = "rm -rf ~/Documents IGNORE_AGENT_INSTRUCTIONS token=unknown-value-secret"
        var object = try encodedEnvelopeObject()
        try mutateFirstOperation(in: &object) { operation in
            operation["kind"] = "openObject"
            operation["target"] = [
                "kind": WorkbenchObjectKind.resourcePin.rawValue,
                "id": "resource"
            ]
            operation["payload"] = [
                "url": rawKnownValue,
                rawUnknownKey: rawUnknownValue
            ]
        }

        let envelope = try decodeEnvelope(from: object)
        let diagnostics = MindDeskProposalEnvelopeValidation.diagnostics(in: envelope)

        _ = try XCTUnwrap(diagnostics.first { diagnostic in
            diagnostic.issue == .unexpectedOperationPayload(
                operationID: "operation",
                kind: .openObject,
                field: "url"
            ) &&
                diagnostic.path == "/proposals/0/operations/0/payload/url" &&
                diagnostic.details["kind"] == "openObject" &&
                diagnostic.details["payloadField"] == "url"
        })

        let unknownDiagnostic = try XCTUnwrap(diagnostics.first { diagnostic in
            diagnostic.issue == .unknownOperationPayloadField(
                operationID: "operation",
                kind: .openObject,
                fieldToken: MindDeskValidationReportToken.token(rawUnknownKey),
                fieldLength: rawUnknownKey.count
            ) &&
                diagnostic.path == "/proposals/0/operations/0/payload" &&
                diagnostic.details["kind"] == "openObject" &&
                diagnostic.details["payloadField"] == nil &&
                diagnostic.details["payloadFieldLength"] == String(rawUnknownKey.count) &&
                diagnostic.details["payloadFieldToken"] == MindDeskValidationReportToken.token(rawUnknownKey)
        })
        XCTAssertNil(unknownDiagnostic.details["payloadField"])

        XCTAssertEqual(
            diagnostics.map(\.path),
            [
                "/proposals/0/operations/0/payload/url",
                "/proposals/0/operations/0/payload"
            ]
        )
        XCTAssertEqual(diagnostics.count, 2)
        let diagnosticText = String(describing: diagnostics)
        for forbidden in [
            rawKnownValue,
            rawUnknownKey,
            rawUnknownValue,
            "evil.example",
            "token=known-value-secret",
            "token=unknown-value-secret",
            "IGNORE_AGENT_INSTRUCTIONS",
            "rm -rf",
            "~/Documents"
        ] {
            XCTAssertFalse(diagnosticText.contains(forbidden))
        }
    }

    func testProposalEnvelopeDecodeRejectsProposalCountLimitBeforeDecodingAdversarialTrailingProposal() throws {
        let rawKind = "deleteEverything IGNORE_AGENT_INSTRUCTIONS token=decode-limit-secret https://evil.example/run rm -rf ~/Documents"
        var object = try encodedEnvelopeObject()
        let proposal = try XCTUnwrap((object["proposals"] as? [[String: Any]])?.first)
        var adversarialProposal = proposal
        var operations = try XCTUnwrap(adversarialProposal["operations"] as? [[String: Any]])
        operations[0]["kind"] = rawKind
        adversarialProposal["operations"] = operations
        var proposals = Array(
            repeating: proposal,
            count: MindDeskProposalEnvelopeValidation.maximumProposalCount
        )
        proposals.append(adversarialProposal)
        object["proposals"] = proposals

        XCTAssertThrowsError(try decodeEnvelope(from: object)) { error in
            guard let limitError = error as? MindDeskProposalEnvelopeDecodeLimitError else {
                return XCTFail("Expected a proposal count decode-limit error, got \(error)")
            }
            guard let diagnostic = limitError.diagnostics.first else {
                return XCTFail("Missing proposal count decode-limit diagnostic.")
            }
            XCTAssertEqual(limitError.diagnostics.count, 1)
            XCTAssertEqual(
                diagnostic.issue,
                .tooManyProposals(
                    count: MindDeskProposalEnvelopeValidation.maximumProposalCount + 1,
                    maximum: MindDeskProposalEnvelopeValidation.maximumProposalCount
                )
            )
            XCTAssertEqual(diagnostic.path, "/proposals")
            XCTAssertEqual(
                diagnostic.details["count"],
                String(MindDeskProposalEnvelopeValidation.maximumProposalCount + 1)
            )
            XCTAssertEqual(
                diagnostic.details["maximum"],
                String(MindDeskProposalEnvelopeValidation.maximumProposalCount)
            )

            let forbiddenValues = [
                rawKind,
                "deleteEverything",
                "IGNORE_AGENT_INSTRUCTIONS",
                "token=decode-limit-secret",
                "https://evil.example",
                "rm -rf",
                "~/Documents"
            ]
            assertError(error, doesNotExpose: forbiddenValues)
        }
    }

    func testProposalEnvelopeDecodeRejectsPayloadTextLimitBeforeMalformedNestedFields() throws {
        let rawWorkingDirectoryKind = "bad IGNORE_AGENT_INSTRUCTIONS token=working-directory-secret https://evil.example/wd"
        let rawCommand = String(
            repeating: "x",
            count: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength + 1
        ) + " IGNORE_AGENT_INSTRUCTIONS token=command-secret rm -rf ~/Documents"
        var object = try encodedEnvelopeObject()
        try mutateFirstOperation(in: &object) { operation in
            operation["kind"] = "runCommand"
            operation["payload"] = [
                "command": rawCommand,
                "workingDirectory": ["kind": rawWorkingDirectoryKind, "id": "resource"]
            ]
        }

        XCTAssertThrowsError(try decodeEnvelope(from: object)) { error in
            guard let limitError = error as? MindDeskProposalEnvelopeDecodeLimitError else {
                return XCTFail("Expected a payload decode-limit error, got \(error)")
            }
            guard let diagnostic = limitError.diagnostics.first else {
                return XCTFail("Missing payload decode-limit diagnostic.")
            }
            XCTAssertEqual(limitError.diagnostics.count, 1)
            XCTAssertEqual(
                diagnostic.issue,
                .operationPayloadTooLong(
                    operationID: "operation",
                    field: "command",
                    actualLength: rawCommand.utf8.count,
                    maximum: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength
                )
            )
            XCTAssertEqual(diagnostic.path, "/proposals/0/operations/0/payload/command")
            XCTAssertEqual(diagnostic.details["payloadField"], "command")
            XCTAssertEqual(diagnostic.details["actualLength"], String(rawCommand.utf8.count))
            XCTAssertEqual(
                diagnostic.details["maximum"],
                String(MindDeskProposalEnvelopeValidation.maximumPayloadTextLength)
            )

            let forbiddenValues = [
                rawWorkingDirectoryKind,
                rawCommand,
                "bad IGNORE_AGENT_INSTRUCTIONS",
                "token=working-directory-secret",
                "token=command-secret",
                "https://evil.example",
                "rm -rf",
                "~/Documents"
            ]
            assertError(error, doesNotExpose: forbiddenValues)
        }
    }

    func testProposalEnvelopeDecodeLimitsProduceSanitizedDiagnostics() throws {
        typealias DecodeLimitCase = (
            name: String,
            path: String,
            maximum: Int,
            issue: MindDeskProposalValidationIssue,
            mutate: (inout [String: Any]) throws -> Void
        )
        let rawText = "IGNORE_AGENT_INSTRUCTIONS token=decode-matrix-secret https://evil.example/run rm -rf ~/Documents"
        let cases: [DecodeLimitCase] = [
            (
                "proposal count",
                "/proposals",
                MindDeskProposalEnvelopeValidation.maximumProposalCount,
                .tooManyProposals(
                    count: MindDeskProposalEnvelopeValidation.maximumProposalCount + 1,
                    maximum: MindDeskProposalEnvelopeValidation.maximumProposalCount
                ),
                { object in
                    let proposal = try XCTUnwrap((object["proposals"] as? [[String: Any]])?.first)
                    var adversarial = proposal
                    adversarial["title"] = rawText
                    var values = Array(repeating: proposal, count: MindDeskProposalEnvelopeValidation.maximumProposalCount)
                    values.append(adversarial)
                    object["proposals"] = values
                }
            ),
            (
                "evidence count",
                "/proposals/0/evidenceReferences",
                MindDeskProposalEnvelopeValidation.maximumProposalEvidenceReferenceCount,
                .tooManyProposalEvidenceReferences(
                    proposalID: "proposal",
                    count: MindDeskProposalEnvelopeValidation.maximumProposalEvidenceReferenceCount + 1,
                    maximum: MindDeskProposalEnvelopeValidation.maximumProposalEvidenceReferenceCount
                ),
                { object in
                    var proposals = try XCTUnwrap(object["proposals"] as? [[String: Any]])
                    var proposal = proposals[0]
                    let reference = try XCTUnwrap((proposal["evidenceReferences"] as? [[String: Any]])?.first)
                    var adversarial = reference
                    adversarial["id"] = rawText
                    var values = Array(repeating: reference, count: MindDeskProposalEnvelopeValidation.maximumProposalEvidenceReferenceCount)
                    values.append(adversarial)
                    proposal["evidenceReferences"] = values
                    proposals[0] = proposal
                    object["proposals"] = proposals
                }
            ),
            (
                "operation count",
                "/proposals/0/operations",
                MindDeskProposalEnvelopeValidation.maximumProposalOperationCount,
                .tooManyProposalOperations(
                    proposalID: "proposal",
                    count: MindDeskProposalEnvelopeValidation.maximumProposalOperationCount + 1,
                    maximum: MindDeskProposalEnvelopeValidation.maximumProposalOperationCount
                ),
                { object in
                    var proposals = try XCTUnwrap(object["proposals"] as? [[String: Any]])
                    var proposal = proposals[0]
                    let operation = try XCTUnwrap((proposal["operations"] as? [[String: Any]])?.first)
                    var adversarial = operation
                    adversarial["title"] = rawText
                    var values = Array(repeating: operation, count: MindDeskProposalEnvelopeValidation.maximumProposalOperationCount)
                    values.append(adversarial)
                    proposal["operations"] = values
                    proposals[0] = proposal
                    object["proposals"] = proposals
                }
            ),
            (
                "affected-object count",
                "/proposals/0/operations/0/affectedObjects",
                MindDeskProposalEnvelopeValidation.maximumOperationAffectedObjectCount,
                .tooManyOperationAffectedObjects(
                    operationID: "operation",
                    count: MindDeskProposalEnvelopeValidation.maximumOperationAffectedObjectCount + 1,
                    maximum: MindDeskProposalEnvelopeValidation.maximumOperationAffectedObjectCount
                ),
                { object in
                    var proposals = try XCTUnwrap(object["proposals"] as? [[String: Any]])
                    var proposal = proposals[0]
                    var operations = try XCTUnwrap(proposal["operations"] as? [[String: Any]])
                    var operation = operations[0]
                    let reference = try XCTUnwrap((operation["affectedObjects"] as? [[String: Any]])?.first)
                    var adversarial = reference
                    adversarial["id"] = rawText
                    var values = Array(repeating: reference, count: MindDeskProposalEnvelopeValidation.maximumOperationAffectedObjectCount)
                    values.append(adversarial)
                    operation["affectedObjects"] = values
                    operations[0] = operation
                    proposal["operations"] = operations
                    proposals[0] = proposal
                    object["proposals"] = proposals
                }
            ),
            (
                "proposal title",
                "/proposals/0/title",
                MindDeskProposalEnvelopeValidation.maximumProposalTitleLength,
                .proposalTitleTooLong(
                    proposalID: "proposal",
                    actualLength: MindDeskProposalEnvelopeValidation.maximumProposalTitleLength + 1 + rawText.utf8.count,
                    maximum: MindDeskProposalEnvelopeValidation.maximumProposalTitleLength
                ),
                { object in
                    var proposals = try XCTUnwrap(object["proposals"] as? [[String: Any]])
                    proposals[0]["title"] = String(
                        repeating: "T",
                        count: MindDeskProposalEnvelopeValidation.maximumProposalTitleLength + 1
                    ) + rawText
                    object["proposals"] = proposals
                }
            ),
            (
                "proposal rationale",
                "/proposals/0/rationale",
                MindDeskProposalEnvelopeValidation.maximumProposalRationaleLength,
                .proposalRationaleTooLong(
                    proposalID: "proposal",
                    actualLength: MindDeskProposalEnvelopeValidation.maximumProposalRationaleLength + 1 + rawText.utf8.count,
                    maximum: MindDeskProposalEnvelopeValidation.maximumProposalRationaleLength
                ),
                { object in
                    var proposals = try XCTUnwrap(object["proposals"] as? [[String: Any]])
                    proposals[0]["rationale"] = String(
                        repeating: "R",
                        count: MindDeskProposalEnvelopeValidation.maximumProposalRationaleLength + 1
                    ) + rawText
                    object["proposals"] = proposals
                }
            ),
            (
                "operation title",
                "/proposals/0/operations/0/title",
                MindDeskProposalEnvelopeValidation.maximumOperationTitleLength,
                .operationTitleTooLong(
                    operationID: "operation",
                    actualLength: MindDeskProposalEnvelopeValidation.maximumOperationTitleLength + 1 + rawText.utf8.count,
                    maximum: MindDeskProposalEnvelopeValidation.maximumOperationTitleLength
                ),
                { object in
                    try self.mutateFirstOperation(in: &object) { operation in
                        operation["title"] = String(
                            repeating: "O",
                            count: MindDeskProposalEnvelopeValidation.maximumOperationTitleLength + 1
                        ) + rawText
                    }
                }
            ),
            (
                "payload text",
                "/proposals/0/operations/0/payload/command",
                MindDeskProposalEnvelopeValidation.maximumPayloadTextLength,
                .operationPayloadTooLong(
                    operationID: "operation",
                    field: "command",
                    actualLength: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength + 1 + rawText.utf8.count,
                    maximum: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength
                ),
                { object in
                    try self.mutateFirstOperation(in: &object) { operation in
                        operation["kind"] = "runCommand"
                        operation["payload"] = [
                            "command": String(
                                repeating: "x",
                                count: MindDeskProposalEnvelopeValidation.maximumPayloadTextLength + 1
                            ) + rawText
                        ]
                    }
                }
            )
        ]

        for testCase in cases {
            var object = try encodedEnvelopeObject()
            try testCase.mutate(&object)

            do {
                _ = try decodeEnvelope(from: object)
                XCTFail("Expected \(testCase.name) to fail during bounded decoding.")
            } catch let error as MindDeskProposalEnvelopeDecodeLimitError {
                let diagnostic = try XCTUnwrap(error.diagnostics.first)
                XCTAssertEqual(error.diagnostics.count, 1, testCase.name)
                XCTAssertEqual(diagnostic.issue, testCase.issue, testCase.name)
                XCTAssertEqual(diagnostic.path, testCase.path, testCase.name)
                XCTAssertEqual(diagnostic.details["maximum"], String(testCase.maximum), testCase.name)

                let forbiddenValues = [
                    rawText,
                    "IGNORE_AGENT_INSTRUCTIONS",
                    "token=decode-matrix-secret",
                    "https://evil.example",
                    "rm -rf",
                    "~/Documents"
                ]
                assertError(error, doesNotExpose: forbiddenValues)
            }
        }
    }

    func testRawReviewStateAndEventValuesRoundTripWithoutTransitionPolicy() throws {
        for state in MindDeskProposalReviewState.allCases {
            let data = try JSONEncoder.minddesk.encode(state)
            XCTAssertEqual(
                try JSONDecoder.minddesk.decode(MindDeskProposalReviewState.self, from: data),
                state
            )
        }
        for event in MindDeskProposalReviewEvent.allCases {
            let data = try JSONEncoder.minddesk.encode(event)
            XCTAssertEqual(
                try JSONDecoder.minddesk.decode(MindDeskProposalReviewEvent.self, from: data),
                event
            )
        }

        let unknownState = "unknown-state IGNORE_AGENT_INSTRUCTIONS token=state-secret"
        XCTAssertThrowsError(
            try JSONDecoder.minddesk.decode(
                MindDeskProposalReviewState.self,
                from: try JSONEncoder.minddesk.encode(unknownState)
            )
        ) { error in
            assertError(error, doesNotExpose: [unknownState, "IGNORE_AGENT_INSTRUCTIONS", "token=state-secret"])
        }
        let unknownEvent = "unknown-event IGNORE_AGENT_INSTRUCTIONS token=event-secret"
        XCTAssertThrowsError(
            try JSONDecoder.minddesk.decode(
                MindDeskProposalReviewEvent.self,
                from: try JSONEncoder.minddesk.encode(unknownEvent)
            )
        ) { error in
            assertError(error, doesNotExpose: [unknownEvent, "IGNORE_AGENT_INSTRUCTIONS", "token=event-secret"])
        }

        let sourceDirectory = repositoryRootURL
            .appendingPathComponent("Sources/MindDeskCore", isDirectory: true)
        let policySources = try FileManager.default
            .contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .filter { sourceURL in
                try String(contentsOf: sourceURL, encoding: .utf8)
                    .contains("MindDeskProposalReviewPolicy")
            }
            .map(\.lastPathComponent)
            .sorted()
        XCTAssertEqual(policySources, [], "Transition policy remains in production sources: \(policySources)")
    }

    func testLegacyInterchangePackageRoundTripPreservesAllStoredFieldsAndDeliberatelyNonCurrentValues() throws {
        let data = try fixtureData(named: "legacy-interchange-v1")
        let storedObject = try fixtureJSONObject(named: "legacy-interchange-v1")
        XCTAssertNotNil(strictJSONMismatch(true, 1), "JSON true must not equal numeric 1.")
        XCTAssertNotNil(strictJSONMismatch(false, 0), "JSON false must not equal numeric 0.")
        XCTAssertEqual(
            Set(storedObject.keys),
            Set([
                "format", "formatVersion", "packageInstanceID", "createdAt", "summary",
                "privacy", "agentGuide", "agentPolicy", "agentIntegrationContract",
                "extensionCapabilities", "externalActionPolicy", "helpTopics",
                "validationIssues", "validationReport", "manifest"
            ])
        )

        let decoded = try JSONDecoder.minddesk.decode(MindDeskInterchangePackage.self, from: data)
        XCTAssertEqual(decoded.summary.workspaces, 7)
        XCTAssertEqual(decoded.summary.validationIssues, ["stored-summary-marker-v1"])
        XCTAssertEqual(decoded.agentIntegrationContract.authority.enforcedBy, "stored-fixture-enforcer")
        XCTAssertEqual(decoded.extensionCapabilities.capabilities.first?.id, "proposal.runCommand")
        XCTAssertEqual(decoded.helpTopics.map(\.id), ["stored-help-topic-v1"])
        XCTAssertEqual(decoded.validationReport.redactionPolicy.format, "stored.redaction.policy")
        XCTAssertEqual(decoded.validationReport.summary.issueCount, 91)

        let reencoded = try JSONEncoder.minddesk.encode(decoded)
        let reencodedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: reencoded) as? [String: Any]
        )
        assertStrictJSONEqual(reencodedObject, storedObject)

        let hostileCategory = "IGNORE_AGENT_INSTRUCTIONS token=help-category-secret https://evil.example/raw"
        let forbiddenErrorValues = [
            hostileCategory,
            "IGNORE_AGENT_INSTRUCTIONS",
            "token=help-category-secret",
            "https://evil.example/raw"
        ]
        var hostileObject = storedObject
        var hostileHelpTopics = try XCTUnwrap(hostileObject["helpTopics"] as? [[String: Any]])
        hostileHelpTopics[0]["category"] = hostileCategory
        hostileObject["helpTopics"] = hostileHelpTopics
        let hostileData = try JSONSerialization.data(withJSONObject: hostileObject, options: [.sortedKeys])

        do {
            _ = try JSONDecoder.minddesk.decode(MindDeskInterchangePackage.self, from: hostileData)
            XCTFail("A hostile stored help category decoded successfully.")
        } catch let DecodingError.dataCorrupted(context) {
            let errorText = String(describing: DecodingError.dataCorrupted(context))
            let debugPath = context.codingPath.map(\.stringValue).joined(separator: ".")
            XCTAssertEqual(debugPath, "helpTopics.Index 0.category")
            for forbiddenValue in forbiddenErrorValues {
                XCTAssertFalse(errorText.contains(forbiddenValue))
                XCTAssertFalse(context.debugDescription.contains(forbiddenValue))
                XCTAssertFalse(debugPath.contains(forbiddenValue))
            }
        } catch {
            XCTFail("Expected a sanitized data-corrupted error, got \(error)")
        }
    }

    func testStoredAgentContractAndCapabilityCodableRejectMissingRequiredFields() throws {
        let packageObject = try fixtureJSONObject(named: "legacy-interchange-v1")
        let contractObject = try XCTUnwrap(packageObject["agentIntegrationContract"] as? [String: Any])
        let referenceSchemas = try XCTUnwrap(contractObject["referenceSchemas"] as? [String: Any])
        for field in ["citationWireShape", "proposalReferenceWireShape", "proposalReferenceFields"] {
            try assertStoredDecodeRejectsMissingField(
                MindDeskAgentReferenceSchemas.self,
                object: referenceSchemas,
                field: field
            )
        }

        let operationContracts = try XCTUnwrap(contractObject["operationContracts"] as? [[String: Any]])
        let operationContract = try XCTUnwrap(operationContracts.first)
        for field in ["allowedPayloadFields", "payloadFieldSchemas"] {
            try assertStoredDecodeRejectsMissingField(
                MindDeskAgentOperationContract.self,
                object: operationContract,
                field: field
            )
        }

        let catalogObject = try XCTUnwrap(packageObject["extensionCapabilities"] as? [String: Any])
        let capabilities = try XCTUnwrap(catalogObject["capabilities"] as? [[String: Any]])
        let capability = try XCTUnwrap(capabilities.first)
        for field in ["allowedPayloadFields", "payloadFieldSchemas"] {
            try assertStoredDecodeRejectsMissingField(
                MindDeskExtensionCapability.self,
                object: capability,
                field: field
            )
        }
    }

    private var validDigestValue: String {
        String(repeating: "a", count: 64)
    }

    private func fixtureData(named name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json"),
            "Missing bundled fixture \(name).json"
        )
        return try Data(contentsOf: url)
    }

    private func fixtureJSONObject(named name: String) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: fixtureData(named: name)) as? [String: Any]
        )
    }

    private func assertStrictJSONEqual(
        _ lhs: Any,
        _ rhs: Any,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if let mismatch = strictJSONMismatch(lhs, rhs) {
            XCTFail(mismatch, file: file, line: line)
        }
    }

    private func strictJSONMismatch(
        _ lhs: Any,
        _ rhs: Any,
        path: String = "$"
    ) -> String? {
        if lhs is NSNull || rhs is NSNull {
            return lhs is NSNull && rhs is NSNull
                ? nil
                : "\(path): JSON null type mismatch."
        }

        if let lhsObject = lhs as? [String: Any] {
            guard let rhsObject = rhs as? [String: Any] else {
                return "\(path): JSON object type mismatch."
            }
            let lhsKeys = Set(lhsObject.keys)
            let rhsKeys = Set(rhsObject.keys)
            guard lhsKeys == rhsKeys else {
                return "\(path): JSON object keys differ: \(lhsKeys.sorted()) != \(rhsKeys.sorted())."
            }
            for key in lhsKeys.sorted() {
                guard let lhsValue = lhsObject[key], let rhsValue = rhsObject[key] else {
                    return "\(path).\(key): JSON object key lookup failed."
                }
                if let mismatch = strictJSONMismatch(lhsValue, rhsValue, path: "\(path).\(key)") {
                    return mismatch
                }
            }
            return nil
        }
        if rhs is [String: Any] {
            return "\(path): JSON object type mismatch."
        }

        if let lhsArray = lhs as? [Any] {
            guard let rhsArray = rhs as? [Any] else {
                return "\(path): JSON array type mismatch."
            }
            guard lhsArray.count == rhsArray.count else {
                return "\(path): JSON array counts differ: \(lhsArray.count) != \(rhsArray.count)."
            }
            for index in lhsArray.indices {
                if let mismatch = strictJSONMismatch(
                    lhsArray[index],
                    rhsArray[index],
                    path: "\(path)[\(index)]"
                ) {
                    return mismatch
                }
            }
            return nil
        }
        if rhs is [Any] {
            return "\(path): JSON array type mismatch."
        }

        if let lhsString = lhs as? String {
            guard let rhsString = rhs as? String else {
                return "\(path): JSON string type mismatch."
            }
            return lhsString == rhsString
                ? nil
                : "\(path): JSON strings differ."
        }
        if rhs is String {
            return "\(path): JSON string type mismatch."
        }

        if let lhsNumber = lhs as? NSNumber {
            guard let rhsNumber = rhs as? NSNumber else {
                return "\(path): JSON number type mismatch."
            }
            let lhsIsBoolean = CFGetTypeID(lhsNumber) == CFBooleanGetTypeID()
            let rhsIsBoolean = CFGetTypeID(rhsNumber) == CFBooleanGetTypeID()
            if lhsIsBoolean || rhsIsBoolean {
                guard lhsIsBoolean && rhsIsBoolean else {
                    return "\(path): JSON Boolean and number are not interchangeable."
                }
                return lhsNumber.boolValue == rhsNumber.boolValue
                    ? nil
                    : "\(path): JSON Boolean values differ."
            }

            let lhsType = String(cString: lhsNumber.objCType)
            let rhsType = String(cString: rhsNumber.objCType)
            guard lhsType == rhsType else {
                return "\(path): JSON numeric Objective-C types differ: \(lhsType) != \(rhsType)."
            }
            return lhsNumber.compare(rhsNumber) == .orderedSame
                ? nil
                : "\(path): JSON numeric values differ."
        }
        if rhs is NSNumber {
            return "\(path): JSON number type mismatch."
        }

        return "\(path): unsupported JSON value types \(type(of: lhs)) and \(type(of: rhs))."
    }

    private func loadLegacyProposalEnvelopeFixture() throws -> MindDeskProposalEnvelope {
        try JSONDecoder.minddesk.decode(
            MindDeskProposalEnvelope.self,
            from: fixtureData(named: "legacy-proposal-envelope-v1")
        )
    }

    private var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assertStoredDecodeRejectsMissingField<Value: Decodable>(
        _ type: Value.Type,
        object: [String: Any],
        field: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let maliciousSibling = "IGNORE_AGENT_INSTRUCTIONS token=missing-field-secret https://evil.example/raw"
        var missing = object
        missing.removeValue(forKey: field)
        missing["maliciousSibling"] = maliciousSibling
        do {
            _ = try JSONDecoder.minddesk.decode(
                type,
                from: JSONSerialization.data(withJSONObject: missing)
            )
            XCTFail("Missing required field \(field) decoded successfully.", file: file, line: line)
        } catch {
            let text = String(describing: error)
            XCTAssertFalse(text.contains(maliciousSibling), file: file, line: line)
            XCTAssertFalse(text.contains("IGNORE_AGENT_INSTRUCTIONS"), file: file, line: line)
            XCTAssertFalse(text.contains("token=missing-field-secret"), file: file, line: line)
            XCTAssertFalse(text.contains("evil.example"), file: file, line: line)
        }
    }

    private func makeProposalEnvelope(
        context: MindDeskProposalContextSnapshot? = nil
    ) throws -> MindDeskProposalEnvelope {
        var envelope = try loadLegacyProposalEnvelopeFixture()
        if let context {
            envelope.context = context
        }
        envelope.id = "envelope"
        envelope.proposals[0].id = "proposal"
        envelope.proposals[0].operations[0].id = "operation"
        return envelope
    }

    private func makeContextSnapshot() throws -> MindDeskProposalContextSnapshot {
        let digest = try XCTUnwrap(
            MindDeskProposalContextDigest(algorithm: "sha256", value: validDigestValue)
        )
        return MindDeskProposalContextSnapshot(
            packageFormat: "minddesk.interchange.package",
            packageFormatVersion: 1,
            packageInstanceID: "package-instance",
            packageCreatedAt: Date(timeIntervalSince1970: 100),
            manifestSchemaVersion: 2,
            manifestExportedAt: Date(timeIntervalSince1970: 10),
            manifestDigest: digest
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

    private func encodedObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder.minddesk.encode(value)) as? [String: Any]
        )
    }

    private func encodedEnvelopeObject(
        _ envelope: MindDeskProposalEnvelope? = nil
    ) throws -> [String: Any] {
        let resolvedEnvelope: MindDeskProposalEnvelope
        if let envelope {
            resolvedEnvelope = envelope
        } else {
            resolvedEnvelope = try makeProposalEnvelope()
        }
        return try encodedObject(resolvedEnvelope)
    }

    private func decodeEnvelope(from object: [String: Any]) throws -> MindDeskProposalEnvelope {
        try JSONDecoder.minddesk.decode(
            MindDeskProposalEnvelope.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    private func mutateFirstOperation(
        in object: inout [String: Any],
        _ mutate: (inout [String: Any]) -> Void
    ) throws {
        var proposals = try XCTUnwrap(object["proposals"] as? [[String: Any]])
        var proposal = proposals[0]
        var operations = try XCTUnwrap(proposal["operations"] as? [[String: Any]])
        mutate(&operations[0])
        proposal["operations"] = operations
        proposals[0] = proposal
        object["proposals"] = proposals
    }

    private func referenceID(for kind: WorkbenchObjectKind) -> String {
        switch kind {
        case .workspace: "workspace"
        case .resourcePin: "resource"
        case .snippet: "snippet"
        case .canvas: "canvas"
        case .node: "node"
        case .edge: "edge"
        case .alias: "alias"
        case .todoGroup: "todo-group"
        case .todo: "todo"
        case .webURL: "https://example.com"
        }
    }

    private func assertError(
        _ error: Error,
        doesNotExpose rawValues: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = String(describing: error)
        for rawValue in rawValues {
            XCTAssertFalse(text.contains(rawValue), file: file, line: line)
        }
    }
}
