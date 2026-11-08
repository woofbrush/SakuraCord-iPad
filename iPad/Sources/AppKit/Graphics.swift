import CoreText
import ObjectiveC

// MARK: Colors

public nonisolated extension UIColor {
    static var labelColor: UIColor { .label }
    static var secondaryLabelColor: UIColor { .secondaryLabel }
    static var tertiaryLabelColor: UIColor { .tertiaryLabel }
    static var quaternaryLabelColor: UIColor { .quaternaryLabel }
    static var placeholderTextColor: UIColor { .placeholderText }
    static var linkColor: UIColor { .link }
    static var separatorColor: UIColor { .separator }
    static var controlBackgroundColor: UIColor { .secondarySystemBackground }
    static var controlColor: UIColor { .secondarySystemFill }
    static var windowBackgroundColor: UIColor { .systemBackground }
    static var textColor: UIColor { .label }
    static var textBackgroundColor: UIColor { .systemBackground }
    static var selectedTextColor: UIColor { .label }
    static var selectedTextBackgroundColor: UIColor { .tintColor.withAlphaComponent(0.3) }
    static var unemphasizedSelectedTextBackgroundColor: UIColor { .systemFill }
    static var unemphasizedSelectedContentBackgroundColor: UIColor { .systemFill }
    static var controlAccentColor: UIColor { .tintColor }

    convenience init(srgbRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    convenience init(calibratedRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    convenience init(calibratedWhite white: CGFloat, alpha: CGFloat) {
        self.init(white: white, alpha: alpha)
    }

    convenience init(deviceRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    convenience init(name _: String?, dynamicProvider: @escaping (NSAppearance) -> UIColor) {
        self.init { traits in
            dynamicProvider(NSAppearance(style: traits.userInterfaceStyle))
        }
    }

    /// AppKit's conversion resolves dynamic colors against the current appearance.
    func usingColorSpace(_: NSColorSpace) -> UIColor? { resolvedColor(with: .ak_effective) }

    var redComponent: CGFloat { rgba.0 }
    var greenComponent: CGFloat { rgba.1 }
    var blueComponent: CGFloat { rgba.2 }
    var alphaComponent: CGFloat { rgba.3 }
    var whiteComponent: CGFloat { rgba.0 }
    var hueComponent: CGFloat { hsba.0 }
    var saturationComponent: CGFloat { hsba.1 }
    var brightnessComponent: CGFloat { hsba.2 }

    private var hsba: (CGFloat, CGFloat, CGFloat, CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
    }

    private var rgba: (CGFloat, CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    func blended(withFraction fraction: CGFloat, of other: UIColor) -> UIColor? {
        let a = rgba, b = other.rgba
        func mix(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * fraction }
        return UIColor(red: mix(a.0, b.0), green: mix(a.1, b.1), blue: mix(a.2, b.2), alpha: mix(a.3, b.3))
    }

    func highlight(withLevel level: CGFloat) -> UIColor? { blended(withFraction: level, of: .white) }
    func shadow(withLevel level: CGFloat) -> UIColor? { blended(withFraction: level, of: .black) }
}

public nonisolated extension CGColor {
    static var clear: CGColor { UIColor.clear.cgColor }
    static var black: CGColor { UIColor.black.cgColor }
    static var white: CGColor { UIColor.white.cgColor }
}

public nonisolated struct NSColorSpace: Sendable {
    public static let sRGB = NSColorSpace()
    public static let deviceRGB = NSColorSpace()
    public static let genericRGB = NSColorSpace()
}

public nonisolated extension Color {
    init(nsColor: UIColor) { self.init(uiColor: nsColor) }
}

// MARK: Appearance

public nonisolated final class NSAppearance: NSObject {
    public nonisolated struct Name: Hashable, Sendable, RawRepresentable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let aqua = Name(rawValue: "aqua")
        public static let darkAqua = Name(rawValue: "darkAqua")
        public static let vibrantLight = Name(rawValue: "vibrantLight")
        public static let vibrantDark = Name(rawValue: "vibrantDark")
        public static let accessibilityHighContrastAqua = Name(rawValue: "highContrastAqua")
        public static let accessibilityHighContrastDarkAqua = Name(rawValue: "highContrastDarkAqua")
    }

    public let name: Name
    public let style: UIUserInterfaceStyle

    public init(style: UIUserInterfaceStyle) {
        self.style = style
        name = style == .dark ? .darkAqua : .aqua
    }

    public convenience init?(named name: Name) {
        self.init(style: name == .darkAqua || name == .vibrantDark || name == .accessibilityHighContrastDarkAqua ? .dark : .light)
    }

    public static var current: NSAppearance {
        get { NSAppearance(style: UITraitCollection.ak_effective.userInterfaceStyle) }
        set { UITraitCollection.current = UITraitCollection(userInterfaceStyle: newValue.style) }
    }

    public static func currentDrawing() -> NSAppearance { current }

    public func bestMatch(from names: [Name]) -> Name? {
        let isDark = style == .dark
        return names.first { ($0 == .darkAqua || $0 == .vibrantDark || $0 == .accessibilityHighContrastDarkAqua) == isDark } ?? names.first
    }

    public func performAsCurrentDrawingAppearance(_ block: () -> Void) {
        UITraitCollection(userInterfaceStyle: style).performAsCurrent(block)
    }
}

// MARK: Fonts

public nonisolated extension UIFont {
    static var macSystemFontSize: CGFloat { 13 }
    static var macSmallSystemFontSize: CGFloat { 11 }

    /// macOS text style sizes, so type matches the Mac app rather than iPadOS's larger defaults.
    static func macPreferredFont(forTextStyle style: TextStyle, options _: [AnyHashable: Any] = [:]) -> UIFont {
        .systemFont(ofSize: macPointSize(style), weight: macWeight(style))
    }

    static func macPointSize(_ style: TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 26
        case .title1: 22
        case .title2: 17
        case .title3: 15
        case .headline, .body: 13
        case .callout: 12
        case .subheadline, .footnote: 11
        case .caption1: 10
        case .caption2: 10
        default: 13
        }
    }

    private static func macWeight(_ style: TextStyle) -> Weight { style == .headline ? .bold : .regular }
}

public nonisolated struct NSFontTraitMask: OptionSet, Hashable, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let italicFontMask = NSFontTraitMask(rawValue: 1)
    public static let boldFontMask = NSFontTraitMask(rawValue: 2)
}

public nonisolated final class NSFontManager: NSObject {
    nonisolated(unsafe) public static let shared = NSFontManager()

    public func convert(_ font: UIFont, toHaveTrait trait: NSFontTraitMask) -> UIFont {
        var traits = font.fontDescriptor.symbolicTraits
        if trait.contains(.italicFontMask) { traits.insert(.traitItalic) }
        if trait.contains(.boldFontMask) { traits.insert(.traitBold) }
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    public func traits(of font: UIFont) -> NSFontTraitMask {
        let symbolic = font.fontDescriptor.symbolicTraits
        var mask: NSFontTraitMask = []
        if symbolic.contains(.traitItalic) { mask.insert(.italicFontMask) }
        if symbolic.contains(.traitBold) { mask.insert(.boldFontMask) }
        return mask
    }
}

// MARK: Graphics context

public nonisolated enum NSImageInterpolation: Sendable {
    case `default`, none, low, medium, high

    var cg: CGInterpolationQuality {
        switch self {
        case .default: .default
        case .none: .none
        case .low: .low
        case .medium: .medium
        case .high: .high
        }
    }
}

public nonisolated final class NSGraphicsContext: NSObject {
    public let cgContext: CGContext
    public let isFlipped: Bool

    public init(cgContext: CGContext, flipped: Bool = true) {
        self.cgContext = cgContext
        isFlipped = flipped
    }

    private final class Stack {
        var pushed: [NSGraphicsContext] = []
        var marks: [Int] = []
    }

    /// UIKit's context stack is per thread, so this must be too.
    private static var stack: Stack {
        let storage = Thread.current.threadDictionary
        if let stack = storage["ak.graphics"] as? Stack { return stack }
        let stack = Stack()
        storage["ak.graphics"] = stack
        return stack
    }

    public static var current: NSGraphicsContext? {
        get {
            guard let context = UIGraphicsGetCurrentContext() else { return nil }
            if let top = stack.pushed.last, top.cgContext === context { return top }
            return NSGraphicsContext(cgContext: context)
        }
        set {
            let stack = stack
            if let newValue {
                stack.pushed.append(newValue)
                UIGraphicsPushContext(newValue.cgContext)
            } else if !stack.pushed.isEmpty {
                stack.pushed.removeLast()
                UIGraphicsPopContext()
            }
        }
    }

    public static func saveGraphicsState() {
        stack.marks.append(stack.pushed.count)
        UIGraphicsGetCurrentContext()?.saveGState()
    }

    public static func restoreGraphicsState() {
        let stack = stack
        let mark = stack.marks.popLast() ?? stack.pushed.count
        while stack.pushed.count > mark {
            stack.pushed.removeLast()
            UIGraphicsPopContext()
        }
        UIGraphicsGetCurrentContext()?.restoreGState()
    }

    public convenience init?(bitmapImageRep representation: NSBitmapImageRep) {
        guard let context = representation.context else { return nil }
        self.init(cgContext: context, flipped: false)
    }

    public func saveGraphicsState() { cgContext.saveGState() }
    public func restoreGraphicsState() { cgContext.restoreGState() }
    public func flushGraphics() { cgContext.flush() }

    public var imageInterpolation: NSImageInterpolation {
        get { .default }
        set { cgContext.interpolationQuality = newValue.cg }
    }

    public var shouldAntialias: Bool {
        get { true }
        set { cgContext.setShouldAntialias(newValue) }
    }

    public var compositingOperation: NSCompositingOperation {
        get { .sourceOver }
        set { cgContext.setBlendMode(newValue.blendMode) }
    }
}

public nonisolated enum NSCompositingOperation: Sendable {
    case sourceOver, copy, clear, sourceIn, sourceOut, sourceAtop, destinationOver, destinationIn, destinationOut, destinationAtop, plusLighter

    var blendMode: CGBlendMode {
        switch self {
        case .sourceOver: .normal
        case .copy: .copy
        case .clear: .clear
        case .sourceIn: .sourceIn
        case .sourceOut: .sourceOut
        case .sourceAtop: .sourceAtop
        case .destinationOver: .destinationOver
        case .destinationIn: .destinationIn
        case .destinationOut: .destinationOut
        case .destinationAtop: .destinationAtop
        case .plusLighter: .plusLighter
        }
    }
}

// MARK: Bezier paths

public nonisolated extension UIBezierPath {
    convenience init(roundedRect rect: CGRect, xRadius: CGFloat, yRadius _: CGFloat) {
        self.init(roundedRect: rect, cornerRadius: xRadius)
    }

    func line(to point: CGPoint) { addLine(to: point) }

    func curve(to point: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) {
        addCurve(to: point, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
    }

    func appendRect(_ rect: CGRect) { append(UIBezierPath(rect: rect)) }
    func appendOval(in rect: CGRect) { append(UIBezierPath(ovalIn: rect)) }

    func appendRoundedRect(_ rect: CGRect, xRadius: CGFloat, yRadius _: CGFloat) {
        append(UIBezierPath(roundedRect: rect, cornerRadius: xRadius))
    }

    func relativeLine(to point: CGPoint) {
        addLine(to: CGPoint(x: currentPoint.x + point.x, y: currentPoint.y + point.y))
    }

    func setClip() { addClip() }

    var windingRule: NSWindingRule {
        get { usesEvenOddFillRule ? .evenOdd : .nonZero }
        set { usesEvenOddFillRule = newValue == .evenOdd }
    }

}

public nonisolated enum NSWindingRule: Sendable { case nonZero, evenOdd }

public nonisolated enum NSLineCapStyle: Sendable { case butt, round, square }

// MARK: Shadow

public nonisolated extension NSShadow {
    func set() {
        UIGraphicsGetCurrentContext()?.setShadow(
            offset: shadowOffset, blur: shadowBlurRadius, color: (shadowColor as? UIColor)?.cgColor
        )
    }
}

// MARK: Gradient

public nonisolated final class NSGradient: NSObject {
    private let gradient: CGGradient?

    public init?(colors: [UIColor], atLocations locations: UnsafePointer<CGFloat>?, colorSpace _: NSColorSpace) {
        let positions = locations.map { Array(UnsafeBufferPointer(start: $0, count: colors.count)) }
        gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: colors.map(\.cgColor) as CFArray,
            locations: positions
        )
    }

    public convenience init?(colorsAndLocations pairs: (UIColor, CGFloat)...) {
        var locations = pairs.map(\.1)
        self.init(colors: pairs.map(\.0), atLocations: &locations, colorSpace: .sRGB)
    }

    public convenience init?(starting: UIColor, ending: UIColor) {
        self.init(colors: [starting, ending])
    }

    public init?(colors: [UIColor]) {
        gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: colors.map(\.cgColor) as CFArray,
            locations: nil
        )
    }

    public func draw(in rect: CGRect, angle: CGFloat) {
        guard let gradient, let context = UIGraphicsGetCurrentContext() else { return }
        let radians = angle * .pi / 180
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let dx = cos(radians) * rect.width / 2, dy = sin(radians) * rect.height / 2
        context.saveGState()
        context.clip(to: rect)
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: center.x - dx, y: center.y - dy),
            end: CGPoint(x: center.x + dx, y: center.y + dy),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    public func draw(in path: UIBezierPath, angle: CGFloat) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        path.addClip()
        draw(in: path.bounds, angle: angle)
        context.restoreGState()
    }
}

