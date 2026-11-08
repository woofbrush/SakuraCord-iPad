import SwiftUI
import UIKit

/// The two points a server rail reorder needs, as `DragGesture.Value` gives them on macOS.
struct PadRailDragValue {
    let startLocation: CGPoint
    let location: CGPoint
}

/// Waits alongside the context-menu press and the rail's own scrolling instead of
/// excluding them: moving before it fires still scrolls, holding on still opens the menu.
private final class PadRailPress: UILongPressGestureRecognizer {
    override func canPrevent(_: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by _: UIGestureRecognizer) -> Bool { false }
}

/// A SwiftUI drag or long press on a row keeps the enclosing ScrollView from panning
/// on touch, so a server is picked up by a UIKit recognizer instead.
struct PadRailReorderGesture: UIGestureRecognizerRepresentable {
    final class Coordinator {
        var start: CGPoint?
        var isDragging = false
    }

    let changed: (PadRailDragValue) -> Void
    let ended: (PadRailDragValue) -> Void

    func makeCoordinator(converter _: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context _: Context) -> UILongPressGestureRecognizer {
        let press = PadRailPress()
        press.minimumPressDuration = 0.25
        press.cancelsTouchesInView = false
        return press
    }

    func handleUIGestureRecognizerAction(_ press: UILongPressGestureRecognizer, context: Context) {
        let location = press.location(in: nil)
        let coordinator = context.coordinator
        switch press.state {
        case .began:
            coordinator.start = location
        case .changed:
            guard let start = coordinator.start else { return }
            if !coordinator.isDragging, hypot(location.x - start.x, location.y - start.y) < 3 { return }
            coordinator.isDragging = true
            changed(PadRailDragValue(startLocation: start, location: location))
        case .ended, .cancelled, .failed:
            if coordinator.isDragging, let start = coordinator.start {
                ended(PadRailDragValue(startLocation: start, location: location))
            }
            coordinator.start = nil
            coordinator.isDragging = false
        default:
            break
        }
    }
}
