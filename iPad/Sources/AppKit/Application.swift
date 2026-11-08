import UserNotifications

public final class NSApplication: NSObject {
    public static let shared: NSApplication = {
        ViewBridge.install()
        let application = NSApplication()
        application.observeSceneVisibility()
        return application
    }()

    /// AppKit reports window occlusion changes; on iPadOS the scene lifecycle is the equivalent.
    private func observeSceneVisibility() {
        let names = [
            UIScene.didActivateNotification, UIScene.willDeactivateNotification,
            UIScene.didEnterBackgroundNotification, UIScene.willEnterForegroundNotification
        ]
        for name in names {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
                nonisolated(unsafe) let object = note.object
                MainActor.assumeIsolated {
                    guard let scene = object as? UIWindowScene else { return }
                    for window in scene.windows {
                        NotificationCenter.default.post(name: UIWindow.didChangeOcclusionStateNotification, object: window)
                    }
                }
            }
        }
    }

    public enum ActivationPolicy: Sendable { case regular, accessory, prohibited }
    public enum TerminateReply: Sendable { case terminateNow, terminateCancel, terminateLater }

    public nonisolated struct ModalResponse: Hashable, Sendable, RawRepresentable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let OK = Self(rawValue: 1)
        public static let cancel = Self(rawValue: 0)
        public static let alertFirstButtonReturn = Self(rawValue: 1000)
        public static let alertSecondButtonReturn = Self(rawValue: 1001)
        public static let alertThirdButtonReturn = Self(rawValue: 1002)
    }

    public static let didBecomeActiveNotification = UIApplication.didBecomeActiveNotification
    public static let didResignActiveNotification = UIApplication.willResignActiveNotification
    public static let willTerminateNotification = UIApplication.willTerminateNotification

    public var delegate: AnyObject?

    /// Lets app-level key equivalents win over UIKit's text-editing shortcuts,
    /// which on iPadOS otherwise take priority for chords like Option-Up Arrow.
    public var textKeyEquivalentHandler: ((NSEvent) -> Bool)?
    public var mainMenu: NSMenu?
    public let dockTile = NSDockTile()

    public var appearance: NSAppearance? {
        didSet {
            for window in windows { window.overrideUserInterfaceStyle = appearance?.style ?? .unspecified }
        }
    }

    public var effectiveAppearance: NSAppearance {
        NSAppearance(style: keyWindow?.traitCollection.userInterfaceStyle ?? .light)
    }

    public var windows: [UIWindow] {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
    }

    public var keyWindow: UIWindow? { windows.first(where: \.isKeyWindow) ?? windows.first }
    public var mainWindow: UIWindow? { keyWindow }
    public var isActive: Bool { UIApplication.shared.applicationState == .active }
    public var currentEvent: NSEvent? { NSEvent.current }
    public var modalWindow: UIWindow? { nil }

    public func activate(ignoringOtherApps _: Bool = false) {}
    public func hide(_: Any?) {}
    public func terminate(_: Any?) {}
    public func requestUserAttention(_: Int) -> Int { 0 }
    public func orderFrontStandardAboutPanel(_: Any? = nil) {}
    public func orderFrontStandardAboutPanel(options _: [AboutPanelOptionKey: Any]) {}

    public enum AboutPanelOptionKey: Hashable, Sendable {
        case applicationName, applicationVersion, version, credits, applicationIcon
    }
    @discardableResult public func setActivationPolicy(_: ActivationPolicy) -> Bool { true }

    @discardableResult
    public func sendAction(_ action: Selector, to target: Any?, from sender: Any?) -> Bool {
        UIApplication.shared.sendAction(action, to: target, from: sender, for: nil)
    }
}

@MainActor public var NSApp: NSApplication { .shared }

public extension UIWindow {
    /// The hosted content, equivalent to an NSWindow's content view.
    var contentView: UIView? { rootViewController?.view }
    var contentViewController: UIViewController? { rootViewController }
    var currentEvent: NSEvent? { NSEvent.current }
    var mouseLocationOutsideOfEventStream: CGPoint { NSEvent.lastLocation }
    var attachedSheet: UIWindow? { nil }
    var sheets: [UIWindow] { [] }
    var childWindows: [UIWindow]? { [] }
    var parent: UIWindow? { nil }
    var isVisible: Bool { !isHidden }
    var canBecomeMain: Bool { true }
    var isMiniaturized: Bool { false }
    var windowNumber: Int { hash }
    var contentLayoutRect: CGRect { bounds.inset(by: safeAreaInsets) }
    /// Visible means on screen, whether or not the scene has keyboard focus, as on macOS.
    var occlusionState: NSWindow.OcclusionState {
        guard let state = windowScene?.activationState else { return [] }
        return state == .foregroundActive || state == .foregroundInactive ? .visible : []
    }
    var styleMask: NSWindow.StyleMask { [] }

