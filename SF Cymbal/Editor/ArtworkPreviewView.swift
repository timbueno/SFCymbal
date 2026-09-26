import SwiftDraw
import SwiftUI

struct ArtworkPreviewView: View {
    let artwork: ImportedArtwork
    let layout: CanvasLayout
    let weight: String
    let generated: SymbolOutput?

    var body: some View {
        let variant = weight == "Regular" ? nil : generated?.previews[weight]
        let geometry = generated?.alignment[weight]
        let svg = variant ?? artwork.svg
        let frame = variant != nil && geometry != nil
            ? layout.generatedArtworkFrame(viewport: svg.size, geometry: geometry!)
            : layout.artworkFrame
        SVGView(svg: svg).resizable()
            .renderingMode(.template)
            .foregroundStyle(.primary)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .accessibilityLabel(variant == nil ? "Original SVG artwork" : "\(weight) generated artwork")
            .allowsHitTesting(false)
    }
}
