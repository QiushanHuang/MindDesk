import Foundation

public enum MindDeskProposalSourcePackageRawValidation {
    public static func issues(
        in data: Data,
        package: MindDeskInterchangePackage
    ) -> [MindDeskValidationReportIssue] {
        rawAgentIntegrationContractIssues(in: data, package: package) +
            rawTopLevelPolicyIssues(in: data) +
            rawValidationReportIssues(in: data, package: package) +
            rawExtensionCapabilityIssues(in: data)
    }

    private static func rawAgentIntegrationContractIssues(
        in data: Data,
        package: MindDeskInterchangePackage
    ) -> [MindDeskValidationReportIssue] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        guard let rawContractObject = object["agentIntegrationContract"] else {
            return [rawAgentIntegrationContractMissingIssue()]
        }
        let rawContractShapeIssues = rawAgentIntegrationContractShapeIssues(in: rawContractObject)
        guard JSONSerialization.isValidJSONObject(rawContractObject),
              let rawContractData = try? JSONSerialization.data(withJSONObject: rawContractObject) else {
            return rawContractShapeIssues + [rawAgentIntegrationContractDecodeIssue()]
        }
        do {
            let rawContract = try JSONDecoder.minddesk.decode(
                MindDeskAgentIntegrationContract.self,
                from: rawContractData
            )
            return rawContractShapeIssues +
                MindDeskAgentIntegrationContractValidationReport.issues(in: rawContract, package: package)
        } catch {
            return rawContractShapeIssues + [rawAgentIntegrationContractDecodeIssue()]
        }
    }

    private static func rawAgentIntegrationContractShapeIssues(
        in rawContractObject: Any
    ) -> [MindDeskValidationReportIssue] {
        guard let rawContract = rawContractObject as? [String: Any],
              let rawReferenceSchemas = rawContract["referenceSchemas"] as? [String: Any] else {
            return [rawAgentIntegrationContractReferenceSchemasMismatchIssue()]
        }
        for requiredKey in ["citationWireShape", "proposalReferenceWireShape", "proposalReferenceFields"]
            where rawReferenceSchemas[requiredKey] == nil {
            return [rawAgentIntegrationContractReferenceSchemasMismatchIssue()]
        }
        return []
    }

    private static func rawAgentIntegrationContractReferenceSchemasMismatchIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .agentIntegrationContract,
            code: "contract.reference-schemas.mismatch",
            severity: .error,
            message: "Reference schemas have drifted from the expected agent reference model.",
            ownerKind: "agentIntegrationContract",
            field: "referenceSchemas",
            path: "/agentIntegrationContract/referenceSchemas"
        )
    }

    private static func rawAgentIntegrationContractMissingIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .agentIntegrationContract,
            code: "contract.raw.missing",
            severity: .error,
            message: "Agent integration contract is missing from the source package.",
            ownerKind: "agentIntegrationContract",
            field: "agentIntegrationContract",
            path: "/agentIntegrationContract"
        )
    }

    private static func rawAgentIntegrationContractDecodeIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .agentIntegrationContract,
            code: "contract.raw.invalid",
            severity: .error,
            message: "Agent integration contract JSON could not be decoded.",
            ownerKind: "agentIntegrationContract",
            field: "agentIntegrationContract",
            path: "/agentIntegrationContract"
        )
    }

    private static func rawTopLevelPolicyIssues(in data: Data) -> [MindDeskValidationReportIssue] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        var issues: [MindDeskValidationReportIssue] = []
        if let rawAgentPolicyObject = object["agentPolicy"] {
            guard JSONSerialization.isValidJSONObject(rawAgentPolicyObject),
                  let rawAgentPolicyData = try? JSONSerialization.data(withJSONObject: rawAgentPolicyObject) else {
                issues.append(rawTopLevelAgentPolicyDecodeIssue())
                return issues
            }
            do {
                let rawAgentPolicy = try JSONDecoder.minddesk.decode(MindDeskAgentPolicy.self, from: rawAgentPolicyData)
                if rawAgentPolicy != .defaultPolicy {
                    issues.append(rawTopLevelAgentPolicyMismatchIssue())
                }
            } catch {
                issues.append(rawTopLevelAgentPolicyDecodeIssue())
            }
        } else {
            issues.append(rawTopLevelAgentPolicyMissingIssue())
        }
        if let rawExternalActionPolicyObject = object["externalActionPolicy"] {
            guard JSONSerialization.isValidJSONObject(rawExternalActionPolicyObject),
                  let rawExternalActionPolicyData = try? JSONSerialization.data(
                    withJSONObject: rawExternalActionPolicyObject
                  ) else {
                issues.append(rawTopLevelExternalActionPolicyDecodeIssue())
                return issues
            }
            do {
                let rawExternalActionPolicy = try JSONDecoder.minddesk.decode(
                    MindDeskInterchangeExternalActionPolicy.self,
                    from: rawExternalActionPolicyData
                )
                if rawExternalActionPolicy != .current {
                    issues.append(rawTopLevelExternalActionPolicyMismatchIssue())
                }
            } catch {
                issues.append(rawTopLevelExternalActionPolicyDecodeIssue())
            }
        } else {
            issues.append(rawTopLevelExternalActionPolicyMissingIssue())
        }
        return issues
    }

    private static func rawTopLevelAgentPolicyMissingIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .package,
            code: "package.agent-policy.missing",
            severity: .error,
            message: "Top-level agent policy is missing from the source package.",
            ownerKind: "interchangePackage",
            field: "agentPolicy",
            path: "/agentPolicy"
        )
    }

    private static func rawTopLevelAgentPolicyMismatchIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .package,
            code: "package.agent-policy.mismatch",
            severity: .error,
            message: "Top-level agent policy has drifted from the expected package policy.",
            ownerKind: "interchangePackage",
            field: "agentPolicy",
            path: "/agentPolicy"
        )
    }

    private static func rawTopLevelAgentPolicyDecodeIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .package,
            code: "package.agent-policy.raw.invalid",
            severity: .error,
            message: "Top-level agent policy JSON could not be decoded.",
            ownerKind: "interchangePackage",
            field: "agentPolicy",
            path: "/agentPolicy"
        )
    }

    private static func rawTopLevelExternalActionPolicyMissingIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .package,
            code: "package.external-action-policy.missing",
            severity: .error,
            message: "Top-level external action policy is missing from the source package.",
            ownerKind: "interchangePackage",
            field: "externalActionPolicy",
            path: "/externalActionPolicy"
        )
    }

    private static func rawTopLevelExternalActionPolicyMismatchIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .package,
            code: "package.external-action-policy.mismatch",
            severity: .error,
            message: "Top-level external action policy has drifted from the expected package policy.",
            ownerKind: "interchangePackage",
            field: "externalActionPolicy",
            path: "/externalActionPolicy"
        )
    }

    private static func rawTopLevelExternalActionPolicyDecodeIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .package,
            code: "package.external-action-policy.raw.invalid",
            severity: .error,
            message: "Top-level external action policy JSON could not be decoded.",
            ownerKind: "interchangePackage",
            field: "externalActionPolicy",
            path: "/externalActionPolicy"
        )
    }

    private static func rawValidationReportIssues(
        in data: Data,
        package: MindDeskInterchangePackage
    ) -> [MindDeskValidationReportIssue] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        guard let rawValidationReportObject = object["validationReport"] else {
            return [rawValidationReportMissingIssue()]
        }
        guard let rawValidationReport = rawValidationReportObject as? [String: Any],
              JSONSerialization.isValidJSONObject(rawValidationReport),
              let expectedValidationReportData = try? JSONEncoder.minddesk.encode(package.validationReport),
              let expectedValidationReport = try? JSONSerialization.jsonObject(
                with: expectedValidationReportData
              ) as? [String: Any] else {
            return [rawValidationReportDecodeIssue()]
        }
        if !NSDictionary(dictionary: rawValidationReport).isEqual(to: expectedValidationReport) {
            return [rawValidationReportMismatchIssue()]
        }
        return []
    }

    private static func rawValidationReportMissingIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .package,
            code: "package.validation-report.missing",
            severity: .error,
            message: "Validation report is missing from the source package.",
            ownerKind: "interchangePackage",
            field: "validationReport",
            path: "/validationReport"
        )
    }

    private static func rawValidationReportMismatchIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .package,
            code: "package.validation-report.mismatch",
            severity: .error,
            message: "Validation report has drifted from the expected package diagnostics.",
            ownerKind: "interchangePackage",
            field: "validationReport",
            path: "/validationReport"
        )
    }

    private static func rawValidationReportDecodeIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .package,
            code: "package.validation-report.raw.invalid",
            severity: .error,
            message: "Validation report JSON could not be decoded.",
            ownerKind: "interchangePackage",
            field: "validationReport",
            path: "/validationReport"
        )
    }

    private static func rawExtensionCapabilityIssues(in data: Data) -> [MindDeskValidationReportIssue] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        guard let rawCatalogObject = object["extensionCapabilities"] else {
            return [rawExtensionCapabilityMissingIssue()]
        }
        guard JSONSerialization.isValidJSONObject(rawCatalogObject),
              let rawCatalogData = try? JSONSerialization.data(withJSONObject: rawCatalogObject) else {
            return [rawExtensionCapabilityDecodeIssue()]
        }
        do {
            let rawCatalog = try JSONDecoder.minddesk.decode(
                MindDeskExtensionCapabilityCatalog.self,
                from: rawCatalogData
            )
            return MindDeskExtensionCapabilityCatalogValidationReport.issues(in: rawCatalog)
        } catch {
            return [rawExtensionCapabilityDecodeIssue()]
        }
    }

    private static func rawExtensionCapabilityMissingIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .extensionCapabilityCatalog,
            code: "capability-catalog.raw.missing",
            severity: .error,
            message: "Extension capability catalog is missing from the source package.",
            ownerKind: "extensionCapabilityCatalog",
            field: "extensionCapabilities",
            path: "/extensionCapabilities"
        )
    }

    private static func rawExtensionCapabilityDecodeIssue() -> MindDeskValidationReportIssue {
        MindDeskValidationReportIssue(
            source: .extensionCapabilityCatalog,
            code: "capability-catalog.raw.invalid",
            severity: .error,
            message: "Extension capability catalog JSON could not be decoded.",
            ownerKind: "extensionCapabilityCatalog",
            field: "extensionCapabilities",
            path: "/extensionCapabilities"
        )
    }
}