public nonisolated final class NSAffineTransform: NSObject {
    public var transformStruct = CGAffineTransform.identity

    public func translateX(by x: CGFloat, yBy y: CGFloat) { transformStruct = transformStruct.translatedBy(x: x, y: y) }
    public func scale(by factor: CGFloat) { transformStruct = transformStruct.scaledBy(x: factor, y: factor) }
    public func scaleX(by x: CGFloat, yBy y: CGFloat) { transformStruct = transformStruct.scaledBy(x: x, y: y) }
    public func rotate(byDegrees degrees: CGFloat) { transformStruct = transformStruct.rotated(by: degrees * .pi / 180) }
    public func rotate(byRadians radians: CGFloat) { transformStruct = transformStruct.rotated(by: radians) }
    public func concat() { UIGraphicsGetCurrentContext()?.concatenate(transformStruct) }
    public func transform(_ point: CGPoint) -> CGPoint { point.applying(transformStruct) }
}

public nonisolated extension CGRect {
    func fill(using operation: NSCompositingOperation = .sourceOver) { UIRectFillUsingBlendMode(self, operation.blendMode) }
    func frame(withWidth width: CGFloat = 1, using operation: NSCompositingOperation = .sourceOver) { UIRectFrameUsingBlendMode(self, operation.blendMode) }
    func clip() { UIRectClip(self) }
}

