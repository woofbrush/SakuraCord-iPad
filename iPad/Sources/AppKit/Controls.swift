import AVKit
import ObjectiveC

public extension UIControl {
    enum ControlSize: Sendable { case regular, small, mini, large, extraLarge }
}

public nonisolated enum NSBezelStyle: Sendable { case glass, `default`, automatic, push, flexiblePush, regularSquare, inline, recessed, texturedRounded, circular, helpButton, accessoryBarAction, accessoryBar, roundRect, badge, shadowlessSquare, smallSquare, rounded }
public nonisolated enum NSButtonType: Sendable { case momentaryLight, momentaryChange, toggle, `switch`, radio, momentaryPushIn, pushOnPushOff, onOff, accelerator, multiLevelAccelerator }
public nonisolated enum NSCellImagePosition: Sendable { case noImage, imageOnly, imageLeft, imageRight, imageBelow, imageAbove, imageOverlaps, imageLeading, imageTrailing }
public nonisolated enum NSImageScaling: Sendable { case scaleProportionallyDown, scaleAxesIndependently, scaleNone, scaleProportionallyUpOrDown }
public nonisolated enum NSImageAlignment: Sendable { case alignCenter, alignTop, alignTopLeft, alignTopRight, alignLeft, alignBottom, alignBottomLeft, alignBottomRight, alignRight }

/// A UIView rather than a UIButton: AppKit's `state` is the checked state, which
/// collides with UIControl's. The embedded button provides the standard rendering.
open class NSButton: UIView {
    public typealias StateValue = NSControlStateValue

    private let control = UIButton(type: .system)
    public weak var target: AnyObject?
    public var action: Selector?
    public var state: StateValue = .off
    public var bezelStyle: NSBezelStyle = .automatic
    public var isBordered = true
    public var imagePosition: NSCellImagePosition = .imageLeading
    public var imageScaling: NSImageScaling = .scaleProportionallyDown
    public var showsBorderOnlyWhileMouseInside = false
    public var controlSize: UIControl.ControlSize = .regular
    public var refusesFirstResponder = false
    public var focusRingType: NSFocusRingType = .none
    public var keyEquivalent = ""
    public var isTransparent = false {
        didSet { control.alpha = isTransparent ? 0.02 : 1 }
    }

    public var isEnabled: Bool {
        get { control.isEnabled }
        set { control.isEnabled = newValue }
    }

    private var buttonType: NSButtonType = .momentaryPushIn

    public var title: String {
        get { control.title(for: .normal) ?? "" }
        set { control.setTitle(newValue, for: .normal) }
    }

    public var attributedTitle: NSAttributedString {
        get { control.attributedTitle(for: .normal) ?? NSAttributedString() }
        set { control.setAttributedTitle(newValue, for: .normal) }
    }

    public var image: UIImage? {
        get { control.image(for: .normal) }
        set { control.setImage(newValue, for: .normal) }
    }

    public var font: UIFont? {
        get { control.titleLabel?.font }
        set { control.titleLabel?.font = newValue }
    }

    public var contentTintColor: UIColor? {
        get { control.tintColor }
        set { control.tintColor = newValue }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        control.frame = bounds
        control.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        control.tintColor = .label
        control.addTarget(self, action: #selector(ak_activate), for: .primaryActionTriggered)
        addSubview(control)
    }

    public required init?(coder: NSCoder) { super.init(coder: coder) }

    override open var intrinsicContentSize: CGSize { control.intrinsicContentSize }

    public convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
    }

    public convenience init(checkboxWithTitle title: String, target: AnyObject?, action: Selector?) {
        self.init(title: title, target: target, action: action)
        buttonType = .switch
    }

    public convenience init(image: UIImage, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.image = image
        self.target = target
        self.action = action
    }

    public func setButtonType(_ type: NSButtonType) { buttonType = type }

    public enum BorderShape: Sendable { case automatic, capsule, roundedRectangle, circle }

    public var bezelColor: UIColor? {
        didSet { control.backgroundColor = bezelColor }
    }

    public var borderShape: BorderShape = .automatic {
        didSet { setNeedsLayout() }
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        if borderShape == .capsule || borderShape == .circle {
            control.layer.cornerRadius = bounds.height / 2
            control.layer.cornerCurve = .continuous
        }
    }

