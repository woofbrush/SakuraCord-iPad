import SwiftUI
import UIKit

/// Pinch, pan and double-tap for the media viewer. The window owns the recognizers: the
/// context-menu view lies over the image and would keep SwiftUI's gestures from seeing a
/// touch, and only UIKit's pan also takes a trackpad's two-finger scroll.
struct PadMediaZoomGestures: UIViewRepresentable {
    let imageFrame: CGRect
    let isZoomed: Bool
    let magnifyChanged: (CGFloat) -> Void
    let magnifyEnded: (CGFloat) -> Void
    let dragChanged: (CGSize) -> Void
    let dragEnded: (CGSize) -> Void
    let doubleTapped: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> Anchor {
        let view = Anchor()
        view.coordinator = context.coordinator
        context.coordinator.view = view
        return view
    }

    func updateUIView(_: Anchor, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_: Anchor, coordinator: Coordinator) {
        coordinator.attach(to: nil)
    }

    final class Anchor: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.attach(to: window)
        }

        override func hitTest(_: CGPoint, with _: UIEvent?) -> UIView? { nil }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PadMediaZoomGestures?
        weak var view: UIView?
        private weak var host: UIWindow?
        private lazy var pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
        private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        private lazy var doubleTap = UITapGestureRecognizer(target: self, action: #selector(tapped))

        func attach(to window: UIWindow?) {
            guard host !== window else { return }
            for recognizer in [pinch, pan, doubleTap] {
                host?.removeGestureRecognizer(recognizer)
                recognizer.delegate = self
                recognizer.cancelsTouchesInView = false
                recognizer.delaysTouchesEnded = false
                window?.addGestureRecognizer(recognizer)
            }
            pan.allowedScrollTypesMask = .continuous
            doubleTap.numberOfTapsRequired = 2
            host = window
        }

        private func isOverImage(_ point: CGPoint) -> Bool {
            parent?.imageFrame.contains(point) == true
        }

        func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view, !(touch.view is UIControl) else { return false }
            return isOverImage(touch.location(in: view))
        }

        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            guard let view else { return false }
            if gesture === pan, parent?.isZoomed != true { return false }
            return isOverImage(gesture.location(in: view))
        }

        func gestureRecognizer(
            _ gesture: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            (gesture === pinch && other === pan) || (gesture === pan && other === pinch)
        }

        @objc private func pinched(_ pinch: UIPinchGestureRecognizer) {
            switch pinch.state {
            case .began, .changed: parent?.magnifyChanged(pinch.scale)
            case .ended, .cancelled, .failed: parent?.magnifyEnded(pinch.scale)
            default: break
            }
        }

        @objc private func panned(_ pan: UIPanGestureRecognizer) {
            guard let view else { return }
            let moved = pan.translation(in: view)
            let translation = CGSize(width: moved.x, height: moved.y)
            switch pan.state {
            case .began, .changed: parent?.dragChanged(translation)
            case .ended, .cancelled, .failed: parent?.dragEnded(translation)
            default: break
            }
        }

        @objc private func tapped() {
            parent?.doubleTapped()
        }
    }
}
