import CoreGraphics
import Foundation
import SwiftDraw

actor SymbolConverter {
    static let shared = SymbolConverter()

    func prepare(data: Data) throws -> ImportedArtwork { try ArtworkLoader.load(data) }

    func read(url: URL) throws -> Data {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: url)
    }

    func convert(data: Data, settings: SymbolSettings) throws -> SymbolOutput {
        let document = try XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])
        let unsupported = try document.nodes(forXPath: "//*[local-name()='mask' or local-name()='filter' or local-name()='image' or local-name()='text']")
        let kinds = Set(unsupported.compactMap { $0.localName })
        var fixes: [String] = []
        if kinds.contains("mask") { fixes.append("Masks: apply the mask using boolean path operations in your drawing app.") }
        if kinds.contains("filter") { fixes.append("Filters: remove blur, shadows, and other filter effects, or recreate them as solid vector shapes.") }
        if kinds.contains("image") { fixes.append("Bitmap images: trace or redraw embedded images as vector paths.") }
        if kinds.contains("text") { fixes.append("Text: convert text to outlines in your drawing app.") }
        guard fixes.isEmpty else {
            throw ConversionError("This SVG contains content SF Symbols can’t represent.\n\n" + fixes.joined(separator: "\n\n") + "\n\nExport a new SVG from that app, then import it here.")
        }
        guard let source = SVG(data: data), source.size.width > 0, source.size.height > 0 else {
            throw ConversionError("This file is not a readable SVG. Include a valid viewBox or width and height.")
        }
        guard [settings.top, settings.left, settings.bottom, settings.right].allSatisfy(\.isFinite),
              settings.left + settings.right < source.size.width,
              settings.top + settings.bottom < source.size.height,
              (!settings.generateWeights || (settings.minimumStroke.isFinite && settings.maximumStroke.isFinite &&
              settings.minimumStroke > 0 && settings.minimumStroke <= 1 &&
              settings.maximumStroke >= 1 && settings.maximumStroke <= 5)) else {
            throw ConversionError("Insets must leave a positive canvas. Stroke multipliers must be 0–1 for Ultralight and 1–5 for Black.")
        }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("svg")
        try data.write(to: temporary)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let insets = settings.automaticAlignment
            ? SwiftDraw.CommandLine.Insets()
            : SwiftDraw.CommandLine.Insets(top: settings.top, left: settings.left, bottom: settings.bottom, right: settings.right)
        let size: SFSymbolRenderer.SizeCategory = switch settings.size {
        case .small: .small
        case .medium: .medium
        case .large: .large
        }
        let renderer = SFSymbolRenderer(
            size: size, options: .default, insets: insets,
            insetsUltralight: insets, insetsBlack: insets,
            precision: 4, isLegacyInsets: false,
            ultralightStrokeScale: settings.generateWeights ? .init(multiplier: settings.minimumStroke) : nil,
            blackStrokeScale: settings.generateWeights ? .init(multiplier: settings.maximumStroke) : nil
        )
        let xml = try renderer.render(regular: temporary, ultralight: nil, black: nil)
        let output = try XMLDocument(xmlString: xml)
        // A full-canvas export gives a known source-to-template transform, allowing us
        // to recover the exact optical bounds (including expanded strokes) per master.
        let calibration: XMLDocument?
        if settings.automaticAlignment {
            let zero = SwiftDraw.CommandLine.Insets(top: 0, left: 0, bottom: 0, right: 0)
            let calibrator = SFSymbolRenderer(
                size: size, options: .default, insets: zero, insetsUltralight: zero, insetsBlack: zero,
                precision: 6, isLegacyInsets: false,
                ultralightStrokeScale: settings.generateWeights ? .init(multiplier: settings.minimumStroke) : nil,
                blackStrokeScale: settings.generateWeights ? .init(multiplier: settings.maximumStroke) : nil
            )
            calibration = try XMLDocument(xmlString: calibrator.render(regular: temporary, ultralight: nil, black: nil))
        } else {
            calibration = nil
        }
        var alignment: [String: AlignmentGeometry] = [:]
        var previews: [String: SVG] = [:]
        var signatures: [[String]] = []
        var pathCount = 0
        for weight in ["Ultralight", "Regular", "Black"] {
            guard let group = try output.nodes(forXPath: "//*[@id='\(weight)-\(settings.size.rawValue)']").first as? XMLElement else {
                throw ConversionError("SwiftDraw did not produce the expected symbol variant.")
            }
            let paths = try group.nodes(forXPath: ".//*[local-name()='path']")
            signatures.append(paths.compactMap { ($0 as? XMLElement)?.attribute(forName: "d")?.stringValue }.map {
                $0.filter { "MmLlHhVvCcSsQqTtAaZz".contains($0) }
            })
            if weight == "Regular" { pathCount = paths.count }
            // Use the actual exported outlines for previews; remove the size-row translation.
            let copy = group.copy() as! XMLElement
            copy.removeAttribute(forName: "transform")
            let center = weight == "Ultralight" ? 265.0 : weight == "Regular" ? 465.0 : 665.0
            let sourceBounds: CGRect
            if let calibration,
               let calibratedGroup = try calibration.nodes(forXPath: "//*[@id='\(weight)-\(settings.size.rawValue)']").first as? XMLElement {
                let bounds = try ExportedPathBounds.bounds(of: calibratedGroup)
                let scale = min(88 / source.size.width, 70 / source.size.height)
                sourceBounds = CGRect(
                    x: (bounds.minX - center) / scale + source.size.width / 2 - 10,
                    y: (bounds.minY - 111) / scale + source.size.height / 2,
                    width: bounds.width / scale + 20,
                    height: bounds.height / scale
                )
            } else {
                sourceBounds = CGRect(x: settings.left, y: settings.top,
                                      width: source.size.width - settings.left - settings.right,
                                      height: source.size.height - settings.top - settings.bottom)
            }
            let previewScale = min(88 / sourceBounds.width, 70 / sourceBounds.height)
            alignment[weight] = AlignmentGeometry(
                sourceSize: source.size, sourceBounds: sourceBounds,
                previewBounds: CGRect(x: 90 - sourceBounds.width * previewScale / 2,
                                      y: 70 - sourceBounds.height * previewScale / 2,
                                      width: sourceBounds.width * previewScale,
                                      height: sourceBounds.height * previewScale),
                previewScale: previewScale
            )
            let previewXML = "<svg xmlns='http://www.w3.org/2000/svg' width='180' height='140' viewBox='\(center - 90) 41 180 140'>\(copy.xmlString)</svg>"
            previews[weight] = SVG(xml: previewXML)
        }
        guard pathCount > 0, signatures[0] == signatures[1], signatures[1] == signatures[2] else {
            throw ConversionError("The generated weights have different path structures, so SF Symbols can’t interpolate them. Turn off Generate stroke weights, or simplify overlapping paths and convert strokes to outlines in your drawing app, then export and import a new SVG.")
        }
        return SymbolOutput(data: Data(xml.utf8), previews: previews, pathCount: pathCount, alignment: alignment)
    }

    struct ConversionError: LocalizedError {
        var errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
