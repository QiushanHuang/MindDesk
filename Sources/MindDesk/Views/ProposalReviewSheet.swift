import MindDeskCore
import SwiftUI

enum ProposalReviewSheetState: Identifiable {
    case ready(ProposalReviewPresentationModel)
    case blocked(ProposalReviewBlockedPresentationModel)

    init(gateResult: MindDeskProposalReviewGateResult) {
        switch gateResult {
        case .ready(let session):
            self = .ready(ProposalReviewPresentationModel(session: session))
        case .blocked(let report):
            self = .blocked(ProposalReviewBlockedPresentationModel(report: report))
        }
    }

    var id: String {
        switch self {
        case .ready(let presentation):
            return "ready-\(presentation.id)"
        case .blocked(let presentation):
            return "blocked-\(presentation.id)"
        }
    }
}

struct ProposalReviewPresentationModel: Identifiable {
    let id: String
    let envelopeID: String
    let title = "Agent Proposal Review (Read-only)"
    let proposalCountText: String
    let operationCountText: String
    let readOnlyNoticeText: String
    let contextSummaryText: String
    let validationSummaryText: String
    let riskSummaryText: String
    let reviewActionBoundaryText: String
    let proposals: [ProposalReviewProposalRow]
    let operationRows: [ProposalReviewOperationRow]
    private(set) var session: MindDeskProposalReviewSession
    private(set) var state: MindDeskProposalReviewState

    init(session: MindDeskProposalReviewSession) {
        self.id = session.envelope.id
        self.envelopeID = Self.safeOpaqueIDText(session.envelope.id)
        self.session = session
        self.state = session.state
        self.proposalCountText = Self.countText(
            session.envelope.proposals.count,
            singular: "proposal",
            plural: "proposals"
        )
        let operationCount = session.envelope.proposals.reduce(0) { count, proposal in
            count + proposal.operations.count
        }
        self.operationCountText = Self.countText(
            operationCount,
            singular: "operation",
            plural: "operations"
        )
        self.readOnlyNoticeText = "Review only. No Finder, URL, clipboard, Terminal, command, alias, import, or apply operation has run."
        self.contextSummaryText = "Context matches original Agent Review package."
        self.validationSummaryText = Self.validationSummaryText(for: session.validationReport)
        self.reviewActionBoundaryText = "Approval and rejection only record in-memory review state. Approval is not authorization and does not run Finder, URL, clipboard, Terminal, command, alias, import, export, apply, or SwiftData changes."
        self.proposals = session.envelope.proposals.map(ProposalReviewProposalRow.init)
        self.operationRows = session.envelope.proposals.flatMap { proposal in
            proposal.operations.map { operation in
                ProposalReviewOperationRow(
                    proposalTitle: proposal.title,
                    operation: operation,
                    proposedBy: session.envelope.proposedBy
                )
            }
        }
        self.riskSummaryText = Self.riskSummaryText(for: operationRows)
    }

    var stateLabel: String {
        switch state {
        case .pendingReview:
            return "Pending review"
        case .approved:
            return "Approved"
        case .rejected:
            return "Rejected"
        case .applied:
            return "Applied"
        case .expired:
            return "Expired"
        case .superseded:
            return "Superseded"
        }
    }

    var availableActions: [ProposalReviewAction] {
        switch state {
        case .pendingReview:
            return [
                ProposalReviewAction(event: .approve, label: "Record approval only", role: nil),
                ProposalReviewAction(event: .reject, label: "Record rejection only", role: .destructive)
            ]
        case .approved:
            return [
                ProposalReviewAction(event: .reject, label: "Record rejection only", role: .destructive)
            ]
        case .rejected, .applied, .expired, .superseded:
            return []
        }
    }

    mutating func apply(_ event: MindDeskProposalReviewEvent) -> Bool {
        guard availableActions.contains(where: { $0.event == event }),
              let nextState = MindDeskProposalReviewPolicy.nextState(
                  from: state,
                  event: event,
                  actor: .directUser
              ) else {
            return false
        }
        state = nextState
        session.state = nextState
        return true
    }

    private static func validationSummaryText(for report: MindDeskValidationReport) -> String {
        let summary = MindDeskValidationReportSummary(issues: report.issues)
        let validity = summary.isValid ? "valid" : "invalid"
        return "Validation: \(validity), \(summary.issueCount) \(Self.issueText(summary.issueCount, noun: "issue")), \(summary.errorCount) \(Self.issueText(summary.errorCount, noun: "error")), \(summary.warningCount) \(Self.issueText(summary.warningCount, noun: "warning"))"
    }

