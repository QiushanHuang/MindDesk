import Foundation

enum OrganizationIntent: String, Codable, CaseIterable, Sendable {
    case summarize, classify, extractTasks, arrange
}

struct OrganizationCard: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var body: String
    var kind: String
}

struct OrganizationRequest: Codable, Equatable, Sendable {
    var workspaceID: String
    var canvasID: String
    var intent: OrganizationIntent
    var cards: [OrganizationCard]

    func validate() throws {
        guard !cards.isEmpty, cards.count <= 100, Set(cards.map(\.id)).count == cards.count else {
            throw OrganizationError.invalidInput("Choose between 1 and 100 distinct cards.")
        }
        try checkedText(workspaceID, maximum: 200)
        try checkedText(canvasID, maximum: 200)
        for card in cards {
            try checkedText(card.id, maximum: 200)
            try checkedText(card.title, maximum: 500, allowEmpty: true)
            try checkedText(card.body, maximum: 20_000, allowEmpty: true)
            try checkedText(card.kind, maximum: 100)
        }
        guard try JSONEncoder().encode(self).count <= 256_000 else {
            throw OrganizationError.invalidInput("Selected card content exceeds 256 KB. Choose fewer cards.")
        }
    }
}

struct OrganizationGroup: Codable, Equatable, Sendable {
    var name: String
    var cardIDs: [String]
}

struct OrganizationTask: Codable, Equatable, Sendable {
    var title: String
    var details: String
    var sourceCardIDs: [String]
}

struct OrganizationProposal: Codable, Equatable, Sendable {
    var summary: String
    var groups: [OrganizationGroup]
    var tasks: [OrganizationTask]

    func validate(for request: OrganizationRequest) throws {
        try request.validate()
        try checkedText(summary, maximum: 12_000, allowEmpty: request.intent != .summarize)
        guard groups.count <= request.cards.count, tasks.count <= 50 else { throw OrganizationError.invalidProposal }
        switch request.intent {
        case .summarize: guard groups.isEmpty, tasks.isEmpty else { throw OrganizationError.invalidProposal }
        case .classify, .arrange: guard summary.isEmpty, tasks.isEmpty, !groups.isEmpty else { throw OrganizationError.invalidProposal }
        case .extractTasks: guard summary.isEmpty, groups.isEmpty else { throw OrganizationError.invalidProposal }
        }
        let ids = Set(request.cards.map(\.id))
        var placed = Set<String>()
        for group in groups {
            try checkedText(group.name, maximum: 200)
            guard !group.cardIDs.isEmpty, group.cardIDs.count <= ids.count else { throw OrganizationError.invalidProposal }
            for id in group.cardIDs {
                guard ids.contains(id), placed.insert(id).inserted else { throw OrganizationError.invalidProposal }
            }
        }
        for task in tasks {
            try checkedText(task.title, maximum: 500)
            try checkedText(task.details, maximum: 4_000, allowEmpty: true)
            guard !task.sourceCardIDs.isEmpty, Set(task.sourceCardIDs).count == task.sourceCardIDs.count,
                  Set(task.sourceCardIDs).isSubset(of: ids) else { throw OrganizationError.invalidProposal }
        }
    }

    // All properties are required; unused intent outputs must be empty.
    static let jsonSchema = #"{"type":"object","additionalProperties":false,"required":["summary","groups","tasks"],"properties":{"summary":{"type":"string"},"groups":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["name","cardIDs"],"properties":{"name":{"type":"string"},"cardIDs":{"type":"array","items":{"type":"string"}}}}},"tasks":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["title","details","sourceCardIDs"],"properties":{"title":{"type":"string"},"details":{"type":"string"},"sourceCardIDs":{"type":"array","items":{"type":"string"}}}}}}}"#
}

enum OrganizationError: LocalizedError {
    case invalidInput(String), invalidProposal, executableMissing, failed(Int32), timedOut, outputTooLarge
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message): return message
        case .invalidProposal: return "Codex returned an invalid organization preview. No cards were changed."
        case .executableMissing: return "Local Codex was not found. Install Codex CLI and sign in before generating a preview."
        case .failed(127): return "Local Codex could not start because a required runtime (such as Node.js) was not found. Check the Codex CLI installation. No cards were changed."
        case .failed(let status): return "Local Codex exited with status \(status). Check the Codex CLI connection and sign-in status. No cards were changed."
        case .timedOut: return "Codex took too long. Try fewer cards. No cards were changed."
        case .outputTooLarge: return "Codex output exceeded the safety limit. No cards were changed."
        }
    }
}

private func checkedText(_ value: String, maximum: Int, allowEmpty: Bool = false) throws {
    guard value.utf8.count <= maximum, allowEmpty || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw OrganizationError.invalidInput("Card or preview text is blank or exceeds its size limit.")
    }
}