    var firstResponder: UIResponder? {
        func find(_ view: UIView) -> UIResponder? {
            if view.isFirstResponder { return view }
            for subview in view.subviews {
                if let found = find(subview) { return found }
            }
            return nil
        }
        return find(self)
    }

    @discardableResult
    func makeFirstResponder(_ responder: UIResponder?) -> Bool {
        if let responder { return responder.becomeFirstResponder() }
        firstResponder?.resignFirstResponder()
        return true
    }

    func makeKeyAndOrderFront(_: Any?) { makeKeyAndVisible() }
    func orderFront(_: Any?) {}
    func orderOut(_: Any?) {}
    func invalidateCursorRects(for _: UIView) {}
    func selectNextKeyView(_: Any?) {}
    func selectPreviousKeyView(_: Any?) {}
    func endSheet(_: UIWindow, returnCode _: NSApplication.ModalResponse = .cancel) {}

    var toolbar: AnyObject? { nil }
    /// macOS popovers have their own window; here that would be the entire app.
    var ignoresMouseEvents: Bool {
        get { false }
        set {}
    }

    static let didResizeNotification = Notification.Name("NSWindowDidResizeNotification")
    static let didEndLiveResizeNotification = Notification.Name("NSWindowDidEndLiveResizeNotification")
    static let didMiniaturizeNotification = Notification.Name("NSWindowDidMiniaturizeNotification")
    static let didDeminiaturizeNotification = Notification.Name("NSWindowDidDeminiaturizeNotification")
    static let didMoveNotification = Notification.Name("NSWindowDidMoveNotification")
    static let willCloseNotification = Notification.Name("NSWindowWillCloseNotification")
    static let didChangeOcclusionStateNotification = Notification.Name("NSWindowDidChangeOcclusionStateNotification")
    static let didChangeScreenNotification = Notification.Name("NSWindowDidChangeScreenNotification")
    static let didEnterFullScreenNotification = Notification.Name("NSWindowDidEnterFullScreenNotification")
    static let didExitFullScreenNotification = Notification.Name("NSWindowDidExitFullScreenNotification")
    static let willEnterFullScreenNotification = Notification.Name("NSWindowWillEnterFullScreenNotification")
    static let willExitFullScreenNotification = Notification.Name("NSWindowWillExitFullScreenNotification")

    enum OrderingMode: Sendable { case above, below, out }
    func convertPoint(fromScreen point: CGPoint) -> CGPoint { point }
    func convertPoint(toScreen point: CGPoint) -> CGPoint { point }
    func convertFromScreen(_ rect: CGRect) -> CGRect { rect }
    func convertToScreen(_ rect: CGRect) -> CGRect { rect }

    struct OcclusionState: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let visible = Self(rawValue: 2)
    }

    struct StyleMask: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let fullScreen = Self(rawValue: 1 << 14)
        public static let titled = Self(rawValue: 1)
    }
}

public extension UIWindow {
    struct DidChangeOcclusionStateMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIWindow
        public static var name: Notification.Name { UIWindow.didChangeOcclusionStateNotification }
        public static func makeMessage(_: Notification) -> Self? { Self() }
    }
}

public extension UIWindow {
    struct DidEnterFullScreenMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIWindow
        public static var name: Notification.Name { UIWindow.didEnterFullScreenNotification }
        public static func makeMessage(_: Notification) -> Self? { Self() }
    }

    struct DidExitFullScreenMessage: NotificationCenter.MainActorMessage {
        public typealias Subject = UIWindow
        public static var name: Notification.Name { UIWindow.didExitFullScreenNotification }
        public static func makeMessage(_: Notification) -> Self? { Self() }
    }
}

public extension UIResponder {
    @discardableResult
    func tryToPerform(_ action: Selector, with sender: Any?) -> Bool {
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: action) {
                current.perform(action, with: sender)
                return true
            }
            responder = current.next
        }
        return false
    }
}

public final class NSDockTile: NSObject {
    public var badgeLabel: String? {
        didSet { UNUserNotificationCenter.current().setBadgeCount(Int(badgeLabel ?? "") ?? 0) }
    }
}

public extension UIScreen {
    var visibleFrame: CGRect { bounds }
}

public extension Bundle {
    func image(forResource name: String) -> UIImage? {
        UIImage(named: name, in: self, compatibleWith: nil)?.withRenderingMode(.alwaysTemplate)
    }
    func path(forSoundResource name: String) -> String? { path(forResource: name, ofType: "mp3") }
}

public final class NSScreen: NSObject {
    private let screen: UIScreen