    private static func riskSummaryText(for operations: [ProposalReviewOperationRow]) -> String {
        let counts = Dictionary(grouping: operations, by: \.riskTier)
            .mapValues(\.count)
        return [
            "Risk:",
            "\(counts[.readOnly, default: 0]) read-only,",
            "\(counts[.userMediated, default: 0]) user-mediated,",
            "\(counts[.confirmationRequired, default: 0]) confirmation required,",
            "\(counts[.denied, default: 0]) denied"
        ].joined(separator: " ")
    }

    private static func countText(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }

    private static func issueText(_ count: Int, noun: String) -> String {
        count == 1 ? noun : "\(noun)s"
    }

    private static func safeOpaqueIDText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.range(of: #"^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$"#, options: .regularExpression) != nil,
              !ProposalReviewSafeDisplayText.containsUnsafeText(trimmed),
              !trimmed.lowercased().contains("://"),
              !trimmed.hasPrefix("/"),
              !trimmed.hasPrefix("~/"),
              trimmed.range(of: #"^[A-Za-z]:[\\/]"#, options: .regularExpression) == nil else {
            return "redacted"
        }
        return trimmed
    }
}

struct ProposalReviewProposalRow: Identifiable, Equatable {
    let id: String
    let title: String
    let rationale: String
    let evidenceCountText: String
    let evidenceReferences: [ProposalReviewReferenceRow]

    init(proposal: MindDeskProposal) {
        self.id = proposal.id
        self.title = ProposalReviewSafeDisplayText.safeAgentText(
            proposal.title,
            fallback: "Untrusted proposal title redacted"
        )
        self.rationale = ProposalReviewSafeDisplayText.safeAgentText(
            proposal.rationale,
            fallback: "Untrusted proposal rationale redacted"
        )
        self.evidenceReferences = proposal.evidenceReferences.map(ProposalReviewReferenceRow.init)
        let count = proposal.evidenceReferences.count
        self.evidenceCountText = "\(count) evidence reference\(count == 1 ? "" : "s")"
    }
}

struct ProposalReviewReferenceRow: Identifiable, Equatable {
    let id: String
    let kind: WorkbenchObjectKind
    let displayID: String

    init(reference: WorkbenchObjectReference) {
        self.id = "\(reference.kind.rawValue):\(reference.id)"
        self.kind = reference.kind
        self.displayID = Self.safeDisplayID(for: reference)
    }

    var displayText: String {
        "\(kind.rawValue): \(displayID)"
    }

    private static func safeDisplayID(for reference: WorkbenchObjectReference) -> String {
        let rawID = reference.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawID.isEmpty,
              reference.kind != .webURL,
              isStructuredObjectID(rawID),
              !looksLikeURL(rawID),
              !looksLikePath(rawID),
              !ProposalReviewSafeDisplayText.containsUnsafeText(rawID) else {
            return "redacted"
        }
        return rawID
    }

    private static func looksLikeURL(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return lowercased.hasPrefix("http://") ||
            lowercased.hasPrefix("https://") ||
            lowercased.contains("://")
    }

    private static func looksLikePath(_ value: String) -> Bool {
        value.hasPrefix("/") ||
            value.hasPrefix("~/") ||
            value.hasPrefix("~\\") ||
            value.range(of: #"^[A-Za-z]:[\\/]"#, options: .regularExpression) != nil
    }

    private static func isStructuredObjectID(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$"#,
            options: .regularExpression
        ) != nil
    }
}

struct ProposalReviewOperationRow: Identifiable, Equatable {
    let id: String
    let proposalTitle: String
    let title: String
    let kind: MindDeskProposalOperationKind
    let capabilityID: String
    let capabilityTitle: String
    let externalAction: WorkbenchExternalAction
    let requiresTarget: Bool
    let supportedTargetKinds: [WorkbenchObjectKind]
    let requiredPayloadFields: [MindDeskAgentOperationPayloadField]
    let allowedPayloadFields: [MindDeskAgentOperationPayloadField]
    let payloadFieldSchemas: [MindDeskAgentOperationPayloadFieldSchema]
    let policyActor: WorkbenchExternalActor
    let policyDecision: WorkbenchExternalActionDecision
    let requiresUserMediation: Bool
    let riskTier: MindDeskProposalOperationRiskTier
    let targetReference: ProposalReviewReferenceRow?
    let targetSummary: String
    let affectedObjectCountText: String

