import AppKitShim
import UIKit

/// Draws a symbol by the pixels it actually shows. iPadOS's copy of a private symbol
/// has its own box and colors, so laying out the macOS metrics against it leaves the
/// glyph off-size and off-center; only its shape is used here.
enum PadCenteredSymbol {
    private static let side: CGFloat = 128
    private static var glyphs: [String: UIImage] = [:]

    static func draw(_ name: String, in frame: CGRect, visibleHeight: CGFloat, color: NSColor) {
        let resolved = color.usingColorSpace(.deviceRGB) ?? color
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let key = "\(name) \(red) \(green) \(blue) \(alpha)"
        guard let glyph = glyphs[key] ?? makeGlyph(name, color: resolved), glyph.size.height > 0 else { return }
        glyphs[key] = glyph
        let width = visibleHeight * glyph.size.width / glyph.size.height
        glyph.draw(
            in: CGRect(x: frame.midX - width / 2, y: frame.midY - visibleHeight / 2, width: width, height: visibleHeight),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    /// The symbol in `color`, cropped to what it shows.
    private static func makeGlyph(_ name: String, color: UIColor) -> UIImage? {
        guard let symbol = SakuraCordSystemSymbol.image(named: name) else { return nil }
        let configuration = UIImage.SymbolConfiguration(pointSize: side, weight: UIImage.SymbolWeight.medium)
        let sized = symbol.applyingSymbolConfiguration(configuration) ?? symbol
        guard sized.size.width > 0, sized.size.height > 0 else { return nil }
        let scale = side / max(sized.size.width, sized.size.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let canvas = CGRect(x: 0, y: 0, width: side, height: side)
        let tinted = UIGraphicsImageRenderer(size: canvas.size, format: format).image { context in
            sized.draw(in: CGRect(x: 0, y: 0, width: sized.size.width * scale, height: sized.size.height * scale))
            color.setFill()
            context.fill(canvas, blendMode: .sourceIn)
        }
        guard let image = tinted.cgImage, let visible = visibleBounds(of: image),
              let cropped = image.cropping(to: visible)
        else { return nil }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    private static func visibleBounds(of image: CGImage) -> CGRect? {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        return pixels.withUnsafeMutableBytes { raw -> CGRect? in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0 ..< height {
                for x in 0 ..< width where raw[(y * width + x) * 4 + 3] > 24 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
            guard maxX >= minX, maxY >= minY else { return nil }
            return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
    }
}