public nonisolated extension UIFontDescriptor.SymbolicTraits {
    static var italic: Self { .traitItalic }
    static var bold: Self { .traitBold }
    static var monoSpace: Self { .traitMonoSpace }
}

public nonisolated extension UIFontDescriptor {
    func nsWithSymbolicTraits(_ traits: SymbolicTraits) -> UIFontDescriptor { withSymbolicTraits(traits) ?? self }
}

public func NSRectFill(_ rect: CGRect) { UIRectFill(rect) }
public func NSFrameRect(_ rect: CGRect) { UIRectFrame(rect) }

// MARK: Images

public nonisolated extension NSLayoutManager {
    func defaultLineHeight(for font: UIFont) -> CGFloat { font.lineHeight }
    func addTemporaryAttribute(_: NSAttributedString.Key, value _: Any, forCharacterRange _: NSRange) {}
    func addTemporaryAttributes(_: [NSAttributedString.Key: Any], forCharacterRange _: NSRange) {}
    func removeTemporaryAttribute(_: NSAttributedString.Key, forCharacterRange _: NSRange) {}
}

public nonisolated enum NSImageHintKey: Hashable, Sendable { case interpolation }

public nonisolated extension UIImage {
    typealias Name = String

    static var imageTypes: [String] { [] }

    convenience init?(systemSymbolName name: String, accessibilityDescription: String?) {
        self.init(systemName: name)
        accessibilityLabel = accessibilityDescription
    }

    convenience init?(contentsOf url: URL) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        self.init(data: data)
    }

    /// `flipped: false` gives the handler AppKit's bottom-left origin.
    convenience init(size: CGSize, flipped: Bool, drawingHandler: @escaping (CGRect) -> Bool) {
        guard size.width > 0, size.height > 0 else {
            self.init()
            return
        }
        let rendered = UIGraphicsImageRenderer(size: size).image { renderer in
            if !flipped {
                renderer.cgContext.translateBy(x: 0, y: size.height)
                renderer.cgContext.scaleBy(x: 1, y: -1)
                ImageDrawing.isContextFlipped = true
            }
            _ = drawingHandler(CGRect(origin: .zero, size: size))
            ImageDrawing.isContextFlipped = false
        }
        guard let image = rendered.cgImage else {
            self.init()
            return
        }
        self.init(cgImage: image, scale: rendered.scale, orientation: .up)
    }

    convenience init(size: CGSize) {
        self.init(size: size, flipped: true) { _ in true }
    }

    convenience init(cgImage: CGImage, size: CGSize) {
        self.init(cgImage: cgImage, scale: size.width > 0 ? CGFloat(cgImage.width) / size.width : 1, orientation: .up)
    }

    /// Palette symbols must be original-rendered, or UIImage.draw paints them black.
    func withSymbolConfiguration(_ configuration: UIImage.SymbolConfiguration) -> UIImage? {
        let image = applyingSymbolConfiguration(configuration)
        return configuration.ak_isPalette ? image?.withRenderingMode(.alwaysOriginal) : image
    }

    var accessibilityDescription: String? {
        get { accessibilityLabel }
        set { accessibilityLabel = newValue }
    }

    var tiffRepresentation: Data? { pngData() }

    func ak_resized(to target: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
    var alignmentRect: CGRect { CGRect(origin: .zero, size: size).inset(by: alignmentRectInsets) }
    var representations: [NSBitmapImageRep] { cgImage.map { [NSBitmapImageRep(cgImage: $0)] } ?? [] }

    convenience init(representation: NSBitmapImageRep, size: CGSize) {
        guard let image = representation.cgImage else {
            self.init()
            return
        }
        self.init(cgImage: image, size: size)
    }

    /// Symbols are templates already; bitmap images keep their colors.
    var isTemplate: Bool {
        get { renderingMode == .alwaysTemplate || isSymbolImage }
        set {}
    }

    func cgImage(forProposedRect _: UnsafeMutablePointer<CGRect>?, context _: NSGraphicsContext?, hints _: [NSImageHintKey: Any]?) -> CGImage? {
        cgImage ?? UIGraphicsImageRenderer(size: size).image { _ in draw(at: .zero) }.cgImage
    }

    func draw(
        in rect: CGRect,
        from _: CGRect,
        operation: NSCompositingOperation = .sourceOver,
        fraction: CGFloat = 1,
        respectFlipped _: Bool = true,
        hints _: [NSImageHintKey: Any]? = nil
    ) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        if ImageDrawing.isContextFlipped || NSGraphicsContext.current?.isFlipped == false {
            context.translateBy(x: 0, y: rect.minY + rect.maxY)
            context.scaleBy(x: 1, y: -1)
        }
        draw(in: rect, blendMode: operation.blendMode, alpha: fraction)
        context.restoreGState()
    }

    func draw(at point: CGPoint, from source: CGRect, operation: NSCompositingOperation, fraction: CGFloat) {
        draw(in: CGRect(origin: point, size: size), from: source, operation: operation, fraction: fraction)
    }
}

