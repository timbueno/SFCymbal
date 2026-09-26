import CoreGraphics
import Foundation

struct SymbolSettings: Codable, Equatable, Sendable {
    var automaticAlignment = true
    var bottom = 0.0
    var generateWeights = false
    var left = 0.0
    var maximumStroke = 2.0
    var minimumStroke = 0.5
    var right = 0.0
    var size = SymbolSize.small
    var top = 0.0

    func validationMessage(for size: CGSize) -> String? {
        guard [left, right, top, bottom].allSatisfy(\.isFinite),
              left + right < size.width, top + bottom < size.height else {
            return "Alignment guides must leave a positive width and height."
        }
        guard !generateWeights || (minimumStroke.isFinite && maximumStroke.isFinite &&
              minimumStroke > 0 && minimumStroke <= 1 && maximumStroke >= 1 && maximumStroke <= 5) else {
            return "Stroke multipliers must be greater than 0 and at most 1 for Ultralight, and 1–5 for Black."
        }
        return nil
    }

    mutating func resetAlignment() {
        bottom = 0
        left = 0
        right = 0
        top = 0
    }

    mutating func resetSymbolSettings() {
        let defaults = Self()
        generateWeights = defaults.generateWeights
        maximumStroke = defaults.maximumStroke
        minimumStroke = defaults.minimumStroke
        size = defaults.size
    }

    enum SymbolSize: String, Codable, CaseIterable, Sendable {
        case small = "S", medium = "M", large = "L"
        var title: String {
            switch self { case .small: "Small"; case .medium: "Medium"; case .large: "Large" }
        }
    }
}
