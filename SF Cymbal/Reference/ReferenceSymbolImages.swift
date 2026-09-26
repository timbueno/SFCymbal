import AppKit

/// Cache configured system images; guide dragging changes geometry only.
@MainActor
final class ReferenceSymbolImages {
    static let shared = ReferenceSymbolImages()
    private let cache = NSCache<NSString, NSImage>()

    private init() { cache.countLimit = 48 }

    func image(name: String, weight: String) -> NSImage? {
        let key = "\(name)|\(weight)" as NSString
        if let image = cache.object(forKey: key) { return image }
        let fontWeight: NSFont.Weight = switch weight {
        case "Ultralight": .ultraLight
        case "Black": .black
        default: .regular
        }
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: name),
              let image = base.withSymbolConfiguration(.init(pointSize: 100, weight: fontWeight)),
              image.size.width > 0, image.size.height > 0,
              image.alignmentRect.height > 0 else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
