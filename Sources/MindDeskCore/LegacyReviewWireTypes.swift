import Foundation

public enum MindDeskProposalReviewState: String, Codable, CaseIterable, Sendable {
    case pendingReview
    case approved
    case rejected
    case applied
    case expired
    case superseded

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported proposal review state."
            )
        }
        self = value
    }
}

public enum MindDeskProposalReviewEvent: String, Codable, CaseIterable, Sendable {
    case approve
    case reject
    case markApplied
    case expire
    case supersede

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported proposal review event."
            )
        }
        self = value
    }
}
