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
        let image = try #require(ReferenceSymbolImages.shared.image(name: name, weight: weight, size: .small))
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
        let again = try #require(ReferenceSymbolImages.shared.image(name: name, weight: weight, size: .small))
        #expect(image === again)
        let layout = CanvasLayout(canvasSize: CGSize(width: 900, height: 600), sourceSize: CGSize(width: 100, height: 100), settings: SymbolSettings(), zoom: 1)
        let reference = layout.referenceFrame(aspectRatio: image.size.width / image.size.height)
        expectNoDifference(reference.minY, layout.guideFrame.minY)
        expectNoDifference(reference.maxY, layout.guideFrame.maxY)
    }

    @Test(arguments: ["Ultralight", "Regular", "Black"])
    func configuredScalesMatchAppKitAndRemainDistinctInCache(weight: String) throws {
        let fontWeight: NSFont.Weight = switch weight {
        case "Ultralight": .ultraLight
        case "Black": .black
        default: .regular
        }
        let base = try #require(NSImage(systemSymbolName: "bookmark", accessibilityDescription: nil))
        let cases: [(SymbolSettings.SymbolSize, NSImage.SymbolScale)] = [
            (.small, .small), (.medium, .medium), (.large, .large)
        ]
        var images: [NSImage] = []
        for (size, scale) in cases {
            let expected = try #require(base.withSymbolConfiguration(.init(pointSize: 100, weight: fontWeight, scale: scale)))
            let actual = try #require(ReferenceSymbolImages.shared.image(name: "bookmark", weight: weight, size: size))
            #expect(actual.size == expected.size)
            #expect(actual.alignmentRect == expected.alignmentRect)
            #expect(images.allSatisfy { $0 !== actual })
            images.append(actual)
        }
        // A request after all three cache entries exist must still return its own scale.
        for ((size, _), image) in zip(cases.reversed(), images.reversed()) {
            #expect(ReferenceSymbolImages.shared.image(name: "bookmark", weight: weight, size: size) === image)
        }
        let heights = images.map { $0.size.height / $0.alignmentRect.height }
        #expect(heights[0] < heights[1])
        #expect(heights[1] < heights[2])
    }

    @Test(arguments: SymbolSettings.SymbolSize.allCases, ["bookmark", "star", "person.fill"])
    func realSymbolAlignmentAndFitPreserveMetrics(size: SymbolSettings.SymbolSize, name: String) throws {
        let image = try #require(ReferenceSymbolImages.shared.image(name: name, weight: "Regular", size: size))
        var settings = SymbolSettings()
        settings.size = size
        let canvas = CGSize(width: 900, height: 600)
        let source = CGSize(width: 100, height: 100)
        let fit = CanvasLayout.fit(canvasSize: canvas, sourceSize: source, settings: settings) {
            $0.referenceSymbolFrame(imageSize: image.size, alignmentRect: image.alignmentRect)
        }
        let layout = CanvasLayout(canvasSize: canvas, sourceSize: source, settings: settings,
                                  zoom: fit.zoom, offset: fit.offset)
        let frame = layout.referenceSymbolFrame(imageSize: image.size, alignmentRect: image.alignmentRect)
        let scale = frame.height / image.size.height
        let alignment = image.alignmentRect
        #expect(abs(frame.maxY - alignment.minY * scale - layout.guideFrame.maxY) < 0.0001)
        #expect(abs(frame.maxY - alignment.maxY * scale - layout.guideFrame.minY) < 0.0001)
        #expect(abs(frame.minX + alignment.maxX * scale - layout.referenceFrame(aspectRatio: 1).maxX) < 0.0001)
        #expect(abs(frame.width / frame.height - image.size.width / image.size.height) < 0.0001)
        if name == "bookmark" {
            #expect(frame.minY < layout.guideFrame.minY)
            #expect(frame.maxY > layout.guideFrame.maxY)
        }
        let bounds = layout.artworkFrame.union(layout.guideFrame).union(frame)
        #expect(bounds.minX >= 40 - 0.0001)
        #expect(bounds.minY >= 40 - 0.0001)
        #expect(bounds.maxX <= canvas.width - 40 + 0.0001)
        #expect(bounds.maxY <= canvas.height - 40 + 0.0001)
        #expect(abs(bounds.midX - canvas.width / 2) < 0.0001)
        #expect(abs(bounds.midY - canvas.height / 2) < 0.0001)
        #expect(abs(bounds.width - (canvas.width - 80)) < 0.001 ||
                abs(bounds.height - (canvas.height - 80)) < 0.001)
    }

    @Test func unknownSystemSymbolIsRejected() {
        #expect(!ReferenceSymbolClient.liveValue.exists("sfcymbal.nonexistent.symbol.12345"))
        #expect(ReferenceSymbolImages.shared.image(name: "sfcymbal.nonexistent.symbol.12345", weight: "Regular", size: .small) == nil)
    }
}
