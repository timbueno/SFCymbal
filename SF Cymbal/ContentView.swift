import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: StoreOf<EditorFeature>
    var documentTitle: String?
    @Environment(\.openDocument) private var openDocument
    @State private var isChoosingReference = false

    private var editor: some View {
        NavigationSplitView {
            InspectorView(store: store)
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 340)
        } detail: {
            SymbolCanvasView(store: store)
            .navigationTitle(documentTitle ?? (store.source == nil ? "Untitled" : store.fileName))
            .navigationSubtitle(store.artwork == nil ? "" : store.settings.generateWeights ? "3 weights" : "Regular weight")
            .toolbar { editorToolbar }
        }
    }

    var body: some View {
        editor
        .overlay(alignment: .bottom) {
            if let url = store.exportedURL {
                HStack(spacing: 12) {
                    Label("Exported \(url.lastPathComponent)", systemImage: "checkmark.circle")
                        .lineLimit(1).truncationMode(.middle)
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    Button("Dismiss", systemImage: "xmark") { store.send(.dismissExportConfirmationButtonTapped) }
                        .labelStyle(.iconOnly).buttonStyle(.plain).help("Dismiss")
                }
                .font(.callout)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(20)
            }
        }
        .focusedSceneValue(\.importSVG, { store.send(.importButtonTapped) })
        .focusedSceneValue(\.exportSymbol, command(.exportButtonTapped, enabled: store.canExport))
        .tint(.teal)
        .frame(minWidth: 860, minHeight: 640)
        .fileImporter(isPresented: $store.isImporting, allowedContentTypes: [.svg]) {
            store.send(.importCompleted($0))
        }
        .fileExporter(isPresented: $store.isExporting, document: store.output.map { SymbolDocument(data: $0.data) }, contentType: .svg,
                      defaultFilename: "\(store.fileName).svg") {
            store.send(.exportCompleted($0))
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, ["svg", "sfcymbal"].contains(url.pathExtension.lowercased()) else { return false }
            if url.pathExtension.lowercased() == "sfcymbal" {
                Task { @MainActor in
                    do { try await openDocument(at: url) }
                    catch { store.send(.sourceLoadFailed(error.localizedDescription)) }
                }
            } else {
                store.send(.importCompleted(.success(url)))
            }
            return true
        }
    }
    private func command(_ action: EditorFeature.Action, enabled: Bool) -> (() -> Void)? {
        guard enabled else { return nil }
        return { store.send(action) }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button("Reference", systemImage: store.reference.kind == .letter ? "textformat" : store.reference.symbolName) {
                isChoosingReference = true
            }
            .help("Choose reference")
            .popover(isPresented: $isChoosingReference) {
                ReferencePickerView(store: store.scope(state: \.reference, action: \.reference))
            }
            .disabled(store.artwork == nil)
            Picker("Weight", selection: $store.weight) {
                Text("Ultralight").tag("Ultralight")
                Text("Regular").tag("Regular")
                Text("Black").tag("Black")
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 110)
            .disabled(store.artwork == nil)
            .help("Preview weight")
            Menu {
                Button("Fit") { store.send(.fitButtonTapped) }
                Divider()
                Button("10%") { store.zoom = 0.1 }
                Button("25%") { store.zoom = 0.25 }
                Button("50%") { store.zoom = 0.5 }
                Button("75%") { store.zoom = 0.75 }
                Button("100%") { store.zoom = 1 }
                Button("125%") { store.zoom = 1.25 }
                Button("150%") { store.zoom = 1.5 }
            } label: {
                if store.isFitZoom {
                    Text("Fit")
                } else {
                    Text(store.zoom, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                }
            }
            .disabled(store.artwork == nil)
            .help("Zoom")
            .accessibilityLabel("Zoom")
            .accessibilityValue(Text(store.zoom, format: .percent))
        }
        ToolbarItemGroup {
            Toggle("Snap", systemImage: "dot.scope", isOn: $store.snapToEdges)
                .toggleStyle(.button)
                .tint(nil)
                .help("Snap to artwork")
            Toggle("Show guides", systemImage: "grid", isOn: $store.showGuides)
                .toggleStyle(.button)
                .tint(nil)
                .help("Show guides")
        }
        if #available(macOS 26.0, *) {
            ToolbarSpacer(.fixed)
        }
        ToolbarItem {
            Button("Export Symbol", systemImage: "square.and.arrow.up") {
                store.send(.exportButtonTapped)
            }
            .disabled(!store.canExport)
            .help("Export SF Symbol")
        }

    }

}

#Preview {
    ContentView(store: Store(initialState: EditorFeature.State()) { EditorFeature() })
}
