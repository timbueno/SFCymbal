import CustomDump
import Foundation
import Testing
@testable import SF_Cymbal

struct SymbolConverterTests {
    @Test(arguments: SymbolSettings.SymbolSize.allCases)
    func exportsThreeMasters(size: SymbolSettings.SymbolSize) async throws {
        var settings = SymbolSettings()
        settings.size = size
        let result = try await SymbolConverter.shared.convert(data: Data(EditorFeature.example.utf8), settings: settings)
        let document = try XMLDocument(data: result.data)
        for weight in ["Ultralight", "Regular", "Black"] {
            let paths = try document.nodes(forXPath: "//*[@id='\(weight)-\(size.rawValue)']/*[local-name()='path']")
            #expect(!paths.isEmpty)
            #expect(result.previews[weight] != nil)
        }
        #expect(result.pathCount > 0)
    }

    @Test func strokeWeightsProduceDifferentOutlines() async throws {
        var settings = SymbolSettings()
        settings.generateWeights = true
        let result = try await SymbolConverter.shared.convert(data: Data(EditorFeature.example.utf8), settings: settings)
        #expect(result.previews["Ultralight"] != result.previews["Black"])
    }

    @Test func manualInsetsChangeExport() async throws {
        var settings = SymbolSettings()
        settings.automaticAlignment = false
        let first = try await SymbolConverter.shared.convert(data: Data(EditorFeature.example.utf8), settings: settings)
        settings.top = 10
        let second = try await SymbolConverter.shared.convert(data: Data(EditorFeature.example.utf8), settings: settings)
        #expect(first.data != second.data)
    }

    @Test func rejectsInvalidInsets() async {
        var settings = SymbolSettings()
        settings.automaticAlignment = false
        settings.top = 100
        await #expect(throws: (any Error).self) {
            try await SymbolConverter.shared.convert(data: Data(EditorFeature.example.utf8), settings: settings)
        }
    }

    @Test(arguments: ["not SVG", "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'/>", "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100'><mask id='mask'/><rect width='50' height='50'/></svg>"])
    func rejectsUnusableArtwork(xml: String) async {
        await #expect(throws: (any Error).self) {
            try await SymbolConverter.shared.convert(data: Data(xml.utf8), settings: SymbolSettings())
        }
    }
}
