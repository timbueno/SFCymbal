import CoreGraphics
import Foundation

struct CanvasLayout {
    let artworkFrame: CGRect
    let guideFrame: CGRect
    let sourceScale: Double

    init(canvasSize: CGSize, sourceSize: CGSize, settings: SymbolSettings, zoom: Double, offset: CGSize = .zero) {
        sourceScale = min(canvasSize.width * 0.42 / sourceSize.width,
                          canvasSize.height * 0.58 / sourceSize.height) * zoom
        let width = sourceSize.width * sourceScale
        let height = sourceSize.height * sourceScale
        artworkFrame = CGRect(x: canvasSize.width * 0.65 - width / 2 + offset.width,
                              y: canvasSize.height / 2 - height / 2 + offset.height, width: width, height: height)
        let valid = settings.validationMessage(for: sourceSize) == nil
        let left = valid ? settings.left : 0
        let right = valid ? settings.right : 0
        let top = valid ? settings.top : 0
        let bottom = valid ? settings.bottom : 0
        guideFrame = CGRect(x: artworkFrame.minX + left * sourceScale,
                            y: artworkFrame.minY + top * sourceScale,
                            width: (sourceSize.width - left - right) * sourceScale,
                            height: (sourceSize.height - top - bottom) * sourceScale)
    }

    func referenceFrame(aspectRatio: Double) -> CGRect {
        let height = guideFrame.height
        let width = height * aspectRatio
        let gap = max(16, min(40, artworkFrame.width * 0.08))
        return CGRect(x: guideFrame.minX - gap - width, y: guideFrame.minY, width: width, height: height)
    }

    func generatedArtworkFrame(viewport: CGSize, geometry: AlignmentGeometry) -> CGRect {
        let scale = sourceScale / geometry.previewScale
        return CGRect(
            x: artworkFrame.minX + geometry.sourceBounds.minX * sourceScale - geometry.previewBounds.minX * scale,
            y: artworkFrame.minY + geometry.sourceBounds.minY * sourceScale - geometry.previewBounds.minY * scale,
            width: viewport.width * scale,
            height: viewport.height * scale
        )
    }

    /// AppKit's alignment rectangle uses bottom-up image coordinates. Its bottom
    /// is the symbol baseline and its height is the configured cap height.
    func referenceSymbolFrame(imageSize: CGSize, alignmentRect: CGRect) -> CGRect {
        let scale = guideFrame.height / alignmentRect.height
        let alignmentRight = referenceFrame(aspectRatio: 1).maxX
        return CGRect(
            x: alignmentRight - alignmentRect.maxX * scale,
            y: guideFrame.maxY - (imageSize.height - alignmentRect.minY) * scale,
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }
}
