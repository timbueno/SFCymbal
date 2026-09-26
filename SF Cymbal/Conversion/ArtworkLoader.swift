import CoreGraphics
import Foundation
import SwiftDraw

/// Parses the source once. A bounded alpha scan measures visible artwork for automatic guides.
/// Editing alignment never invokes this loader or the SF Symbols exporter.
enum ArtworkLoader {
    static func load(_ data: Data) throws -> ImportedArtwork {
        guard let svg = SVG(data: data), svg.size.width.isFinite, svg.size.height.isFinite,
              svg.size.width > 0, svg.size.height > 0 else {
            throw SymbolConverter.ConversionError("This file is not a readable SVG with a valid canvas.")
        }
        let scale = 1024 / max(svg.size.width, svg.size.height)
        let width = max(1, Int(ceil(svg.size.width * scale)))
        let height = max(1, Int(ceil(svg.size.height * scale)))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else {
            throw SymbolConverter.ConversionError("Could not prepare the SVG preview.")
        }
        context.scaleBy(x: scale, y: scale)
        context.draw(svg)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where bytes[y * context.bytesPerRow + x * 4 + 3] > 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else {
            throw SymbolConverter.ConversionError("The SVG contains no visible artwork.")
        }
        return ImportedArtwork(svg: svg, opticalBounds: CGRect(
            x: Double(minX) / scale, y: svg.size.height - Double(maxY + 1) / scale,
            width: Double(maxX - minX + 1) / scale, height: Double(maxY - minY + 1) / scale
        ))
    }
}
