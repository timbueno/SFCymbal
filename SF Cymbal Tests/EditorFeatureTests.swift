import ComposableArchitecture
import Foundation
import Testing
@testable import SF_Cymbal

@MainActor
struct EditorFeatureTests {
    @Test func importingPreparesArtworkWithoutExporting() async throws {
        let data = Data(EditorFeature.example.utf8)
        let artwork = try ArtworkLoader.load(data)
        let store = TestStore(initialState: EditorFeature.State()) { EditorFeature() } withDependencies: {
            $0.symbolClient.prepare = { _ in artwork }
            $0.symbolClient.convert = { _, _ in
                Issue.record("Import must not generate an SF Symbol")
                return SymbolOutput(data: Data(), previews: [:], pathCount: 0)
            }
        }
        await store.send(.sourceLoaded(data, "mark")) {
            $0.pendingImport = PendingSVGImport(data: data, name: "mark")
            $0.weightPreviewRevision = 1
            $0.isLoading = true
            $0.status = "Loading SVG…"
        }
        await store.receive(\.artworkPrepared.success) {
            $0.pendingImport = nil
            $0.source = data
            $0.fileName = "mark"
            $0.artwork = artwork
            $0.isLoading = false
            $0.status = "Ready · Original SVG · Export to create SF Symbol"
        }
    }

    @Test func exportUsesLatestAlignmentAndOpensSavePanel() async throws {
        var state = try loadedState()
        state.settings.automaticAlignment = false
        state.settings.left = 12
        state.settings.top = 8
        let expected = state.effectiveSettings
        let output = SymbolOutput(data: Data("symbol".utf8), previews: [:], pathCount: 1)
        let store = TestStore(initialState: state) { EditorFeature() } withDependencies: {
            $0.symbolClient.convert = { _, settings in
                #expect(settings.left == expected.left && settings.top == expected.top)
                #expect(settings.left > 12 && settings.top > 8)
                #expect(!settings.automaticAlignment)
                return output
            }
        }
        await store.send(.exportButtonTapped) {
            $0.isConverting = true
            $0.status = "Preparing export…"
        }
        await store.receive(\.conversionResponse.success) {
            $0.isConverting = false
            $0.isExporting = true
            $0.output = output
            $0.status = "Symbol ready to save"
        }
    }

    @Test func failedExportPreservesArtwork() async throws {
        let state = try loadedState()
        let store = TestStore(initialState: state) { EditorFeature() } withDependencies: {
            $0.symbolClient.convert = { _, _ in throw SymbolConverter.ConversionError("Unsupported SVG") }
        }
        await store.send(.exportButtonTapped) {
            $0.isConverting = true
            $0.status = "Preparing export…"
        }
        await store.receive(\.conversionResponse.failure) {
            $0.isConverting = false
            $0.error = "Unsupported SVG"
            $0.status = "Export needs attention"
        }
    }

    static func loadedState() throws -> EditorFeature.State {
        var state = EditorFeature.State()
        state.source = Data(EditorFeature.example.utf8)
        state.artwork = try ArtworkLoader.load(state.source!)
        state.status = "Ready · Original SVG · Export to create SF Symbol"
        return state
    }

    private func loadedState() throws -> EditorFeature.State { try Self.loadedState() }
}
