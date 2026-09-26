import ComposableArchitecture
import Foundation
import CoreGraphics
import Testing
@testable import SF_Cymbal

@MainActor
struct CanvasNavigationTests {
    @Test func panningAccumulatesAndRecenteringPreservesSettings() async throws {
        let state = try EditorFeatureTests.loadedState()
        let store = TestStore(initialState: state) { EditorFeature() }
        await store.send(.canvasDragChanged(CGSize(width: 80, height: -25))) {
            $0.canvasDragOrigin = .zero
            $0.canvasOffset = CGSize(width: 80, height: -25)
        }
        await store.send(.canvasDragEnded) { $0.canvasDragOrigin = nil }
        await store.send(.canvasDragChanged(CGSize(width: 20, height: 5))) {
            $0.canvasDragOrigin = CGSize(width: 80, height: -25)
            $0.canvasOffset = CGSize(width: 100, height: -20)
        }
        await store.send(.canvasDragEnded) { $0.canvasDragOrigin = nil }
        await store.send(.recenterButtonTapped) { $0.canvasOffset = .zero }
        #expect(store.state.settings == state.settings)
        #expect(store.state.artwork == state.artwork)
        await store.finish()
    }

    @Test func fitAndNumericZoomDoNotRegenerateArtwork() async throws {
        var state = try EditorFeatureTests.loadedState()
        state.canvasOffset = CGSize(width: 100, height: 40)
        let store = TestStore(initialState: state) { EditorFeature() }
        await store.send(.fitButtonTapped) { $0.fitRequest = 1 }
        await store.send(.canvasFitted(0.85, CGSize(width: -20, height: 10))) {
            $0.zoom = 0.85
            $0.fitOffset = CGSize(width: -20, height: 10)
            $0.canvasOffset = .zero
            $0.isFitZoom = true
        }
        await store.send(.binding(.set(\.zoom, 0.5))) {
            $0.zoom = 0.5
            $0.isFitZoom = false
            $0.fitOffset = .zero
        }
        #expect(store.state.settings == state.settings)
        #expect(store.state.artwork == state.artwork)
        await store.finish()
    }

    @Test func panMovesArtworkAndGuidesWithoutChangingScale() {
        let canvas = CGSize(width: 900, height: 600)
        let source = CGSize(width: 100, height: 100)
        let normal = CanvasLayout(canvasSize: canvas, sourceSize: source, settings: SymbolSettings(), zoom: 1)
        let offset = CGSize(width: 180, height: -60)
        let panned = CanvasLayout(canvasSize: canvas, sourceSize: source, settings: SymbolSettings(), zoom: 1, offset: offset)
        #expect(panned.sourceScale == normal.sourceScale)
        #expect(panned.artworkFrame == normal.artworkFrame.offsetBy(dx: offset.width, dy: offset.height))
        #expect(panned.guideFrame == normal.guideFrame.offsetBy(dx: offset.width, dy: offset.height))
        let expected = normal.referenceFrame(aspectRatio: 0.8).offsetBy(dx: offset.width, dy: offset.height)
        let actual = panned.referenceFrame(aspectRatio: 0.8)
        #expect(abs(actual.minX - expected.minX) < 0.0001)
        #expect(abs(actual.minY - expected.minY) < 0.0001)
        #expect(actual.size == expected.size)
    }
}