    init(
        proposalTitle: String,
        operation: MindDeskProposalOperation,
        proposedBy: WorkbenchExternalActor
    ) {
        let capability = MindDeskExtensionCapabilityCatalog.current.capability(for: operation.kind)
        let policy = capability?.policyDecision(for: proposedBy)
        let targetReference = operation.target.map(ProposalReviewReferenceRow.init)
        self.id = operation.id
        self.proposalTitle = ProposalReviewSafeDisplayText.safeAgentText(
            proposalTitle,
            fallback: "Untrusted proposal title redacted"
        )
        self.title = ProposalReviewSafeDisplayText.safeAgentText(
            operation.title,
            fallback: "Untrusted operation title redacted"
        )
        self.kind = operation.kind
        self.capabilityID = capability?.id ?? "proposal.\(operation.kind.rawValue)"
        self.capabilityTitle = capability?.title ?? operation.kind.rawValue
        self.externalAction = capability?.externalAction ?? operation.kind.externalAction
        self.requiresTarget = capability?.requiresTarget ?? (operation.target != nil)
        self.supportedTargetKinds = capability?.supportedTargetKinds ?? []
        self.requiredPayloadFields = capability?.requiredPayloadFields ?? []
        self.allowedPayloadFields = capability?.allowedPayloadFields ?? []
        self.payloadFieldSchemas = capability?.payloadFieldSchemas ?? []
        self.policyActor = proposedBy
        self.policyDecision = policy?.decision ?? WorkbenchExternalActionPolicy.decision(for: operation.kind.externalAction, actor: proposedBy)
        self.requiresUserMediation = policy?.requiresUserMediation ?? WorkbenchExternalActionPolicy.requiresUserMediation(
            operation.kind.externalAction,
            actor: proposedBy
        )
        self.riskTier = policy?.riskTier ?? operation.kind.riskTier(for: proposedBy)
        self.targetReference = targetReference
        self.targetSummary = targetReference?.displayText ?? "No target"
        let affectedCount = operation.affectedObjects.count
        self.affectedObjectCountText = "\(affectedCount) affected object\(affectedCount == 1 ? "" : "s")"
    }

    var capabilityText: String {
        "Capability: \(capabilityID) - \(capabilityTitle)"
    }

    var targetRequirementText: String {
        if requiresTarget {
            let kinds = supportedTargetKinds.map(\.rawValue).joined(separator: ", ")
            return "Target required: \(kinds.isEmpty ? "none" : kinds)"
        }
        return "Target not required"
    }

    var requiredPayloadFieldsText: String {
        if requiredPayloadFields.isEmpty {
            return "Required proposal JSON fields: none"
        }
        return "Required proposal JSON fields: \(requiredPayloadFields.map(\.rawValue).joined(separator: ", "))"
    }

    var allowedPayloadFieldsText: String {
        if allowedPayloadFields.isEmpty {
            return "Accepted proposal JSON fields: none"
        }
        return "Accepted proposal JSON fields: \(allowedPayloadFields.map(\.rawValue).joined(separator: ", "))"
    }

    var payloadFieldSchemasText: String {
        if payloadFieldSchemas.isEmpty {
            return "Proposal JSON schema: no fields"
        }
        let schemaText = payloadFieldSchemas
            .map { schema in
                let requiredText = schema.required ? "required" : "optional"
                return "\(schema.field.rawValue) (\(schema.valueShape.rawValue), \(requiredText))"
            }
            .joined(separator: ", ")
        return "Proposal JSON schema: \(schemaText)"
    }

    var payloadFieldSchemaBoundaryText: String {
        "Proposal JSON schema is for review only. It does not authorize or execute this operation."
    }

    var actorPolicyText: String {
        let mediationText = requiresUserMediation ? "user mediation required" : "no user mediation"
        return "Policy for \(policyActor.rawValue): \(policyDecision.rawValue), \(riskTier.rawValue) risk, \(mediationText)"
    }

    var displayText: String {
        [
            title,
            capabilityText,
            kind.rawValue,
            riskTier.label,
            targetRequirementText,
            targetSummary,
            requiredPayloadFieldsText,
            allowedPayloadFieldsText,
            payloadFieldSchemasText,
            payloadFieldSchemaBoundaryText,
            actorPolicyText,
            affectedObjectCountText
        ].joined(separator: " - ")
    }
}

struct ProposalReviewAction: Identifiable, Equatable {
    let event: MindDeskProposalReviewEvent
    let label: String
    let role: ButtonRole?

    var id: String { event.rawValue }
}

