import Foundation

public struct CanvasNodeColorStyle: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let opacity: Double

    public var normalizedRawValue: String {
        "#\(Self.hexByte(red))\(Self.hexByte(green))\(Self.hexByte(blue))\(Self.hexByte(opacity))"
    }

    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = Self.clamped(red)
        self.green = Self.clamped(green)
        self.blue = Self.clamped(blue)
        self.opacity = Self.clamped(opacity)
    }

    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let expanded: String
        switch hex.count {
        case 3:
            expanded = hex.map { "\($0)\($0)" }.joined() + "FF"
        case 6:
            expanded = hex + "FF"
        case 8:
            expanded = hex
        default:
            return nil
        }

        guard let value = UInt32(expanded, radix: 16) else { return nil }
        self.red = Double((value >> 24) & 0xFF) / 255
        self.green = Double((value >> 16) & 0xFF) / 255
        self.blue = Double((value >> 8) & 0xFF) / 255
        self.opacity = Double(value & 0xFF) / 255
    }

    public func withOpacity(_ opacity: Double) -> CanvasNodeColorStyle {
        CanvasNodeColorStyle(red: red, green: green, blue: blue, opacity: opacity)
    }

    private static func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func hexByte(_ value: Double) -> String {
        String(format: "%02X", Int((clamped(value) * 255).rounded()))
    }
}

public struct CanvasNodeColorPreset: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let style: CanvasNodeColorStyle

    public init(id: String, title: String, style: CanvasNodeColorStyle) {
        self.id = id
        self.title = title
        self.style = style
    }

    public static let common: [CanvasNodeColorPreset] = [
        CanvasNodeColorPreset(id: "sky", title: "Sky", style: CanvasNodeColorStyle(red: 0.22, green: 0.74, blue: 0.97, opacity: 0.82)),
        CanvasNodeColorPreset(id: "mint", title: "Mint", style: CanvasNodeColorStyle(red: 0.20, green: 0.83, blue: 0.60, opacity: 0.82)),
        CanvasNodeColorPreset(id: "amber", title: "Amber", style: CanvasNodeColorStyle(red: 0.96, green: 0.62, blue: 0.04, opacity: 0.82)),
        CanvasNodeColorPreset(id: "rose", title: "Rose", style: CanvasNodeColorStyle(red: 0.96, green: 0.33, blue: 0.47, opacity: 0.82)),
        CanvasNodeColorPreset(id: "violet", title: "Violet", style: CanvasNodeColorStyle(red: 0.55, green: 0.36, blue: 0.96, opacity: 0.82)),
        CanvasNodeColorPreset(id: "slate", title: "Slate", style: CanvasNodeColorStyle(red: 0.39, green: 0.45, blue: 0.55, opacity: 0.72))
    ]
}
