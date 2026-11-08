import AppKit
import ObjectiveC
import SwiftUI

/// Same symbols as macOS. The private SF Symbols ship with iPadOS but are only
/// reachable through UIKit's private lookup; custom ones are bundled templates.
enum SakuraCordSystemSymbol {
    nonisolated static let emojiFaceGrinning = "emoji.face.grinning"
    nonisolated static let sticker = "sticker"
    nonisolated static let thread = "thread"
    nonisolated static let applicationCommands = "xmark.triangle.circle.square.fill"

    private static func privateSymbol(_ name: String) -> UIImage? {
        let selector = NSSelectorFromString("_systemImageNamed:")
        guard UIImage.responds(to: selector) else { return nil }
        return UIImage.perform(selector, with: name)?.takeUnretainedValue() as? UIImage
    }

    /// SwiftUI's named lookup reads asset catalogs, and this build's images are loose files.
    static func bundledImage(_ name: String) -> Image {
        UIImage(named: name, in: .module, compatibleWith: nil)
            .map { Image(uiImage: $0).renderingMode(.template) }
            ?? Image(systemName: "questionmark.square.dashed")
    }

    private static func symbolImage(_ name: String, fallback: String) -> Image {
        if UIImage(systemName: name) != nil { return Image(systemName: name) }
        return privateSymbol(name).map { Image(uiImage: $0).renderingMode(.template) } ?? Image(systemName: fallback)
    }

    static var emojiFaceGrinningImage: Image {
        symbolImage(emojiFaceGrinning, fallback: "face.smiling")
    }

    static var stickerImage: Image {
        symbolImage(sticker, fallback: "doc.richtext")
    }

    @ViewBuilder
    static func swiftUIImage(named name: String) -> some View {
        if name == thread {
            bundledImage(name)
                .imageScale(.large)
        } else if let image = privateSymbol(name) {
            Image(uiImage: image).renderingMode(.template)
        } else {
            Image(systemName: name)
        }
    }

    static func image(
        named name: String,
        accessibilityDescription: String? = nil
    ) -> NSImage? {
        if name == thread {
            return Bundle.module.image(forResource: name)
        }
        return NSImage(systemSymbolName: name, accessibilityDescription: accessibilityDescription)
            ?? privateSymbol(name)
    }
}