nonisolated enum ImageDrawing {
    nonisolated(unsafe) static var isContextFlipped = false
}

public nonisolated struct NSColorSpaceName: Sendable {
    public static let deviceRGB = NSColorSpaceName()
    public static let calibratedRGB = NSColorSpaceName()
}

public nonisolated final class NSBitmapImageRep: NSObject {
    public enum FileType: Sendable { case png, jpeg, tiff }
    public enum PropertyKey: Hashable, Sendable { case compressionFactor }

    private var image: UIImage?
    let context: CGContext?
    public var size: CGSize = .zero
    public var pixelsWide: Int { context?.width ?? image?.cgImage?.width ?? 0 }
    public var pixelsHigh: Int { context?.height ?? image?.cgImage?.height ?? 0 }

    public init?(data: Data) {
        image = UIImage(data: data)
        context = nil
        super.init()
        if image == nil { return nil }
        size = image?.size ?? .zero
    }

    public init(cgImage: CGImage) {
        image = UIImage(cgImage: cgImage)
        context = nil
        size = CGSize(width: cgImage.width, height: cgImage.height)
    }

    public init?(
        bitmapDataPlanes _: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
        pixelsWide: Int,
        pixelsHigh: Int,
        bitsPerSample _: Int,
        samplesPerPixel _: Int,
        hasAlpha _: Bool,
        isPlanar _: Bool,
        colorSpaceName _: NSColorSpaceName,
        bytesPerRow _: Int,
        bitsPerPixel _: Int
    ) {
        context = CGContext(
            data: nil, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        super.init()
        if context == nil { return nil }
    }

    public struct BitmapFormat: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let alphaFirst = Self(rawValue: 1)
    }

    public var bitmapData: UnsafeMutablePointer<UInt8>? { context?.data?.assumingMemoryBound(to: UInt8.self) }
    public var bitsPerPixel: Int { 32 }
    public var bytesPerRow: Int { context?.bytesPerRow ?? 0 }
    public var bitmapFormat: BitmapFormat { [] }
    public var cgImage: CGImage? { context?.makeImage() ?? image?.cgImage }

    public func representation(using type: FileType, properties: [PropertyKey: Any]) -> Data? {
        let source = cgImage.map { UIImage(cgImage: $0) } ?? image
        if type == .jpeg {
            return source?.jpegData(compressionQuality: properties[.compressionFactor] as? CGFloat ?? 0.9)
        }
        return source?.pngData()
    }
}

