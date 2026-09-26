import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let sfCymbalProject = UTType(exportedAs: "dev.sfcymbal.project", conformingTo: .package)
}

struct ProjectDocument: FileDocument, Equatable {
    static var readableContentTypes: [UTType] { [.sfCymbalProject] }
    var project: SymbolProject?

    init(project: SymbolProject? = nil) { self.project = project }

    init(configuration: ReadConfiguration) throws {
        try self.init(wrapper: configuration.file)
    }

    init(wrapper: FileWrapper) throws {
        guard wrapper.isDirectory,
              let metadata = wrapper.fileWrappers?["project.json"], metadata.isRegularFile,
              let data = metadata.regularFileContents else {
            throw SymbolConverter.ConversionError("The project package is missing project.json.")
        }
        let header = try JSONDecoder().decode(Header.self, from: data)
        guard header.formatVersion == 1 else {
            throw SymbolConverter.ConversionError("Unsupported project format version \(header.formatVersion).")
        }
        if header.empty == true {
            guard wrapper.fileWrappers?["source.svg"] == nil else {
                throw SymbolConverter.ConversionError("The empty project contains unexpected source artwork.")
            }
            project = nil
        } else {
            let loaded = try SymbolProject(wrapper: wrapper)
            // Reject unusable source data during the native open operation.
            _ = try ArtworkLoader.load(loaded.source)
            project = loaded
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try package()
    }

    func package() throws -> FileWrapper {
        if let project { return try project.fileWrapper() }
        return FileWrapper(directoryWithFileWrappers: [
            "project.json": FileWrapper(regularFileWithContents: try JSONEncoder().encode(Header(formatVersion: 1, empty: true)))
        ])
    }

    private struct Header: Codable {
        var formatVersion: Int
        var empty: Bool?
    }
}
