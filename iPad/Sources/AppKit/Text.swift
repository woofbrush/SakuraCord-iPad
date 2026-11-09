import ObjectiveC

@objc public protocol NSTextDelegate: NSObjectProtocol {
    @objc optional func textDidChange(_ notification: Notification)
    @objc optional func textDidBeginEditing(_ notification: Notification)
    @objc optional func textDidEndEditing(_ notification: Notification)
}

@objc public protocol NSTextViewDelegate: NSTextDelegate {
    @objc optional func textViewDidChangeSelection(_ notification: Notification)
    @objc optional func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool
    @objc optional func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool
    @objc optional func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool
    @objc optional func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu?
}

public nonisolated enum NSText {
    public static let didBeginEditingNotification = Notification.Name("NSTextDidBeginEditing")
    public static let didChangeNotification = Notification.Name("NSTextDidChange")
    public static let didEndEditingNotification = Notification.Name("NSTextDidEndEditing")
}

public extension NSAttributedString.Key {
    static let toolTip = NSAttributedString.Key("NSToolTip")
    static let cursor = NSAttributedString.Key("NSCursor")
}

/// A TextKit 1 UITextView presenting NSTextView's API. Keyboard commands follow
/// AppKit's route: keyDown, then doCommandBy on the delegate, then default editing.
open class NSTextView: UITextView, UITextViewDelegate {
    public weak var nsDelegate: NSTextViewDelegate?

    /// SwiftUI may propose an infinite width; AppKit tolerates that frame, CALayer throws.
    override open var frame: CGRect {
        get { super.frame }
        set { super.frame = newValue.ak_validated(fallback: super.frame) }
    }

    public var isRichText = true
    public var importsGraphics = false
    public var allowsUndo = true
    public var isFieldEditor = false
    public var isVerticallyResizable = true
    public var isHorizontallyResizable = false
    public var minSize: CGSize = .zero
    public var maxSize: CGSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
    public var usesRuler = false
    public var usesFontPanel = false
    public var usesInspectorBar = false
    public var insertionPointColor: UIColor? { didSet { tintColor = insertionPointColor } }
    public var selectedTextAttributes: [NSAttributedString.Key: Any] = [:]
    public var isContinuousSpellCheckingEnabled = false { didSet { spellCheckingType = isContinuousSpellCheckingEnabled ? .yes : .no } }
    public var isGrammarCheckingEnabled = false
    public var isAutomaticSpellingCorrectionEnabled = false { didSet { autocorrectionType = isAutomaticSpellingCorrectionEnabled ? .yes : .no } }
    public var isAutomaticQuoteSubstitutionEnabled = false { didSet { smartQuotesType = isAutomaticQuoteSubstitutionEnabled ? .yes : .no } }
    public var isAutomaticDashSubstitutionEnabled = false { didSet { smartDashesType = isAutomaticDashSubstitutionEnabled ? .yes : .no } }
    public var isAutomaticTextReplacementEnabled = false
    public var isAutomaticLinkDetectionEnabled = false
    public var isAutomaticDataDetectionEnabled = false
    public var allowsDocumentBackgroundColorChange = false
    public var isIncrementalSearchingEnabled = false
    public var usesFindBar = false
    public var isAutomaticTextCompletionEnabled = false
    public var inputContext: NSTextInputContext? { NSTextInputContext.shared }

    public var drawsBackground: Bool {
        get { backgroundColor != nil && backgroundColor != .clear }
        set { if !newValue { backgroundColor = .clear } }
    }

    public var string: String {
        get { text ?? "" }
        set { text = newValue }
    }

    public var nsTextContainerInset: CGSize {
        get { CGSize(width: textContainerInset.left, height: textContainerInset.top) }
        set { textContainerInset = UIEdgeInsets(top: newValue.height, left: newValue.width, bottom: newValue.height, right: newValue.width) }
    }

    public var textContainerOrigin: CGPoint { CGPoint(x: textContainerInset.left, y: textContainerInset.top) }

    public convenience init() {
        self.init(frame: .zero)
    }

