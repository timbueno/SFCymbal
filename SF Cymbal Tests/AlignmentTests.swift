import CoreGraphics
import CustomDump
import Foundation
import Testing
@testable import SF_Cymbal

struct AlignmentTests {
    @Test func dragDirectionsMatchInsets() {
        var settings = SymbolSettings()
        settings.left = 10
        settings.right = 10
        settings.top = 20
        settings.bottom = 20
        let size = CGSize(width: 100, height: 100)
        expectNoDifference(AlignmentGuide.left.moving(settings, by: 5, sourceSize: size).left, 15)
        expectNoDifference(AlignmentGuide.right.moving(settings, by: 5, sourceSize: size).right, 5)
        expectNoDifference(AlignmentGuide.top.moving(settings, by: 5, sourceSize: size).top, 25)
        expectNoDifference(AlignmentGuide.bottom.moving(settings, by: 5, sourceSize: size).bottom, 15)
    }

    @Test(arguments: AlignmentGuide.allCases)
    func guidesCannotCross(guide: AlignmentGuide) {
        let delta = guide == .left || guide == .top ? 1000.0 : -1000.0
        let settings = guide.moving(SymbolSettings(), by: delta, sourceSize: CGSize(width: 100, height: 100))
        #expect(settings.left + settings.right < 100)
        #expect(settings.top + settings.bottom < 100)
    }

    @Test(arguments: ["Ultralight", "Regular", "Black"])
    func leavingAutomaticPreservesSelectedOutline(weight: String) async throws {
        var settings = SymbolSettings()
        settings.generateWeights = true
        let source = Data(EditorFeature.example.utf8)
        let automatic = try await SymbolConverter.shared.convert(data: source, settings: settings)
        let geometry = try #require(automatic.alignment[weight])
        let manual = try await SymbolConverter.shared.convert(data: source, settings: geometry.manualSettings(from: settings))
        let before = try XMLDocument(data: automatic.data)
        let after = try XMLDocument(data: manual.data)
        let xpath = "//*[@id='\(weight)-S']"
        let first = try #require(before.nodes(forXPath: xpath).first as? XMLElement)
        let second = try #require(after.nodes(forXPath: xpath).first as? XMLElement)
        let original = try ExportedPathBounds.bounds(of: first)
        let updated = try ExportedPathBounds.bounds(of: second)
        #expect(abs(original.minX - updated.minX) < 0.002)
        #expect(abs(original.minY - updated.minY) < 0.002)
        #expect(abs(original.width - updated.width) < 0.002)
        #expect(abs(original.height - updated.height) < 0.002)
    }
}

extension AlignmentTests {
    @Test func zeroManualInsetsUseFullSVGCanvas() async throws {
        let xml = "<svg xmlns='http://www.w3.org/2000/svg' width='200' height='100' viewBox='10 20 200 100'><rect x='40' y='35' width='100' height='50'/></svg>"
        var settings = SymbolSettings()
        settings.automaticAlignment = false
        let output = try await SymbolConverter.shared.convert(data: Data(xml.utf8), settings: settings)
        let alignment = try #require(output.alignment["Regular"])
        expectNoDifference(alignment.sourceBounds, CGRect(x: 0, y: 0, width: 200, height: 100))
        expectNoDifference(alignment.manualSettings(from: settings), settings)
        #expect(abs(alignment.previewBounds.width - 88) < 0.001)
        #expect(abs(alignment.previewBounds.height - 44) < 0.001)
    }
}