public nonisolated extension NSString {
    func boundingRect(with size: CGSize, options: NSStringDrawingOptions, attributes: [NSAttributedString.Key: Any]?) -> CGRect {
        boundingRect(with: size, options: options, attributes: attributes, context: nil)
    }
}

public nonisolated extension NSAttributedString {
    func boundingRect(with size: CGSize, options: NSStringDrawingOptions) -> CGRect {
        boundingRect(with: size, options: options, context: nil)
    }
}

public nonisolated extension UIImage.SymbolConfiguration {
    @_disfavoredOverload convenience init(pointSize: CGFloat, weight: UIFont.Weight) {
        self.init(pointSize: pointSize, weight: UIImage.SymbolWeight(fontWeight: weight))
    }
}

nonisolated extension UIImage.SymbolWeight {
    init(fontWeight: UIFont.Weight) {
        self = switch fontWeight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}

/// CALayer contents take a CGImage on iOS, where AppKit also accepts an NSImage.
public func nsLayerContents(_ value: Any?) -> Any? {
    (value as? UIImage).map { $0.cgImage as Any } ?? value
}

nonisolated(unsafe) private var paletteKey: UInt8 = 0

public nonisolated extension UIImage.SymbolConfiguration {
    fileprivate(set) var ak_isPalette: Bool {
        get { objc_getAssociatedObject(self, &paletteKey) != nil }
        set { objc_setAssociatedObject(self, &paletteKey, newValue ? true : nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    static func ak_palette(_ colors: [UIColor]) -> UIImage.SymbolConfiguration {
        let configuration = UIImage.SymbolConfiguration(paletteColors: colors)
        configuration.ak_isPalette = true
        return configuration
    }

    func ak_applying(_ other: UIImage.SymbolConfiguration) -> UIImage.SymbolConfiguration {
        let combined = applying(other)
        combined.ak_isPalette = ak_isPalette || other.ak_isPalette
        return combined
    }
}

// MARK: CoreText colors

public nonisolated enum AppearanceState {
    nonisolated(unsafe) public static var style: UIUserInterfaceStyle = .unspecified
}

public nonisolated extension UITraitCollection {
    /// The current traits, or the app's when none are set (background layout work).
    static var ak_effective: UITraitCollection {
        current.userInterfaceStyle == .unspecified && AppearanceState.style != .unspecified
            ? UITraitCollection(userInterfaceStyle: AppearanceState.style)
            : current
    }
}

/// CoreText on iOS ignores UIKit's color attributes and draws such runs black;
/// macOS honors them. Copies them to CoreText's own keys.
nonisolated private func coreTextColored(_ source: CFAttributedString) -> CFAttributedString {
    let string = source as NSAttributedString
    let foreground = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
    let fromContext = NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String)
    let underline = NSAttributedString.Key(kCTUnderlineColorAttributeName as String)
    let whole = NSRange(location: 0, length: string.length)
    var output: NSMutableAttributedString?
    let traits = UITraitCollection.ak_effective
    func copy(_ key: NSAttributedString.Key, to target: NSAttributedString.Key) {
        string.enumerateAttributes(in: whole) { attributes, range, _ in
            guard let color = attributes[key] as? UIColor, attributes[target] == nil, attributes[fromContext] == nil else { return }
            let mutable = output ?? NSMutableAttributedString(attributedString: string)
            output = mutable
            mutable.addAttribute(target, value: color.resolvedColor(with: traits).cgColor, range: range)
        }
    }
    copy(.foregroundColor, to: foreground)
    copy(.underlineColor, to: underline)
    return output ?? source
}

public nonisolated func AKCTLineCreate(_ string: CFAttributedString) -> CTLine {
    CTLineCreateWithAttributedString(coreTextColored(string))
}

public nonisolated func AKCTFramesetterCreate(_ string: CFAttributedString) -> CTFramesetter {
    CTFramesetterCreateWithAttributedString(coreTextColored(string))
}

public nonisolated func AKCTTypesetterCreate(_ string: CFAttributedString) -> CTTypesetter {
    CTTypesetterCreateWithAttributedString(coreTextColored(string))
}
