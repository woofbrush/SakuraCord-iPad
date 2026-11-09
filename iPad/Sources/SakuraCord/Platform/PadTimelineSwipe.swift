import AppKitShim
import SakuraCordModels
import UIKit

/// Discord's message swipes, for a finger: left replies, right edits your own message.
/// The canvas draws its rows itself, so a badge follows the swipe rather than the row.
@MainActor
final class PadTimelineSwipe: NSObject, UIGestureRecognizerDelegate {
    private enum Action { case reply, edit }

    private static let threshold: CGFloat = 64
    private static let badgeSize: CGFloat = 36

    private weak var canvas: NativeTimelineCanvasView?
    private let badge = UIView()
    private let icon = UIImageView()
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    private var active: (action: Action, message: Message)?
    private var passedThreshold = false

    func attach(to canvas: NativeTimelineCanvasView) {
        self.canvas = canvas
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        pan.delegate = self
        canvas.addGestureRecognizer(pan)
        badge.frame = CGRect(x: 0, y: 0, width: Self.badgeSize, height: Self.badgeSize)
        badge.layer.cornerRadius = Self.badgeSize / 2
        badge.isUserInteractionEnabled = false
        icon.frame = badge.bounds.insetBy(dx: 9, dy: 9)
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .white
        badge.addSubview(icon)
    }

    private func candidate(for gesture: UIPanGestureRecognizer) -> (action: Action, message: Message)? {
        guard let canvas, !canvas.overlayBlocksInteractions, !canvas.sendTransitionBlocksInteractions else { return nil }
        let velocity = gesture.velocity(in: canvas)
        guard abs(velocity.x) > abs(velocity.y) * 1.4 else { return nil }
        guard let index = canvas.rowIndex(at: gesture.location(in: canvas).y),
              canvas.items.indices.contains(index),
              case let .message(row, _, _) = canvas.items[index],
              MessageOutboxPresentation.interactionMode(for: row.message).allowsMessageContextMenu,
              MessageReplyPresentationPolicy.allowsReplyAction(for: row.message)
        else { return nil }
        let message = row.message
        if velocity.x < 0 {
            return canvas.actions?.reply == nil ? nil : (.reply, message)
        }
        // The same conditions as the Edit Message menu item.
        guard let model = canvas.model, message.author.id == model.currentUser?.id, !message.hasPoll,
              !message.flags.contains(.voiceMessage),
              model.guildTimeoutUntil(in: message.channelID, guildID: message.guildID) == nil
        else { return nil }
        return (.edit, message)
    }

    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard let pan = gesture as? UIPanGestureRecognizer else { return false }
        return candidate(for: pan) != nil
    }

    /// A vertical drag fails this at once; only a sideways one holds the scroll view back.
    func gestureRecognizer(
        _: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer
    ) -> Bool {
        other is UIPanGestureRecognizer && other.view is UIScrollView
    }

    @objc private func panned(_ pan: UIPanGestureRecognizer) {
        guard let canvas else { return }
        switch pan.state {
        case .began:
            guard let candidate = candidate(for: pan) else { return finish() }
            active = candidate
            passedThreshold = false
            icon.image = UIImage(systemName: candidate.action == .reply ? "arrowshape.turn.up.left.fill" : "pencil")
            badge.backgroundColor = NSColor.sakuraCordAccentColor
            badge.center.y = pan.location(in: canvas).y
            canvas.addSubview(badge)
            haptics.prepare()
            follow(pan)
        case .changed:
            follow(pan)
        case .ended:
            if let active, passedThreshold { perform(active) }
            finish()
        default:
            finish()
        }
    }

    private func follow(_ pan: UIPanGestureRecognizer) {
        guard let canvas, let active else { return }
        let moved = pan.translation(in: canvas).x
        let distance = min(max(0, active.action == .reply ? -moved : moved), Self.threshold)
        let progress = distance / Self.threshold
        let travel = progress * (Self.badgeSize + 16)
        badge.center.x = active.action == .reply
            ? canvas.bounds.maxX + Self.badgeSize / 2 - travel
            : canvas.bounds.minX - Self.badgeSize / 2 + travel
        badge.alpha = progress
        badge.transform = CGAffineTransform(scaleX: 0.7 + 0.3 * progress, y: 0.7 + 0.3 * progress)
        let passed = progress >= 1
        if passed, !passedThreshold { haptics.impactOccurred() }
        passedThreshold = passed
    }

    private func perform(_ active: (action: Action, message: Message)) {
        guard let canvas else { return }
        switch active.action {
        case .reply: canvas.actions?.reply?(active.message)
        case .edit: _ = canvas.beginEditingCurrentUserMessage(active.message.id)
        }
    }

    private func finish() {
        active = nil
        passedThreshold = false
        badge.removeFromSuperview()
        badge.transform = .identity
    }
}
