// A small NSCollectionView: lays out visible items from its layout object as the
// enclosing scroll view moves. Only item-based, single-section use exists in the app.

@objc public protocol NSCollectionViewDataSource: NSObjectProtocol {
    @objc optional func numberOfSections(in collectionView: NSCollectionView) -> Int
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem
}

open class NSCollectionViewLayoutAttributes: NSObject {
    public var frame: CGRect = .zero
    public let indexPath: IndexPath?

    public init(forItemWith indexPath: IndexPath) {
        self.indexPath = indexPath
    }
}

open class NSCollectionViewLayout: NSObject {
    public fileprivate(set) weak var collectionView: NSCollectionView?

    open var collectionViewContentSize: CGSize { .zero }
    open func prepare() {}
    open func layoutAttributesForElements(in _: CGRect) -> [NSCollectionViewLayoutAttributes] { [] }
    open func layoutAttributesForItem(at _: IndexPath) -> NSCollectionViewLayoutAttributes? { nil }
    open func shouldInvalidateLayout(forBoundsChange _: CGRect) -> Bool { false }
    open func invalidateLayout() { collectionView?.setNeedsLayout() }
}

open class NSCollectionViewItem: NSObject {
    private var loadedView: UIView?

    public var view: UIView {
        get {
            if loadedView == nil { loadView() }
            return loadedView ?? UIView()
        }
        set { loadedView = newValue }
    }

    public var representedObject: Any?
    public var isSelected = false

    public override required init() {}

    open func loadView() { loadedView = UIView() }
    open func prepareForReuse() {}
}

open class NSCollectionView: UIView {
    public var collectionViewLayout: NSCollectionViewLayout? {
        didSet {
            collectionViewLayout?.collectionView = self
            setNeedsLayout()
        }
    }

    public weak var dataSource: NSCollectionViewDataSource?
    public var isSelectable = false
    public var allowsEmptySelection = true
    public var backgroundColors: [UIColor] = []
    private var registered: [String: NSCollectionViewItem.Type] = [:]
    private var visible: [IndexPath: NSCollectionViewItem] = [:]
    private var reusable: [String: [NSCollectionViewItem]] = [:]
    private var identifiers: [ObjectIdentifier: String] = [:]
    private var boundsObserver: (any NSObjectProtocol)?

    public func register(_ itemClass: NSCollectionViewItem.Type?, forItemWithIdentifier identifier: String) {
        registered[identifier] = itemClass
    }

    public func makeItem(withIdentifier identifier: String, for _: IndexPath) -> NSCollectionViewItem {
        if let item = reusable[identifier]?.popLast() {
            item.prepareForReuse()
            return item
        }
        let item = (registered[identifier] ?? NSCollectionViewItem.self).init()
        identifiers[ObjectIdentifier(item)] = identifier
        return item
    }

    public func reloadData() {
        for (_, item) in visible { recycle(item) }
        visible.removeAll()
        collectionViewLayout?.prepare()
        setNeedsLayout()
    }

    public func visibleItems() -> [NSCollectionViewItem] { Array(visible.values) }
    public func indexPath(for item: NSCollectionViewItem) -> IndexPath? { visible.first { $0.value === item }?.key }
    public func item(at indexPath: IndexPath) -> NSCollectionViewItem? { visible[indexPath] }
    public func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        collectionViewLayout?.layoutAttributesForItem(at: indexPath)
    }

    private func recycle(_ item: NSCollectionViewItem) {
        item.view.removeFromSuperview()
        if let identifier = identifiers[ObjectIdentifier(item)] {
            reusable[identifier, default: []].append(item)
        }
    }

    override open func didMoveToSuperview() {
        super.didMoveToSuperview()
        if let observer = boundsObserver { NotificationCenter.default.removeObserver(observer) }
        guard let scrollView = enclosingScrollView else { return }
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification, object: scrollView, queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.placeVisibleItems() }
        }
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        placeVisibleItems()
    }

    private func placeVisibleItems() {
        guard let layout = collectionViewLayout, let dataSource else { return }
        layout.prepare()
        let rect = convert(enclosingScrollView?.bounds ?? bounds, from: enclosingScrollView).insetBy(dx: 0, dy: -200)
        let attributes = layout.layoutAttributesForElements(in: rect)
        let wanted = Set(attributes.compactMap(\.indexPath))
        for (path, item) in visible where !wanted.contains(path) {
            recycle(item)
            visible[path] = nil
        }
        for attribute in attributes {
            guard let path = attribute.indexPath else { continue }
            let item = visible[path] ?? dataSource.collectionView(self, itemForRepresentedObjectAt: path)
            visible[path] = item
            if item.view.superview !== self { addSubview(item.view) }
            item.view.frame = attribute.frame
        }
    }
}
