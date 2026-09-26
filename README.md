# SF Cymbal

A small native macOS app for turning SVG artwork into custom SF Symbols. Uses Point-Free’s Composable Architecture 1.26.2 for editor state and effects and SwiftDraw 0.29.0 for SVG parsing, rendering, and SF Symbols export. Requires macOS 14 or later.

## Status

SF Cymbal is in early development. This repository currently provides source code; a signed, notarized download has not been published yet.

## Run

The project is currently built and tested with **Xcode 27.1 beta**. Older Xcode versions have not been verified. The deployment target is macOS 14. Package versions are pinned in `Package.resolved`.


Open `SF Cymbal.xcodeproj`, select **SF Cymbal** and **My Mac**, and run. Allow Xcode to resolve the pinned Swift packages and enable the Point-Free package macros when prompted.

## Editing

Choose **File → Import SVG… (⇧⌘I)**, drop an SVG onto the window, or choose **Try an example**.

The original SVG stays at a fixed size and position while you edit alignment. Zoom and window resizing determine the canvas scale. Dragging guides and entering values are immediate layout updates: they do not reparse the artwork or generate an SF Symbol.

- The **Reference** button lets you choose the letter **A** or any SF Symbol available on your Mac by entering its system name (for example, `heart.fill` or `square.and.arrow.up`). A few common symbols are offered as shortcuts. Invalid names leave the last valid reference visible and show a message. The reference is a comparison aid and is never included in the export.
- The reference fits between cap and baseline guides and sits just left of the left-margin guide. Its size follows cap/baseline spacing; its horizontal placement follows the left margin.
- **Snap** in the top row snaps dragged guides to their corresponding visible artwork edge within eight screen points. It is on by default and can be turned off; typed values are not snapped. Zoom presets range from 10% to 150%.
- Left/right guides indicate the symbol’s alignment width. Changing right-side spacing does not move the source artwork.
- The weight selector changes the reference and, when stroke generation is enabled, the cached artwork variant.
- **Fit guides to artwork** measures visible bounds once at import. The four displayed values are offsets from those edges, so a fitted guide reads zero. The alpha measurement has a maximum resolution of 1024 pixels on its longest side; the same resolved bounds are passed to export.
- Toggling Fit guides to artwork in either direction clears all user insets. Manual zero also means the visible artwork edge; internal canvas whitespace is accounted for automatically when generating the export. Positive offsets move inward and negative offsets add space.
- Dragging from fitted mode starts with all four values at zero and switches to manual mode without moving the source. Snapping back to an artwork edge returns the corresponding value to zero. Opposite guides cannot cross.
- The Alignment reset clears all insets while preserving the mode. Stroke weights reset restores default stroke generation settings independently.

## App preferences and feedback

The Reference popover’s **Use as Default for New Documents** button remembers your preferred letter or system symbol. Existing documents retain their own reference and artwork settings. New windows restore the last editor window size.

Undo menu entries describe alignment, stroke scale, reference, zoom, and other changes. After exporting, a quiet confirmation offers **Show in Finder** and **Dismiss**. Export validation identifies unsupported SVG content and explains how to repair it in the source drawing app.

## Saving projects

Each window edits a native `.sfcymbal` document. Use **File → New (⌘N)** for a blank document, **Open… (⌘O)** or Open Recent for saved projects, and **Save (⌘S)** to choose its location. macOS manages autosave, unsaved changes, undo/redo, and the standard Duplicate, Rename, Move, and Revert commands. Import SVG replaces the artwork in the current document; opening or dropping a saved project opens its own document. Exporting an SF Symbol remains a separate operation.

Finder presents the package as one document. Internally it contains:

```text
spark.sfcymbal/
  source.svg
  project.json
```

`source.svg` is an unchanged copy of the imported SVG. `project.json` uses format version 1 and records the symbol name, alignment settings, stroke scales, reference choice, preview weight, guide visibility, snapping, zoom, and canvas offsets. Source content is embedded, so moving the package or deleting the original SVG does not break it. Previews, errors, selections, and in-progress operations are not saved; previews are regenerated when opening.

Blank documents can also be saved: their package contains only a versioned `project.json` with an `empty` marker. Existing version 1 projects remain compatible. Files with missing components, malformed metadata, invalid SVG content, or unsupported versions are rejected. Failed SVG imports preserve the current document and artwork.

## Export

Exports use the Small template. Optionally enable stroke-based weight generation. Use **⇧⌘E** to generate the SF Symbols SVG and choose its save location. The exporter receives the current alignment bounds and generates Ultralight, Regular, and Black masters for the Small template. The canvas stays visible while export runs.

Filled paths retain their original weight; stroke multipliers affect strokes. Masks, filters, and bitmap images cannot be faithfully represented by the outline exporter and are rejected on export. Incompatible weight-master path structures are also rejected. Export errors leave the source canvas available for further editing.

Import the exported `.svg` into Apple’s SF Symbols app for review or an Xcode asset catalog as a symbol image set. Exports use the Small source masters required for variable-symbol interpolation.

## Architecture and verification

- `ProjectDocument` / `DocumentGroup`: native document lifecycle and versioned package storage.
- `DocumentEditorView`: synchronizes the native document binding with a separate TCA store per window, including undo and revert. Completed drags publish one document edit; intermediate rendering state is excluded.
- `EditorFeature`: TCA import, local editing, reset/drag actions, and export-on-demand effects.
- `ArtworkLoader`: one-time source parsing and automatic optical-bound measurement.
- `CanvasLayout`: source-frame, guide, and reference-letter geometry independent of export normalization.
- `ReferenceLetterView` / `ReferenceSymbolView`: cached letter outlines or configured system symbols positioned against the guides.
- `SymbolConverter`: actor-isolated SwiftDraw export, path validation, and temporary-file cleanup.

Run the shared scheme’s Swift Testing suites with **⌘U** or:

```sh
xcodebuild -project "SF Cymbal.xcodeproj" -scheme "SF Cymbal" \
  -destination 'platform=macOS' -skipMacroValidation CODE_SIGNING_ALLOWED=NO test
```

Tests cover export structure, invalid artwork, automatic bounds with a nonzero viewBox origin, fixed artwork layout, reference-letter geometry, local-only editing, resets, guide dragging, conversion only when export is requested, package compatibility and validation, native document state restoration, completed-drag publication, and failed-import preservation.

## Contributing

Issues and focused pull requests are welcome. SF Cymbal is an alignment and conversion utility, rather than a vector drawing app. Please discuss larger changes in an issue first.

Run the tests before submitting a pull request. When reporting a conversion problem, include a minimal SVG you have permission to share, reproduction steps, and your macOS/Xcode versions.

## Dependencies

Full license texts for the pinned dependencies are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

- [SwiftDraw](https://github.com/swhitty/SwiftDraw), by Simon Whitty (zlib license).
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture), by Point-Free (MIT license).

## License

Copyright © 2026 Tim Bueno. SF Cymbal is licensed under the [GNU General Public License v3.0](LICENSE) (GPL-3.0-only).

Third-party dependencies remain under their respective licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
