import ObjectiveC

public nonisolated final class NSEvent: NSObject {
    public enum EventType: UInt, Sendable {
        case leftMouseDown = 1, leftMouseUp, rightMouseDown, rightMouseUp, mouseMoved, leftMouseDragged, rightMouseDragged
        case mouseEntered, mouseExited, keyDown, keyUp, flagsChanged, scrollWheel = 22
        case otherMouseDown = 25, otherMouseUp, otherMouseDragged, magnify = 30, swipe, smartMagnify = 32
        case cursorUpdate = 17, systemDefined = 14, appKitDefined = 13, applicationDefined = 15, periodic = 16
    }

    public nonisolated struct EventTypeMask: OptionSet, Sendable {
        public let rawValue: UInt64
        public init(rawValue: UInt64) { self.rawValue = rawValue }
        public init(type: EventType) { rawValue = 1 << type.rawValue }
        public static let leftMouseDown = Self(type: .leftMouseDown)
        public static let leftMouseUp = Self(type: .leftMouseUp)
        public static let rightMouseDown = Self(type: .rightMouseDown)
        public static let rightMouseUp = Self(type: .rightMouseUp)
        public static let otherMouseDown = Self(type: .otherMouseDown)
        public static let otherMouseUp = Self(type: .otherMouseUp)
        public static let mouseMoved = Self(type: .mouseMoved)
        public static let leftMouseDragged = Self(type: .leftMouseDragged)
        public static let rightMouseDragged = Self(type: .rightMouseDragged)
        public static let mouseEntered = Self(type: .mouseEntered)
        public static let mouseExited = Self(type: .mouseExited)
        public static let keyDown = Self(type: .keyDown)
        public static let keyUp = Self(type: .keyUp)
        public static let flagsChanged = Self(type: .flagsChanged)
        public static let scrollWheel = Self(type: .scrollWheel)
        public static let cursorUpdate = Self(type: .cursorUpdate)
        public static let any = Self(rawValue: .max)
    }

    public nonisolated struct ModifierFlags: OptionSet, Hashable, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let capsLock = Self(rawValue: 1 << 16)
        public static let shift = Self(rawValue: 1 << 17)
        public static let control = Self(rawValue: 1 << 18)
        public static let option = Self(rawValue: 1 << 19)
        public static let command = Self(rawValue: 1 << 20)
        public static let numericPad = Self(rawValue: 1 << 21)
        public static let help = Self(rawValue: 1 << 22)
        public static let function = Self(rawValue: 1 << 23)
        public static let deviceIndependentFlagsMask = Self(rawValue: 0xFFFF_0000)

        init(_ flags: UIKeyModifierFlags) {
            var value: ModifierFlags = []
            if flags.contains(.shift) { value.insert(.shift) }
            if flags.contains(.control) { value.insert(.control) }
            if flags.contains(.alternate) { value.insert(.option) }
            if flags.contains(.command) { value.insert(.command) }
            if flags.contains(.alphaShift) { value.insert(.capsLock) }
            self = value
        }
    }

    public nonisolated struct Phase: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let began = Self(rawValue: 1)
        public static let stationary = Self(rawValue: 2)
        public static let changed = Self(rawValue: 4)
        public static let ended = Self(rawValue: 8)
        public static let cancelled = Self(rawValue: 16)
        public static let mayBegin = Self(rawValue: 32)
    }

    public nonisolated struct SpecialKey: Hashable, Sendable, RawRepresentable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public var unicodeScalar: Unicode.Scalar { Unicode.Scalar(UInt32(rawValue)) ?? " " }
        public static let upArrow = Self(rawValue: 0xF700)
        public static let downArrow = Self(rawValue: 0xF701)
        public static let leftArrow = Self(rawValue: 0xF702)
        public static let rightArrow = Self(rawValue: 0xF703)
        public static let home = Self(rawValue: 0xF729)
        public static let end = Self(rawValue: 0xF72B)
        public static let pageUp = Self(rawValue: 0xF72C)
        public static let pageDown = Self(rawValue: 0xF72D)
        public static let delete = Self(rawValue: 0x7F)
        public static let deleteForward = Self(rawValue: 0xF728)
        public static let carriageReturn = Self(rawValue: 0x0D)
        public static let newline = Self(rawValue: 0x0A)
        public static let enter = Self(rawValue: 0x03)
        public static let tab = Self(rawValue: 0x09)
        public static let backTab = Self(rawValue: 0x19)
        public static let f1 = Self(rawValue: 63236)
        public static let f2 = Self(rawValue: 63237)
        public static let f3 = Self(rawValue: 63238)
        public static let f4 = Self(rawValue: 63239)
        public static let f5 = Self(rawValue: 63240)
        public static let f6 = Self(rawValue: 63241)
        public static let f7 = Self(rawValue: 63242)
        public static let f8 = Self(rawValue: 63243)
        public static let f9 = Self(rawValue: 63244)
        public static let f10 = Self(rawValue: 63245)
        public static let f11 = Self(rawValue: 63246)
        public static let f12 = Self(rawValue: 63247)
        public static let f13 = Self(rawValue: 63248)
        public static let f14 = Self(rawValue: 63249)
        public static let f15 = Self(rawValue: 63250)
        public static let f16 = Self(rawValue: 63251)
        public static let f17 = Self(rawValue: 63252)
        public static let f18 = Self(rawValue: 63253)
        public static let f19 = Self(rawValue: 63254)
        public static let f20 = Self(rawValue: 63255)
        public static let f21 = Self(rawValue: 63256)
        public static let f22 = Self(rawValue: 63257)
        public static let f23 = Self(rawValue: 63258)
        public static let f24 = Self(rawValue: 63259)
        public static let f25 = Self(rawValue: 63260)
        public static let f26 = Self(rawValue: 63261)
        public static let f27 = Self(rawValue: 63262)
        public static let f28 = Self(rawValue: 63263)
        public static let f29 = Self(rawValue: 63264)
        public static let f30 = Self(rawValue: 63265)
        public static let f31 = Self(rawValue: 63266)
        public static let f32 = Self(rawValue: 63267)
        public static let f33 = Self(rawValue: 63268)
        public static let f34 = Self(rawValue: 63269)
        public static let f35 = Self(rawValue: 63270)
    }

    public let type: EventType
    public let locationInWindow: CGPoint
    public let modifierFlags: ModifierFlags
    public let timestamp: TimeInterval
    public var stage: Int { 0 }
    public let clickCount: Int
    public let buttonNumber: Int
    public let characters: String?
    public let charactersIgnoringModifiers: String?
    public let keyCode: UInt16
    public let isARepeat: Bool
    public let scrollingDeltaX: CGFloat
    public let scrollingDeltaY: CGFloat
    public let hasPreciseScrollingDeltas: Bool
    public let phase: Phase
    public let momentumPhase: Phase
    public let trackingArea: NSTrackingArea?
    public weak var window: UIWindow?

    public var deltaX: CGFloat { scrollingDeltaX }
    public var deltaY: CGFloat { scrollingDeltaY }
    public var isDirectionInvertedFromDevice: Bool { true }

    public var specialKey: SpecialKey? {
        guard let scalar = charactersIgnoringModifiers?.unicodeScalars.first else { return nil }
        let key = SpecialKey(rawValue: Int(scalar.value))
        let known: Set<SpecialKey> = [
            .upArrow, .downArrow, .leftArrow, .rightArrow, .home, .end, .pageUp, .pageDown,
            .delete, .deleteForward, .carriageReturn, .newline, .enter, .tab, .backTab
        ]
        return known.contains(key) ? key : nil
    }

    public init(
        type: EventType,
        location: CGPoint = .zero,
        modifiers: ModifierFlags = [],
        window: UIWindow? = nil,
        clickCount: Int = 0,
        buttonNumber: Int = 0,
        characters: String? = nil,
        charactersIgnoringModifiers: String? = nil,
        keyCode: UInt16 = 0,
        isARepeat: Bool = false,
        scrollingDeltaX: CGFloat = 0,
        scrollingDeltaY: CGFloat = 0,
        hasPreciseScrollingDeltas: Bool = true,
        phase: Phase = [],
        momentumPhase: Phase = [],
        trackingArea: NSTrackingArea? = nil
    ) {
        self.type = type
        locationInWindow = location
        modifierFlags = modifiers
        timestamp = ProcessInfo.processInfo.systemUptime
        self.clickCount = clickCount
        self.buttonNumber = buttonNumber
        self.characters = characters
        self.charactersIgnoringModifiers = charactersIgnoringModifiers
        self.keyCode = keyCode
        self.isARepeat = isARepeat
        self.scrollingDeltaX = scrollingDeltaX
        self.scrollingDeltaY = scrollingDeltaY
        self.hasPreciseScrollingDeltas = hasPreciseScrollingDeltas
        self.phase = phase
        self.momentumPhase = momentumPhase
        self.trackingArea = trackingArea
        self.window = window
    }

    // MARK: Global state

    public internal(set) nonisolated(unsafe) static var current: NSEvent?
    nonisolated(unsafe) static var lastLocation: CGPoint = .zero
    nonisolated(unsafe) static var currentModifiers: ModifierFlags = []

    public class var mouseLocation: CGPoint { lastLocation }
    public class var modifierFlags: ModifierFlags { currentModifiers }
    public class var pressedMouseButtons: Int { 0 }

    // MARK: Monitors

    private nonisolated final class Monitor: NSObject {
        let mask: EventTypeMask
        let handler: (NSEvent) -> NSEvent?

        init(mask: EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) {
            self.mask = mask
            self.handler = handler
        }
    }

    nonisolated(unsafe) private static var monitors: [Monitor] = []

    public class func addLocalMonitorForEvents(
        matching mask: EventTypeMask,
        handler: @escaping (NSEvent) -> NSEvent?
    ) -> Any? {
        let monitor = Monitor(mask: mask, handler: handler)
        monitors.append(monitor)
        return monitor
    }

    public class func addGlobalMonitorForEvents(
        matching _: EventTypeMask,
        handler _: @escaping (NSEvent) -> Void
    ) -> Any? { nil }

    public class func removeMonitor(_ monitor: Any) {
        guard let monitor = monitor as? Monitor else { return }
        monitors.removeAll { $0 === monitor }
    }

    /// Runs local monitors; `nil` means one of them consumed the event.
    static func dispatch(_ event: NSEvent) -> NSEvent? {
        current = event
        var result: NSEvent? = event
        for monitor in monitors where monitor.mask.contains(EventTypeMask(type: event.type)) {
            guard let value = result else { return nil }
            result = monitor.handler(value)
        }
        return result
    }

    // MARK: Hardware keys

    @MainActor static func key(_ press: UIPress, type: EventType, window: UIWindow?) -> NSEvent? {
        guard let key = press.key else { return nil }
        let special = KeyTranslation.characters[key.keyCode]
        let plain = special ?? key.charactersIgnoringModifiers
        let isModifier = KeyTranslation.modifierKeys.contains(key.keyCode)
        return NSEvent(
            type: isModifier ? .flagsChanged : type,
            location: lastLocation,
            modifiers: ModifierFlags(key.modifierFlags),
            window: window,
            characters: special ?? key.characters,
            charactersIgnoringModifiers: plain,
            keyCode: KeyTranslation.macKeyCodes[key.keyCode] ?? UInt16(key.keyCode.rawValue)
        )
    }
}