    public convenience init(frame: CGRect) {
        let storage = NSTextStorage()
        let manager = NSLayoutManager()
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: CGSize(width: frame.width, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = true
        manager.addTextContainer(container)
        self.init(frame: frame, textContainer: container)
    }

    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        backgroundColor = .clear
        textContainer?.lineFragmentPadding = 5
        textContainerInset = .zero
        super.delegate = self
        isScrollEnabled = false
    }

    public required init?(coder: NSCoder) { super.init(coder: coder) }

    public func nsSelectedRange() -> NSRange { selectedRange }

    open func pasteAsPlainText(_: Any?) {
        guard let string = UIPasteboard.general.string else { return }
        insertText(string)
    }

    public func markedRange() -> NSRange {
        guard let marked = markedTextRange else { return NSRange(location: NSNotFound, length: 0) }
        return NSRange(
            location: offset(from: beginningOfDocument, to: marked.start),
            length: offset(from: marked.start, to: marked.end)
        )
    }

    open func setMarkedText(_ value: Any, selectedRange: NSRange, replacementRange _: NSRange) {
        let text = (value as? NSAttributedString)?.string ?? value as? String
        super.setMarkedText(text, selectedRange: selectedRange)
    }

    override open func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        setMarkedText(markedText ?? "", selectedRange: selectedRange, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    @objc open func drawBackground(in _: CGRect) {}

    override open func draw(_ rect: CGRect) {
        drawBackground(in: rect)
        super.draw(rect)
    }
    /// UIKit has already applied the selection; subclasses observe it here as on macOS.
    @objc(ak_setSelectedRanges:affinity:stillSelecting:) open dynamic func setSelectedRanges(_: [NSValue], affinity _: NSSelectionAffinity, stillSelecting _: Bool) {}
    public func setSelectedRange(_ range: NSRange) { selectedRange = range }
    public func setSelectedRange(_ range: NSRange, affinity _: NSSelectionAffinity, stillSelecting _: Bool) { selectedRange = range }
    public func attributedString() -> NSAttributedString { attributedText ?? NSAttributedString() }
    public func hasMarkedText() -> Bool { markedTextRange != nil }
    public func breakUndoCoalescing() {}
    public func showFindIndicator(for _: NSRange) {}
    public func invalidateTextContainerOrigin() {}
    public func updateInsertionPointStateAndRestartTimer(_: Bool) {}
    public func setAlignment(_ alignment: NSTextAlignment, range _: NSRange) { textAlignment = alignment }

    open func insertText(_ string: Any, replacementRange: NSRange) {
        if replacementRange.location != NSNotFound { selectedRange = replacementRange }
        insertText((string as? NSAttributedString)?.string ?? (string as? String) ?? "")
    }

    open var readablePasteboardTypes: [NSPasteboard.PasteboardType] { [.string] }
    open func readSelection(from _: NSPasteboard, type _: NSPasteboard.PasteboardType) -> Bool { false }

    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) { return isEditable && UIPasteboard.general.numberOfItems > 0 }
        return super.canPerformAction(action, withSender: sender)
    }

    /// AppKit's route: the first readable type this view accepts.
    override open func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        for type in readablePasteboardTypes where pasteboard.availableType(from: [type]) != nil {
            if readSelection(from: pasteboard, type: type) { return }
        }
        super.paste(sender)
    }
    @objc open func validateMenuItem(_: NSMenuItem) -> Bool { true }

    @objc open dynamic func shouldChangeText(in range: NSRange, replacementString string: String?) -> Bool {
        nsDelegate?.textView?(self, shouldChangeTextIn: range, replacementString: string) ?? true
    }

    /// The height `text` needs at `width`, without insets. A UITextView that doesn't
    /// scroll bounds its layout by its own height, so its layout manager never reports
    /// a line past the ones already showing; only `sizeThatFits` measures beyond them.
    public func ak_fittingTextHeight(width: CGFloat) -> CGFloat {
        let fitted = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return max(0, fitted - textContainerInset.top - textContainerInset.bottom)
    }

    private var fittedContent: (width: CGFloat, text: String)?

    /// NSTextView grows with its content when vertically resizable; UITextView does not.
    private func fitHeightToContent() {
        guard isVerticallyResizable, !isTracking, bounds.width > 0 else { return }
        let content = text ?? ""
        if let fittedContent, fittedContent.width == bounds.width, fittedContent.text == content { return }
        fittedContent = (bounds.width, content)
        let fitted = ceil(ak_fittingTextHeight(width: bounds.width) + textContainerInset.top + textContainerInset.bottom)
        let height = min(max(minSize.height, fitted), maxSize.height)
        guard abs(frame.height - height) > 0.5 else { return }
        frame.size.height = height
        guard let scrollView = enclosingScrollView, scrollView.documentView === self else { return }
        scrollView.syncContentSize()
        if height <= scrollView.bounds.height, scrollView.contentOffset.y != 0 { scrollView.contentOffset.y = 0 }
    }

    /// NSTextView keeps the caret inside its clip view as it edits. Waits for the
    /// update that follows the edit, which may give the scroll view a new height.
    private func revealCaretInScrollView() {
        guard let scrollView = enclosingScrollView, scrollView.documentView === self, scrollView.hasVerticalScroller else { return }
        Task { @MainActor [weak self, weak scrollView] in
            guard let self, let scrollView, let end = self.selectedTextRange?.end else { return }
            scrollView.syncContentSize()
            scrollView.scrollRectToVisible(self.convert(self.caretRect(for: end), to: scrollView), animated: false)
        }
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        fitHeightToContent()
    }

    @objc open dynamic func didChangeText() {
        fitHeightToContent()
        let note = Notification(name: NSText.didChangeNotification, object: self)
        nsDelegate?.textDidChange?(note)
        NotificationCenter.default.post(note)
        revealCaretInScrollView()
    }

    @objc open dynamic func doCommand(by selector: Selector) {}

    // MARK: UITextViewDelegate, forwarded to AppKit's callbacks

    public func textView(_: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n", !isHandlingHardwareNewline, handle(#selector(UIResponder.insertNewline(_:))) { return false }
        return shouldChangeText(in: range, replacementString: text)
    }

    public func textViewDidChange(_: UITextView) { didChangeText() }

    public func textViewDidChangeSelection(_: UITextView) {
        setSelectedRanges([NSValue(range: selectedRange)], affinity: .downstream, stillSelecting: false)
        nsDelegate?.textViewDidChangeSelection?(Notification(name: Notification.Name("NSTextViewDidChangeSelection"), object: self))
    }

    public func textViewDidBeginEditing(_: UITextView) {
        nsDelegate?.textDidBeginEditing?(Notification(name: NSText.didBeginEditingNotification, object: self))
    }

    public func textViewDidEndEditing(_: UITextView) {
        nsDelegate?.textDidEndEditing?(Notification(name: NSText.didEndEditingNotification, object: self))
    }

    public func textView(
        _: UITextView,
        primaryActionFor textItem: UITextItem,
        defaultAction: UIAction
    ) -> UIAction? {
        guard case let .link(url) = textItem.content else { return defaultAction }
        return UIAction { [self] _ in
            if nsDelegate?.textView?(self, clickedOnLink: url, at: textItem.range.location) != true {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: Hardware keys

    private var currentPresses: (Set<UIPress>, UIPressesEvent?)?
    private var isHandlingHardwareNewline = false

    private func handle(_ selector: Selector) -> Bool {
        if nsDelegate?.textView?(self, doCommandBy: selector) == true { return true }
        guard responds(to: selector), ViewBridge.overrides(self, selector, base: NSTextView.self) else { return false }
        perform(selector, with: nil)
        return true
    }

    override open func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first, let key = NSEvent.key(press, type: .keyDown, window: window) else {
            return super.pressesBegan(presses, with: event)
        }
        currentPresses = (presses, event)
        keyDown(with: key)
        currentPresses = nil
    }

    override open func keyDown(with event: NSEvent) {
        if !event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
            if NSApp.textKeyEquivalentHandler?(event) == true { return }
            if performKeyEquivalent(with: event) { return }
            if event.modifierFlags.intersection([.command, .option, .control]) == .command,
               event.charactersIgnoringModifiers?.lowercased() == "v" {
                paste(nil)
                return
            }
        }
        if let selector = TextCommands.selector(for: event), handle(selector) { return }
        isHandlingHardwareNewline = event.keyCode == 36
        defer { isHandlingHardwareNewline = false }
        if let (presses, uiEvent) = currentPresses { super.pressesBegan(presses, with: uiEvent) }
    }
}

