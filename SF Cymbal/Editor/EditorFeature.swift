import ComposableArchitecture
import Foundation
import CoreGraphics

@Reducer
struct EditorFeature {
    @ObservableState
    struct State: Equatable {
        var alignmentDrag: AlignmentDrag?
        var artwork: ImportedArtwork?
        var error: String?
        var exportedURL: URL?
        var fileName = "Untitled"
        var isConverting = false
        var isExporting = false
        var isImporting = false
        var isLoading = false
        var documentRevision = 0
        var pendingImport: PendingSVGImport?
        var output: SymbolOutput?
        var weightPreview: SymbolOutput?
        var weightPreviewSettings: SymbolSettings?
        var weightPreviewRevision = 0
        var isGeneratingWeights = false
        var weightPreviewError: String?
        var reference = ReferenceFeature.State()
        var settings = SymbolSettings()
        var showGuides = true
        var snapToEdges = true
        var source: Data?
        var status = "Import an SVG to get started"
        var weight = "Regular"
        var zoom = 1.0
        var canvasOffset = CGSize.zero
        var canvasDragOrigin: CGSize?
        var fitOffset = CGSize.zero
        var isFitZoom = false
        var fitRequest = 0

        var project: SymbolProject? {
            guard let source, artwork != nil else { return nil }
            return SymbolProject(source: source, manifest: ProjectManifest(
                name: fileName, settings: settings, referenceKind: reference.kind,
                referenceSymbol: reference.symbolName, previewWeight: weight,
                showGuides: showGuides, snapToEdges: snapToEdges, zoom: zoom,
                canvasOffset: canvasOffset, fitOffset: fitOffset, isFitZoom: isFitZoom))
        }
        var documentEdit: DocumentEditSnapshot { DocumentEditSnapshot(state: self) }

        var effectiveSettings: SymbolSettings { artwork?.alignmentSettings(settings) ?? settings }
        var validationMessage: String? { artwork.flatMap { effectiveSettings.validationMessage(for: $0.size) } }
        var canExport: Bool { artwork != nil && !isLoading && !isConverting && alignmentDrag == nil && validationMessage == nil }
    }

    enum Action: BindableAction {
        case documentChanged(SymbolProject?)
        case documentArtworkPrepared(Int, Result<ImportedArtwork, any Error>)
        case alignmentResetButtonTapped
        case artworkPrepared(Result<ImportedArtwork, any Error>)
        case automaticAlignmentToggled(Bool)
        case binding(BindingAction<State>)
        case canvasDragChanged(CGSize)
        case canvasDragEnded
        case recenterButtonTapped
        case fitButtonTapped
        case canvasFitted(Double, CGSize)
        case conversionResponse(Result<SymbolOutput, any Error>)
        case dismissErrorButtonTapped
        case exampleButtonTapped
        case dismissExportConfirmationButtonTapped
        case exportButtonTapped
        case exportCompleted(Result<URL, any Error>)
        case guideDragChanged(AlignmentGuide, Double, snapDistance: Double = 0)
        case guideDragEnded
        case reference(ReferenceFeature.Action)
        case importButtonTapped
        case importCompleted(Result<URL, any Error>)
        case sourceLoaded(Data, String)
        case sourceLoadFailed(String)
        case symbolSettingsResetButtonTapped
        case weightPreviewResponse(Int, Result<SymbolOutput, any Error>)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.symbolClient) var symbolClient
    @Dependency(\.referenceSymbols) var referenceSymbols
    private enum CancelID { case conversion, preparation, fileRead, weightPreview }

