import SwiftUI

struct AppCommands: Commands {
    @Environment(\.newDocument) private var newDocument
    @FocusedValue(\.documentUndoMenu) private var undoMenu
    @FocusedValue(\.importSVG) private var importSVG
    @FocusedValue(\.exportSymbol) private var exportSymbol

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(undoMenu?.undoTitle ?? "Undo") { undoMenu?.manager?.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(undoMenu?.canUndo != true)
            Button(undoMenu?.redoTitle ?? "Redo") { undoMenu?.manager?.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(undoMenu?.canRedo != true)
        }
        CommandGroup(after: .newItem) {
            Button("Import SVG…") { importSVG?() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(importSVG == nil)
        }
        CommandGroup(after: .saveItem) {
            Button("Export SF Symbol…") { exportSymbol?() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(exportSymbol == nil)
        }
        CommandGroup(before: .windowArrangement) {
            Button("New SF Cymbals Window") { newDocument(ProjectDocument()) }
        }
    }
}

private struct ImportSVGKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct ExportSymbolKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var exportSymbol: (() -> Void)? {
        get { self[ExportSymbolKey.self] }
        set { self[ExportSymbolKey.self] = newValue }
    }
    var importSVG: (() -> Void)? {
        get { self[ImportSVGKey.self] }
        set { self[ImportSVGKey.self] = newValue }
    }
}
