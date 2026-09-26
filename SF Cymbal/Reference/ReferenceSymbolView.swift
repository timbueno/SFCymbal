import AppKit
import SwiftUI

struct ReferenceSymbolView: View {
    let layout: CanvasLayout
    let name: String
    let weight: String

    var body: some View {
        if let image = ReferenceSymbolImages.shared.image(name: name, weight: weight) {
            let reference = layout.referenceSymbolFrame(imageSize: image.size, alignmentRect: image.alignmentRect)
            Image(nsImage: image)
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(.cyan.opacity(0.8))
                .frame(width: reference.width, height: reference.height)
                .position(x: reference.midX, y: reference.midY)
                .accessibilityLabel("Reference SF Symbol \(name)")
                .allowsHitTesting(false)
        }
    }
}
