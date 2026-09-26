import ComposableArchitecture
import CoreGraphics
import Foundation
import Testing
@testable import SF_Cymbal

@MainActor
struct ProjectTests {
    static func project() throws -> SymbolProject {
        var state = try EditorFeatureTests.loadedState()
        state.fileName = "spark"
        state.settings.automaticAlignment = false
        state.settings.left = -3
        state.settings.top = 5
        state.settings.generateWeights = true
        state.settings.minimumStroke = 0.35
        state.settings.maximumStroke = 2.5
        state.reference.kind = .symbol
        state.reference.symbolName = "heart.fill"
        state.weight = "Black"
        state.showGuides = false
        state.snapToEdges = false
        state.zoom = 0.75
        state.canvasOffset = CGSize(width: 20, height: -40)
        state.fitOffset = CGSize(width: 4, height: 8)
        state.isFitZoom = true
        return try #require(state.project)
    }

    @Test func olderMediumProjectsUseSmallMasters() throws {
        var original = try Self.project()
        original.manifest.settings.size = .medium
        let restored = try SymbolProject(wrapper: original.fileWrapper())
        original.manifest.settings.size = .small
        #expect(restored == original)
    }

    @Test func packageRoundTripsSourceAndSettings() throws {
        let original = try Self.project()
        let wrapper = try original.fileWrapper()
        #expect(Set(wrapper.fileWrappers?.keys.map { $0 } ?? []) == ["source.svg", "project.json"])
        let restored = try SymbolProject(wrapper: wrapper)
        #expect(restored == original)
        #expect(restored.source == Data(EditorFeature.example.utf8))
    }

    @Test func packageIsPortableAndSupportsAtomicOverwrite() async throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let originalURL = parent.appendingPathComponent("original.sfcymbal")
        let movedURL = parent.appendingPathComponent("moved.sfcymbal")
        var project = try Self.project()
        try ProjectDocument(project: project).package().write(to: originalURL, options: .atomic, originalContentsURL: nil)
        project.manifest.settings.left = 12
        try ProjectDocument(project: project).package().write(to: originalURL, options: .atomic, originalContentsURL: nil)
        try FileManager.default.moveItem(at: originalURL, to: movedURL)
        let reopened = try #require(ProjectDocument(wrapper: FileWrapper(url: movedURL)).project)
        #expect(reopened == project)
        #expect(try ArtworkLoader.load(reopened.source).size == CGSize(width: 100, height: 100))
    }

    @Test func malformedAndFuturePackagesAreRejected() throws {
        let missingSource = FileWrapper(directoryWithFileWrappers: ["project.json": FileWrapper(regularFileWithContents: Data("{}".utf8))])
        #expect(throws: (any Error).self) { try SymbolProject(wrapper: missingSource) }
        let future = FileWrapper(directoryWithFileWrappers: [
            "project.json": FileWrapper(regularFileWithContents: Data("{\"formatVersion\":999}".utf8)),
            "source.svg": FileWrapper(regularFileWithContents: Data(EditorFeature.example.utf8))
        ])
        #expect(throws: (any Error).self) { try SymbolProject(wrapper: future) }
        var invalid = try Self.project()
        invalid.manifest.zoom = 0
        #expect(throws: (any Error).self) { try invalid.fileWrapper() }
    }

    @Test func emptyNativeDocumentsCanSaveAndReopen() throws {
        let blank = ProjectDocument()
        let reopened = try ProjectDocument(wrapper: blank.package())
        #expect(reopened == blank)
        #expect(reopened.project == nil)
    }

    @Test func nativeDocumentRejectsCorruptSourceBeforeOpening() throws {
        var project = try Self.project()
        project.source = Data("not an SVG".utf8)
        #expect(throws: (any Error).self) { try ProjectDocument(wrapper: project.fileWrapper()) }
    }

    @Test func documentBindingRestoresStateAndRebuildsWeights() async throws {
        let project = try Self.project()
        let artwork = try ArtworkLoader.load(project.source)
        let clock = TestClock()
        let store = TestStore(initialState: EditorFeature.State()) { EditorFeature() } withDependencies: {
            $0.symbolClient.prepare = { _ in artwork }
            $0.referenceSymbols.exists = { _ in true }
            $0.continuousClock = clock
            $0.symbolClient.convert = { _, settings in
                #expect(settings.generateWeights)
                #expect(settings.minimumStroke == 0.35)
                return SymbolOutput(data: Data(), previews: [:], pathCount: 1)
            }
        }
        store.exhaustivity = .off
        await store.send(.documentChanged(project))
        #expect(!store.state.documentEdit.isStable)
        await store.receive(\.documentArtworkPrepared)
        #expect(store.state.project == project)
        #expect(store.state.documentEdit.isStable)
        #expect(store.state.artwork == artwork)
        await clock.advance(by: .milliseconds(250))
        await store.receive(\.weightPreviewResponse)
        #expect(store.state.weightPreview != nil)
        await store.finish()
    }

    @Test func nativeUndoRestoresSettingsWithoutReparsingSource() async throws {
        let initial = try EditorFeatureTests.loadedState()
        let project = try #require(initial.project)
        let store = TestStore(initialState: initial) { EditorFeature() } withDependencies: {
            $0.referenceSymbols.exists = { _ in true }
            $0.symbolClient.prepare = { _ in
                Issue.record("Restoring settings should reuse the loaded artwork")
                return initial.artwork!
            }
        }
        store.exhaustivity = .off
        await store.send(.binding(.set(\.settings.left, 8)))
        await store.send(.documentChanged(project))
        #expect(store.state.project == project)
        #expect(store.state.artwork == initial.artwork)
        await store.finish()
    }

    @Test func dragsPublishOnlyCompletedEdits() async throws {
        let state = try EditorFeatureTests.loadedState()
        let store = TestStore(initialState: state) { EditorFeature() }
        store.exhaustivity = .off
        await store.send(.guideDragChanged(.left, 3))
        #expect(!store.state.documentEdit.isStable)
        await store.send(.guideDragEnded)
        #expect(store.state.documentEdit.isStable)
        await store.send(.canvasDragChanged(CGSize(width: 40, height: 20)))
        #expect(!store.state.documentEdit.isStable)
        await store.send(.canvasDragEnded)
        #expect(store.state.documentEdit.isStable)
        await store.finish()
    }

    @Test func failedImportPreservesDocumentAndArtwork() async throws {
        let state = try EditorFeatureTests.loadedState()
        let store = TestStore(initialState: state) { EditorFeature() } withDependencies: {
            $0.symbolClient.prepare = { _ in throw SymbolConverter.ConversionError("Invalid SVG") }
        }
        store.exhaustivity = .off
        await store.send(.sourceLoaded(Data("invalid".utf8), "broken"))
        #expect(!store.state.documentEdit.isStable)
        await store.receive(\.artworkPrepared.failure)
        #expect(store.state.project == state.project)
        #expect(store.state.artwork == state.artwork)
        #expect(store.state.documentEdit.isStable)
        await store.finish()
    }
}
