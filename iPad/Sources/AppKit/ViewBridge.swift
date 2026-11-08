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
    @objc(ak_isFlipped) open var isFlipped: Bool { true }
    @objc(ak_acceptsFirstMouse:) open func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }
    @objc(ak_acceptsFirstResponder) open var acceptsFirstResponder: Bool { false }

    @objc(ak_setFrameSize:) open func setFrameSize(_ newSize: CGSize) { frame.size = newSize }
    @objc(ak_setFrameOrigin:) open func setFrameOrigin(_ newOrigin: CGPoint) { frame.origin = newOrigin }

    /// Point is in the superview's coordinates, as in AppKit.
    @objc(ak_hitTest:) open func hitTest(_ point: CGPoint) -> UIView? {
        ViewBridge.defaultHitTest(self, superview.map { convert(point, from: $0) } ?? point)
    }

    @objc(ak_menuForEvent:) open func menu(for event: NSEvent) -> NSMenu? { nil }

    /// What a context menu at `point` lifts, framed in this view. Nil lifts nothing, as on macOS.
    @objc(ak_contextMenuPreviewAt:) open func contextMenuPreview(at point: CGPoint) -> UIView? { nil }

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
    public var fittingSize: CGSize {
        if String(describing: type(of: self)).contains("HostingView") {
            return sizeThatFits(CGSize(width: bounds.width > 0 ? bounds.width : CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
        }
        guard bounds.width > 0 else { return systemLayoutSizeFitting(UIView.layoutFittingCompressedSize) }
        return systemLayoutSizeFitting(
            CGSize(width: bounds.width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
    }

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
    @objc(ak_keyDown:) open func keyDown(with event: NSEvent) { ViewBridge.continueKeyDown(from: self) }
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
    public static let alignAllEdgesNearest = NSAlignmentOptions(rawValue: 1)
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
    nonisolated(unsafe) private static var lastSizeKey: UInt8 = 0
    private static var isApplyingFrameSize = false

    static func sizeChanged(_ view: UIView) -> Bool {
        let size = view.bounds.size
        let previous = (objc_getAssociatedObject(view, &lastSizeKey) as? NSValue)?.cgSizeValue
        guard previous != size else { return false }
        objc_setAssociatedObject(view, &lastSizeKey, NSValue(cgSize: size), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return true
    }

    /// AppKit routes every resize through setFrameSize(_:); UIKit only sets the frame.
    static func frameDidChange(_ view: UIView, from oldSize: CGSize) {
        guard oldSize != view.frame.size else { return }
        (view.superview as? NSScrollView)?.documentFrameDidChange(view)
        guard !isApplyingFrameSize, overrides(view, #selector(UIView.setFrameSize(_:)), base: UIView.self) else { return }
        isApplyingFrameSize = true
        view.setFrameSize(view.frame.size)
        isApplyingFrameSize = false
    }
    nonisolated(unsafe) private static var hoverKey: UInt8 = 0
    nonisolated(unsafe) private static var scrollKey: UInt8 = 0
    nonisolated(unsafe) private static var pressKey: UInt8 = 0
    private typealias ResponderIMP = @convention(c) (UIResponder, Selector, NSSet, UIEvent?) -> Void
    private static var responderIMPs: [Selector: ResponderIMP] = [:]
    private static let forwardedSelectors: Set<Selector> = [
        #selector(UIResponder.touchesBegan(_:with:)),
        #selector(UIResponder.touchesMoved(_:with:)),
        #selector(UIResponder.touchesEnded(_:with:)),
        #selector(UIResponder.touchesCancelled(_:with:)),
        #selector(UIResponder.pressesBegan(_:with:)),
        #selector(UIResponder.pressesEnded(_:with:))
    ]

    static var pendingKeyPresses: (NSSet, UIEvent?)?

    /// `super.keyDown` in AppKit passes the key to the next responder.
    static func continueKeyDown(from responder: UIResponder) {
        guard let (presses, event) = pendingKeyPresses else { return }
        pendingKeyPresses = nil
        forward(responder, #selector(UIResponder.pressesBegan(_:with:)), presses, event)
    }

    /// Calls UIKit's implementation under its real selector. UIKit forwards up the
    /// responder chain using the selector it was invoked with, so the swizzled name
    /// would reach responders that do not implement it.
    static func forward(_ responder: UIResponder, _ selector: Selector, _ items: NSSet, _ event: UIEvent?) {
        responderIMPs[selector]?(responder, selector, items, event)
    }

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

    /// Touch has no secondary click, so a long press opens the same context menus.
    static func installContextMenuPress(on view: UIView) {
        guard objc_getAssociatedObject(view, &pressKey) == nil else { return }
        let press = UILongPressGestureRecognizer(target: PointerRouter.shared, action: #selector(PointerRouter.contextPress(_:)))
        press.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        view.addGestureRecognizer(press)
        objc_setAssociatedObject(view, &pressKey, press, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private static var appClasses: [ObjectIdentifier: Bool] = [:]

    private static func isAppClass(_ type: AnyClass) -> Bool {
        let key = ObjectIdentifier(type)
        if let known = appClasses[key] { return known }
        let isApp = Bundle(for: type).bundlePath == Bundle.main.bundlePath
        appClasses[key] = isApp
        return isApp
    }

    // MARK: Lifecycle

    static func prepareForDisplay(_ view: UIView) {
        // Only the app's own views: UIKit's drawing views manage their own opacity.
        if isAppClass(type(of: view)), overrides(view, #selector(UIView.draw(_:)), base: UIView.self) {
            view.isOpaque = false
            view.contentMode = .redraw
        }
        if overrides(view, #selector(UIResponder.scrollWheel(with:)), base: UIResponder.self), !(view is UIScrollView) {
            installScrollWheel(on: view)
        }
        if overrides(view, #selector(UIView.menu(for:)), base: UIView.self) {
            installContextMenuPress(on: view)
        }
        if overrides(view, #selector(UIView.viewDidChangeEffectiveAppearance), base: UIView.self) {
            view.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _: UITraitCollection) in
                view.viewDidChangeEffectiveAppearance()
            }
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
            (view, #selector(UIView.willMove(toWindow:)), #selector(UIView.ak_swizzled_willMove(toWindow:))),
            (view, #selector(setter: UIView.frame), #selector(UIView.ak_swizzled_setFrame(_:))),
            (UIWindow.self, #selector(UIView.safeAreaInsetsDidChange), #selector(UIWindow.ak_swizzled_safeAreaInsetsDidChange)),
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
            if forwardedSelectors.contains(original) {
                responderIMPs[original] = unsafeBitCast(method_getImplementation(a), to: ResponderIMP.self)
            }
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
        if ViewBridge.overrides(self, #selector(UIView.updateTrackingAreas), base: UIView.self), ViewBridge.sizeChanged(self) {
            updateTrackingAreas()
        }
        if postsFrameChangedNotifications {
            NotificationCenter.default.post(name: NSView.frameDidChangeNotification, object: self)
            NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: self)
        }
    }

    @objc func ak_swizzled_setFrame(_ frame: CGRect) {
        let oldSize = self.frame.size
        ak_swizzled_setFrame(frame)
        ViewBridge.frameDidChange(self, from: oldSize)
    }

    @objc func ak_swizzled_willMove(toWindow newWindow: UIWindow?) {
        ak_swizzled_willMove(toWindow: newWindow)
        viewWillMove(toWindow: newWindow)
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
                menu.popUpForContextClick(at: convert(mouse.locationInWindow, from: nil), in: self)
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
        ViewBridge.forward(self, #selector(UIResponder.touchesBegan(_:with:)), touches as NSSet, event)
    }

    @objc func ak_swizzled_touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if routes(#selector(UIResponder.mouseDragged(with:))), let mouse = mouseEvent(.leftMouseDragged, touches, event) {
            mouseDragged(with: mouse)
            return
        }
        ViewBridge.forward(self, #selector(UIResponder.touchesMoved(_:with:)), touches as NSSet, event)
    }

    @objc func ak_swizzled_touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if routes(#selector(UIResponder.mouseUp(with:))), let mouse = mouseEvent(.leftMouseUp, touches, event) {
            mouseUp(with: mouse)
            return
        }
        ViewBridge.forward(self, #selector(UIResponder.touchesEnded(_:with:)), touches as NSSet, event)
    }

    @objc func ak_swizzled_touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if routes(#selector(UIResponder.mouseUp(with:))), let mouse = mouseEvent(.leftMouseUp, touches, event) {
            mouseUp(with: mouse)
            return
        }
        ViewBridge.forward(self, #selector(UIResponder.touchesCancelled(_:with:)), touches as NSSet, event)
    }
}

extension UIResponder {
    @objc var ak_swizzled_canBecomeFirstResponder: Bool {
        if let view = self as? UIView, view.acceptsFirstResponder { return true }
        return self.ak_swizzled_canBecomeFirstResponder
    }

    @objc func ak_swizzled_pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // NSTextView routes its own keys; UITextView's handling reaches this base
        // implementation, so routing it here again would recurse.
        if !(self is NSTextView),
           ViewBridge.overrides(self, #selector(UIResponder.keyDown(with:)), base: UIResponder.self),
           let press = presses.first,
           let key = NSEvent.key(press, type: .keyDown, window: (self as? UIView)?.window) {
            ViewBridge.pendingKeyPresses = (presses as NSSet, event)
            keyDown(with: key)
            ViewBridge.pendingKeyPresses = nil
            return
        }
        ViewBridge.forward(self, #selector(UIResponder.pressesBegan(_:with:)), presses as NSSet, event)
    }

    @objc func ak_swizzled_pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if ViewBridge.overrides(self, #selector(UIResponder.keyUp(with:)), base: UIResponder.self),
           let press = presses.first,
           let key = NSEvent.key(press, type: .keyUp, window: (self as? UIView)?.window) {
            keyUp(with: key)
            return
        }
        ViewBridge.forward(self, #selector(UIResponder.pressesEnded(_:with:)), presses as NSSet, event)
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

/// iPadOS has no hover tool tips on arbitrary view regions.
public protocol NSViewToolTipOwner: AnyObject {}

public extension UIView {
    typealias ToolTipTag = Int

    @discardableResult
    func addToolTip(_: CGRect, owner _: Any, userData _: UnsafeMutableRawPointer?) -> ToolTipTag { 0 }
    func removeAllToolTips() {}
    /// UIKit views and their layers share one coordinate space.
    func convertToLayer(_ rect: CGRect) -> CGRect { rect }
    func convertFromLayer(_ rect: CGRect) -> CGRect { rect }
}

extension UIWindow {
    public var colorSpace: NSColorSpace? { nil }
    public func setFrame(_: CGRect, display _: Bool) {}
    public func disableCursorRects() {}
    public func enableCursorRects() {}

    /// Window-space centre of the toolbar row. The system places that row differently
    /// in a window and in full screen, so the toolbar search field measures it.
    public nonisolated(unsafe) static var ak_toolbarCenterY: CGFloat = 27
    /// Where content that scrolls beneath the toolbar comes to rest.
    public nonisolated(unsafe) static var ak_toolbarBottomY: CGFloat = 58
    public static let ak_safeAreaDidChange = Notification.Name("AKWindowSafeAreaDidChange")

    @objc func ak_swizzled_safeAreaInsetsDidChange() {
        ak_swizzled_safeAreaInsetsDidChange()
        NotificationCenter.default.post(name: UIWindow.ak_safeAreaDidChange, object: self)
        if let style = NSApp.appearance?.style { overrideUserInterfaceStyle = style }
        AppearanceState.style = traitCollection.userInterfaceStyle
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (window: UIWindow, _: UITraitCollection) in
            AppearanceState.style = window.traitCollection.userInterfaceStyle
        }
    }

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
extension CGRect {
    /// Replaces any component a CALayer would reject with the matching one from `fallback`.
    func ak_validated(fallback: CGRect) -> CGRect {
        func valid(_ value: CGFloat, _ replacement: CGFloat) -> CGFloat {
            value.isFinite && abs(value) < 1_000_000 ? value : replacement
        }
        return CGRect(
            x: valid(origin.x, fallback.origin.x),
            y: valid(origin.y, fallback.origin.y),
            width: valid(size.width, fallback.size.width),
            height: valid(size.height, fallback.size.height)
        )
    }
}

extension UIView {
    /// The part of the window standing in for one AppKit window: a popover overlay,
    /// a presented sheet or popover, or the main content.
    fileprivate var ak_windowLayer: UIView {
        var top: UIView = self
        while let parent = top.superview, !(parent is UIWindow), !(top is PopoverContainerView) {
            top = parent
        }
        return top
    }

    /// AppKit only tracks the pointer in the window under it; UIKit hover recognizers
    /// fire through popovers and sheets that are in the same window.
    fileprivate func ak_isCovered(atWindowPoint point: CGPoint) -> Bool {
        guard !trackingAreas.isEmpty, let window, let hit = window.hitTest(point, with: nil),
              hit !== self, !hit.isDescendant(of: self)
        else { return false }
        return hit.ak_windowLayer !== ak_windowLayer
    }

    /// True when nothing, in any layer, is above this view at the pointer.
    public var isFrontmostAtPointer: Bool {
        guard let window, let hit = window.hitTest(NSEvent.lastLocation, with: nil) else { return true }
        return hit === self || hit.isDescendant(of: self)
    }
}

final class PointerRouter: NSObject {
    static let shared = PointerRouter()

    @objc func hover(_ recognizer: UIHoverGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let location = recognizer.location(in: view)
        let windowLocation = recognizer.location(in: nil)
        NSEvent.lastLocation = windowLocation
        NSEvent.currentModifiers = NSEvent.ModifierFlags(recognizer.modifierFlags)
        let isOver = (recognizer.state == .began || recognizer.state == .changed)
            && !view.ak_isCovered(atWindowPoint: windowLocation)
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

    @objc func contextPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let view = recognizer.view else { return }
        let location = recognizer.location(in: nil)
        NSEvent.lastLocation = location
        let event = NSEvent(type: .rightMouseDown, location: location, window: view.window, clickCount: 1, buttonNumber: 1)
        NSEvent.current = event
        view.menu(for: event)?.popUpForContextClick(at: recognizer.location(in: view), in: view)
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

/// Draws a very tall canvas through a surface a few screens high that follows the
/// scroll position. AppKit tiles large layer-backed views; a UIKit layer beyond the
/// GPU texture limit renders nothing.
public final class NSViewportBackingView: UIView {
    public var drawContent: ((CGRect) -> Void)?
    private weak var owner: UIView?
    private var scrollObserver: (any NSObjectProtocol)?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isUserInteractionEnabled = false
    }

    public required init?(coder: NSCoder) { super.init(coder: coder) }

    public func attach(to owner: UIView) {
        self.owner = owner
        if superview !== owner { owner.insertSubview(self, at: 0) }
        if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
        scrollObserver = owner.enclosingScrollView.map { scrollView in
            NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification, object: scrollView, queue: nil
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.reposition() }
            }
        }
        reposition()
    }

    public func reposition() {
        guard let owner else { return }
        let visible = owner.enclosingScrollView.map { owner.convert($0.bounds, from: $0) } ?? owner.bounds
        let needed = visible.insetBy(dx: 0, dy: -96).intersection(owner.bounds)
        let widthMatches = abs(frame.width - owner.bounds.width) < 0.5
        guard !needed.isNull, !(widthMatches && frame.contains(needed)) else { return }
        frame = visible.insetBy(dx: 0, dy: -visible.height).intersection(owner.bounds)
        setNeedsDisplay()
    }

    public func invalidate(_ rect: CGRect?) {
        guard let rect else { return setNeedsDisplay() }
        setNeedsDisplay(rect.offsetBy(dx: -frame.minX, dy: -frame.minY))
    }

    override public func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.translateBy(x: -frame.minX, y: -frame.minY)
        drawContent?(rect.offsetBy(dx: frame.minX, dy: frame.minY))
        context.restoreGState()
    }
}
