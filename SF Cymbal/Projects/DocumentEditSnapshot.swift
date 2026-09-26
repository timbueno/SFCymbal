/// Only completed edits enter the document binding, so a drag is one native undo step.
struct DocumentEditSnapshot: Equatable {
    var project: SymbolProject?
    var isStable: Bool

    init(state: EditorFeature.State) {
        project = state.project
        isStable = !state.isLoading && state.alignmentDrag == nil && state.canvasDragOrigin == nil
            && (state.source == nil || state.artwork != nil)
    }
}
