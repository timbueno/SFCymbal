import CoreGraphics
import Foundation
import SwiftDraw

struct ImportedArtwork: Equatable, Sendable {
    var svg: SVG
    var opticalBounds: CGRect

    var size: CGSize { svg.size }

    func alignmentSettings(_ settings: SymbolSettings) -> SymbolSettings {
        // Editor values are offsets from visible artwork, not the SVG canvas.
        // Resolve to canvas insets only for layout and SwiftDraw export.
        var result = settings
        if settings.automaticAlignment { result.resetAlignment() }
        result.automaticAlignment = false
        result.left += opticalBounds.minX
        result.right += size.width - opticalBounds.maxX
        result.top += opticalBounds.minY
        result.bottom += size.height - opticalBounds.maxY
        return result
    }
}