    private init(_ screen: UIScreen) { self.screen = screen }

    public static var main: NSScreen? { NSApp.keyWindow.map { NSScreen($0.screen) } }
    public static var screens: [NSScreen] { main.map { [$0] } ?? [] }
    public var frame: CGRect { screen.bounds }
    public var visibleFrame: CGRect { screen.bounds }
    public var backingScaleFactor: CGFloat { screen.scale }
    public var maximumFramesPerSecond: Int { screen.maximumFramesPerSecond }
}

public final class NSWorkspace: NSObject {
    public static let shared = NSWorkspace()
    public var notificationCenter: NotificationCenter { .default }
    public var accessibilityDisplayShouldReduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    public var accessibilityDisplayShouldReduceTransparency: Bool { UIAccessibility.isReduceTransparencyEnabled }
    public var isVoiceOverEnabled: Bool { UIAccessibility.isVoiceOverRunning }
    public var isSwitchControlEnabled: Bool { UIAccessibility.isSwitchControlRunning }
    public var accessibilityDisplayShouldIncreaseContrast: Bool { UIAccessibility.isDarkerSystemColorsEnabled }
    public static let accessibilityDisplayOptionsDidChangeNotification = UIAccessibility.reduceMotionStatusDidChangeNotification

    @discardableResult
    public func open(_ url: URL) -> Bool {
        UIApplication.shared.open(url)
        return true
    }

    public func activateFileViewerSelecting(_ urls: [URL]) {
        guard let url = urls.first else { return }
        UIApplication.shared.open(url)
    }

    public final class OpenConfiguration: NSObject {
        public var activates = true
        public var promptsUserIfNeeded = true
    }

    public func open(_ url: URL, configuration _: OpenConfiguration, completionHandler: ((AnyObject?, (any Error)?) -> Void)? = nil) {
        _ = open(url)
        completionHandler?(nil, nil)
    }

    public func urlForApplication(toOpen _: URL) -> URL? { nil }
    public func urlForApplication(withBundleIdentifier _: String) -> URL? { nil }

    public func open(
        _ urls: [URL],
        withApplicationAt _: URL,
        configuration _: OpenConfiguration,
        completionHandler: ((AnyObject?, (any Error)?) -> Void)? = nil
    ) {
        urls.first.map { _ = open($0) }
        completionHandler?(nil, nil)
    }

    public func icon(forFile _: String) -> UIImage { UIImage(systemName: "doc") ?? UIImage() }

    public func icon(for _: UTType) -> UIImage { UIImage(systemName: "doc") ?? UIImage() }
}

public enum NSSound {
    public static func beep() {}
}

public final class NSHapticFeedbackManager {
    public enum FeedbackPattern: Sendable { case generic, alignment, levelChange }
    public enum PerformanceTime: Sendable { case `default`, now, drawCompleted }

    public static var defaultPerformer: NSHapticFeedbackManager { NSHapticFeedbackManager() }

