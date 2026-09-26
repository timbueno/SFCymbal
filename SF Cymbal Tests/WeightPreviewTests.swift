import ComposableArchitecture
import Foundation
import Testing
@testable import SF_Cymbal

@MainActor
struct WeightPreviewTests {
    @Test func debounceCachesWeightsAndGuideEditsReuseThem() async throws {
        let clock = TestClock()
        let initial = try EditorFeatureTests.loadedState()
        let output = SymbolOutput(data: Data(), previews: [:], pathCount: 1)
        let store = TestStore(initialState: initial) { EditorFeature() } withDependencies: {
            $0.continuousClock = clock
            $0.symbolClient.convert = { _, settings in
                #expect(settings.minimumStroke == 0.3)
                #expect(settings.left == 0 && settings.top == 0)
                #expect(!settings.automaticAlignment)
                return output
            }
        }
        await store.send(.binding(.set(\.settings.generateWeights, true))) {
            $0.settings.generateWeights = true
            var preview = SymbolSettings()
            preview.generateWeights = true
            preview.automaticAlignment = false
            $0.weightPreviewSettings = preview
            $0.weightPreviewRevision = 1
            $0.isGeneratingWeights = true
        }
        await store.send(.binding(.set(\.settings.minimumStroke, 0.3))) {
            $0.settings.minimumStroke = 0.3
            $0.weightPreviewSettings?.minimumStroke = 0.3
            $0.weightPreviewRevision = 2
        }
        await clock.advance(by: .milliseconds(250))
        await store.receive(\.weightPreviewResponse) {
            $0.isGeneratingWeights = false
            $0.weightPreview = output
        }
        await store.send(.binding(.set(\.weight, "Black"))) { $0.weight = "Black" }
        await store.send(.automaticAlignmentToggled(false)) { $0.settings.automaticAlignment = false }
        await store.send(.binding(.set(\.settings.left, 5))) { $0.settings.left = 5 }
        await store.send(.binding(.set(\.settings.size, .large))) { $0.settings.size = .large }
        await store.finish()
    }

    @Test func regenerationKeepsLastDrawingAndDisablingRejectsStaleResponse() async throws {
        var state = try EditorFeatureTests.loadedState()
        state.settings.generateWeights = true
        var preview = SymbolSettings()
        preview.automaticAlignment = false
        preview.generateWeights = true
        state.weightPreviewSettings = preview
        let output = SymbolOutput(data: Data(), previews: [:], pathCount: 1)
        state.weightPreview = output
        let clock = TestClock()
        let store = TestStore(initialState: state) { EditorFeature() } withDependencies: {
            $0.continuousClock = clock
        }
        await store.send(.binding(.set(\.settings.maximumStroke, 3))) {
            $0.settings.maximumStroke = 3
            $0.weightPreviewSettings?.maximumStroke = 3
            $0.weightPreviewRevision = 1
            $0.isGeneratingWeights = true
        }
        #expect(store.state.weightPreview == output)
        await store.send(.binding(.set(\.settings.generateWeights, false))) {
            $0.settings.generateWeights = false
            $0.weightPreviewSettings = nil
            $0.weightPreview = nil
            $0.weightPreviewRevision = 2
            $0.isGeneratingWeights = false
        }
        await store.send(.weightPreviewResponse(1, .success(output)))
        await store.finish()
    }

    @Test func disabledMultipliersDoNotBlockExport() async throws {
        var settings = SymbolSettings()
        settings.minimumStroke = -5
        settings.maximumStroke = 0
        #expect(settings.validationMessage(for: CGSize(width: 100, height: 100)) == nil)
        let output = try await SymbolConverter.shared.convert(data: Data(EditorFeature.example.utf8), settings: settings)
        #expect(output.pathCount > 0)
    }

    @Test func generatedPreviewUsesOriginalSourceCoordinates() async throws {
        var settings = SymbolSettings()
        settings.automaticAlignment = false
        settings.generateWeights = true
        let output = try await SymbolConverter.shared.convert(data: Data(EditorFeature.example.utf8), settings: settings)
        let layout = CanvasLayout(canvasSize: CGSize(width: 900, height: 600), sourceSize: CGSize(width: 100, height: 100), settings: settings, zoom: 1)
        for weight in ["Ultralight", "Black"] {
            let svg = try #require(output.previews[weight])
            let geometry = try #require(output.alignment[weight])
            let frame = layout.generatedArtworkFrame(viewport: svg.size, geometry: geometry)
            let scale = frame.width / svg.size.width
            #expect(abs(frame.minX + geometry.previewBounds.minX * scale - layout.artworkFrame.minX) < 0.001)
            #expect(abs(frame.minY + geometry.previewBounds.minY * scale - layout.artworkFrame.minY) < 0.001)
            #expect(abs(geometry.previewBounds.width * scale - layout.artworkFrame.width) < 0.001)
        }
    }
}
