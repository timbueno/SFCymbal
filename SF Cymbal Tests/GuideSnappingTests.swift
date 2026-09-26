import ComposableArchitecture
import CustomDump
import Foundation
import Testing
@testable import SF_Cymbal

struct GuideSnappingTests {
    @Test(arguments: AlignmentGuide.allCases, [0.25, 1.0, 4.0])
    func snapsAtConsistentScreenDistance(guide: AlignmentGuide, scale: Double) {
        let size = CGSize(width: 100, height: 100)
        let within = guide.moving(SymbolSettings(), by: 7 / scale, sourceSize: size, snapDistance: 8 / scale)
        expectNoDifference(within, SymbolSettings())
        let outside = guide.moving(SymbolSettings(), by: 9 / scale, sourceSize: size, snapDistance: 8 / scale)
        #expect(outside != SymbolSettings())
    }

    @Test(arguments: AlignmentGuide.allCases)
    func snappingNeverCrossesOppositeGuide(guide: AlignmentGuide) {
        var settings = SymbolSettings()
        settings.left = 110
        settings.right = -20
        settings.top = 110
        settings.bottom = -20
        let moved = guide.moving(settings, by: 20, sourceSize: CGSize(width: 100, height: 100), snapDistance: 8)
        #expect(moved.left + moved.right < 100)
        #expect(moved.top + moved.bottom < 100)
    }

    @MainActor @Test(arguments: [true, false])
    func toggleControlsDragging(snapEnabled: Bool) async throws {
        var state = try EditorFeatureTests.loadedState()
        state.settings.automaticAlignment = false
        state.snapToEdges = snapEnabled
        let store = TestStore(initialState: state) { EditorFeature() }
        let drag = AlignmentDrag(guide: .left, initialSettings: state.settings, sourceSize: state.artwork!.opticalBounds.size)
        await store.send(.guideDragChanged(.left, 1.5, snapDistance: 2)) {
            $0.alignmentDrag = drag
            $0.settings.left = snapEnabled ? 0 : 1.5
            $0.status = "Adjusting left margin…"
        }
        // Moving out of the snap radius must release the guide immediately.
        await store.send(.guideDragChanged(.left, 3, snapDistance: 2)) { $0.settings.left = 3 }
        await store.send(.guideDragEnded) {
            $0.alignmentDrag = nil
            $0.status = "Ready · Original SVG · Export to create SF Symbol"
        }
        await store.send(.binding(.set(\.snapToEdges, !snapEnabled))) { $0.snapToEdges = !snapEnabled }
    }
}