/// macOS virtual key codes and function-key characters, which the app compares against.
enum KeyTranslation {
    static let modifierKeys: Set<UIKeyboardHIDUsage> = [
        .keyboardLeftShift, .keyboardRightShift, .keyboardLeftControl, .keyboardRightControl,
        .keyboardLeftAlt, .keyboardRightAlt, .keyboardLeftGUI, .keyboardRightGUI, .keyboardCapsLock
    ]

    static let characters: [UIKeyboardHIDUsage: String] = [
        .keyboardUpArrow: "\u{F700}", .keyboardDownArrow: "\u{F701}",
        .keyboardLeftArrow: "\u{F702}", .keyboardRightArrow: "\u{F703}",
        .keyboardHome: "\u{F729}", .keyboardEnd: "\u{F72B}",
        .keyboardPageUp: "\u{F72C}", .keyboardPageDown: "\u{F72D}",
        .keyboardDeleteOrBackspace: "\u{7F}", .keyboardDeleteForward: "\u{F728}",
        .keyboardReturnOrEnter: "\r", .keyboardEscape: "\u{1B}", .keyboardTab: "\t"
    ]

    static let macKeyCodes: [UIKeyboardHIDUsage: UInt16] = [
        .keyboardA: 0, .keyboardS: 1, .keyboardD: 2, .keyboardF: 3, .keyboardH: 4, .keyboardG: 5,
        .keyboardZ: 6, .keyboardX: 7, .keyboardC: 8, .keyboardV: 9, .keyboardB: 11, .keyboardQ: 12,
        .keyboardW: 13, .keyboardE: 14, .keyboardR: 15, .keyboardY: 16, .keyboardT: 17,
        .keyboard1: 18, .keyboard2: 19, .keyboard3: 20, .keyboard4: 21, .keyboard6: 22, .keyboard5: 23,
        .keyboardEqualSign: 24, .keyboard9: 25, .keyboard7: 26, .keyboardHyphen: 27, .keyboard8: 28,
        .keyboard0: 29, .keyboardCloseBracket: 30, .keyboardO: 31, .keyboardU: 32, .keyboardOpenBracket: 33,
        .keyboardI: 34, .keyboardP: 35, .keyboardReturnOrEnter: 36, .keyboardL: 37, .keyboardJ: 38,
        .keyboardQuote: 39, .keyboardK: 40, .keyboardSemicolon: 41, .keyboardBackslash: 42,
        .keyboardComma: 43, .keyboardSlash: 44, .keyboardN: 45, .keyboardM: 46, .keyboardPeriod: 47,
        .keyboardTab: 48, .keyboardSpacebar: 49, .keyboardGraveAccentAndTilde: 50,
        .keyboardDeleteOrBackspace: 51, .keyboardEscape: 53, .keyboardLeftGUI: 55, .keyboardLeftShift: 56,
        .keyboardCapsLock: 57, .keyboardLeftAlt: 58, .keyboardLeftControl: 59, .keyboardRightShift: 60,
        .keyboardRightAlt: 61, .keyboardRightControl: 62, .keyboardHome: 115, .keyboardPageUp: 116,
        .keyboardDeleteForward: 117, .keyboardEnd: 119, .keyboardPageDown: 121, .keyboardLeftArrow: 123,
        .keyboardRightArrow: 124, .keyboardDownArrow: 125, .keyboardUpArrow: 126
    ]
}

