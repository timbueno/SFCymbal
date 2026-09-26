import CoreGraphics
import Foundation

/// Versioned, persistent editor state. Cached previews and transient UI state are excluded.
struct ProjectManifest: Codable, Equatable, Sendable {
    var formatVersion = 1
    var name: String
    var settings: SymbolSettings
    var referenceKind: ReferenceKind
    var referenceSymbol: String
    var previewWeight: String
    var showGuides: Bool
    var snapToEdges: Bool
    var zoom: Double
    var canvasOffset: CGSize
    var fitOffset: CGSize
    var isFitZoom: Bool

    func validate() throws {
        guard formatVersion == 1 else {
            throw SymbolConverter.ConversionError("This project uses format version \(formatVersion). This version of SF Cymbal supports version 1.")
        }
        let values = [settings.left, settings.right, settings.top, settings.bottom,
                      settings.minimumStroke, settings.maximumStroke, zoom,
                      canvasOffset.width, canvasOffset.height, fitOffset.width, fitOffset.height]
        guard values.allSatisfy(\.isFinite), zoom > 0,
              ["Ultralight", "Regular", "Black"].contains(previewWeight),
              !name.isEmpty, !referenceSymbol.isEmpty, [.small, .medium].contains(settings.size) else {
            throw SymbolConverter.ConversionError("This project contains invalid settings.")
        }
    }
}