@objc public nonisolated enum NSSelectionAffinity: Int, Sendable { case upstream, downstream }

public final class NSTextInputContext: NSObject {
    static let shared = NSTextInputContext()
    public func discardMarkedText() {}
    public func invalidateCharacterCoordinates() {}
}

/// The editing commands AppKit's key bindings send for these keys.
enum TextCommands {
    static func selector(for event: NSEvent) -> Selector? {
        let shift = event.modifierFlags.contains(.shift)
        let hasOtherModifiers = !event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        switch event.keyCode {
        case 36: return hasOtherModifiers ? nil : (shift ? #selector(UIResponder.insertLineBreak(_:)) : #selector(UIResponder.insertNewline(_:)))
        case 53: return #selector(UIResponder.cancelOperation(_:))
        case 48: return shift ? #selector(UIResponder.insertBacktab(_:)) : #selector(UIResponder.insertTab(_:))
        case 126 where !hasOtherModifiers: return #selector(UIResponder.moveUp(_:))
        case 125 where !hasOtherModifiers: return #selector(UIResponder.moveDown(_:))
        case 123 where !hasOtherModifiers: return #selector(UIResponder.moveLeft(_:))
        case 124 where !hasOtherModifiers: return #selector(UIResponder.moveRight(_:))
        default: return nil
        }
    }
}

extension UIResponder {
    @objc(ak_insertNewline:) open func insertNewline(_ sender: Any?) {}
    @objc(ak_insertLineBreak:) open func insertLineBreak(_ sender: Any?) {}
    @objc(ak_insertNewlineIgnoringFieldEditor:) open func insertNewlineIgnoringFieldEditor(_ sender: Any?) {}
    @objc(ak_insertTab:) open func insertTab(_ sender: Any?) {}
    @objc(ak_insertBacktab:) open func insertBacktab(_ sender: Any?) {}
    @objc(ak_moveUp:) open func moveUp(_ sender: Any?) {}
    @objc(ak_moveDown:) open func moveDown(_ sender: Any?) {}
    @objc(ak_moveLeft:) open func moveLeft(_ sender: Any?) {}
    @objc(ak_moveRight:) open func moveRight(_ sender: Any?) {}
    @objc(ak_deleteBackward:) open func deleteBackward(_ sender: Any?) {}
    @objc(ak_deleteForward:) open func deleteForward(_ sender: Any?) {}
}

// MARK: Text fields

@objc public protocol NSControlTextEditingDelegate: NSObjectProtocol {
    @objc optional func controlTextDidChange(_ notification: Notification)
    @objc optional func controlTextDidBeginEditing(_ notification: Notification)
    @objc optional func controlTextDidEndEditing(_ notification: Notification)
    @objc optional func control(_ control: UIControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool
}

@objc public protocol NSTextFieldDelegate: NSControlTextEditingDelegate {}

@objc public protocol NSSearchFieldDelegate: NSTextFieldDelegate {
    @objc optional func searchFieldDidEndSearching(_ sender: NSSearchField)
}

open class NSControl: UIControl {
    public weak var target: AnyObject?
    public var action: Selector?
    public var focusRingType: NSFocusRingType = .none
    public var controlSize: UIControl.ControlSize = .regular

