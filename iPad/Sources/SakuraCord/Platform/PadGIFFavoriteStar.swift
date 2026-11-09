import AppKitShim
import SakuraCordModels
import UIKit

/// Discord's favorite star, on the GIF under the pointer: a GIF link's embed or an
/// uploaded .gif. Touch has no hover, so a finger uses the long-press menu.
@MainActor
final class PadGIFFavoriteStar: NSObject {
    private static let size: CGFloat = 36
    private static let inset: CGFloat = 8

    private weak var canvas: NativeTimelineCanvasView?
    private let button = UIButton(type: .custom)
    private var gif: GIFSearchResult?

    func attach(to canvas: NativeTimelineCanvasView) {
        self.canvas = canvas
        button.frame = CGRect(x: 0, y: 0, width: Self.size, height: Self.size)
        button.layer.cornerRadius = Self.size / 2
        button.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        button.tintColor = .white
        button.accessibilityLabel = "Favorite GIF"
        button.addTarget(self, action: #selector(toggle), for: .touchUpInside)
    }

    func pointerMoved(to point: CGPoint) {
        guard let canvas, let target = target(at: point) else { return hide() }
        gif = target.gif
        showState(isFavorite(target.gif))
        button.frame.origin = CGPoint(
            x: target.frame.maxX - Self.size - Self.inset,
            y: target.frame.minY + Self.inset
        )
        if button.superview !== canvas { canvas.addSubview(button) }
    }

    func hide() {
        gif = nil
        button.removeFromSuperview()
    }

    private func target(at point: CGPoint) -> (gif: GIFSearchResult, frame: CGRect)? {
        guard let canvas, !canvas.overlayBlocksInteractions,
              let index = canvas.rowIndex(at: point.y),
              canvas.layouts.indices.contains(index),
              case let .message(row, _, _) = canvas.items[index]
        else { return nil }
        let layout = canvas.layouts[index]
        let origin = canvas.displayedRowOrigin(at: index)
        let local = CGPoint(x: point.x, y: point.y - origin)
        if let gif = NativeTimelineGIFContextMenuPlan.result(in: row.message, layout: layout, at: local),
           let frame = layout.embedRegions.first(where: { $0.mediaFrame?.contains(local) == true })?.mediaFrame {
            return (gif, frame.offsetBy(dx: 0, dy: origin))
        }
        guard let region = layout.attachmentRegions.first(where: {
            $0.attachment.mediaKind == .animatedImage && $0.frame.contains(local)
        }) else { return nil }
        let attachment = region.attachment
        let gif = GIFSearchResult(
            id: String(describing: attachment.id),
            title: attachment.filename,
            url: attachment.url,
            previewURL: attachment.url,
            width: attachment.width,
            height: attachment.height,
            thumbnailURL: nil,
            mediaURL: attachment.url,
            mediaKind: .image
        )
        return (gif, region.frame.offsetBy(dx: 0, dy: origin))
    }

    private func isFavorite(_ gif: GIFSearchResult) -> Bool {
        canvas?.model?.favoriteGIFs.contains { $0.url == gif.url } == true
    }

    private func showState(_ isFavorite: Bool) {
        button.setImage(UIImage(systemName: isFavorite ? "star.fill" : "star"), for: .normal)
    }

    @objc private func toggle() {
        guard let gif, let model = canvas?.model else { return }
        let favorite = !isFavorite(gif)
        model.setGIFFavorite(gif, isFavorite: favorite)
        showState(favorite)
    }
}
