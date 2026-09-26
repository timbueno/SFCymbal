import CoreGraphics
import Foundation

/// Maps source SVG units into the 180 × 140 exported preview viewport.
struct AlignmentGeometry: Equatable, Sendable {
    var sourceSize: CGSize
    var sourceBounds: CGRect
    var previewBounds: CGRect
    var previewScale: Double

    func manualSettings(from settings: SymbolSettings) -> SymbolSettings {
        var result = settings
        result.automaticAlignment = false
        result.left = sourceBounds.minX
        result.right = sourceSize.width - sourceBounds.maxX
        result.top = sourceBounds.minY
        result.bottom = sourceSize.height - sourceBounds.maxY
        return result
    }
}
