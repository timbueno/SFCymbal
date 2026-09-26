import SwiftUI

/// Original visible artwork edges, independent of the editable alignment guides.
struct ArtworkEdgeGuidesView: View {
    let bounds: CGRect
    let canvasSize: CGSize

    var body: some View {
        Path { path in
            for x in [bounds.minX, bounds.maxX] {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
            }
            for y in [bounds.minY, bounds.maxY] {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
            }
        }
        .stroke(.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 4]))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
