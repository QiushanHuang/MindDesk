import Foundation

public enum CanvasReviewCapabilityError: Error, Equatable, Sendable, LocalizedError {
    case unavailable

    public var errorDescription: String? {
        "Canvas Review is unavailable in this version of MindDesk."
    }
}

public enum CanvasReviewCapabilityLock {
    public static func requireEnabled() throws -> Never {
        throw CanvasReviewCapabilityError.unavailable
    }
}
