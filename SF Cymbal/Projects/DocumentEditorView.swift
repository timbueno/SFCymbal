import Combine
import ComposableArchitecture
import SwiftUI

/// Bridges persistent TCA state to the native document binding in both directions.
struct DocumentEditorView: View {
    @Environment(\.undoManager) private var undoManager
    @AppStorage("preferredReferenceKind") private var preferredReferenceKind = ReferenceKind.letter.rawValue
    @AppStorage("preferredReferenceSymbol") private var preferredReferenceSymbol = "star"
    @Binding var document: ProjectDocument
    let fileURL: URL?
    @State private var store = Store(initialState: EditorFeature.State()) { EditorFeature() }
    @State private var synchronizedProject: SymbolProject?
    @State private var editorWindow: NSWindow?
    @State private var undoMenu = DocumentUndoMenu(manager: nil)
    @State private var hasLoaded = false

    var body: some View {
        ContentView(store: store, documentTitle: fileURL?.deletingPathExtension().lastPathComponent)
            .background(WindowFramePersistence { window in
                DispatchQueue.main.async {
                    editorWindow = window
                    undoMenu = DocumentUndoMenu(manager: window.undoManager)
                }
            })
            .focusedSceneValue(\.documentUndoMenu, undoMenu)
            .onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)
                .merge(with: NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange))) { notification in
                guard let manager = notification.object as? UndoManager,
                      manager === (editorWindow?.undoManager ?? undoManager) else { return }
                DispatchQueue.main.async { undoMenu = DocumentUndoMenu(manager: manager) }
            }
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                synchronizedProject = document.project
                store.send(.documentChanged(document.project))
                if document.project == nil {
                    store.send(.reference(.symbolNameChanged(preferredReferenceSymbol)))
                    store.send(.reference(.kindChanged(ReferenceKind(rawValue: preferredReferenceKind) ?? .letter)))
                }
            }
            .onChange(of: document.project) { _, project in
                // Native undo, redo, and revert update the binding, then the editor.
                guard project != synchronizedProject else { return }
                synchronizedProject = project
                store.send(.documentChanged(project))
            }
            .onChange(of: store.documentEdit) { _, snapshot in
                guard hasLoaded, snapshot.isStable, snapshot.project != synchronizedProject else { return }
                // Never publish a snapshot that cannot be autosaved.
                if let project = snapshot.project, (try? project.manifest.validate()) == nil { return }
                let name = DocumentChangeName.name(from: synchronizedProject, to: snapshot.project)
                synchronizedProject = snapshot.project
                document.project = snapshot.project
                // FileDocument registers its undo operation after the binding update.
                DispatchQueue.main.async {
                    let manager = editorWindow?.undoManager ?? undoManager
                    manager?.setActionName(name)
                    undoMenu = DocumentUndoMenu(manager: manager)
                }
            }
    }
}
