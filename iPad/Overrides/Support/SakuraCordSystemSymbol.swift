import AppKit
import ObjectiveC
import SwiftUI

/// Same symbols as macOS. The private SF Symbols ship with iPadOS but are only
/// reachable through UIKit's private lookup; custom ones are bundled templates.
enum SakuraCordSystemSymbol {
    nonisolated static let emojiFaceGrinning = "emoji.face.grinning"
    nonisolated static let stickerFill = "sticker.fill"
    nonisolated static let thread = "thread"
    nonisolated static let applicationCommands = "xmark.triangle.circle.square.fill"

    private static func privateSymbol(_ name: String) -> UIImage? {
        let selector = NSSelectorFromString("_systemImageNamed:")
        guard UIImage.responds(to: selector) else { return nil }
        return UIImage.perform(selector, with: name)?.takeUnretainedValue() as? UIImage
    }

    private static func symbolImage(_ name: String, fallback: String) -> Image {
        privateSymbol(name).map { Image(uiImage: $0).renderingMode(.template) } ?? Image(systemName: fallback)
    }

    static var emojiFaceGrinningImage: Image {
        symbolImage(emojiFaceGrinning, fallback: "face.smiling")
    }

    static var stickerFillImage: Image {
        symbolImage(stickerFill, fallback: "doc.richtext.fill")
    }

    @ViewBuilder
    static func swiftUIImage(named name: String) -> some View {
        if name == thread {
            Image(name, bundle: .module).renderingMode(.template)
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