    @discardableResult
    public func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        guard let action else { return false }
        return UIApplication.shared.sendAction(action, to: target, from: self, for: nil)
    }
    public func performClick(_: Any?) { ak_activate() }

    @objc private func ak_activate() {
        if buttonType == .switch || buttonType == .toggle || buttonType == .pushOnPushOff || buttonType == .onOff {
            state = state == .on ? .off : .on
        }
        guard let action else { return }
        UIApplication.shared.sendAction(action, to: target, from: self, for: nil)
    }
}

open class NSImageView: UIImageView {
    public var imageScaling: NSImageScaling = .scaleProportionallyDown {
        didSet {
            contentMode = imageScaling == .scaleAxesIndependently ? .scaleToFill : .scaleAspectFit
        }
    }

    public var imageAlignment: NSImageAlignment = .alignCenter
    public var animates = false
    public var isEditable = false
    public var contentTintColor: UIColor? {
        get { tintColor }
        set { tintColor = newValue }
    }

    public convenience init() { self.init(frame: .zero) }

    public convenience init(image: UIImage) {
        self.init(frame: .zero)
        self.image = image
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .scaleAspectFit
        tintColor = .label
    }

    public required init?(coder: NSCoder) { super.init(coder: coder) }
}

open class NSVisualEffectView: UIView {
    public enum Material: Sendable { case titlebar, selection, menu, popover, sidebar, headerView, sheet, windowBackground, hudWindow, fullScreenUI, toolTip, contentBackground, underWindowBackground, underPageBackground }
    public enum BlendingMode: Sendable { case behindWindow, withinWindow }
    public enum State: Sendable { case followsWindowActiveState, active, inactive }

    private let effect = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    public var material: Material = .sidebar
    public var blendingMode: BlendingMode = .behindWindow
    public var state: State = .followsWindowActiveState
    public var isEmphasized = false
    public var maskImage: UIImage?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        effect.frame = bounds
        effect.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(effect, at: 0)
    }

    public required init?(coder: NSCoder) { super.init(coder: coder) }
}

/// Liquid Glass host; content is placed inside the effect, as NSGlassEffectView does.
open class NSGlassEffectView: UIView {
    public enum Style: Sendable { case regular, clear }

    private let effect = UIVisualEffectView(effect: UIGlassEffect())
    public var style: Style = .regular
    public var effectIsInteractive = false

    public var contentView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            guard let contentView else { return }
            contentView.frame = effect.contentView.bounds
            contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            effect.contentView.addSubview(contentView)
        }
    }

    public var cornerRadius: CGFloat = 0 {
        didSet {
            effect.layer.cornerRadius = cornerRadius
            effect.layer.cornerCurve = .continuous
            effect.clipsToBounds = cornerRadius > 0
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        effect.frame = bounds
        effect.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(effect, at: 0)
    }

    public required init?(coder: NSCoder) { super.init(coder: coder) }
}

open class NSProgressIndicator: UIActivityIndicatorView {
    public enum Style: Sendable { case bar, spinning }
    public var isIndeterminate = true
    public var isDisplayedWhenStopped = false
    public var controlSize: UIControl.ControlSize = .regular
    public var nsStyle: Style = .spinning
    public func startAnimation(_: Any?) { startAnimating() }
    public func stopAnimation(_: Any?) { stopAnimating() }
}

// MARK: Alerts

public final class NSAlert: NSObject {
    public enum Style: Sendable { case warning, informational, critical }

    public var messageText = ""
    public var informativeText = ""
    public var alertStyle: Style = .warning
    public var icon: UIImage?
    public var accessoryView: UIView?
    public var showsSuppressionButton = false
    public private(set) var buttons: [NSButton] = []
    public lazy var suppressionButton: NSButton? = NSButton(checkboxWithTitle: "Do not show this again", target: nil, action: nil)
    public var window: UIWindow? { NSApp.keyWindow }

    @discardableResult
    public func addButton(withTitle title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        buttons.append(button)
        return button
    }

    public convenience init(error: any Error) {
        self.init()
        messageText = error.localizedDescription
    }