struct ProposalReviewBlockedPresentationModel: Identifiable {
    let id: String
    let title = "Proposal Import Blocked"
    let diagnosticScopeText = "Diagnostics only. Shows validation code, source, severity, safe location, static message, and safe token details; no proposal action has run."
    let summaryText: String
    let issues: [ProposalReviewBlockedIssueRow]
    let remainingIssueCount: Int
    let availableActions: [ProposalReviewAction] = []

    init(report: MindDeskValidationReport, maximumIssues: Int = 5) {
        let issueCount = report.issues.count
        self.id = "\(report.generatedAt.timeIntervalSince1970)-\(issueCount)"
        self.summaryText = "\(issueCount) validation \(issueCount == 1 ? "issue" : "issues") blocked review."
        self.issues = report.issues
            .prefix(maximumIssues)
            .map(ProposalReviewBlockedIssueRow.init)
        self.remainingIssueCount = max(0, issueCount - min(issueCount, maximumIssues))
    }

    var visibleTextForTesting: String {
        let issueText = issues
            .map { issue in
                [
                    issue.code,
                    issue.message,
                    issue.location,
                    issue.sourceText,
                    issue.severityText,
                    issue.details.map(\.displayText).joined(separator: " ")
                ].joined(separator: " ")
            }
            .joined(separator: " ")
        return "\(title) \(diagnosticScopeText) \(summaryText) \(issueText) \(remainingIssueCount)"
    }
}

struct ProposalReviewBlockedIssueRow: Identifiable, Equatable {
    let id: String
    let code: String
    let source: MindDeskValidationReportSource
    let sourceText: String
    let message: String
    let severity: MindDeskValidationSeverity
    let severityText: String
    let location: String
    let details: [ProposalReviewBlockedIssueDetailRow]

    init(issue: MindDeskValidationReportIssue) {
        let safeLocation = ProposalReviewSafeDisplayText.safeIssueLocation(
            path: issue.path,
            field: issue.field,
            ownerKind: issue.ownerKind,
            source: issue.source
        )
        self.id = "\(issue.source.rawValue)-\(issue.code)-\(safeLocation)"
        self.code = issue.code
        self.source = issue.source
        self.sourceText = "Source: \(issue.source.rawValue)"
        self.message = ProposalReviewSafeDisplayText.safeDiagnosticMessage(issue.message)
        self.severity = issue.severity
        self.severityText = "Severity: \(issue.severity.rawValue)"
        self.location = safeLocation
        self.details = issue.details
            .compactMap(ProposalReviewBlockedIssueDetailRow.init)
            .sorted { lhs, rhs in
                lhs.key < rhs.key
            }
    }
}

struct ProposalReviewBlockedIssueDetailRow: Identifiable, Equatable {
    let key: String
    let value: String

    init?(key: String, value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isDisplaySafeKey(key),
              Self.isDisplaySafeValue(trimmedValue, for: key) else {
            return nil
        }
        self.key = key
        self.value = trimmedValue
    }

    var id: String {
        key
    }

    var displayText: String {
        "\(key): \(value)"
    }

    private static func isDisplaySafeKey(_ key: String) -> Bool {
        allowedKeys.contains(key) ||
            key.hasSuffix("Token") ||
            key.hasSuffix("Length") ||
            key.hasSuffix("Count") ||
            key.hasSuffix("Index")
    }

    private static func isDisplaySafeValue(_ value: String, for key: String) -> Bool {
        guard !value.isEmpty,
              value.count <= 256,
              !ProposalReviewSafeDisplayText.containsUnsafeText(value) else {
            return false
        }
        if key.hasSuffix("Token") {
            return isOpaqueToken(value)
        }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.,: -")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func isOpaqueToken(_ value: String) -> Bool {
        value.range(
            of: #"^sha256:[0-9a-f]{16}$"#,
            options: .regularExpression
        ) != nil
    }

    private static let allowedKeys: Set<String> = [
        "actualLength",
        "actualNumber",
        "actualTargetType",
        "actualValueKind",
        "actualVersion",
        "allowedObjectTypes",
        "allowedSchemes",
        "allowedSourceObjectTypes",
        "allowedValues",
        "bindingField",
        "count",
        "expected",
        "expectedTargetType",
        "fallbackSource",
        "kind",
        "maximum",
        "minimum",
        "mismatchedFields",
        "nodeType",
        "normalizedReferenceIDLength",
        "objectType",
        "objectTypeStatus",
        "operationKind",
        "payloadField",
        "reason",
        "referenceKind",
        "referencedOwnerKind",
        "sourceField",
        "sourceObjectType",
        "supportedVersions",
        "targetKind",
        "unexpectedBindingFieldsCount",
        "unexpectedBindingFieldsLength"
    ]
}

