import Foundation

public enum MindDeskAgentReviewCustomGuidancePresentationStatusKind: Equatable, Sendable {
    case empty
    case included
    case atLimit
}

public struct MindDeskAgentReviewCustomGuidancePresentation: Equatable, Sendable {
    public let title: String
    public let placeholder: String
    public let settingsDescription: String
    public let privacyDescription: String
    public let clearButtonTitle: String
    public let statusTitle: String
    public let statusKind: MindDeskAgentReviewCustomGuidancePresentationStatusKind
    public let statusValue: String
    public let statusDescription: String
    public let characterBudgetText: String
    public let characterCount: Int
    public let originalCharacterCount: Int
    public let characterLimit: Int
    public let remainingCharacterCount: Int
    public let storedValue: String
    public let isIncluded: Bool
    public let isClearEnabled: Bool
    public let wasTruncated: Bool

    public var visibleText: String {
        [
            title,
            clearButtonTitle,
            statusTitle,
            statusValue,
            statusDescription,
            characterBudgetText
        ].joined(separator: " ")
    }
}

public enum MindDeskAgentReviewCustomGuidancePresentationPolicy {
    public static func presentation(
        for guidance: String
    ) -> MindDeskAgentReviewCustomGuidancePresentation {
        let trimmed = guidance.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedValue = MindDeskAgentReviewCustomGuidancePolicy.boundedForStorage(guidance)
        let characterLimit = MindDeskAgentReviewCustomGuidancePolicy.characterLimit
        let characterCount = storedValue.count
        let originalCharacterCount = trimmed.count
        let remainingCharacterCount = max(0, characterLimit - characterCount)
        let wasTruncated = originalCharacterCount > characterCount
        let isIncluded = !storedValue.isEmpty
        let statusKind: MindDeskAgentReviewCustomGuidancePresentationStatusKind

        if !isIncluded {
            statusKind = .empty
        } else if characterCount >= characterLimit {
            statusKind = .atLimit
        } else {
            statusKind = .included
        }

        let characterBudgetText = "\(formattedCount(characterCount)) of \(formattedCount(characterLimit)) characters used"
        let statusValue: String
        let statusDescription: String

        switch statusKind {
        case .empty:
            statusValue = "Not included"
            statusDescription = "No custom guidance will be added to the next Agent Review .mip.json. \(characterBudgetText)."
        case .included:
            statusValue = "Included"
            statusDescription = includedStatusDescription(
                characterBudgetText: characterBudgetText,
                wasTruncated: wasTruncated
            )
        case .atLimit:
            statusValue = "Bounded to \(formattedCount(characterLimit)) characters"
            statusDescription = includedStatusDescription(
                characterBudgetText: characterBudgetText,
                wasTruncated: wasTruncated
            )
        }

        return MindDeskAgentReviewCustomGuidancePresentation(
            title: MindDeskAgentReviewCustomGuidancePolicy.title,
            placeholder: MindDeskAgentReviewCustomGuidancePolicy.placeholder,
            settingsDescription: MindDeskAgentReviewCustomGuidancePolicy.settingsDescription,
            privacyDescription: MindDeskAgentReviewCustomGuidancePolicy.privacyDescription,
            clearButtonTitle: "Clear",
            statusTitle: "Next Agent Review export",
            statusKind: statusKind,
            statusValue: statusValue,
            statusDescription: statusDescription,
            characterBudgetText: characterBudgetText,
            characterCount: characterCount,
            originalCharacterCount: originalCharacterCount,
            characterLimit: characterLimit,
            remainingCharacterCount: remainingCharacterCount,
            storedValue: storedValue,
            isIncluded: isIncluded,
            isClearEnabled: isIncluded,
            wasTruncated: wasTruncated
        )
    }

    private static func includedStatusDescription(
        characterBudgetText: String,
        wasTruncated: Bool
    ) -> String {
        var description = "Custom guidance will be included in the next Agent Review .mip.json as plain text, untrusted, non-authoritative guidance. \(characterBudgetText)."
        if wasTruncated {
            description += " Extra text was truncated before export."
        }
        return description
    }

    private static func formattedCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSize = 3
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