    var body: some ReducerOf<Self> {
        Scope(state: \.reference, action: \.reference) { ReferenceFeature() }
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .documentChanged(let project):
                let revision = state.documentRevision + 1
                let previewRevision = state.weightPreviewRevision + 1
                guard let project else {
                    state = State()
                    state.documentRevision = revision
                state.weightPreviewRevision = previewRevision
                    return .merge(.cancel(id: CancelID.preparation), .cancel(id: CancelID.fileRead),
                                  .cancel(id: CancelID.conversion), .cancel(id: CancelID.weightPreview))
                }
                let cachedArtwork = state.source == project.source ? state.artwork : nil
                let cachedPreview = state.source == project.source && !state.isGeneratingWeights ? state.weightPreview : nil
                let cachedPreviewSettings = state.source == project.source ? state.weightPreviewSettings : nil
                let manifest = project.manifest
                state = State()
                state.documentRevision = revision
                state.weightPreviewRevision = previewRevision
                state.source = project.source
                state.artwork = cachedArtwork
                state.fileName = manifest.name
                state.settings = manifest.settings
                state.reference.kind = manifest.referenceKind
                state.reference.symbolName = manifest.referenceSymbol
                state.reference.draftName = manifest.referenceSymbol
                if !referenceSymbols.exists(manifest.referenceSymbol) {
                    state.reference.error = "This reference symbol isn’t available on this Mac. Choose another reference."
                }
                state.weight = manifest.previewWeight
                state.showGuides = manifest.showGuides
                state.snapToEdges = manifest.snapToEdges
                state.zoom = manifest.zoom
                state.canvasOffset = manifest.canvasOffset
                state.fitOffset = manifest.fitOffset
                state.isFitZoom = manifest.isFitZoom
                state.weightPreview = cachedPreview
                // Only reuse a completed cache; an interrupted generation must restart.
                state.weightPreviewSettings = cachedPreview == nil ? nil : cachedPreviewSettings
                if cachedArtwork != nil {
                    return .merge(.cancel(id: CancelID.preparation), .cancel(id: CancelID.fileRead), settingsChanged(&state))
                }
                state.isLoading = true
                return .merge(
                    .cancel(id: CancelID.fileRead), .cancel(id: CancelID.conversion),
                    .cancel(id: CancelID.weightPreview),
                    .run { send in
                        do {
                            let artwork = try await symbolClient.prepare(project.source)
                            try Task.checkCancellation()
                            await send(.documentArtworkPrepared(revision, .success(artwork)))
                        } catch is CancellationError {
                        } catch { await send(.documentArtworkPrepared(revision, .failure(error))) }
                    }.cancellable(id: CancelID.preparation, cancelInFlight: true)
                )
            case let .documentArtworkPrepared(revision, result):
                guard revision == state.documentRevision else { return .none }
                state.isLoading = false
                switch result {
                case .success(let artwork):
                    state.artwork = artwork
                    return settingsChanged(&state)
                case .failure(let error):
                    state.error = error.localizedDescription
                    return .none
                }

            case .canvasDragChanged(let translation):
                guard state.artwork != nil, state.alignmentDrag == nil,
                      translation.width.isFinite, translation.height.isFinite else { return .none }
                let origin = state.canvasDragOrigin ?? state.canvasOffset
                state.canvasDragOrigin = origin
                state.canvasOffset = CGSize(width: origin.width + translation.width, height: origin.height + translation.height)
                return .none
            case .canvasDragEnded:
                state.canvasDragOrigin = nil
                return .none
            case .recenterButtonTapped:
                state.canvasOffset = .zero
                state.canvasDragOrigin = nil
                return .none
            case .fitButtonTapped:
                guard state.artwork != nil else { return .none }
                state.fitRequest += 1
                return .none
            case let .canvasFitted(zoom, offset):
                guard zoom.isFinite, zoom > 0, offset.width.isFinite, offset.height.isFinite else { return .none }
                state.zoom = zoom
                state.fitOffset = offset
                state.canvasOffset = .zero
                state.canvasDragOrigin = nil
                state.isFitZoom = true
                return .none
            case .binding(\.zoom):
                state.isFitZoom = false
                state.fitOffset = .zero
                return .none
            case let .weightPreviewResponse(revision, result):
                guard revision == state.weightPreviewRevision else { return .none }
                state.isGeneratingWeights = false
                switch result {
                case .success(let output):
                    state.weightPreview = output
                    state.weightPreviewError = nil
                case .failure(let error):
                    state.weightPreviewError = "Weight preview: \(error.localizedDescription)"
                }
                return .none
            case .reference:
                return .none
            case .alignmentResetButtonTapped:
                state.settings.resetAlignment()
                return settingsChanged(&state)
            case .automaticAlignmentToggled(let isAutomatic):
                state.settings.automaticAlignment = isAutomatic
                state.settings.resetAlignment()
                return settingsChanged(&state)
            case .symbolSettingsResetButtonTapped:
                state.settings.resetSymbolSettings()
                return settingsChanged(&state)
            case let .guideDragChanged(guide, delta, snapDistance):
                guard delta.isFinite, let artwork = state.artwork, !state.isLoading else { return .none }
                if state.alignmentDrag == nil {
                    var initial = state.settings
                    if initial.automaticAlignment { initial.resetAlignment() }
                    initial.automaticAlignment = false
                    state.alignmentDrag = AlignmentDrag(guide: guide, initialSettings: initial, sourceSize: artwork.opticalBounds.size)
                }
                guard let drag = state.alignmentDrag, drag.guide == guide else { return .none }
                state.settings = guide.moving(drag.initialSettings, by: delta, sourceSize: drag.sourceSize, snapDistance: state.snapToEdges ? snapDistance : 0)
                state.settings.automaticAlignment = false
                state.output = nil
                state.isConverting = false
                state.error = nil
                state.status = "Adjusting \(guide.title.lowercased())…"
                return .cancel(id: CancelID.conversion)
            case .guideDragEnded:
                state.alignmentDrag = nil
                return settingsChanged(&state)
            case .binding(\.isImporting), .binding(\.isExporting), .binding(\.showGuides), .binding(\.snapToEdges), .binding(\.weight):
                return .none
            case .binding:
                return settingsChanged(&state)
            case .importButtonTapped:
                state.isImporting = true
                return .none
            case .importCompleted(.success(let url)):
                state.isLoading = true
                return .run { send in
                    do {
                        let data = try await symbolClient.read(url)
                        try Task.checkCancellation()
                        await send(.sourceLoaded(data, url.deletingPathExtension().lastPathComponent))
                    } catch is CancellationError {
                    } catch { await send(.sourceLoadFailed(error.localizedDescription)) }
                }
                .cancellable(id: CancelID.fileRead, cancelInFlight: true)
            case .importCompleted(.failure(let error)):
                state.error = error.localizedDescription
                return .none
            case .sourceLoadFailed(let message):
                state.isLoading = false
                state.error = message
                return .none
            case let .sourceLoaded(data, name):
                return prepare(&state, data: data, name: name)
            case .exampleButtonTapped:
                return prepare(&state, data: Data(Self.example.utf8), name: "spark")
            case .artworkPrepared(.success(let artwork)):
                guard let imported = state.pendingImport else { return .none }
                state.pendingImport = nil
                state.source = imported.data
                state.fileName = imported.name
                state.settings = SymbolSettings()
                state.canvasOffset = .zero
                state.canvasDragOrigin = nil
                state.fitOffset = .zero
                state.isFitZoom = false
                state.weightPreview = nil
                state.weightPreviewSettings = nil
                state.weightPreviewError = nil
                state.artwork = artwork
                state.isLoading = false
                state.status = "Ready · Original SVG · Export to create SF Symbol"
                return .none
            case .artworkPrepared(.failure(let error)):
                state.pendingImport = nil
                state.isLoading = false
                state.error = error.localizedDescription
                state.status = "Could not load SVG"
                return .none
            case .dismissExportConfirmationButtonTapped:
                state.exportedURL = nil
                return .none
            case .exportButtonTapped:
                state.exportedURL = nil
                guard state.canExport, let data = state.source else { return .none }
                state.isConverting = true
                state.error = nil
                state.status = "Preparing export…"
                let settings = state.effectiveSettings
                return .run { send in
                    do {
                        let output = try await symbolClient.convert(data, settings)
                        try Task.checkCancellation()
                        await send(.conversionResponse(.success(output)))
                    } catch is CancellationError {
                    } catch { await send(.conversionResponse(.failure(error))) }
                }
                .cancellable(id: CancelID.conversion, cancelInFlight: true)
            case .conversionResponse(.success(let output)):
                guard state.isConverting else { return .none }
                state.output = output
                state.isConverting = false
                state.isExporting = true
                state.status = "Symbol ready to save"
                return .none
            case .conversionResponse(.failure(let error)):
                guard state.isConverting else { return .none }
                state.output = nil
                state.isConverting = false
                state.error = error.localizedDescription
                state.status = "Export needs attention"
                return .none
            case .dismissErrorButtonTapped:
                state.error = nil
                return .none
            case .exportCompleted(.success(let url)):
                state.exportedURL = url
                state.status = "Exported \(url.lastPathComponent)"
                return .none
            case .exportCompleted(.failure(let error)):
                state.error = error.localizedDescription
                return .none
            }
        }
    }

    private func settingsChanged(_ state: inout State) -> Effect<Action> {
        state.alignmentDrag = nil
        state.output = nil
        state.error = nil
        state.isConverting = false
        state.status = state.validationMessage ?? (state.artwork == nil ? "Import an SVG to get started" : "Ready · Original SVG · Export to create SF Symbol")
        return .merge(.cancel(id: CancelID.conversion), refreshWeightPreview(&state))
    }

    private func refreshWeightPreview(_ state: inout State) -> Effect<Action> {
        guard state.settings.generateWeights, let data = state.source, let artwork = state.artwork else {
            if state.weightPreviewSettings != nil {
                state.weightPreviewRevision += 1
                state.weightPreviewSettings = nil
                state.weightPreview = nil
                state.weightPreviewError = nil
                state.isGeneratingWeights = false
            }
            return .cancel(id: CancelID.weightPreview)
        }
        // Preview in the original coordinate system, independent of export guides
        // and size category. Only stroke changes invalidate these cached drawings.
        var settings = SymbolSettings()
        settings.automaticAlignment = false
        settings.generateWeights = true
        settings.minimumStroke = state.settings.minimumStroke
        settings.maximumStroke = state.settings.maximumStroke
        guard settings != state.weightPreviewSettings else { return .none }
        state.weightPreviewSettings = settings
        state.weightPreviewRevision += 1
        state.weightPreviewError = nil
        guard settings.validationMessage(for: artwork.size) == nil else {
            state.isGeneratingWeights = false
            return .cancel(id: CancelID.weightPreview)
        }
        state.isGeneratingWeights = true
        let revision = state.weightPreviewRevision
        return .run { [settings] send in
            do {
                try await clock.sleep(for: .milliseconds(250))
                let output = try await symbolClient.convert(data, settings)
                try Task.checkCancellation()
                await send(.weightPreviewResponse(revision, .success(output)))
            } catch is CancellationError {
            } catch {
                await send(.weightPreviewResponse(revision, .failure(error)))
            }
        }
        .cancellable(id: CancelID.weightPreview, cancelInFlight: true)
    }

    private func prepare(_ state: inout State, data: Data, name: String) -> Effect<Action> {
        state.alignmentDrag = nil
        state.pendingImport = PendingSVGImport(data: data, name: name)
        state.weightPreviewRevision += 1
        state.isGeneratingWeights = false
        state.output = nil
        state.error = nil
        state.isConverting = false
        state.isLoading = true
        state.status = "Loading SVG…"
        return .merge(
            .cancel(id: CancelID.conversion),
            .cancel(id: CancelID.weightPreview),
            .run { send in
                do {
                    let artwork = try await symbolClient.prepare(data)
                    try Task.checkCancellation()
                    await send(.artworkPrepared(.success(artwork)))
                } catch is CancellationError {
                } catch { await send(.artworkPrepared(.failure(error))) }
            }.cancellable(id: CancelID.preparation, cancelInFlight: true)
        )
    }

    static let example = """
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
      <path d="M50 8 L61 37 L90 50 L61 63 L50 92 L39 63 L10 50 L39 37 Z" fill="none" stroke="black" stroke-width="7" stroke-linejoin="round"/>
    </svg>
    """
}
