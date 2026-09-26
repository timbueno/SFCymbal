import Foundation

enum AlignmentGuide: String, CaseIterable, Sendable {
    case left, right, top, bottom

    var isVertical: Bool { self == .left || self == .right }
    var title: String {
        switch self {
        case .left: "Left margin"
        case .right: "Right margin"
        case .top: "Cap height"
        case .bottom: "Baseline"
        }
    }

    func offset(from initial: SymbolSettings, to current: SymbolSettings) -> Double {
        switch self {
        case .left: current.left - initial.left
        case .right: initial.right - current.right
        case .top: current.top - initial.top
        case .bottom: initial.bottom - current.bottom
        }
    }

    func moving(_ settings: SymbolSettings, by delta: Double, sourceSize: CGSize, snapDistance: Double = 0) -> SymbolSettings {
        var result = settings
        // The view supplies an eight-point screen-space radius converted to source units.
        // Only dragging snaps; typed values and accessibility nudges remain exact.
        func snapped(_ value: Double) -> Double {
            snapDistance.isFinite && snapDistance > 0 && abs(value) <= snapDistance ? 0 : value
        }
        // Keep the alignment rectangle positive even when dragging across its opposite edge.
        let gap = max(0.001, min(sourceSize.width, sourceSize.height) * 0.001)
        switch self {
        case .left: result.left = min(snapped(settings.left + delta), sourceSize.width - settings.right - gap)
        case .right: result.right = min(snapped(settings.right - delta), sourceSize.width - settings.left - gap)
        case .top: result.top = min(snapped(settings.top + delta), sourceSize.height - settings.bottom - gap)
        case .bottom: result.bottom = min(snapped(settings.bottom - delta), sourceSize.height - settings.top - gap)
        }
        return result
    }
}