public nonisolated final class NSTrackingArea: NSObject {
    public nonisolated struct Options: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let mouseEnteredAndExited = Self(rawValue: 1)
        public static let mouseMoved = Self(rawValue: 2)
        public static let cursorUpdate = Self(rawValue: 4)
        public static let activeWhenFirstResponder = Self(rawValue: 0x10)
        public static let activeInKeyWindow = Self(rawValue: 0x20)
        public static let activeInActiveApp = Self(rawValue: 0x40)
        public static let activeAlways = Self(rawValue: 0x80)
        public static let assumeInside = Self(rawValue: 0x100)
        public static let inVisibleRect = Self(rawValue: 0x200)
        public static let enabledDuringMouseDrag = Self(rawValue: 0x400)
    }

    public private(set) var rect: CGRect
    public let options: Options
    public weak var owner: AnyObject?
    public let userInfo: [AnyHashable: Any]?
    var isInside = false

    public init(rect: CGRect, options: Options, owner: Any?, userInfo: [AnyHashable: Any]? = nil) {
        self.rect = rect
        self.options = options
        self.owner = owner as AnyObject?
        self.userInfo = userInfo
    }
}

public nonisolated struct NSCursor: Sendable {
    public static let arrow = NSCursor()
    public static let pointingHand = NSCursor()
    public static let iBeam = NSCursor()
    public static let crosshair = NSCursor()
    public static let closedHand = NSCursor()
    public static let openHand = NSCursor()
    public static let resizeUpDown = NSCursor()
    public static let resizeLeftRight = NSCursor()
    public static let operationNotAllowed = NSCursor()
    public static var current: NSCursor { arrow }

    public func set() {}
    public func push() {}
    public func pop() {}
    public static func pop() {}
    public static func hide() {}
    public static func unhide() {}
    public static func setHiddenUntilMouseMoves(_: Bool) {}
}