    public func beginSheetModal(for window: UIWindow, completionHandler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        let controller = UIAlertController(title: messageText, message: informativeText, preferredStyle: .alert)
        if buttons.isEmpty { addButton(withTitle: "OK") }
        for (index, button) in buttons.enumerated() {
            let isDestructive = button.hasDestructiveAction || (alertStyle == .critical && index == 0)
            let style: UIAlertAction.Style = isDestructive ? .destructive : (button.title == "Cancel" ? .cancel : .default)
            controller.addAction(UIAlertAction(title: button.title, style: style) { _ in
                completionHandler?(NSApplication.ModalResponse(rawValue: 1000 + index))
            })
        }
        (window.ak_topViewController ?? window.rootViewController)?.present(controller, animated: true)
    }

    public func beginSheetModal(for window: UIWindow) async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            beginSheetModal(for: window) { continuation.resume(returning: $0) }
        }
    }

    /// Spins the run loop until answered, matching runModal's synchronous contract.
    public func runModal() -> NSApplication.ModalResponse {
        guard let window = NSApp.keyWindow else { return .cancel }
        var response: NSApplication.ModalResponse?
        beginSheetModal(for: window) { response = $0 }
        while response == nil { RunLoop.current.run(mode: .default, before: .now + 0.05) }
        return response ?? .cancel
    }
}

