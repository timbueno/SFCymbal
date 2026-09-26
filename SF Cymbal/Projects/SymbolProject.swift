import Foundation

struct SymbolProject: Equatable, Sendable {
    var source: Data
    var manifest: ProjectManifest

    init(source: Data, manifest: ProjectManifest) {
        self.source = source
        self.manifest = manifest
    }

    init(wrapper: FileWrapper) throws {
        guard wrapper.isDirectory,
              let source = wrapper.fileWrappers?["source.svg"], source.isRegularFile,
              let data = source.regularFileContents,
              let metadata = wrapper.fileWrappers?["project.json"], metadata.isRegularFile,
              let json = metadata.regularFileContents else {
            throw SymbolConverter.ConversionError("This is not a valid SF Cymbal project. The package must contain source.svg and project.json.")
        }
        // Read the version first, so newer schemas get a useful error even if their fields differ.
        struct Header: Decodable { var formatVersion: Int }
        let decoder = JSONDecoder()
        let header = try decoder.decode(Header.self, from: json)
        guard header.formatVersion == 1 else {
            throw SymbolConverter.ConversionError("This project requires a newer version of SF Cymbal (format \(header.formatVersion)).")
        }
        var manifest = try decoder.decode(ProjectManifest.self, from: json)
        // Older projects used Medium; Small supplies the interpolation source masters.
        try manifest.validate()
        manifest.settings.size = .small
        self.init(source: data, manifest: manifest)
    }

    func fileWrapper() throws -> FileWrapper {
        try manifest.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(directoryWithFileWrappers: [
            "source.svg": FileWrapper(regularFileWithContents: source),
            "project.json": FileWrapper(regularFileWithContents: try encoder.encode(manifest))
        ])
    }
}
