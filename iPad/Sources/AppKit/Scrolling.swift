/// AppKit's scroll view maps closely onto UIScrollView: a clip view's bounds origin
/// *is* a UIScrollView's content offset, so the scroll view acts as its own clip view.
public typealias NSClipView = UIScrollView

public nonisolated enum NSBorderType: Sendable { case noBorder, lineBorder, bezelBorder, grooveBorder }
public nonisolated enum NSScrollerStyle: Sendable { case legacy, overlay }

open class NSScrollView: UIScrollView, UIScrollViewDelegate, @unchecked Sendable {
    public static let willStartLiveScrollNotification = Notification.Name("NSScrollViewWillStartLiveScroll")
    public static let didLiveScrollNotification = Notification.Name("NSScrollViewDidLiveScroll")
    public static let didEndLiveScrollNotification = Notification.Name("NSScrollViewDidEndLiveScroll")

    public enum Elasticity: Sendable { case automatic, none, allowed }

    public var hasVerticalScroller = false { didSet { showsVerticalScrollIndicator = hasVerticalScroller } }
    public var hasHorizontalScroller = false { didSet { showsHorizontalScrollIndicator = hasHorizontalScroller } }
    public var autohidesScrollers = true
    public var drawsBackground = false
    public var borderType: NSBorderType = .noBorder
    public var scrollerStyle: NSScrollerStyle = .overlay
    public var usesPredominantAxisScrolling = true
    public var automaticallyAdjustsContentInsets = false
    public var contentInsets: UIEdgeInsets {
        get { contentInset }
        set { contentInset = newValue }
    }

    public var verticalScrollElasticity: Elasticity = .automatic { didSet { alwaysBounceVertical = verticalScrollElasticity == .allowed } }
    public var horizontalScrollElasticity: Elasticity = .automatic { didSet { bounces = horizontalScrollElasticity != .none || verticalScrollElasticity != .none } }

    override open var frame: CGRect {
        get { super.frame }
        set { super.frame = newValue.ak_validated(fallback: super.frame) }
    }

    public var contentView: NSClipView { self }
    public var verticalScroller: UIView? { nil }
    public var horizontalScroller: UIView? { nil }

    public var documentView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let documentView { addSubview(documentView) }
            syncContentSize()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        contentInsetAdjustmentBehavior = .never
        delegate = self
    }

    public required init?(coder: NSCoder) { super.init(coder: coder) }

    public func reflectScrolledClipView(_: NSClipView) { syncContentSize() }
    public func tile() { setNeedsLayout() }
    public func flashScrollers() { flashScrollIndicators() }

    override open func layoutSubviews() {
        super.layoutSubviews()
        syncContentSize()
    }

    func documentFrameDidChange(_ view: UIView) {
        if view === documentView { syncContentSize() }
    }

    public func syncContentSize() {
        let size = documentView?.frame.size ?? .zero
        if contentSize != size { contentSize = size }
    }

    open func scrollViewDidScroll(_: UIScrollView) {
        NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: self)
        if isTracking || isDecelerating {
            NotificationCenter.default.post(name: Self.didLiveScrollNotification, object: self)
        }
    }

    open func scrollViewWillBeginDragging(_: UIScrollView) {
        NotificationCenter.default.post(name: Self.willStartLiveScrollNotification, object: self)
    }

    open func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { NotificationCenter.default.post(name: Self.didEndLiveScrollNotification, object: self) }
    }

    open func scrollViewDidEndDecelerating(_: UIScrollView) {
        NotificationCenter.default.post(name: Self.didEndLiveScrollNotification, object: self)
    }
}

public extension UIScrollView {
    /// NSScrollView.contentSize is the viewport; UIScrollView's is the document.
    var nsContentSize: CGSize { bounds.size }

    var documentVisibleRect: CGRect { bounds }

    func scroll(to point: CGPoint) { contentOffset = point }
    func constrainBoundsRect(_ rect: CGRect) -> CGRect { rect }
}
