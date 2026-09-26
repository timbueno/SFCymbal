import ComposableArchitecture
import Foundation
import Testing
@testable import SF_Cymbal

@MainActor
struct EditorSettingsTests {
    @Test(arguments: [false, true])
    func automaticToggleClearsInsetsWithoutReprocessing(isAutomatic: Bool) async throws {
        var state = try EditorFeatureTests.loadedState()
        state.settings.automaticAlignment = !isAutomatic
        state.settings.left = 4
        state.settings.right = 5
        state.settings.top = 6
        state.settings.bottom = 7
        let store = makeStore(state)
        await store.send(.automaticAlignmentToggled(isAutomatic)) {
            $0.settings.automaticAlignment = isAutomatic
            $0.settings.left = 0
            $0.settings.right = 0
            $0.settings.top = 0
            $0.settings.bottom = 0
        }
    }

    @Test func editsAndResetsDoNotReprocessArtwork() async throws {
        var state = try EditorFeatureTests.loadedState()
        state.settings.automaticAlignment = false
        let store = makeStore(state)
        await store.send(.binding(.set(\.settings.top, 15))) { $0.settings.top = 15 }
        await store.send(.binding(.set(\.settings.left, -20))) { $0.settings.left = -20 }
        await store.send(.binding(.set(\.settings.maximumStroke, 3))) { $0.settings.maximumStroke = 3 }
        await store.send(.symbolSettingsResetButtonTapped) { $0.settings.maximumStroke = 2 }
        await store.send(.alignmentResetButtonTapped) {
            $0.settings.top = 0
            $0.settings.left = 0
        }
    }

    @Test func draggingStaysLocalAndDoesNotReprocessOnRelease() async throws {
        var state = try EditorFeatureTests.loadedState()
        state.settings.automaticAlignment = false
        let store = makeStore(state)
        let drag = AlignmentDrag(guide: .left, initialSettings: state.settings, sourceSize: state.artwork!.opticalBounds.size)
        await store.send(.guideDragChanged(.left, 4)) {
            $0.alignmentDrag = drag
            $0.settings.left = 4
            $0.status = "Adjusting left margin…"
        }
        await store.send(.guideDragChanged(.left, 10)) { $0.settings.left = 10 }
        await store.send(.guideDragEnded) {
            $0.alignmentDrag = nil
            $0.status = "Ready · Original SVG · Export to create SF Symbol"
        }
    }

    @Test func invalidInsetsKeepArtworkAndPreventExport() async throws {
        var state = try EditorFeatureTests.loadedState()
        state.settings.automaticAlignment = false
        let store = makeStore(state)
        await store.send(.binding(.set(\.settings.left, 1000))) {
            $0.settings.left = 1000
            $0.status = "Alignment guides must leave a positive width and height."
        }
        #expect(!store.state.canExport)
        await store.send(.exportButtonTapped)
    }

    private func makeStore(_ state: EditorFeature.State) -> TestStoreOf<EditorFeature> {
        TestStore(initialState: state) { EditorFeature() } withDependencies: {
            $0.symbolClient.prepare = { _ in
                Issue.record("Editing must not reload the source")
                return state.artwork!
            }
            $0.symbolClient.convert = { _, _ in
                Issue.record("Editing must not invoke the SF Symbols exporter")
                return SymbolOutput(data: Data(), previews: [:], pathCount: 0)
            }
        }
    }
}
