import SwiftUI
import UniformTypeIdentifiers

struct SymbolDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.svg] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