public extension NSButton {
    var hasDestructiveAction: Bool {
        get { objc_getAssociatedObject(self, &NSButtonKeys.destructive) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &NSButtonKeys.destructive, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private enum NSButtonKeys {
    nonisolated(unsafe) static var destructive: UInt8 = 0
}

public extension UIWindow {
    var sheetParent: UIWindow? { nil }

    var ak_topViewController: UIViewController? {
        var controller = rootViewController
        while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}

// MARK: Popovers

public nonisolated enum NSRectEdge: Sendable {
    case minX, minY, maxX, maxY
}

public extension CGRectEdge {
    var nsEdge: NSRectEdge { .minX }
}

@objc public protocol NSPopoverDelegate: NSObjectProtocol {
    @objc optional func popoverWillShow(_ notification: Notification)
    @objc optional func popoverDidShow(_ notification: Notification)
    @objc optional func popoverWillClose(_ notification: Notification)
    @objc optional func popoverDidClose(_ notification: Notification)
    @objc optional func popoverShouldClose(_ popover: NSPopover) -> Bool
}

/// Glass surface for a popover. Touches on its chrome pass through, so a popover
/// whose content ignores input (a hover card) never blocks the view beneath it.
private final class PopoverContainerView: UIView {
    let effect = UIVisualEffectView(effect: UIGlassEffect())

    override init(frame: CGRect) {
        super.init(frame: frame)
        effect.frame = bounds
        effect.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        effect.layer.cornerRadius = 18
        effect.layer.cornerCurve = .continuous
        effect.clipsToBounds = true
        addSubview(effect)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self || hit === effect || hit === effect.contentView ? nil : hit
    }
}

/// AppKit popovers are separate non-modal windows: hover cards do not take input,
/// several can be open, and showing one again only moves it. UIKit's modal popover
/// presentation allows none of that, so this is an overlay anchored to its view.
public final class NSPopover: NSObject {
    public enum Behavior: Sendable { case applicationDefined, transient, semitransient }

    public static let willShowNotification = Notification.Name("NSPopoverWillShowNotification")
    public static let didShowNotification = Notification.Name("NSPopoverDidShowNotification")
    public static let willCloseNotification = Notification.Name("NSPopoverWillCloseNotification")
    public static let didCloseNotification = Notification.Name("NSPopoverDidCloseNotification")

    private static var open: [NSPopover] = []

    public var contentViewController: UIViewController?
    public var behavior: Behavior = .applicationDefined
    public var animates = true
    public var hasFullSizeContent = false
    public weak var delegate: NSPopoverDelegate?
    public var appearance: NSAppearance?
    public private(set) var isShown = false

    public var positioningRect: CGRect = .zero {
        didSet { if isShown, oldValue != positioningRect { reposition() } }
    }

    public var contentSize: CGSize {
        get { contentViewController?.preferredContentSize ?? .zero }
        set {
            contentViewController?.preferredContentSize = newValue
            if isShown { reposition() }
        }
    }

    private var container: PopoverContainerView?
    private var closingContainer: PopoverContainerView?
    private weak var hostController: UIViewController?
    private weak var anchorView: UIView?
    private var edge: NSRectEdge = .maxY
    private var sizeObservation: NSKeyValueObservation?
    private var outsideClickMonitor: Any?

    private func notify(_ name: Notification.Name, _ call: (Notification) -> Void) {
        let note = Notification(name: name, object: self)
        call(note)
        NotificationCenter.default.post(note)
    }

    public func show(relativeTo rect: CGRect, of view: UIView, preferredEdge: NSRectEdge) {
        guard let controller = contentViewController, let window = view.window else { return }
        anchorView = view
        edge = preferredEdge
        positioningRect = rect
        if isShown {
            reposition()
            return
        }
        finishClosing()
        guard let host = window.ak_topViewController else { return }
        isShown = true
        hostController = host
        notify(Self.willShowNotification) { delegate?.popoverWillShow?($0) }

        let container = PopoverContainerView()
        host.addChild(controller)
        controller.view.backgroundColor = .clear
        controller.view.translatesAutoresizingMaskIntoConstraints = true
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.effect.contentView.addSubview(controller.view)
        host.view.addSubview(container)
        controller.didMove(toParent: host)
        self.container = container
        Self.open.append(self)
        reposition()
        controller.view.frame = container.bounds

        sizeObservation = controller.observe(\.preferredContentSize, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        if behavior != .applicationDefined {
            outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.handleClick(event)
                return event
            }
        }

        guard animates else {
            notify(Self.didShowNotification) { delegate?.popoverDidShow?($0) }
            return
        }
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            container.alpha = 1
            container.transform = .identity
        } completion: { [self] _ in
            notify(Self.didShowNotification) { delegate?.popoverDidShow?($0) }
        }
    }

    private var resolvedSize: CGSize {
        guard let controller = contentViewController else { return .zero }
        let preferred = controller.preferredContentSize
        if preferred.width >= 2, preferred.height >= 2 { return preferred }
        return controller.view.sizeThatFits(CGSize(width: 480, height: 640))
    }

    private func reposition() {
        guard let container, let hostView = hostController?.view, let anchorView, anchorView.window != nil else { return }
        let area = hostView.bounds.inset(by: hostView.safeAreaInsets).insetBy(dx: 8, dy: 8)
        let size = CGSize(width: min(resolvedSize.width, area.width), height: min(resolvedSize.height, area.height))
        let anchor = anchorView.convert(positioningRect, to: hostView)
        let gap: CGFloat = 6

        func origin(_ edge: NSRectEdge) -> CGPoint {
            switch edge {
            case .minY: CGPoint(x: anchor.midX - size.width / 2, y: anchor.minY - gap - size.height)
            case .maxY: CGPoint(x: anchor.midX - size.width / 2, y: anchor.maxY + gap)
            case .minX: CGPoint(x: anchor.minX - gap - size.width, y: anchor.midY - size.height / 2)
            case .maxX: CGPoint(x: anchor.maxX + gap, y: anchor.midY - size.height / 2)
            }
        }

        func fits(_ edge: NSRectEdge) -> Bool {
            switch edge {
            case .minY: anchor.minY - gap - size.height >= area.minY
            case .maxY: anchor.maxY + gap + size.height <= area.maxY
            case .minX: anchor.minX - gap - size.width >= area.minX
            case .maxX: anchor.maxX + gap + size.width <= area.maxX
            }
        }

        let opposite: NSRectEdge = switch edge {
        case .minY: .maxY
        case .maxY: .minY
        case .minX: .maxX
        case .maxX: .minX
        }
        var point = origin(fits(edge) || !fits(opposite) ? edge : opposite)
        point.x = min(max(point.x, area.minX), max(area.minX, area.maxX - size.width))
        point.y = min(max(point.y, area.minY), max(area.minY, area.maxY - size.height))

        let transform = container.transform
        container.transform = .identity
        container.frame = CGRect(origin: point, size: size)
        container.transform = transform
    }

    private func handleClick(_ event: NSEvent) {
        guard isShown else { return }
        // A popover opened from this one is its child: clicking it is not "outside".
        let index = Self.open.firstIndex { $0 === self } ?? 0
        for popover in Self.open[index...] {
            guard let surface = popover.container else { continue }
            if surface.bounds.contains(surface.convert(event.locationInWindow, from: nil)) { return }
        }
        DispatchQueue.main.async { [weak self] in self?.performClose(nil) }
    }

    public func close() {
        guard isShown else { return }
        notify(Self.willCloseNotification) { delegate?.popoverWillClose?($0) }
        isShown = false
        sizeObservation = nil
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
        Self.open.removeAll { $0 === self }
        closingContainer = container
        container = nil
        guard animates, let closing = closingContainer else { return finishClosing() }
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseIn, .allowUserInteraction]) {
            closing.alpha = 0
        } completion: { [weak self] _ in
            self?.finishClosing()
        }
    }

    public func performClose(_: Any?) {
        guard delegate?.popoverShouldClose?(self) != false else { return }
        close()
    }

    private func finishClosing() {
        guard let closing = closingContainer else { return }
        closingContainer = nil
        contentViewController?.willMove(toParent: nil)
        contentViewController?.view.removeFromSuperview()
        contentViewController?.removeFromParent()
        closing.removeFromSuperview()
        notify(Self.didCloseNotification) { delegate?.popoverDidClose?($0) }
    }
}

// MARK: File panels

open class NSSavePanel: NSObject, UIDocumentPickerDelegate {
    public var url: URL?
    public var allowedContentTypes: [UTType] = []
    public var nameFieldStringValue = ""
    public var canCreateDirectories = true
    public var message: String?
    public var prompt: String?
    public var title: String?
    public var directoryURL: URL?
    public var isExtensionHidden = false
    public var showsTagField = false
    fileprivate var completion: ((NSApplication.ModalResponse) -> Void)?
    fileprivate var retained: NSSavePanel?

