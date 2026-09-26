import ComposableArchitecture
import SwiftDraw
import SwiftUI

struct SymbolCanvasView: View {
    let store: StoreOf<EditorFeature>

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(nsColor: .textBackgroundColor)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 3)
                        .onChanged { store.send(.canvasDragChanged($0.translation)) }
                        .onEnded { _ in store.send(.canvasDragEnded) })
                if let error = store.error, store.artwork == nil {
                    ContentUnavailableView {
                        Label("Couldn’t create symbol", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error).frame(maxWidth: 420)
                    } actions: {
                        Button("Dismiss") { store.send(.dismissErrorButtonTapped) }
                        Button("Import another SVG…") { store.send(.importButtonTapped) }
                    }
                } else if store.isLoading && store.artwork == nil {
                    ProgressView("Loading SVG…")
                } else if let artwork = store.artwork {
                    let layout = CanvasLayout(canvasSize: geometry.size, sourceSize: artwork.size,
                                              settings: store.effectiveSettings, zoom: store.zoom,
                                              offset: CGSize(width: store.fitOffset.width + store.canvasOffset.width,
                                                             height: store.fitOffset.height + store.canvasOffset.height))
                    ArtworkPreviewView(artwork: artwork, layout: layout, weight: store.weight,
                                       generated: store.settings.generateWeights ? store.weightPreview : nil)
                    if store.reference.kind == .letter {
                        ReferenceLetterView(layout: layout, weight: store.weight)
                    } else {
                        ReferenceSymbolView(layout: layout, name: store.reference.symbolName, weight: store.weight)
                    }
                    ArtworkEdgeGuidesView(
                        bounds: artwork.opticalBounds.applying(CGAffineTransform(
                            a: layout.sourceScale, b: 0, c: 0, d: layout.sourceScale,
                            tx: layout.artworkFrame.minX, ty: layout.artworkFrame.minY)),
                        canvasSize: geometry.size
                    )
                    if store.showGuides {
                        AlignmentGuidesView(store: store, layout: layout, canvasSize: geometry.size)
                    }
                } else {
                    VStack(spacing: 18) {
                        Image(systemName: "square.on.circle")
                            .font(.system(size: 54, weight: .ultraLight)).foregroundStyle(.teal)
                            .padding(24).background(.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 28))
                        VStack(spacing: 8) {
                            Text("Make your mark.").font(.largeTitle.weight(.semibold))
                            Text("Turn your vector artwork into a custom SF Symbol.")
                                .foregroundStyle(.secondary)
                            Text("Drop an SVG or SF Cymbals project here to begin.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Button("Import SVG…") { store.send(.importButtonTapped) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                        Button("Try an example", systemImage: "sparkles") { store.send(.exampleButtonTapped) }
                            .buttonStyle(.plain).foregroundStyle(.teal)
                    }
                    .padding(30)
                }
            }
            .overlay(alignment: .top) {
                if let error = store.error ?? store.validationMessage ?? store.weightPreviewError, store.artwork != nil {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout).padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial)
                        .padding(12)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if store.artwork != nil, store.canvasOffset != .zero {
                    Button("Recenter", systemImage: "scope") { store.send(.recenterButtonTapped) }
                        .buttonStyle(.bordered)
                        .help("Recenter canvas")
                        .padding(20)
                }
            }
            .onChange(of: store.fitRequest) { old, new in
                if new > old { fitCanvas(size: geometry.size) }
            }
            .onChange(of: geometry.size) { _, size in
                if store.isFitZoom && store.canvasOffset == .zero { fitCanvas(size: size) }
            }
            .coordinateSpace(name: "symbolCanvas")
            .clipped()
        }
    }
    private func fitCanvas(size: CGSize) {
        guard let artwork = store.artwork, size.width > 80, size.height > 80 else { return }
        func contentBounds(zoom: Double) -> CGRect {
            let layout = CanvasLayout(canvasSize: size, sourceSize: artwork.size,
                                      settings: store.effectiveSettings, zoom: zoom)
            let reference: CGRect
            if store.reference.kind == .symbol,
               let image = ReferenceSymbolImages.shared.image(name: store.reference.symbolName, weight: store.weight) {
                reference = layout.referenceSymbolFrame(imageSize: image.size, alignmentRect: image.alignmentRect)
            } else {
                reference = layout.referenceFrame(aspectRatio: ReferenceLetterView.aspectRatio(weight: store.weight))
            }
            return layout.artworkFrame.union(layout.guideFrame).union(reference)
        }
        // Find the largest scale that fits both artwork and reference with breathing room.
        var lower = 0.0001
        var upper = 10.0
        for _ in 0..<40 {
            let candidate = (lower + upper) / 2
            let bounds = contentBounds(zoom: candidate)
            if bounds.width <= size.width - 80 && bounds.height <= size.height - 80 {
                lower = candidate
            } else { upper = candidate }
        }
        let bounds = contentBounds(zoom: lower)
        store.send(.canvasFitted(lower, CGSize(width: size.width / 2 - bounds.midX,
                                              height: size.height / 2 - bounds.midY)))
    }

}
