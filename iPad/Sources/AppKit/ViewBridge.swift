import ObjectiveC

/// `NSView` is `UIView`. AppKit's overridable entry points are `@objc` extension
/// members (so Swift subclasses can override them) and swizzled UIKit callbacks
/// route into them. The `ak_` selectors keep clear of UIKit's private methods.
extension UIView {
    @objc(ak_layout) open func layout() {}
    @objc(ak_quickLook:) open func quickLook(with event: NSEvent) {}
    @objc(ak_prepareForReuse) open func prepareForReuse() {}
    @objc(ak_viewDidMoveToWindow) open func viewDidMoveToWindow() {}
    @objc(ak_viewWillMoveToWindow:) open func viewWillMove(toWindow newWindow: UIWindow?) {}
    @objc(ak_viewDidMoveToSuperview) open func viewDidMoveToSuperview() {}
    @objc(ak_viewDidChangeEffectiveAppearance) open func viewDidChangeEffectiveAppearance() {}
    @objc(ak_viewDidChangeBackingProperties) open func viewDidChangeBackingProperties() {}
    @objc(ak_viewDidHide) open func viewDidHide() {}
    @objc(ak_viewDidUnhide) open func viewDidUnhide() {}
    @objc(ak_updateTrackingAreas) open func updateTrackingAreas() {}
    @objc(ak_resetCursorRects) open func resetCursorRects() {}
    @objc(ak_isFlipped) open var isFlipped: Bool { false }
    @objc(ak_acceptsFirstMouse:) open func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }
    @objc(ak_acceptsFirstResponder) open var acceptsFirstResponder: Bool { false }

    @objc(ak_setFrameSize:) open func setFrameSize(_ newSize: CGSize) { frame.size = newSize }
    @objc(ak_setFrameOrigin:) open func setFrameOrigin(_ newOrigin: CGPoint) { frame.origin = newOrigin }

    /// Point is in the superview's coordinates, as in AppKit.
    @objc(ak_hitTest:) open func hitTest(_ point: CGPoint) -> UIView? {
        ViewBridge.defaultHitTest(self, superview.map { convert(point, from: $0) } ?? point)
    }

    @objc(ak_menuForEvent:) open func menu(for event: NSEvent) -> NSMenu? { nil }

    public var alphaValue: CGFloat {
        get { alpha }
        set { alpha = newValue }
    }

    public var needsDisplay: Bool {
        get { false }
        set { if newValue { setNeedsDisplay() } }
    }

    public var needsLayout: Bool {
        get { false }
        set { if newValue { setNeedsLayout() } }
    }

    public var wantsLayer: Bool {
        get { true }
        set {}
    }

    public var layerContentsRedrawPolicy: NSViewLayerContentsRedrawPolicy {
        get { .onSetNeedsDisplay }
        set {}
    }

    public var canDrawSubviewsIntoLayer: Bool {
        get { false }
        set {}
    }

    public var effectiveAppearance: NSAppearance { NSAppearance(style: traitCollection.userInterfaceStyle) }

    public var appearance: NSAppearance? {
        get { overrideUserInterfaceStyle == .unspecified ? nil : NSAppearance(style: overrideUserInterfaceStyle) }
        set { overrideUserInterfaceStyle = newValue?.style ?? .unspecified }
    }

    public var isHiddenOrHasHiddenAncestor: Bool {
        var view: UIView? = self
        while let current = view {
            if current.isHidden { return true }
            view = current.superview
        }
        return false
    }

    public var visibleRect: CGRect {
        var rect = bounds
        var view: UIView = self
        while let parent = view.superview {
            let clipped = parent.bounds.intersection(view.convert(view.bounds, to: parent))
            rect = rect.intersection(parent.convert(clipped, to: self))
            view = parent
        }
        return rect
    }

    public var enclosingScrollView: NSScrollView? {
        var view = superview
        while let current = view {
            if let scrollView = current as? NSScrollView { return scrollView }
            view = current.superview
        }
        return nil
    }

    public var backingScaleFactor: CGFloat { window?.screen.scale ?? 2 }
    public var inLiveResize: Bool { false }
    @_disfavoredOverload public var toolTip: String? {
        get { nil }
        set {}
    }

    public var identifier: String? {
        get { accessibilityIdentifier }
        set { accessibilityIdentifier = newValue }
    }

    public func layoutSubtreeIfNeeded() { layoutIfNeeded() }
    public func autoscroll(with _: NSEvent) -> Bool { false }
    public func displayLink(target: Any, selector: Selector) -> CADisplayLink { CADisplayLink(target: target, selector: selector) }

    @discardableResult
    public func scrollToVisible(_ rect: CGRect) -> Bool {
        guard let scrollView = enclosingScrollView else { return false }
        scrollView.scrollRectToVisible(convert(rect, to: scrollView), animated: false)
        return true
    }
    public func showDefinition(for _: NSAttributedString?, range _: NSRange, options _: [AnyHashable: Any]?, baselineOriginProvider _: (NSRange) -> CGPoint) {}

    public var layerContentsPlacement: NSViewLayerContentsPlacement {
        get { .scaleAxesIndependently }
        set {}
    }

    public func bitmapImageRepForCachingDisplay(in rect: CGRect) -> NSBitmapImageRep? {
        let scale = window?.screen.scale ?? 2
        return NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(ceil(rect.width * scale)), pixelsHigh: Int(ceil(rect.height * scale)),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )
    }

    public func cacheDisplay(in rect: CGRect, to representation: NSBitmapImageRep) {
        guard let context = representation.context, rect.height > 0 else { return }
        let scale = CGFloat(context.height) / rect.height
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(context.height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -rect.minX, y: -rect.minY)
        layer.render(in: context)
        context.restoreGState()
    }

    public func addSubview(_ view: UIView, positioned place: UIWindow.OrderingMode, relativeTo other: UIView?) {
        if let other, place == .above {
            insertSubview(view, aboveSubview: other)
        } else if let other {
            insertSubview(view, belowSubview: other)
        } else if place == .above {
            addSubview(view)
        } else {
            insertSubview(view, at: 0)
        }
    }

    public var postsBoundsChangedNotifications: Bool {
        get { postsFrameChangedNotifications }
        set { postsFrameChangedNotifications = newValue }
    }

    public var postsFrameChangedNotifications: Bool {
        get { objc_getAssociatedObject(self, &ViewBridge.postsChangesKey) != nil }
        set { objc_setAssociatedObject(self, &ViewBridge.postsChangesKey, newValue ? true : nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    public var fittingSize: CGSize { systemLayoutSizeFitting(UIView.layoutFittingCompressedSize) }

    public func sortSubviews(
        _ compare: @convention(c) (UIView, UIView, UnsafeMutableRawPointer?) -> ComparisonResult,
        context: UnsafeMutableRawPointer?
    ) {
        for view in subviews.sorted(by: { compare($0, $1, context) == .orderedAscending }) {
            bringSubviewToFront(view)
        }
    }
    public func displayIfNeeded() { setNeedsDisplay() }
    public func display() { setNeedsDisplay() }
    public func discardCursorRects() {}
    public func addCursorRect(_: CGRect, cursor _: NSCursor) {}
    public func registerForDraggedTypes(_: [NSPasteboard.PasteboardType]) {}
    public func unregisterDraggedTypes() {}

    public func backingAlignedRect(_ rect: CGRect, options _: NSAlignmentOptions) -> CGRect {
        let scale = window?.screen.scale ?? 2
        return CGRect(
            x: (rect.minX * scale).rounded() / scale,
            y: (rect.minY * scale).rounded() / scale,
            width: (rect.width * scale).rounded() / scale,
            height: (rect.height * scale).rounded() / scale
        )
    }

    public func centerScanRect(_ rect: CGRect) -> CGRect { backingAlignedRect(rect, options: []) }

    // MARK: Tracking areas

    public var trackingAreas: [NSTrackingArea] { ViewBridge.tracking(of: self) }

    public func addTrackingArea(_ area: NSTrackingArea) {
        ViewBridge.setTracking(trackingAreas + [area], on: self)
        ViewBridge.installHover(on: self)
    }

    public func removeTrackingArea(_ area: NSTrackingArea) {
        ViewBridge.setTracking(trackingAreas.filter { $0 !== area }, on: self)
    }
}

extension UIResponder {
    @objc(ak_mouseDown:) open func mouseDown(with event: NSEvent) {}
    @objc(ak_mouseUp:) open func mouseUp(with event: NSEvent) {}
    @objc(ak_mouseDragged:) open func mouseDragged(with event: NSEvent) {}
    @objc(ak_mouseMoved:) open func mouseMoved(with event: NSEvent) {}
    @objc(ak_mouseEntered:) open func mouseEntered(with event: NSEvent) {}
    @objc(ak_mouseExited:) open func mouseExited(with event: NSEvent) {}
    @objc(ak_rightMouseDown:) open func rightMouseDown(with event: NSEvent) {}
    @objc(ak_rightMouseUp:) open func rightMouseUp(with event: NSEvent) {}
    @objc(ak_otherMouseDown:) open func otherMouseDown(with event: NSEvent) {}
    @objc(ak_scrollWheel:) open func scrollWheel(with event: NSEvent) {}
    @objc(ak_keyDown:) open func keyDown(with event: NSEvent) {}
    @objc(ak_keyUp:) open func keyUp(with event: NSEvent) {}
    @objc(ak_flagsChanged:) open func flagsChanged(with event: NSEvent) {}
    @objc(ak_cursorUpdate:) open func cursorUpdate(with event: NSEvent) {}
    @objc(ak_performKeyEquivalent:) open func performKeyEquivalent(with event: NSEvent) -> Bool { false }
    @objc(ak_cancelOperation:) open func cancelOperation(_ sender: Any?) {}
}

public nonisolated enum NSViewLayerContentsPlacement: Sendable { case scaleAxesIndependently, scaleProportionallyToFit, scaleProportionallyToFill, center, top, topRight, right, bottomRight, bottom, bottomLeft, left, topLeft }

public nonisolated enum NSViewLayerContentsRedrawPolicy: Sendable {
    case never, onSetNeedsDisplay, duringViewResize, beforeViewResize, crossfade
}

public nonisolated struct NSAlignmentOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
}

public extension UIView.AutoresizingMask {
    static var width: Self { .flexibleWidth }
    static var height: Self { .flexibleHeight }
    static var minXMargin: Self { .flexibleLeftMargin }
    static var maxXMargin: Self { .flexibleRightMargin }
    static var minYMargin: Self { .flexibleTopMargin }
    static var maxYMargin: Self { .flexibleBottomMargin }
}

public extension NSView {
    static let boundsDidChangeNotification = Notification.Name("NSViewBoundsDidChangeNotification")
    static let frameDidChangeNotification = Notification.Name("NSViewFrameDidChangeNotification")
}

@MainActor
enum ViewBridge {
    nonisolated(unsafe) private static var trackingKey: UInt8 = 0
    nonisolated(unsafe) static var postsChangesKey: UInt8 = 0
    nonisolated(unsafe) private static var hoverKey: UInt8 = 0
    nonisolated(unsafe) private static var scrollKey: UInt8 = 0
    private static var originalHitTest: (@convention(c) (UIView, Selector, CGPoint, UIEvent?) -> UIView?)?

    static func tracking(of view: UIView) -> [NSTrackingArea] {
        objc_getAssociatedObject(view, &trackingKey) as? [NSTrackingArea] ?? []
    }

    static func setTracking(_ areas: [NSTrackingArea], on view: UIView) {
        objc_setAssociatedObject(view, &trackingKey, areas, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func overrides(_ object: AnyObject, _ selector: Selector, base: AnyClass) -> Bool {
        class_getMethodImplementation(object_getClass(object), selector) != class_getMethodImplementation(base, selector)
    }

    static func defaultHitTest(_ view: UIView, _ point: CGPoint) -> UIView? {
        originalHitTest?(view, #selector(UIView.hitTest(_:with:)), point, nil)
    }

    // MARK: Hover and scroll wheel

    static func installHover(on view: UIView) {
        guard objc_getAssociatedObject(view, &hoverKey) == nil else { return }
        let hover = UIHoverGestureRecognizer(target: PointerRouter.shared, action: #selector(PointerRouter.hover(_:)))
        hover.cancelsTouchesInView = false
        hover.delaysTouchesBegan = false
        view.addGestureRecognizer(hover)
        objc_setAssociatedObject(view, &hoverKey, hover, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func installScrollWheel(on view: UIView) {
        guard objc_getAssociatedObject(view, &scrollKey) == nil else { return }
        let pan = UIPanGestureRecognizer(target: PointerRouter.shared, action: #selector(PointerRouter.scroll(_:)))
        pan.allowedScrollTypesMask = .all
        pan.allowedTouchTypes = []
        pan.cancelsTouchesInView = false
        view.addGestureRecognizer(pan)
        objc_setAssociatedObject(view, &scrollKey, pan, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: Lifecycle

    static func prepareForDisplay(_ view: UIView) {
        if overrides(view, #selector(UIView.draw(_:)), base: UIView.self) {
            view.isOpaque = false
            view.contentMode = .redraw
        }
        if overrides(view, #selector(UIResponder.scrollWheel(with:)), base: UIResponder.self) {
            installScrollWheel(on: view)
        }
    }

    // MARK: Installation

    static func install() {
        guard originalHitTest == nil else { return }
        let view: AnyClass = UIView.self
        let hitTest = class_getInstanceMethod(view, #selector(UIView.hitTest(_:with:)))!
        originalHitTest = unsafeBitCast(
            method_getImplementation(hitTest),
            to: (@convention(c) (UIView, Selector, CGPoint, UIEvent?) -> UIView?).self
        )
        let pairs: [(AnyClass, Selector, Selector)] = [
            (view, #selector(UIView.layoutSubviews), #selector(UIView.ak_swizzled_layoutSubviews)),
            (view, #selector(UIView.didMoveToWindow), #selector(UIView.ak_swizzled_didMoveToWindow)),
            (view, #selector(UIView.didMoveToSuperview), #selector(UIView.ak_swizzled_didMoveToSuperview)),
            (view, #selector(UIView.hitTest(_:with:)), #selector(UIView.ak_swizzled_hitTest(_:with:))),
            (view, #selector(UIResponder.touchesBegan(_:with:)), #selector(UIView.ak_swizzled_touchesBegan(_:with:))),
            (view, #selector(UIResponder.touchesMoved(_:with:)), #selector(UIView.ak_swizzled_touchesMoved(_:with:))),
            (view, #selector(UIResponder.touchesEnded(_:with:)), #selector(UIView.ak_swizzled_touchesEnded(_:with:))),
            (view, #selector(UIResponder.touchesCancelled(_:with:)), #selector(UIView.ak_swizzled_touchesCancelled(_:with:))),
            (UIResponder.self, #selector(UIResponder.pressesBegan(_:with:)), #selector(UIResponder.ak_swizzled_pressesBegan(_:with:))),
            (UIResponder.self, #selector(UIResponder.pressesEnded(_:with:)), #selector(UIResponder.ak_swizzled_pressesEnded(_:with:))),
            (UIResponder.self, #selector(getter: UIResponder.canBecomeFirstResponder), #selector(getter: UIResponder.ak_swizzled_canBecomeFirstResponder)),
            (UIApplication.self, #selector(UIApplication.sendEvent(_:)), #selector(UIApplication.ak_swizzled_sendEvent(_:))),
            (UIWindow.self, #selector(UIWindow.sendEvent(_:)), #selector(UIWindow.ak_swizzled_sendEvent(_:)))
        ]
        for (cls, original, replacement) in pairs {
            guard let a = class_getInstanceMethod(cls, original), let b = class_getInstanceMethod(cls, replacement) else { continue }
            if class_addMethod(cls, original, method_getImplementation(b), method_getTypeEncoding(b)) {
                class_replaceMethod(cls, replacement, method_getImplementation(a), method_getTypeEncoding(a))
            } else {
                method_exchangeImplementations(a, b)
            }
        }
    }
}

extension UIView {
    @objc func ak_swizzled_layoutSubviews() {
        ak_swizzled_layoutSubviews()
        layout()
        if postsFrameChangedNotifications {
            NotificationCenter.default.post(name: NSView.frameDidChangeNotification, object: self)
            NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: self)
        }
    }

    @objc func ak_swizzled_didMoveToWindow() {
        ak_swizzled_didMoveToWindow()
        if window != nil { ViewBridge.prepareForDisplay(self) }
        viewDidMoveToWindow()
        if window != nil, !trackingAreas.isEmpty || ViewBridge.overrides(self, #selector(UIView.updateTrackingAreas), base: UIView.self) {
            updateTrackingAreas()
        }
    }

    @objc func ak_swizzled_didMoveToSuperview() {
        ak_swizzled_didMoveToSuperview()
        viewDidMoveToSuperview()
    }

    @objc func ak_swizzled_hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if ViewBridge.overrides(self, #selector(UIView.hitTest(_:)), base: UIView.self) {
            guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
            return hitTest(superview.map { convert(point, to: $0) } ?? point)
        }
        return ak_swizzled_hitTest(point, with: event)
    }

    private func routes(_ selector: Selector) -> Bool {
        ViewBridge.overrides(self, selector, base: UIResponder.self)
    }

    private func mouseEvent(_ type: NSEvent.EventType, _ touches: Set<UITouch>, _ event: UIEvent?) -> NSEvent? {
        guard let touch = touches.first else { return nil }
        let location = touch.location(in: nil)
        NSEvent.lastLocation = location
        return NSEvent(
            type: type,
            location: location,
            modifiers: NSEvent.ModifierFlags(event?.modifierFlags ?? []),
            window: window,
            clickCount: touch.tapCount,
            buttonNumber: event?.buttonMask.contains(.secondary) == true ? 1 : 0
        )
    }

    @objc func ak_swizzled_touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let isSecondary = event?.buttonMask.contains(.secondary) == true
        if isSecondary, let mouse = mouseEvent(.rightMouseDown, touches, event) {
            if let menu = menu(for: mouse) {
                menu.popUp(at: convert(mouse.locationInWindow, from: nil), in: self)
                return
            }
            if routes(#selector(UIResponder.rightMouseDown(with:))) {
                rightMouseDown(with: mouse)
                return
            }
        } else if routes(#selector(UIResponder.mouseDown(with:))), let mouse = mouseEvent(.leftMouseDown, touches, event) {
            mouseDown(with: mouse)
            return
        }
        ak_swizzled_touchesBegan(touches, with: event)
    }

    @objc func ak_swizzled_touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if routes(#selector(UIResponder.mouseDragged(with:))), let mouse = mouseEvent(.leftMouseDragged, touches, event) {
            mouseDragged(with: mouse)
            return
        }
        ak_swizzled_touchesMoved(touches, with: event)
    }

    @objc func ak_swizzled_touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if routes(#selector(UIResponder.mouseUp(with:))), let mouse = mouseEvent(.leftMouseUp, touches, event) {
            mouseUp(with: mouse)
            return
        }
        ak_swizzled_touchesEnded(touches, with: event)
    }

    @objc func ak_swizzled_touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if routes(#selector(UIResponder.mouseUp(with:))), let mouse = mouseEvent(.leftMouseUp, touches, event) {
            mouseUp(with: mouse)
            return
        }
        ak_swizzled_touchesCancelled(touches, with: event)
    }
}

extension UIResponder {
    @objc var ak_swizzled_canBecomeFirstResponder: Bool {
        if let view = self as? UIView, view.acceptsFirstResponder { return true }
        return self.ak_swizzled_canBecomeFirstResponder
    }

    @objc func ak_swizzled_pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if ViewBridge.overrides(self, #selector(UIResponder.keyDown(with:)), base: UIResponder.self),
           let press = presses.first,
           let key = NSEvent.key(press, type: .keyDown, window: (self as? UIView)?.window) {
            keyDown(with: key)
            return
        }
        ak_swizzled_pressesBegan(presses, with: event)
    }

    @objc func ak_swizzled_pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if ViewBridge.overrides(self, #selector(UIResponder.keyUp(with:)), base: UIResponder.self),
           let press = presses.first,
           let key = NSEvent.key(press, type: .keyUp, window: (self as? UIView)?.window) {
            keyUp(with: key)
            return
        }
        ak_swizzled_pressesEnded(presses, with: event)
    }
}

extension UIApplication {
    /// Key events pass through local monitors before reaching the responder chain, as in AppKit.
    @objc func ak_swizzled_sendEvent(_ event: UIEvent) {
        if let pressesEvent = event as? UIPressesEvent {
            for press in pressesEvent.allPresses where press.phase == .began {
                NSEvent.currentModifiers = NSEvent.ModifierFlags(press.key?.modifierFlags ?? [])
                if let key = NSEvent.key(press, type: .keyDown, window: keyWindowForMonitors),
                   NSEvent.dispatch(key) == nil {
                    return
                }
            }
        }
        ak_swizzled_sendEvent(event)
    }

    private var keyWindowForMonitors: UIWindow? { NSApplication.shared.keyWindow }
}

extension UIWindow {
    @objc func ak_swizzled_sendEvent(_ event: UIEvent) {
        if event.type == .touches, let touch = event.allTouches?.first {
            let location = touch.location(in: nil)
            NSEvent.lastLocation = location
            NSEvent.currentModifiers = NSEvent.ModifierFlags(event.modifierFlags)
            let isSecondary = event.buttonMask.contains(.secondary)
            let type: NSEvent.EventType? = switch touch.phase {
            case .began: isSecondary ? .rightMouseDown : .leftMouseDown
            case .moved: .leftMouseDragged
            case .ended, .cancelled: isSecondary ? .rightMouseUp : .leftMouseUp
            default: nil
            }
            if let type {
                let mouse = NSEvent(
                    type: type,
                    location: location,
                    modifiers: NSEvent.ModifierFlags(event.modifierFlags),
                    window: self,
                    clickCount: touch.tapCount,
                    buttonNumber: isSecondary ? 1 : 0
                )
                if NSEvent.dispatch(mouse) == nil { return }
            }
        }
        ak_swizzled_sendEvent(event)
    }
}

/// Target for the gesture recognizers that synthesize hover and scroll-wheel events.
final class PointerRouter: NSObject {
    static let shared = PointerRouter()

    @objc func hover(_ recognizer: UIHoverGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let location = recognizer.location(in: view)
        let windowLocation = recognizer.location(in: nil)
        NSEvent.lastLocation = windowLocation
        NSEvent.currentModifiers = NSEvent.ModifierFlags(recognizer.modifierFlags)
        let isOver = recognizer.state == .began || recognizer.state == .changed
        for area in view.trackingAreas {
            let rect = area.options.contains(.inVisibleRect) ? view.bounds : area.rect
            let isInside = isOver && rect.contains(location)
            let target = area.owner as? UIResponder ?? view
            func send(_ type: NSEvent.EventType) -> NSEvent {
                NSEvent(type: type, location: windowLocation, modifiers: NSEvent.currentModifiers, window: view.window, trackingArea: area)
            }
            if isInside != area.isInside {
                area.isInside = isInside
                if area.options.contains(.mouseEnteredAndExited) {
                    let event = send(isInside ? .mouseEntered : .mouseExited)
                    NSEvent.current = event
                    if isInside { target.mouseEntered(with: event) } else { target.mouseExited(with: event) }
                }
            }
            if isInside, area.options.contains(.mouseMoved) {
                let event = send(.mouseMoved)
                NSEvent.current = event
                target.mouseMoved(with: event)
            }
        }
    }

    @objc func scroll(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let translation = recognizer.translation(in: view)
        recognizer.setTranslation(.zero, in: view)
        let phase: NSEvent.Phase = switch recognizer.state {
        case .began: .began
        case .changed: .changed
        case .ended: .ended
        default: .cancelled
        }
        let event = NSEvent(
            type: .scrollWheel,
            location: recognizer.location(in: nil),
            modifiers: NSEvent.currentModifiers,
            window: view.window,
            scrollingDeltaX: translation.x,
            scrollingDeltaY: translation.y,
            phase: phase
        )
        if NSEvent.dispatch(event) != nil { view.scrollWheel(with: event) }
    }
}