    @discardableResult
    public func sendAction(_ action: Selector?, to target: Any?) -> Bool {
        guard let action else { return false }
        return UIApplication.shared.sendAction(action, to: target, from: self, for: nil)
    }
}

public extension UIControl {
    static let textDidBeginEditingNotification = Notification.Name("NSControlTextDidBeginEditingNotification")
    static let textDidChangeNotification = Notification.Name("NSControlTextDidChangeNotification")
    static let textDidEndEditingNotification = Notification.Name("NSControlTextDidEndEditingNotification")
}

open class NSTextField: UITextField, UITextFieldDelegate {
    public weak var nsDelegate: NSTextFieldDelegate?
    public var isBordered = false
    public var isBezeled = false
    public var drawsBackground = false
    public var focusRingType: NSFocusRingType = .none
    public var isSelectable = true
    public var lineBreakMode: NSLineBreakMode = .byTruncatingTail
    public var usesSingleLineMode = true
    public var maximumNumberOfLines = 1
    public var isAutomaticTextCompletionEnabled = false
    public var contentType: NSTextContentType?
    public var allowsWritingTools = false
    public var allowsWritingToolsAffordance = false
    public lazy var cell: NSSearchFieldCell? = NSSearchFieldCell(owner: self)

    public var alignment: NSTextAlignment {
        get { textAlignment }
        set { textAlignment = newValue }
    }