    override public init() {}

    /// iPadOS can only hand back an existing location, so saving picks a folder.
    fileprivate func makePicker() -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    }

    fileprivate func accept(_ urls: [URL]) {
        url = urls.first?.appendingPathComponent(nameFieldStringValue)
        _ = urls.first?.startAccessingSecurityScopedResource()
    }

    public func begin(completionHandler: @escaping (NSApplication.ModalResponse) -> Void) {
        guard let window = NSApp.keyWindow else { return completionHandler(.cancel) }
        beginSheetModal(for: window, completionHandler: completionHandler)
    }

    public func beginSheetModal(for window: UIWindow, completionHandler: @escaping (NSApplication.ModalResponse) -> Void) {
        completion = completionHandler
        retained = self
        let picker = makePicker()
        picker.delegate = self
        window.ak_topViewController?.present(picker, animated: true)
    }

    public func cancel(_: Any?) {}

    public func runModal() -> NSApplication.ModalResponse {
        var response: NSApplication.ModalResponse?
        begin { response = $0 }
        while response == nil { RunLoop.current.run(mode: .default, before: .now + 0.05) }
        return response ?? .cancel
    }

    public func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        accept(urls)
        completion?(.OK)
        retained = nil
    }

    public func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
        completion?(.cancel)
        retained = nil
    }
}

public final class NSOpenPanel: NSSavePanel {
    public var canChooseFiles = true
    public var canChooseDirectories = false
    public var allowsMultipleSelection = false
    public var resolvesAliases = true
    public private(set) var urls: [URL] = []

    override fileprivate func makePicker() -> UIDocumentPickerViewController {
        let types = canChooseDirectories ? [UTType.folder] : (allowedContentTypes.isEmpty ? [UTType.item] : allowedContentTypes)
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: !canChooseDirectories)
        picker.allowsMultipleSelection = allowsMultipleSelection
        return picker
    }

    override fileprivate func accept(_ urls: [URL]) {
        self.urls = urls
        url = urls.first
        if canChooseDirectories { _ = urls.first?.startAccessingSecurityScopedResource() }
    }
}

// MARK: Drag and drop types (drops arrive through UIKit interactions on iPadOS)

