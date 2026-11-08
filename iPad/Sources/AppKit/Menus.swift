import ObjectiveC

@objc public protocol NSMenuDelegate: NSObjectProtocol {
    @objc optional func menuWillOpen(_ menu: NSMenu)
    @objc optional func menuDidClose(_ menu: NSMenu)
    @objc optional func menuNeedsUpdate(_ menu: NSMenu)
}

public nonisolated enum NSControlStateValue: Int, Sendable {
    case off = 0, on = 1, mixed = -1
}

public nonisolated enum NSMenuItemImageVisibility: Sendable { case automatic, visible, hidden }

public final class NSMenuItem: NSObject {
    public typealias StateValue = NSControlStateValue

    public var title: String
    public var attributedTitle: NSAttributedString?
    public var action: Selector?
    public weak var target: AnyObject?
    public var keyEquivalent: String
    public var keyEquivalentModifierMask: NSEvent.ModifierFlags = .command
    public var representedObject: Any?
    public var submenu: NSMenu?
    public var state: StateValue = .off
    public var isEnabled = true
    public var isHidden = false
    public var image: UIImage?
    public var onStateImage: UIImage?
    public var offStateImage: UIImage?
    public var mixedStateImage: UIImage?
    public var tag = 0
    public var indentationLevel = 0
    public var toolTip: String?
    public var subtitle: String?
    public var isAlternate = false
    public var preferredImageVisibility: NSMenuItemImageVisibility = .automatic
    public var view: UIView?
    public private(set) var isSeparatorItem = false
    public var hasSubmenu: Bool { submenu != nil }
    public fileprivate(set) weak var menu: NSMenu?

    public init(title: String, action: Selector?, keyEquivalent: String) {
        self.title = title
        self.action = action
        self.keyEquivalent = keyEquivalent
    }

    public convenience override init() {
        self.init(title: "", action: nil, keyEquivalent: "")
    }

    public static func separator() -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isSeparatorItem = true
        return item
    }

    public static func sectionHeader(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    func perform() {
        guard let action else { return }
        UIApplication.shared.sendAction(action, to: target, from: self, for: nil)
    }

    var element: UIMenuElement? {
        guard !isHidden, !isSeparatorItem else { return nil }
        let text = attributedTitle?.string ?? title
        if let submenu {
            return UIMenu(title: text, image: image, children: submenu.elements)
        }
        let action = UIAction(title: text, subtitle: subtitle, image: image) { [self] _ in perform() }
        action.state = switch state {
        case .on: .on
        case .mixed: .mixed
        case .off: .off
        }
        if !isEnabled || (self.action == nil) {
            action.attributes.insert(.disabled)
        }
        return action
    }
}

public final class NSMenu: NSObject {
    public static let didBeginTrackingNotification = Notification.Name("NSMenuDidBeginTrackingNotification")
    public static let didEndTrackingNotification = Notification.Name("NSMenuDidEndTrackingNotification")

    public var title: String
    public private(set) var items: [NSMenuItem] = []
    public var autoenablesItems = true
    public weak var delegate: NSMenuDelegate?
    public var minimumWidth: CGFloat = 0
    public var font: UIFont?
    public var showsStateColumn = true
    public var numberOfItems: Int { items.count }

    public init(title: String = "") {
        self.title = title
    }

    public func addItem(_ item: NSMenuItem) {
        item.menu = self
        items.append(item)
    }

    @discardableResult
    public func addItem(withTitle title: String, action: Selector?, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        addItem(item)
        return item
    }

    public func insertItem(_ item: NSMenuItem, at index: Int) {
        item.menu = self
        items.insert(item, at: index)
    }
    public func removeItem(_ item: NSMenuItem) { items.removeAll { $0 === item } }
    public func removeItem(at index: Int) { items.remove(at: index) }
    public func removeAllItems() { items.removeAll() }
    public func item(at index: Int) -> NSMenuItem? { items.indices.contains(index) ? items[index] : nil }
    public func item(withTitle title: String) -> NSMenuItem? { items.first { $0.title == title } }
    public func item(withTag tag: Int) -> NSMenuItem? { items.first { $0.tag == tag } }
    public func index(of item: NSMenuItem) -> Int { items.firstIndex { $0 === item } ?? -1 }
    public func cancelTracking() {}

    /// Separator items start a new inline group, as UIKit menus express them.
    var elements: [UIMenuElement] {
        delegate?.menuNeedsUpdate?(self)
        var groups: [[UIMenuElement]] = [[]]
        for item in items {
            if item.isSeparatorItem {
                groups.append([])
            } else if let element = item.element {
                groups[groups.count - 1].append(element)
            }
        }
        let filled = groups.filter { !$0.isEmpty }
        return filled.count == 1 ? filled[0] : filled.map { UIMenu(options: .displayInline, children: $0) }
    }

    public func popUp(at location: CGPoint, in view: UIView) {
        MenuPresenter.present(self, at: location, in: view)
    }

    @discardableResult
    public func popUp(positioning _: NSMenuItem?, at location: CGPoint, in view: UIView?) -> Bool {
        guard let view = view ?? NSApp.keyWindow else { return false }
        popUp(at: location, in: view)
        return true
    }

    public static func popUpContextMenu(_ menu: NSMenu, with event: NSEvent, for view: UIView) {
        menu.popUp(at: view.convert(event.locationInWindow, from: nil), in: view)
    }
}

/// Shows a menu at an arbitrary point through a transient context-menu interaction.
@MainActor
private final class MenuPresenter: NSObject, UIContextMenuInteractionDelegate {
    private static var active: MenuPresenter?
    private let menu: NSMenu
    private weak var view: UIView?
    private var interaction: UIContextMenuInteraction?

    private init(menu: NSMenu, view: UIView) {
        self.menu = menu
        self.view = view
    }

    static func present(_ menu: NSMenu, at location: CGPoint, in view: UIView) {
        let presenter = MenuPresenter(menu: menu, view: view)
        active = presenter
        menu.delegate?.menuWillOpen?(menu)
        NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: menu)
        let interaction = UIContextMenuInteraction(delegate: presenter)
        presenter.interaction = interaction
        view.addInteraction(interaction)
        let selector = NSSelectorFromString("_presentMenuAtLocation:")
        guard let method = class_getInstanceMethod(UIContextMenuInteraction.self, selector) else {
            presenter.presentAsSheet(at: location)
            return
        }
        typealias Present = @convention(c) (AnyObject, Selector, CGPoint) -> Void
        unsafeBitCast(method_getImplementation(method), to: Present.self)(interaction, selector, location)
    }

    /// Fallback if the private point-anchored presentation ever disappears.
    private func presentAsSheet(at location: CGPoint) {
        guard let view, let presenter = view.window?.ak_topViewController else { return }
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for item in menu.items where !item.isSeparatorItem && !item.isHidden && item.isEnabled {
            sheet.addAction(UIAlertAction(title: item.attributedTitle?.string ?? item.title, style: .default) { _ in item.perform() })
        }
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(origin: location, size: .zero)
        presenter.present(sheet, animated: true)
    }

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        configurationForMenuAtLocation _: CGPoint
    ) -> UIContextMenuConfiguration? {
        let elements = menu.elements
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: elements)
        }
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor _: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        let finish = { [self] in
            view?.removeInteraction(interaction)
            menu.delegate?.menuDidClose?(menu)
            NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: menu)
            if Self.active === self { Self.active = nil }
        }
        if let animator { animator.addCompletion(finish) } else { finish() }
    }
}
