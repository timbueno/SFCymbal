import CoreGraphics
import CustomDump
import Foundation
import Testing
@testable import SF_Cymbal

struct CanvasLayoutTests {
    @Test func symbolPreservesBaselineOvershootAndSideBearings() {
        let layout = CanvasLayout(canvasSize: CGSize(width: 900, height: 600), sourceSize: CGSize(width: 100, height: 100), settings: SymbolSettings(), zoom: 1)
        let size = CGSize(width: 140, height: 120)
        let alignment = CGRect(x: 8, y: 20, width: 110, height: 70)
        let frame = layout.referenceSymbolFrame(imageSize: size, alignmentRect: alignment)
        let scale = frame.height / size.height

        // The image extends past the guides, while its intrinsic baseline and
        // cap line land on them exactly. Badge space remains beyond the bearing.
        #expect(frame.minY < layout.guideFrame.minY)
        #expect(frame.maxY > layout.guideFrame.maxY)
        #expect(abs(frame.maxY - alignment.minY * scale - layout.guideFrame.maxY) < 0.0001)
        #expect(abs(frame.maxY - alignment.maxY * scale - layout.guideFrame.minY) < 0.0001)
        #expect(abs(frame.minX + alignment.maxX * scale - layout.referenceFrame(aspectRatio: 1).maxX) < 0.0001)
        #expect(abs(frame.width / frame.height - size.width / size.height) < 0.0001)
    }

    @Test func artworkStaysFixedWhileLetterAndGuidesMove() {
        var settings = SymbolSettings()
        settings.automaticAlignment = false
        let canvas = CGSize(width: 900, height: 600)
        let source = CGSize(width: 100, height: 100)
        let initial = CanvasLayout(canvasSize: canvas, sourceSize: source, settings: settings, zoom: 1)
        settings.top = 15
        settings.bottom = 20
        settings.left = -30
        settings.right = -10
        let edited = CanvasLayout(canvasSize: canvas, sourceSize: source, settings: settings, zoom: 1)
        expectNoDifference(edited.artworkFrame, initial.artworkFrame)
        #expect(edited.referenceFrame(aspectRatio: 0.8).height < initial.referenceFrame(aspectRatio: 0.8).height)
        #expect(edited.referenceFrame(aspectRatio: 0.8).maxX < initial.referenceFrame(aspectRatio: 0.8).maxX)
        #expect(edited.guideFrame.maxX > initial.guideFrame.maxX)
        expectNoDifference(edited.referenceFrame(aspectRatio: 0.8).minY, edited.guideFrame.minY)
        expectNoDifference(edited.referenceFrame(aspectRatio: 0.8).maxY, edited.guideFrame.maxY)
    }

    @Test func zeroInsetsMatchSourceCanvas() {
        let layout = CanvasLayout(canvasSize: CGSize(width: 900, height: 600), sourceSize: CGSize(width: 200, height: 80), settings: SymbolSettings(), zoom: 1)
        expectNoDifference(layout.guideFrame, layout.artworkFrame)
    }

    @Test func automaticBoundsRespectAsymmetricSourceAndViewBox() throws {
        let xml = "<svg xmlns='http://www.w3.org/2000/svg' width='200' height='100' viewBox='10 20 200 100'><rect x='40' y='35' width='100' height='50'/></svg>"
        let artwork = try ArtworkLoader.load(Data(xml.utf8))
        #expect(abs(artwork.opticalBounds.minX - 30) < 0.4)
        #expect(abs(artwork.opticalBounds.minY - 15) < 0.4)
        #expect(abs(artwork.opticalBounds.width - 100) < 0.4)
        #expect(abs(artwork.opticalBounds.height - 50) < 0.4)
        let settings = artwork.alignmentSettings(SymbolSettings())
        #expect(!settings.automaticAlignment)
        #expect(abs(settings.bottom - 35) < 0.4)
    }
}
