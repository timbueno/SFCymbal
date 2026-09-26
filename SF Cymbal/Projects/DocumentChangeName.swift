/// Names native undo entries without putting transient interaction state in the document.
enum DocumentChangeName {
    static func name(from old: SymbolProject?, to new: SymbolProject?) -> String {
        guard let old, let new, old.source == new.source else { return "Import SVG" }
        let a = old.manifest
        let b = new.manifest
        if a.settings.minimumStroke != b.settings.minimumStroke || a.settings.maximumStroke != b.settings.maximumStroke { return "Stroke Scale" }
        if a.settings.generateWeights != b.settings.generateWeights { return "Stroke Weights" }
        if a.settings != b.settings { return "Alignment Change" }
        if a.referenceKind != b.referenceKind || a.referenceSymbol != b.referenceSymbol { return "Reference Change" }
        if a.previewWeight != b.previewWeight { return "Preview Weight" }
        if a.showGuides != b.showGuides { return "Guide Visibility" }
        if a.snapToEdges != b.snapToEdges { return "Snapping" }
        if a.zoom != b.zoom || a.isFitZoom != b.isFitZoom { return "Zoom" }
        return "Canvas Position"
    }
}
