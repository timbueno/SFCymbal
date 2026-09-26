import AppKit
import CoreText
import SwiftUI

struct ReferenceLetterView: View {
    let layout: CanvasLayout
    let weight: String

    var body: some View {
        let letter = Self.letters[weight] ?? Self.letters["Regular"]!
        let rect = layout.referenceFrame(aspectRatio: letter.bounds.width / letter.bounds.height)
        Path(letter.path)
            .fill(.cyan.opacity(0.8))
            .scaleEffect(x: rect.width / letter.bounds.width, y: rect.height / letter.bounds.height, anchor: .topLeading)
            .frame(width: rect.width, height: rect.height, alignment: .topLeading)
            .position(x: rect.midX, y: rect.midY)
            .accessibilityLabel("Reference letter A")
            .allowsHitTesting(false)
    }

    static func aspectRatio(weight: String) -> Double {
        let letter = letters[weight] ?? letters["Regular"]!
        return letter.bounds.width / letter.bounds.height
    }

    private struct Letter {
        var path: CGPath
        var bounds: CGRect
    }

    private static let letters: [String: Letter] = {
        var result: [String: Letter] = [:]
        for (name, weight) in [("Ultralight", NSFont.Weight.ultraLight), ("Regular", .regular), ("Black", .black)] {
            let font = NSFont.systemFont(ofSize: 100, weight: weight) as CTFont
            var character: UniChar = 65
            var glyph: CGGlyph = 0
            CTFontGetGlyphsForCharacters(font, &character, &glyph, 1)
            guard let path = CTFontCreatePathForGlyph(font, glyph, nil) else { continue }
            let bounds = path.boundingBoxOfPath
            var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: -bounds.minX, ty: bounds.maxY)
            if let normalized = path.copy(using: &transform) {
                result[name] = Letter(path: normalized, bounds: CGRect(origin: .zero, size: bounds.size))
            }
        }
        return result
    }()
}
