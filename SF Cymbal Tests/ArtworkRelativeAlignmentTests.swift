import ComposableArchitecture
import CoreGraphics
import CustomDump
import Foundation
import Testing
@testable import SF_Cymbal

struct ArtworkRelativeAlignmentTests {
    private func artwork() throws -> ImportedArtwork {
        // Canvas whitespace deliberately differs on all four sides.
        let xml = "<svg xmlns='http://www.w3.org/2000/svg' width='200' height='100'><rect x='30' y='15' width='100' height='50'/></svg>"
        return try ArtworkLoader.load(Data(xml.utf8))
    }

    @Test func zeroMeansArtworkEdgeInEitherMode() throws {
        let artwork = try artwork()
        let fitted = artwork.alignmentSettings(SymbolSettings())
        var manual = SymbolSettings()
        manual.automaticAlignment = false
        expectNoDifference(artwork.alignmentSettings(manual), fitted)
        let layout = CanvasLayout(canvasSize: CGSize(width: 900, height: 600), sourceSize: artwork.size, settings: fitted, zoom: 1)
        #expect(abs(layout.guideFrame.minX - (layout.artworkFrame.minX + 30 * layout.sourceScale)) < 1)
        #expect(abs(layout.guideFrame.minY - (layout.artworkFrame.minY + 15 * layout.sourceScale)) < 1)
        #expect(abs(layout.guideFrame.width - 100 * layout.sourceScale) < 1)
        #expect(abs(layout.guideFrame.height - 50 * layout.sourceScale) < 1)
    }

    @Test func relativeOffsetsTranslateToExportInsetsOnce() throws {
        let artwork = try artwork()
        let base = artwork.alignmentSettings(SymbolSettings())
        var edited = SymbolSettings()
        edited.automaticAlignment = false
        edited.left = -10
        edited.right = 5
        edited.top = 8
        edited.bottom = -4
        var expected = base
        expected.left -= 10
        expected.right += 5
        expected.top += 8
        expected.bottom -= 4
        expectNoDifference(artwork.alignmentSettings(edited), expected)
    }

    @MainActor @Test func draggingFromFitKeepsOtherFieldsAtZeroAndSnapsBack() async throws {
        var state = try EditorFeatureTests.loadedState()
        state.artwork = try artwork()
        let store = TestStore(initialState: state) { EditorFeature() }
        var initial = state.settings
        initial.automaticAlignment = false
        let drag = AlignmentDrag(guide: .top, initialSettings: initial, sourceSize: state.artwork!.opticalBounds.size)
        await store.send(.guideDragChanged(.top, 8, snapDistance: 2)) {
            $0.alignmentDrag = drag
            $0.settings.automaticAlignment = false
            $0.settings.top = 8
            $0.status = "Adjusting cap height…"
        }
        await store.send(.guideDragChanged(.top, 1, snapDistance: 2)) { $0.settings.top = 0 }
        await store.send(.guideDragEnded) {
            $0.alignmentDrag = nil
            $0.status = "Ready · Original SVG · Export to create SF Symbol"
        }
    }

    @MainActor @Test func dragClampUsesArtworkSizeInsteadOfPaddedCanvas() async throws {
        var state = try EditorFeatureTests.loadedState()
        state.artwork = try artwork()
        state.settings.automaticAlignment = false
        let store = TestStore(initialState: state) { EditorFeature() }
        let size = state.artwork!.opticalBounds.size
        let drag = AlignmentDrag(guide: .left, initialSettings: state.settings, sourceSize: size)
        await store.send(.guideDragChanged(.left, 500)) {
            $0.alignmentDrag = drag
            $0.settings.left = size.width - max(0.001, min(size.width, size.height) * 0.001)
            $0.status = "Adjusting left margin…"
        }
        #expect(store.state.validationMessage == nil)
    }
}