public nonisolated struct NSDragOperation: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let copy = Self(rawValue: 1)
    public static let link = Self(rawValue: 2)
    public static let generic = Self(rawValue: 4)
    public static let move = Self(rawValue: 16)
    public static let every = Self(rawValue: .max)
}

@objc public protocol NSDraggingInfo: NSObjectProtocol {
    var draggingLocation: CGPoint { get }
    var draggingPasteboard: NSPasteboard { get }
}

public final class NSFilePromiseReceiver: NSObject {
    public static var readableDraggedTypes: [String] { [] }
    public var fileTypes: [String] { [] }
    public func receivePromisedFiles(
        atDestination _: URL,
        options _: [AnyHashable: Any] = [:],
        operationQueue _: OperationQueue,
        reader _: @escaping (URL, (any Error)?) -> Void
    ) {}
}

// MARK: Accessibility

public nonisolated enum NSAccessibility {
    public nonisolated struct Role: Hashable, Sendable, RawRepresentable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let button = Role(rawValue: "button")
        public static let group = Role(rawValue: "group")
        public static let staticText = Role(rawValue: "text")
        public static let image = Role(rawValue: "image")
        public static let link = Role(rawValue: "link")
        public static let list = Role(rawValue: "list")
        public static let row = Role(rawValue: "row")
        public static let cell = Role(rawValue: "cell")
        public static let textArea = Role(rawValue: "textArea")
        public static let textField = Role(rawValue: "textField")
        public static let unknown = Role(rawValue: "unknown")
        public static let scrollArea = Role(rawValue: "scrollArea")
        public static let menuButton = Role(rawValue: "menuButton")
        public static let popUpButton = Role(rawValue: "popUpButton")
        public static let progressIndicator = Role(rawValue: "progressIndicator")
        public static let checkBox = Role(rawValue: "checkBox")
        public static let radioButton = Role(rawValue: "radioButton")
        public static let heading = Role(rawValue: "heading")
        public static let table = Role(rawValue: "table")
        public static let layoutArea = Role(rawValue: "layoutArea")
        public static let toolbar = Role(rawValue: "toolbar")
        public static let slider = Role(rawValue: "slider")
    }

    public nonisolated struct Action: Hashable, Sendable, RawRepresentable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let press = Action(rawValue: "press")
        public static let showMenu = Action(rawValue: "showMenu")
    }

    public nonisolated struct Notification: Hashable, Sendable, RawRepresentable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let layoutChanged = Self(rawValue: "layoutChanged")
        public static let valueChanged = Self(rawValue: "valueChanged")
        public static let selectedChildrenChanged = Self(rawValue: "selectedChildrenChanged")
        public static let focusedUIElementChanged = Self(rawValue: "focusedUIElementChanged")
        public static let announcementRequested = Self(rawValue: "announcementRequested")
    }

    public nonisolated struct NotificationUserInfoKey: Hashable, Sendable, RawRepresentable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let announcement = Self(rawValue: "announcement")
        public static let priority = Self(rawValue: "priority")
    }

    public static func unignoredAncestor(of element: Any) -> Any? { element }

    public static func post(element _: Any, notification: Notification, userInfo: [NotificationUserInfoKey: Any]? = nil) {
        if notification == .announcementRequested, let text = userInfo?[.announcement] as? String {
            UIAccessibility.post(notification: .announcement, argument: text)
        } else if notification == .layoutChanged {
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }
}

public nonisolated enum NSAccessibilityPriorityLevel: Int, Sendable { case low = 10, medium = 50, high = 90 }

public typealias NSAccessibilityCustomAction = UIAccessibilityCustomAction

