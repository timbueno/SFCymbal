import ComposableArchitecture
import Foundation
import Testing
@testable import SF_Cymbal

@MainActor
struct EditorPolishTests {
    @Test func undoNamesDescribeChanges() throws {
        let original = try ProjectTests.project()
        var changed = original
        changed.manifest.settings.left += 1
        #expect(DocumentChangeName.name(from: original, to: changed) == "Alignment Change")
        changed = original
        changed.manifest.settings.minimumStroke = 0.2
        #expect(DocumentChangeName.name(from: original, to: changed) == "Stroke Scale")
        changed = original
        changed.manifest.referenceSymbol = "circle"
        #expect(DocumentChangeName.name(from: original, to: changed) == "Reference Change")
    }

    @Test func exportConfirmationDoesNotChangeDocument() async throws {
        let state = try EditorFeatureTests.loadedState()
        let project = state.project
        let store = TestStore(initialState: state) { EditorFeature() }
        let url = URL(fileURLWithPath: "/tmp/example.svg")
        await store.send(.exportCompleted(.success(url))) {
            $0.exportedURL = url
            $0.status = "Exported example.svg"
        }
        #expect(store.state.project == project)
        await store.send(.dismissExportConfirmationButtonTapped) { $0.exportedURL = nil }
    }

    @Test(arguments: [("mask", "boolean path operations"), ("filter", "remove blur"), ("image", "trace or redraw"), ("text", "convert text to outlines")])
    func validationExplainsHowToRepair(tag: String, remedy: String) async throws {
        let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><\(tag)/><rect width='50' height='50'/></svg>"
        do {
            _ = try await SymbolConverter.shared.convert(data: Data(svg.utf8), settings: SymbolSettings())
            Issue.record("Expected unsupported content to be rejected")
        } catch {
            #expect(error.localizedDescription.lowercased().contains(remedy))
        }
    }
}
