import Foundation

struct OrganizationWorkflow: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var intent: OrganizationIntent
    var scope: OrganizationContextScope
    var instructions: String
}

enum OrganizationWorkflowLibrary {
    static let storageKey = "organizationSavedWorkflows"
    static let maximumCount = 24
    static let maximumBytes = 128_000

    static func validate(_ workflows: [OrganizationWorkflow]) throws {
        guard workflows.count <= maximumCount, Set(workflows.map(\.id)).count == workflows.count,
              workflows.allSatisfy({ !$0.id.isEmpty && $0.id.utf8.count <= 100
                  && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && $0.title.utf8.count <= 200 && $0.instructions.utf8.count <= 4_000 }),
              try JSONEncoder().encode(workflows).count <= maximumBytes else {
            throw OrganizationError.invalidInput("Use workflow names within 200 bytes, instructions within 4,000 bytes, and at most 24 workflows (128 KB total).")
        }
    }

    static func encode(_ workflows: [OrganizationWorkflow]) throws -> String {
        try validate(workflows)
        return String(decoding: try JSONEncoder().encode(workflows), as: UTF8.self)
    }

    static func decode(_ value: String) throws -> [OrganizationWorkflow] {
        guard !value.isEmpty else { return [] }
        guard value.utf8.count <= maximumBytes else { throw OrganizationError.invalidInput("The saved workflow library exceeds 128 KB.") }
        let workflows = try JSONDecoder().decode([OrganizationWorkflow].self, from: Data(value.utf8))
        try validate(workflows)
        return workflows
    }
}

struct OrganizationRequestInspection {
    let request: OrganizationRequest
    let title: String

    static func resolve(current: OrganizationRequest, generated: OrganizationRequest?, inFlight: OrganizationRequest?, revision: OrganizationRequest?) -> Self {
        if let inFlight { return .init(request: inFlight, title: "Request being generated") }
        if let revision { return .init(request: revision, title: "Next revision request") }
        if let generated { return .init(request: generated, title: "Request used for this preview") }
        return .init(request: current, title: "Request to be sent")
    }
}
