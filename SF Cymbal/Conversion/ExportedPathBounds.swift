import CoreGraphics
import Foundation

/// SwiftDraw's SF Symbols renderer emits absolute M, L, C, and Z commands only.
/// Reading those outlines avoids approximating optical bounds from rasterized pixels.
enum ExportedPathBounds {
    static func bounds(of group: XMLElement) throws -> CGRect {
        let tokens = try NSRegularExpression(pattern: "[MLCZ]|[-+]?(?:[0-9]*\\.[0-9]+|[0-9]+\\.?[0-9]*)(?:[eE][-+]?[0-9]+)?")
        let combined = CGMutablePath()
        for node in try group.nodes(forXPath: ".//*[local-name()='path']") {
            guard let data = (node as? XMLElement)?.attribute(forName: "d")?.stringValue else { continue }
            let values = tokens.matches(in: data, range: NSRange(data.startIndex..., in: data)).compactMap {
                Range($0.range, in: data).map { String(data[$0]) }
            }
            var index = 0
            var command = ""
            func number() throws -> Double {
                guard index < values.count, let number = Double(values[index]), number.isFinite else {
                    throw SymbolConverter.ConversionError("Could not read exported alignment geometry.")
                }
                index += 1
                return number
            }
            func point() throws -> CGPoint { CGPoint(x: try number(), y: try number()) }
            while index < values.count {
                if ["M", "L", "C", "Z"].contains(values[index]) {
                    command = values[index]
                    index += 1
                }
                switch command {
                case "M": combined.move(to: try point()); command = "L"
                case "L": combined.addLine(to: try point())
                case "C":
                    let first = try point()
                    let second = try point()
                    combined.addCurve(to: try point(), control1: first, control2: second)
                case "Z": combined.closeSubpath(); command = ""
                default: throw SymbolConverter.ConversionError("Unexpected exported path command.")
                }
            }
        }
        guard !combined.isEmpty else { throw SymbolConverter.ConversionError("No exported outlines found.") }
        return combined.boundingBoxOfPath
    }
}
