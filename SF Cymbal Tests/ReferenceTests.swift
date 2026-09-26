import AppKit
import ComposableArchitecture
import CustomDump
import Foundation
import Testing
@testable import SF_Cymbal

@MainActor
struct ReferenceTests {
    @Test func acceptsArbitraryAvailableSymbolNames() async {
        let store = TestStore(initialState: ReferenceFeature.State()) { ReferenceFeature() } withDependencies: {
            $0.referenceSymbols.exists = { $0 == "arrow.up.right.square.fill" }
        }
        await store.send(.kindChanged(.symbol)) { $0.kind = .symbol }
        await store.send(.symbolNameChanged(" arrow.up.right.square.fill\n")) {
            $0.draftName = " arrow.up.right.square.fill\n"
            $0.symbolName = "arrow.up.right.square.fill"
        }
        await store.send(.kindChanged(.letter)) { $0.kind = .letter }
        await store.send(.kindChanged(.symbol)) { $0.kind = .symbol }
    }

    @Test func invalidNamePreservesLastValidReference() async {
        var state = ReferenceFeature.State()
        state.kind = .symbol
        let store = TestStore(initialState: state) { ReferenceFeature() } withDependencies: {
            $0.referenceSymbols.exists = { $0 == "heart.fill" }
        }
        await store.send(.symbolNameChanged("missing.symbol")) {
            $0.draftName = "missing.symbol"
            $0.error = "This symbol isn’t available on this Mac. Check its name in Apple’s SF Symbols app."
        }
        await store.send(.symbolNameChanged("")) {
            $0.draftName = ""
            $0.error = "Enter an SF Symbol name."
        }
        await store.send(.suggestedSymbolTapped("heart.fill")) {
            $0.draftName = "heart.fill"
            $0.symbolName = "heart.fill"
            $0.error = nil
        }
    }

    @Test func referenceChangesDoNotInvalidateArtworkOrExport() async throws {
        var state = try EditorFeatureTests.loadedState()
        state.output = SymbolOutput(data: Data("existing export".utf8), previews: [:], pathCount: 1)
        let store = TestStore(initialState: state) { EditorFeature() } withDependencies: {
            $0.referenceSymbols.exists = { _ in true }
        }
        await store.send(.reference(.suggestedSymbolTapped("leaf.fill"))) {
            $0.reference.kind = .symbol
            $0.reference.draftName = "leaf.fill"
            $0.reference.symbolName = "leaf.fill"
        }
        await store.send(.binding(.set(\.weight, "Black"))) { $0.weight = "Black" }
        #expect(store.state.canExport)
    }

    @Test(arguments: ["star", "heart.fill", "arrow.left.and.right", "person.fill"], ["Ultralight", "Regular", "Black"])
    func systemSymbolsHaveUsableDimensions(name: String, weight: String) throws {
        #expect(ReferenceSymbolClient.liveValue.exists(name))
        let image = try #require(ReferenceSymbolImages.shared.image(name: name, weight: weight))
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
        let again = try #require(ReferenceSymbolImages.shared.image(name: name, weight: weight))
        #expect(image === again)
        let layout = CanvasLayout(canvasSize: CGSize(width: 900, height: 600), sourceSize: CGSize(width: 100, height: 100), settings: SymbolSettings(), zoom: 1)
        let reference = layout.referenceFrame(aspectRatio: image.size.width / image.size.height)
        expectNoDifference(reference.minY, layout.guideFrame.minY)
        expectNoDifference(reference.maxY, layout.guideFrame.maxY)
    }

    @Test func unknownSystemSymbolIsRejected() {
        #expect(!ReferenceSymbolClient.liveValue.exists("sfcymbal.nonexistent.symbol.12345"))
        #expect(ReferenceSymbolImages.shared.image(name: "sfcymbal.nonexistent.symbol.12345", weight: "Regular") == nil)
    }
}
