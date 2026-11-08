#if os(iOS)
import UIKit

// The attributed renderer is written against AppKit's names; on iOS the same
// code draws with their UIKit equivalents.
typealias NSFont = UIFont
typealias NSColor = UIColor

extension UIColor {
    static var labelColor: UIColor { .label }
    static var secondaryLabelColor: UIColor { .secondaryLabel }
    static var linkColor: UIColor { .link }

    convenience init(srgbRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

struct NSFontTraitMask: OptionSet {
    let rawValue: Int
    static let boldFontMask = NSFontTraitMask(rawValue: 1)
    static let italicFontMask = NSFontTraitMask(rawValue: 2)
}

struct NSFontManager {
    static let shared = NSFontManager()

    func convert(_ font: UIFont, toHaveTrait trait: NSFontTraitMask) -> UIFont {
        var traits = font.fontDescriptor.symbolicTraits
        if trait.contains(.boldFontMask) { traits.insert(.traitBold) }
        if trait.contains(.italicFontMask) { traits.insert(.traitItalic) }
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}
#endif