    public func perform(_: FeedbackPattern, performanceTime _: PerformanceTime) {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

public enum NSAnimationContext {
    public final class Context {
        public var duration: TimeInterval = 0.25
        public var timingFunction: CAMediaTimingFunction?
        public var allowsImplicitAnimation = false
    }

    private static var queued: [() -> Void]?

    /// Property changes made through `animator()` run together, once the group's duration is known.
    static func enqueue(_ change: @escaping () -> Void) {
        if queued == nil { change() } else { queued?.append(change) }
    }

    public static func runAnimationGroup(_ changes: (Context) -> Void, completionHandler: (@MainActor () -> Void)? = nil) {
        let context = Context()
        queued = []
        changes(context)
        let animations = queued ?? []
        queued = nil
        guard !animations.isEmpty else {
            completionHandler?()
            return
        }
        UIView.animate(
            withDuration: context.duration, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { animations.forEach { $0() } },
            completion: { _ in completionHandler?() }
        )
    }
}

@MainActor
public struct NSViewAnimator {
    let view: UIView

    public var alphaValue: CGFloat {
        get { view.alpha }
        nonmutating set { NSAnimationContext.enqueue { view.alpha = newValue } }
    }

    public var frame: CGRect {
        get { view.frame }
        nonmutating set { NSAnimationContext.enqueue { view.frame = newValue } }
    }
}

public extension UIView {
    func animator() -> NSViewAnimator { NSViewAnimator(view: self) }
}

// MARK: Pasteboard

public final class NSPasteboard: NSObject {
    public nonisolated struct PasteboardType: Hashable, Sendable, RawRepresentable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let string = Self(rawValue: UTType.utf8PlainText.identifier)
        public static let fileURL = Self(rawValue: UTType.fileURL.identifier)
        public static let URL = Self(rawValue: UTType.url.identifier)
        public static let png = Self(rawValue: UTType.png.identifier)
        public static let tiff = Self(rawValue: UTType.tiff.identifier)
        public static let html = Self(rawValue: UTType.html.identifier)
        public static let rtf = Self(rawValue: UTType.rtf.identifier)
        public static let rtfd = Self(rawValue: UTType.rtfd.identifier)
    }

    public static let general = NSPasteboard()
    private var board: UIPasteboard { .general }

    @discardableResult public func clearContents() -> Int {
        board.items = []
        return 0
    }

    @discardableResult public func setString(_ string: String, forType _: PasteboardType) -> Bool {
        board.string = string
        return true
    }

    public func string(forType _: PasteboardType) -> String? { board.string }
    public func data(forType type: PasteboardType) -> Data? { board.data(forPasteboardType: type.rawValue) }

    @discardableResult public func setData(_ data: Data?, forType type: PasteboardType) -> Bool {
        guard let data else { return false }
        board.setData(data, forPasteboardType: type.rawValue)
        return true
    }

    public func availableType(from types: [PasteboardType]) -> PasteboardType? {
        types.first { $0 == .string ? board.hasStrings : board.contains(pasteboardTypes: [$0.rawValue]) }
    }

    public var types: [PasteboardType]? { board.types.map(PasteboardType.init(rawValue:)) }

    @discardableResult public func writeObjects(_ objects: [NSObject]) -> Bool {
        for object in objects {
            if let url = object as? NSURL as URL? { board.url = url }
            if let image = object as? UIImage { board.image = image }
            if let string = object as? NSString { board.string = string as String }
        }
        return true
    }

    public enum ReadingOptionKey: Hashable, Sendable { case urlReadingFileURLsOnly, urlReadingContentsConformToTypes }

    public func readObjects(forClasses _: [AnyClass], options _: [ReadingOptionKey: Any]? = nil) -> [Any]? {
        if let urls = board.urls { return urls }
        if let images = board.images { return images }
        return nil
    }
}

// MARK: Sparkle and ServiceManagement stand-ins (updates and login items do not exist on iPadOS)

public nonisolated final class SMAppService: NSObject, @unchecked Sendable {
    public enum Status: Sendable { case notRegistered, enabled, requiresApproval, notFound }
    public static let mainApp = SMAppService()
    public var status: Status { .notRegistered }
    public func register() throws {}
    public func unregister() throws {}
    public static func openSystemSettingsLoginItems() {}
}

// MARK: Sparkle (self-updating does not exist on iPadOS; updates come from sideloading)

@objc public protocol SPUUpdaterDelegate: NSObjectProtocol {}
@objc public protocol SPUStandardUserDriverDelegate: NSObjectProtocol {}
@objc public nonisolated protocol SUVersionComparison: NSObjectProtocol {}

public nonisolated final class SUAppcastItem: NSObject, @unchecked Sendable {
    public var displayVersionString: String { "" }
    public var versionString: String { "" }
}

@objc public nonisolated protocol SUVersionDisplay: NSObjectProtocol {}

public nonisolated final class SUStandardVersionComparator: NSObject, @unchecked Sendable {
    public func compareVersion(_ lhs: String, toVersion rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: .numeric)
    }
}

public final class SUAppcast: NSObject {}
public enum SPUUpdateCheck: Int, Sendable { case updates, updatesInBackground, updateInformation }

public final class SPUUpdater: NSObject {
    @objc public dynamic var automaticallyChecksForUpdates = false
    @objc public dynamic var automaticallyDownloadsUpdates = false
    @objc public dynamic var allowsAutomaticUpdates = false
    public func checkForUpdateInformation() {}
    public var canCheckForUpdates: Bool { false }
    public var sessionInProgress: Bool { false }
    public var lastUpdateCheckDate: Date? { nil }
    public func checkForUpdates() {}
    public func checkForUpdatesInBackground() {}
    public func resetUpdateCycle() {}
    public func clearFeedURLFromUserDefaults() -> URL? { nil }
}

public final class SPUStandardUserDriver: NSObject {
    public func showUpdateInFocus() {}
}

public final class SPUStandardUpdaterController: NSObject {
    public let updater = SPUUpdater()
    public let userDriver = SPUStandardUserDriver()

    public init(startingUpdater _: Bool, updaterDelegate _: AnyObject?, userDriverDelegate _: AnyObject?) {}
    public func startUpdater() {}
    public func checkForUpdates(_: Any?) {}
}

public func DCSGetTermRangeInString(_: AnyObject?, _: CFString, _: CFIndex) -> CFRange { CFRange(location: kCFNotFound, length: 0) }