    public var attributedStringValue: NSAttributedString {
        get { attributedText ?? NSAttributedString() }
        set { attributedText = newValue }
    }

    public var stringValue: String {
        get { text ?? "" }
        set { text = newValue }
    }

    public var placeholderAttributedString: NSAttributedString? {
        get { attributedPlaceholder }
        set { attributedPlaceholder = newValue }
    }

    public func currentEditor() -> NSTextField? { isFirstResponder ? self : nil }

    public var selectedRange: NSRange {
        get {
            guard let range = selectedTextRange else { return NSRange(location: 0, length: 0) }
            return NSRange(location: offset(from: beginningOfDocument, to: range.start), length: offset(from: range.start, to: range.end))
        }
        set {
            guard let start = position(from: beginningOfDocument, offset: newValue.location),
                  let end = position(from: start, offset: newValue.length) else { return }
            selectedTextRange = textRange(from: start, to: end)
        }
    }

    public var placeholderString: String? {
        get { placeholder }
        set { placeholder = newValue }
    }

    public convenience init(string: String) {
        self.init(frame: .zero)
        text = string
    }

    public convenience init(labelWithString string: String) {
        self.init(string: string)
        isUserInteractionEnabled = false
    }

    public convenience init(wrappingLabelWithString string: String) {
        self.init(labelWithString: string)
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        super.delegate = self
        addTarget(self, action: #selector(ak_textChanged), for: .editingChanged)
    }

    public required init?(coder: NSCoder) { super.init(coder: coder) }

    @objc private func ak_textChanged() {
        nsDelegate?.controlTextDidChange?(Notification(name: Notification.Name("NSControlTextDidChange"), object: self))
    }

    public func textFieldDidBeginEditing(_: UITextField) {
        nsDelegate?.controlTextDidBeginEditing?(Notification(name: Notification.Name("NSControlTextDidBeginEditing"), object: self))
    }

    public func textFieldDidEndEditing(_: UITextField) {
        nsDelegate?.controlTextDidEndEditing?(Notification(name: Notification.Name("NSControlTextDidEndEditing"), object: self))
    }

    public func textFieldShouldReturn(_: UITextField) -> Bool {
        _ = command(#selector(UIResponder.insertNewline(_:)))
        return false
    }

    private static let fieldEditor = NSTextView()

    private func command(_ selector: Selector) -> Bool {
        nsDelegate?.control?(self, textView: Self.fieldEditor, doCommandBy: selector) ?? false
    }

    override open var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand.inputUpArrow, UIKeyCommand.inputDownArrow, UIKeyCommand.inputEscape].map {
            let command = UIKeyCommand(input: $0, modifierFlags: [], action: #selector(ak_fieldCommand(_:)))
            command.wantsPriorityOverSystemBehavior = true
            return command
        }
    }

    @objc private func ak_fieldCommand(_ sender: UIKeyCommand) {
        let selector = switch sender.input {
        case UIKeyCommand.inputUpArrow: #selector(UIResponder.moveUp(_:))
        case UIKeyCommand.inputDownArrow: #selector(UIResponder.moveDown(_:))
        default: #selector(UIResponder.cancelOperation(_:))
        }
        _ = command(selector)
    }
}

public nonisolated struct NSTextContentType: Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public nonisolated enum NSFocusRingType: Sendable { case `default`, none, exterior }

public final class NSSearchFieldCell: NSObject {
    public var placeholderString: String?
    public var usesSingleLineMode = true
    public var isScrollable = true
    public var wraps = false
    public var searchButtonCell: AnyObject?
    public var cancelButtonCell: AnyObject?
    private weak var owner: UIView?

    init(owner: UIView) {
        self.owner = owner
    }

    public func cellSize(forBounds rect: CGRect) -> CGSize {
        owner?.sizeThatFits(rect.size) ?? .zero
    }
}

open class NSSearchField: NSTextField {
    public var sendsSearchStringImmediately = true
    public var sendsWholeSearchString = false
}
