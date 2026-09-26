import SwiftUI

struct DocumentUndoMenu {
    var manager: UndoManager?
    var undoTitle: String
    var redoTitle: String
    var canUndo: Bool
    var canRedo: Bool

    init(manager: UndoManager?) {
        self.manager = manager
        undoTitle = manager?.undoMenuItemTitle ?? "Undo"
        redoTitle = manager?.redoMenuItemTitle ?? "Redo"
        canUndo = manager?.canUndo ?? false
        canRedo = manager?.canRedo ?? false
    }
}

private struct DocumentUndoMenuKey: FocusedValueKey {
    typealias Value = DocumentUndoMenu
}

extension FocusedValues {
    var documentUndoMenu: DocumentUndoMenu? {
        get { self[DocumentUndoMenuKey.self] }
        set { self[DocumentUndoMenuKey.self] = newValue }
    }
}
