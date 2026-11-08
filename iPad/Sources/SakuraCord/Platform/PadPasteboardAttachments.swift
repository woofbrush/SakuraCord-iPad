import Foundation
import UIKit
import UniformTypeIdentifiers

/// iPadOS clipboards carry item providers rather than file URLs, and a file copied
/// in Files may be readable only through its provider, so pastes load from those.
enum PadPasteboardAttachments {
    private static let discordImageTypes: [UTType] = [.gif, .png, .jpeg, .webP]

    static func providers() -> [NSItemProvider] {
        UIPasteboard.general.itemProviders.filter { attachmentType(of: $0) != nil }
    }

    static func receive(
        _ providers: [NSItemProvider],
        deliver: @escaping (ComposerPromisedFileBatch) -> Void
    ) {
        Task {
            guard let directory = try? ComposerPromisedFileStorage.makeReceivingDirectory() else { return }
            var urls: [URL] = []
            for provider in providers {
                guard let type = attachmentType(of: provider) else { continue }
                let destination = directory.appendingPathComponent(
                    filename(for: provider, type: type, taken: urls)
                )
                guard await copy(provider, type: type, to: destination) else { continue }
                urls.append(webReadable(destination, type: type))
            }
            guard !urls.isEmpty else {
                ComposerPromisedFileStorage.removeDirectory(directory)
                return
            }
            deliver(ComposerPromisedFileBatch(directory: directory, urls: urls))
        }
    }

    /// Images and media outrank the text or link that accompanies them, as on macOS.
    /// Rich text registers private data types too, so only a named file or a public
    /// non-text type counts as anything else.
    private static func attachmentType(of provider: NSItemProvider) -> UTType? {
        let types = provider.registeredTypeIdentifiers.compactMap { UTType($0) }
        let images = types.filter { $0.conforms(to: .image) }
        if let image = discordImageTypes.first(where: images.contains) ?? images.first {
            return image
        }
        if let media = types.first(where: { $0.conforms(to: .audiovisualContent) }) {
            return media
        }
        let isNamedFile = provider.suggestedName.map { !($0 as NSString).pathExtension.isEmpty } ?? false
        if types.contains(.fileURL) || isNamedFile {
            return types.first { $0 != .fileURL && $0.conforms(to: .data) }
        }
        guard !types.contains(where: { $0.conforms(to: .text) || $0.conforms(to: .url) }) else { return nil }
        return types.first { $0.conforms(to: .data) && !$0.identifier.hasPrefix("com.apple.") }
    }

    private static func filename(for provider: NSItemProvider, type: UTType, taken: [URL]) -> String {
        var name = (provider.suggestedName ?? (type.conforms(to: .image) ? "image" : "file"))
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        if (name as NSString).pathExtension.isEmpty, let suffix = type.preferredFilenameExtension {
            name += "." + suffix
        }
        guard taken.contains(where: { $0.lastPathComponent == name }) else { return name }
        return "\(taken.count + 1) " + name
    }

    private static func copy(_ provider: NSItemProvider, type: UTType, to destination: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { @Sendable source, _ in
                let copied = source.map { (try? FileManager.default.copyItem(at: $0, to: destination)) != nil }
                continuation.resume(returning: copied ?? false)
            }
        }
    }

    /// Discord shows HEIC and TIFF as plain file downloads.
    private static func webReadable(_ url: URL, type: UTType) -> URL {
        guard type.conforms(to: .image), !discordImageTypes.contains(type),
              let png = UIImage(contentsOfFile: url.path)?.pngData()
        else { return url }
        let converted = url.deletingPathExtension().appendingPathExtension("png")
        guard (try? png.write(to: converted, options: .atomic)) != nil else { return url }
        try? FileManager.default.removeItem(at: url)
        return converted
    }
}