struct ProposalReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var presentation: ProposalReviewPresentationModel
    let onPresentationChange: (ProposalReviewPresentationModel) -> Void

    init(
        presentation: ProposalReviewPresentationModel,
        onPresentationChange: @escaping (ProposalReviewPresentationModel) -> Void = { _ in }
    ) {
        _presentation = State(initialValue: presentation)
        self.onPresentationChange = onPresentationChange
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Summary") {
                    LabeledContent("Envelope", value: presentation.envelopeID)
                    LabeledContent("Proposals", value: presentation.proposalCountText)
                    LabeledContent("Operations", value: presentation.operationCountText)
                    LabeledContent("State", value: presentation.stateLabel)
                    Text(verbatim: presentation.readOnlyNoticeText)
                        .foregroundStyle(.secondary)
                    Text(verbatim: presentation.contextSummaryText)
                        .foregroundStyle(.secondary)
                    Text(verbatim: presentation.validationSummaryText)
                        .foregroundStyle(.secondary)
                    Text(verbatim: presentation.riskSummaryText)
                        .foregroundStyle(.secondary)
                }

                Section("Proposals") {
                    ForEach(presentation.proposals) { proposal in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: proposal.title)
                                .font(.headline)
                            Text(verbatim: proposal.rationale)
                                .foregroundStyle(.secondary)
                            Text(verbatim: proposal.evidenceCountText)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            ForEach(proposal.evidenceReferences) { evidenceReference in
                                Text(verbatim: evidenceReference.displayText)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Proposed Operations") {
                    ForEach(presentation.operationRows) { operation in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: operation.title)
                                .font(.headline)
                            Text(verbatim: "\(operation.kind.rawValue) - \(operation.riskTier.label)")
                                .foregroundStyle(operation.riskTier.foregroundStyle)
                            Text(verbatim: "\(operation.targetSummary) - \(operation.affectedObjectCountText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(verbatim: operation.capabilityText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(verbatim: operation.targetRequirementText)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(verbatim: operation.requiredPayloadFieldsText)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(verbatim: operation.allowedPayloadFieldsText)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(verbatim: operation.payloadFieldSchemasText)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(verbatim: operation.payloadFieldSchemaBoundaryText)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(verbatim: operation.actorPolicyText)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: presentation.reviewActionBoundaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    Spacer()
                    ForEach(presentation.availableActions) { action in
                        Button(action.label, role: action.role) {
                            if presentation.apply(action.event) {
                                onPresentationChange(presentation)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 620, minHeight: 560)
    }
}

struct ProposalReviewBlockedSheet: View {
    @Environment(\.dismiss) private var dismiss
    let presentation: ProposalReviewBlockedPresentationModel

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Summary") {
                    Text(verbatim: presentation.diagnosticScopeText)
                        .foregroundStyle(.secondary)
                    Text(verbatim: presentation.summaryText)
                        .foregroundStyle(.secondary)
                }

                Section("Validation Issues") {
                    ForEach(presentation.issues) { issue in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: issue.message)
                                .font(.headline)
                            Text(verbatim: "\(issue.code) at \(issue.location)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(verbatim: "\(issue.sourceText) - \(issue.severityText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(issue.details) { detail in
                                Text(verbatim: detail.displayText)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if presentation.remainingIssueCount > 0 {
                        Text(verbatim: "\(presentation.remainingIssueCount) more issue\(presentation.remainingIssueCount == 1 ? "" : "s").")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}

struct ProposalReviewSheetRoot: View {
    let state: ProposalReviewSheetState
    var onReadyPresentationChange: (ProposalReviewPresentationModel) -> Void = { _ in }

    var body: some View {
        switch state {
        case .ready(let presentation):
            ProposalReviewSheet(
                presentation: presentation,
                onPresentationChange: onReadyPresentationChange
            )
        case .blocked(let presentation):
            ProposalReviewBlockedSheet(presentation: presentation)
        }
    }
}

private extension MindDeskProposalOperationRiskTier {
    var label: String {
        switch self {
        case .readOnly:
            return "Read-only"
        case .userMediated:
            return "User-mediated"
        case .confirmationRequired:
            return "Confirmation required"
        case .denied:
            return "Denied"
        }
    }

    var foregroundStyle: HierarchicalShapeStyle {
        switch self {
        case .readOnly:
            return .secondary
        case .userMediated:
            return .primary
        case .confirmationRequired:
            return .primary
        case .denied:
            return .tertiary
        }
    }
}