public extension NSObject {
    func setAccessibilityLabel(_ label: String?) { accessibilityLabel = label }
    func setAccessibilityValue(_ value: Any?) { accessibilityValue = value.map { "\($0)" } }
    func setAccessibilityHelp(_ help: String?) { accessibilityHint = help }
    func setAccessibilityElement(_ isElement: Bool) { isAccessibilityElement = isElement }
    func setAccessibilityHidden(_ hidden: Bool) { accessibilityElementsHidden = hidden }
    func setAccessibilityEnabled(_: Bool) {}
    func setAccessibilityRole(_: NSAccessibility.Role?) {}
    func setAccessibilityRoleDescription(_: String?) {}
    func setAccessibilityIdentifier(_: String?) {}
    func setAccessibilityChildren(_ children: [Any]?) { accessibilityElements = children }
    func setAccessibilityCustomActions(_ actions: [UIAccessibilityCustomAction]?) { accessibilityCustomActions = actions }
    func setAccessibilityParent(_: Any?) {}
    func setAccessibilitySubrole(_: NSAccessibility.Role?) {}
    func setAccessibilityModal(_ isModal: Bool) { accessibilityViewIsModal = isModal }
    func setAccessibilityWindow(_: Any?) {}
    func setAccessibilityTopLevelUIElement(_: Any?) {}
    func setAccessibilityFrame(_: CGRect) {}
    func setAccessibilityFrameInParentSpace(_: CGRect) {}
    func setAccessibilityFocused(_: Bool) {}
    func setAccessibilitySelected(_: Bool) {}
    func setAccessibilityTitle(_ title: String?) { accessibilityLabel = title }
}

public extension UIAccessibilityCustomAction {
    convenience init(name: String, handler: @escaping () -> Bool) {
        self.init(name: name) { _ in handler() }
    }
}

open class NSAccessibilityElement: NSObject {
    public override nonisolated init() {}
    public func nsa_accessibilityChildren() -> [Any]? { accessibilityElements }
    public func nsa_accessibilityFrame() -> CGRect { accessibilityFrame }
    public func nsa_accessibilityRole() -> NSAccessibility.Role? { nil }
    public func accessibilitySubrole() -> NSAccessibility.Role? { nil }
    public func nsa_accessibilityLabel() -> String? { accessibilityLabel }
    public func nsa_accessibilityValue() -> Any? { accessibilityValue }
    public func nsa_accessibilityHelp() -> String? { accessibilityHint }
    public func nsa_accessibilityIdentifier() -> String? { nil }
    public func isAccessibilityEnabled() -> Bool { true }
    public func nsa_accessibilityCustomActions() -> [UIAccessibilityCustomAction]? { accessibilityCustomActions }
}

public extension UIAccessibilityCustomAction {
    var handler: (() -> Bool)? {
        get { actionHandler.map { action in { action(self) } } }
        set { actionHandler = newValue.map { handler in { _ in handler() } } }
    }
}

/// macOS's text-only link button.
public struct NSLinkButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.accentColor)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// macOS's checkbox, which SwiftUI does not offer on iPadOS.
public struct NSCheckboxToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? Color.accentColor : Color.secondary)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: AVPlayerView

open class AVPlayerView: UIView {
    public enum ControlsStyle: Sendable { case none, inline, floating, minimal, `default` }

    private let controller = AVPlayerViewController()
    public var controlsStyle: ControlsStyle = .inline {
        didSet { controller.showsPlaybackControls = controlsStyle != .none }
    }

    public var player: AVPlayer? {
        get { controller.player }
        set { controller.player = newValue }
    }

    public var videoGravity: AVLayerVideoGravity {
        get { controller.videoGravity }
        set { controller.videoGravity = newValue }
    }

    public var showsFullScreenToggleButton = false
    public var allowsPictureInPicturePlayback: Bool {
        get { controller.allowsPictureInPicturePlayback }
        set { controller.allowsPictureInPicturePlayback = newValue }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        controller.view.frame = bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(controller.view)
    }

    public required init?(coder: NSCoder) { super.init(coder: coder) }
}

// Types the app probes for inside SwiftUI lists; UIKit never produces them.
public extension NSRange {
    var integerRange: Range<Int> { location ..< location + length }
}

open class NSTableRowView: UIView {}

open class NSTableView: UIView {
    public enum SelectionHighlightStyle: Sendable { case none, regular, sourceList }
    public var selectionHighlightStyle: SelectionHighlightStyle = .regular
    public func rows(in _: CGRect) -> NSRange { NSRange(location: 0, length: 0) }
    public func rowView(atRow _: Int, makeIfNecessary _: Bool) -> NSTableRowView? { nil }
}

open class NSOutlineView: NSTableView {}
