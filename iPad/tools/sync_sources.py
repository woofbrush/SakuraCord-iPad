#!/usr/bin/env python3
"""Generates iPad/Sources/SakuraCord/Generated from the macOS app's sources.

The iPad build compiles the real macOS app. Sources/AppKit implements the AppKit
API on UIKit; this script handles the few differences that are pure syntax, and
iPad/Overrides/<relative path> replaces a macOS file outright where the platforms
genuinely differ. Files are only rewritten when their content changes, so
incremental builds stay incremental.
"""
import pathlib
import re

IPAD = pathlib.Path(__file__).resolve().parent.parent
MAC = IPAD.parent / "App/Sources/SakuraCord"
OUT = IPAD / "Sources/SakuraCord/Generated"
OVERRIDES = IPAD / "Overrides"
FOLDERS = ["App", "Models", "Services", "Support", "Views"]

# UIKit declares these non-optional; AppKit declares them optional.
NON_OPTIONAL = r"layer|textStorage|layoutManager|textContainer"
REMOVED_IMPORTS = re.compile(r"^(@preconcurrency )?import (Sparkle|ServiceManagement)\n", re.M)
RULES = [
    (re.compile(r"\b(\w*[sS]croll(?:View)?[?]?)[.]contentSize\b"), lambda m: f"{m.group(1)}.nsContentSize"),
    (re.compile(r"\bproposal[.](width|height) *[?][?]"), lambda m: f"proposal.finite{m.group(1).capitalize()} ??"),
    (re.compile(r"\bCTLineCreateWithAttributedString\("), "AKCTLineCreate("),
    (re.compile(r"\bCTFramesetterCreateWithAttributedString\("), "AKCTFramesetterCreate("),
    (re.compile(r"\bCTTypesetterCreateWithAttributedString\("), "AKCTTypesetterCreate("),
    (re.compile(r"[.]applying\(\s*(?:NSImage[.]SymbolConfiguration|[.]init)\(\s*paletteColors:\s*"), ".ak_applying(NSImage.SymbolConfiguration.ak_palette("),
    (re.compile(r"(?:NSImage[.]SymbolConfiguration|[.]init)\(\s*paletteColors:\s*"), "NSImage.SymbolConfiguration.ak_palette("),
    (re.compile(r"^(@preconcurrency )?import AppKit$", re.M), "import AppKitShim"),
    (re.compile(r"\bAppKit[.]"), "AppKitShim."),
    (re.compile(r"\[[.]withSecurityScope[^\]]*\]"), "[]"),
    (re.compile(rf"\b({NON_OPTIONAL})\?(?=[.\[])"), r"\1"),
    (re.compile(r"\.selectedRange\(\)"), ".nsSelectedRange()"),
    (re.compile(r"\.nextResponder"), ".next"),
    (re.compile(r"(?<![.\w])nextResponder\b"), "next"),
    (re.compile(r"\brenderer[.]nsImage\b"), "renderer.uiImage"),
    (re.compile(r"guard let (\w+) = NSApp else [{] return (?:nil )?[}]"), lambda m: f"let {m.group(1)}: NSApplication = NSApp"),
    (re.compile(r"[.]identifier[?][.]rawValue\b"), ".identifier"),
    (re.compile(r"[.]window[?][.]screen[?][.]"), ".window?.screen."),
    (re.compile(r"(let screen = )(\w+[.]screen)(?=\s*(?:,|else\b|\{))"), lambda m: f"{m.group(1)}Optional({m.group(2)})"),
    (re.compile(r"override var wantsUpdateLayer"), "var wantsUpdateLayer"),
    (re.compile(r"(\blet \w+ = )(\w+[.]layer)(?=\s*(?:,|else\b|\{))"), lambda m: f"{m.group(1)}Optional({m.group(2)})"),
    (re.compile(r"(?<![A-Za-z_.])(textContainerInset)(?![A-Za-z_])"), "nsTextContainerInset"),
    (re.compile(r"[.]textContainerInset(?![A-Za-z_])"), ".nsTextContainerInset"),
    (re.compile(r"(?<![A-Za-z_])((?:[a-zA-Z]*[tT]extView|[a-zA-Z]*[Ff]ield|search)[?]?)[.]delegate(?![A-Za-z_])"), lambda m: m.group(1) + ".nsDelegate"),
    (re.compile(r"\[[.]withSecurityScope\]"), "[]"),
    (re.compile(r"(bookmarkData[(]\s*options: )[.]withSecurityScope"), lambda m: m.group(1) + "[]"),
    (re.compile(r"[.]withSecurityScope"), ".withoutUI"),
    (re.compile(r"((?:guard|if|,)\s+let )(textStorage|layoutManager|textContainer|layer)(?=\s*(?:,|else\b|\{))"), lambda m: f"{m.group(1)}{m.group(2)} = Optional({m.group(2)})"),
    (re.compile(r"((?:guard|if|,)\s+let \w+ = )(\w*[tT]extView\.(?:textStorage|layoutManager|textContainer))(?=\s*(?:,|else\b|\{|$))", re.M), lambda m: f"{m.group(1)}Optional({m.group(2)})"),
    (re.compile(r"override (func (?:draggingEntered|draggingUpdated|draggingExited|draggingEnded|prepareForDragOperation|performDragOperation|concludeDragOperation|wantsPeriodicDraggingUpdates|resize\(withOldSuperviewSize oldSize: NSSize\)\s*(?=[{])|__none__)\()"), lambda m: m.group(1)),
    (re.compile(r"(@Entry var \w+: [^=\n]+\?)[ ]*$", re.M), lambda m: m.group(1) + " = nil"),
    (re.compile(r"(?<![.\w])selectedRange\(\)"), "nsSelectedRange()"),
    (re.compile(r"^import PhotosUI$", re.M), "import PhotosUI\nimport _PhotosUI_SwiftUI"),
    (re.compile(r"^import AVKit$", re.M), "import AVKit\nimport _AVKit_SwiftUI"),
    (re.compile(r"^import Translation$", re.M), "import Translation\nimport _Translation_SwiftUI"),
    (re.compile(r"(coordinator(?: _)?: )\(\)"), lambda m: m.group(1) + "Coordinator"),
    (re.compile(r"\\.openSettings\b"), lambda m: "\\.nsOpenSettings"),
    (re.compile(r"(?<![.\w])ContentMode\b"), "SwiftUI.ContentMode"),
    (re.compile(r"[.]screen[?][.]visibleFrame"), ".screen.visibleFrame"),
    (re.compile(r"selectedValue[.]rangeValue"), "selectedValue"),
    (re.compile(r"override func (view(?:Did|Will)(?:Appear|Disappear))\(\)"), lambda m: f"override func {m.group(1)}(_ animated: Bool)"),
    (re.compile(r"super[.](view(?:Did|Will)(?:Appear|Disappear))\(\)"), lambda m: f"super.{m.group(1)}(animated)"),
    (re.compile(r"override func viewDidLayout\(\)"), "override func viewDidLayoutSubviews()"),
    (re.compile(r"super[.]viewDidLayout\(\)"), "super.viewDidLayoutSubviews()"),
    (re.compile(r"guard let copy = event[.]cgEvent.*?return NSEvent\(cgEvent: copy\) [?][?] event", re.S), "return event"),
    (re.compile(r"[.]toggleStyle\([.]checkbox\)"), ".toggleStyle(NSCheckboxToggleStyle())"),
    (re.compile(r"override func (accessibility[A-Z]\w*|isAccessibilityElement)\("), lambda m: f"func nsa_{m.group(1)}("),
    (re.compile(r"super[.]accessibilityChildren\(\)"), "Optional<[Any]>.none"),
    (re.compile(r"super[.]accessibilityPerformPress\(\)"), "false"),
    (re.compile(r"[.](accessibility(?:Children|Frame|PerformPress|ActionNames|IsIgnored|VisibleRows|Value|Rows|Role|Label|CustomActions|Parent|Help|Title|Identifier)|isAccessibilityElement)\(\)"), lambda m: f".nsa_{m.group(1)}()"),
    (re.compile(r"(?<![\w.])(accessibility(?:Children|Frame|PerformPress|ActionNames|IsIgnored|VisibleRows|Value|Rows|Role|Label|CustomActions|Parent|Help|Title|Identifier)|isAccessibilityElement)\(\)"), lambda m: f"nsa_{m.group(1)}()"),
    (re.compile(r"override var isOpaque: Bool [{] (\w+) [}]"), lambda m: f"override var isOpaque: Bool {{ get {{ {m.group(1)} }} set {{}} }}"),
    (re.compile(r"let (\w+) = NSImage\(size: ([^\n]+)\)\s*\1[.]addRepresentation\((\w+)\)(?!\s*\1[.]alignmentRect)"), lambda m: f"let {m.group(1)} = NSImage(representation: {m.group(3)}, size: {m.group(2)})"),
    (re.compile(r"\bNSValue\(size:"), "NSValue(cgSize:"),
    (re.compile(r"\bNSValue\(point:"), "NSValue(cgPoint:"),
    (re.compile(r"playerLayer[.]autoresizingMask = \[.*?\]", re.S), "_ = ()"),
    (re.compile(r"[.]withSymbolicTraits\("), ".nsWithSymbolicTraits("),
    (re.compile(r"progressIndicator[.]style = "), "progressIndicator.nsStyle = "),
    (re.compile(r"[.]buttonStyle\([.]link\)"), ".buttonStyle(NSLinkButtonStyle())"),
    (re.compile(r"(_ control: )NSControl(, textView:)"), lambda m: f"{m.group(1)}UIControl{m.group(2)}"),
    (re.compile(r"NSTextContainer\(\s*containerSize:"), "NSTextContainer(size:"),
    (re.compile(r"(?<!Metrics)[.]containerSize\b"), ".size"),
    (re.compile(r"for: [.]windowToolbar"), "for: .navigationBar"),
    (re.compile(r"[.]gesture\(WindowDragGesture\(\)\)"), ""),
    (re.compile(r"let image = NSImage\(size: (NSSize\([^)]*\))\)\s*image[.]lockFocus\(\)"), lambda m: f"let image = NSImage(size: {m.group(1)}, flipped: true) {{ _ in"),
    (re.compile(r"image[.]unlockFocus\(\)"), "return true }"),
    (re.compile(r"image[.]size = (NSSize\([^)]*\))\s*return image"), lambda m: f"return image.ak_resized(to: {m.group(1)})"),
    (re.compile(r"\s*[.]windowResizeBehavior\([.]\w+\)"), ""),
    (re.compile(r"window[.]toolbarStyle = [.]\w+"), "_ = window"),
    (re.compile(r"private func centerWindow\(\) [{].*?\n        [}]\n", re.S), "private func centerWindow() {}\n"),
    (re.compile(r"_ = textSystemPrewarmer[.]textContentStorage"), "_ = textSystemPrewarmer.textStorage"),
    (re.compile(r"for: [.]window\)"), "for: .navigation)"),
    (re.compile(r"\bNSFont[.]systemFontSize"), "NSFont.macSystemFontSize"),
    (re.compile(r"\bNSFont[.]smallSystemFontSize"), "NSFont.macSmallSystemFontSize"),
    (re.compile(r"field[.]isEditable = (\w+)"), lambda m: f"field.isEnabled = {m.group(1)}"),
    (re.compile(r"keyWindow[?][.]screen[?][.]"), "keyWindow?.screen."),
    (re.compile(r"path[.]transform\(using: AffineTransform\(scaleByX: 1, byY: -1\)\)"), "path.apply(CGAffineTransform(scaleX: 1, y: -1))"),
    (re.compile(r"let rasterized = NSImage\(size: size\)\s*rasterized[.]addRepresentation\(representation\)\s*rasterized[.]alignmentRect = image[.]alignmentRect"), "let rasterized = NSImage(representation: representation, size: size)"),
    (re.compile(r"[.]pickerStyle\([.]radioGroup\)"), ".pickerStyle(.segmented)"),
    (re.compile(r"\s*[.]horizontalRadioGroupLayout\(\)"), ""),
    (re.compile(r"\s*[.]collapsible\(false\)"), ""),
    (re.compile(r'Image\("(discord|thread|github)", bundle: [.]module\)'), lambda m: f'Image("{m.group(1)}", bundle: .module).renderingMode(.template)'),
    (re.compile(r'Image\("gif[.]square", bundle: [.]module\)'), 'Image("gif_square", bundle: .module).renderingMode(.template)'),
    (re.compile(r"NSFont\.preferredFont\("), "NSFont.macPreferredFont("),
]


# UIView already has a `contentMode`; this view's own property means SwiftUI's.
FILE_RULES = {
    "NativeTimelineCanvasInteractions.swift": [
        (re.compile(r"guard let hit,\n(\s+)let reaction = hit[.]reaction,"), lambda m: f"guard isFrontmostAtPointer,\n{m.group(1)}let hit,\n{m.group(1)}let reaction = hit.reaction,"),
    ],
    # arrowEdge means the anchor's edge on macOS but the popover's edge on iOS, where
    # it is also strict: a popover forced toward a window edge collapses. Without it,
    # iPadOS picks a side that fits, as macOS does when the requested side has no room.
    "ServerTagCard.swift": [
        (re.compile(r"[.]popover\(isPresented: [$]isPresented, arrowEdge: [.]bottom\)"), ".popover(isPresented: $isPresented)"),
    ],
    "NativeMemberListViewBridge.swift": [
        (re.compile(r"width: max\(0, contentSize[.]width\)"), "width: max(0, nsContentSize.width)"),
    ],
    "StableAnchoredPopover.swift": [
        (re.compile(r"popover[.]contentViewController[?][.]view[.]window[?][.]ignoresMouseEvents =\s*configuration[.]ignoresMouseEvents"),
         "popover.contentViewController?.view.isUserInteractionEnabled = !configuration.ignoresMouseEvents"),
    ],
    "PopoverEscapeKeyCoordinator.swift": [
        (re.compile(r"arrowEdge: arrowEdge\n"), "arrowEdge: nil\n"),
        (re.compile(r"^( +)(content\((?:value)?\))\n( +)[.]background [{]", re.M),
         lambda m: f"{m.group(1)}{m.group(2)}\n{m.group(3)}.fixedSize()\n{m.group(3)}.presentationCompactAdaptation(.popover)\n{m.group(3)}.background {{"),
    ],
    "NativeMemberListCanvasView.swift": [
        (re.compile(r"override func draw\(_ dirtyRect: NSRect\) [{]"), "func drawCanvas(_ dirtyRect: NSRect) {"),
        (re.compile(r"(    override func updateTrackingAreas\(\) [{])"), lambda m: """    private lazy var viewportBacking: NSViewportBackingView = {
        let backing = NSViewportBackingView(frame: .zero)
        backing.drawContent = { [weak self] rect in self?.drawCanvas(rect) }
        return backing
    }()

    override func didMoveToWindow() {
        super.didMoveToWindow()
        viewportBacking.attach(to: self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        viewportBacking.reposition()
    }

    override func setNeedsDisplay() { viewportBacking.invalidate(nil) }
    override func setNeedsDisplay(_ rect: CGRect) { viewportBacking.invalidate(rect) }

""" + m.group(1)),
    ],
    "DiscordCaptchaPresentation.swift": [
        (re.compile(r'webView[.]setValue\(false, forKey: "drawsBackground"\)'), "webView.isOpaque = false; webView.backgroundColor = .clear; webView.scrollView.backgroundColor = .clear"),
    ],
    # iPadOS draws its sidebar toggle where macOS draws the server name; keep the
    # toggle at the sidebar's trailing edge, which is where macOS places it.
    "RootView.swift": [
        (re.compile(r"[.]navigationSplitViewColumnWidth\(\s*min: ChatChromeMetrics[.]serverRailWidth"),
         lambda m: ".toolbar(removing: .sidebarToggle)\n            .toolbar { ToolbarItem(placement: .topBarTrailing) { padSidebarToggle } }\n            " + m.group(0)),
        (re.compile(r"[.]toolbar [{]\s*detailToolbar\s*[}]"),
         ".toolbar {\n                detailToolbar\n                ToolbarItem(placement: .topBarLeading) { if columnVisibility == .detailOnly { padSidebarToggle } }\n                ToolbarItem(id: \"pad-search\") { PadToolbarSearchField(model: model) }\n                    .sharedBackgroundVisibility(PadToolbarSearch.shared.isVisible ? .visible : .hidden)\n            }"),
        (re.compile(r"\n +[.]modifier\(MessageSearchToolbarModifier\(\s*model: model,\s*search: search,\s*prompt: prompt\s*\)\)"), ""),
        # Below the real toolbar row: on iPadOS that row is inside the split view, not above the root.
        (re.compile(r"[.]padding\([.]trailing, toolbarMetrics[.]trailingInset\)"),
         ".onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { PadToolbarSearch.shared.autocompleteFrame = $0 }\n                    .padding(.trailing, toolbarMetrics.trailingInset)\n                    .padding(.top, toolbarMetrics.bottomInset)\n                    .ignoresSafeArea()"),
        # A background on a toolbar button is not dependably installed on iPadOS, so the
        # panels anchor from outside the toolbar, under their buttons.
        (re.compile(r"\s*[.]background [{]\s*StableAnchoredPopoverPresenter\(\s*isPresented: model[.](?:inbox|pinnedMessages)[.]isPresented,.*?[.]frame\(maxWidth: [.]infinity, maxHeight: [.]infinity\)\s*[}]", re.S), ""),
        (re.compile(r"([.]overlay\(alignment: [.]topLeading\) [{]\s*ZStack\(alignment: [.]topLeading\) [{]\s*SakuraCordTextInputAccentBridge)"),
         lambda m: ".overlay(alignment: .topTrailing) { padToolbarPanels }\n        " + m.group(1)),
        (re.compile(r"(    @ViewBuilder private var workspace: some View [{])"),
         lambda m: """    private var padSidebarToggle: some View {
        Button {
            NotificationCenter.default.post(name: .sakuracordToggleChannelSidebar, object: nil)
        } label: {
            Label("Toggle Sidebar", systemImage: "sidebar.leading")
        }
    }

    private var padToolbarPanels: some View {
        let searchEdge = toolbarSearchFieldMetrics.trailingInset + ChatChromeMetrics.toolbarSearchMaximumFieldWidth
        return ZStack(alignment: .topTrailing) {
            StableAnchoredPopoverPresenter(
                isPresented: !usesWorkspaceTitlebar && model.inbox.isPresented,
                configuration: .toolbarPanel,
                onDismiss: model.dismissInbox
            ) { InboxPopoverView(model: model) }
            .frame(width: 44, height: 1)
            .padding(.trailing, searchEdge + 105)

            StableAnchoredPopoverPresenter(
                isPresented: !usesWorkspaceTitlebar && model.pinnedMessages.isPresented,
                configuration: .toolbarPanel,
                onDismiss: model.dismissPinnedMessages
            ) { PinnedMessagesPopoverView(model: model) }
            .frame(width: 44, height: 1)
            .padding(.trailing, searchEdge + 57)
        }
        .padding(.top, toolbarSearchFieldMetrics.bottomInset)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

""" + m.group(1)),
    ],
    # The search field is a UITextField, which macOS's check would miss, sending typing to the composer.
    # Quick Look's macOS view does not exist on iPadOS; its controller is the equivalent.
    "MediaViewerFile.swift": [
        (re.compile(r"^import QuickLookUI$", re.M), "import QuickLook"),
        (re.compile(r"private struct MediaViewerQuickLook: NSViewRepresentable [{].*?\n[}]\n", re.S),
         """private struct MediaViewerQuickLook: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in _: QLPreviewController) -> Int { 1 }

        func previewController(_: QLPreviewController, previewItemAt _: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}
"""),
    ],
    "NativeTimelineModels.swift": [
        (re.compile(r"fullRate\(on screen: NSScreen[?]\)"), "fullRate(on screen: UIScreen?)"),
    ],
    # Window coordinates run downward here, and the toolbar is inside the split view.
    "ToolbarObscuredScrollerInset.swift": [
        (re.compile(r"frameInWindow[.]maxY - window[.]contentLayoutRect[.]maxY"), "UIWindow.ak_toolbarBottomY - frameInWindow.minY"),
        (re.compile(r"styleMask[.]contains\([.]fullSizeContentView\) && locationInWindow[.]y > contentLayoutRect[.]maxY"), "locationInWindow.y < UIWindow.ak_toolbarBottomY"),
    ],
    "NativeForumBoardView.swift": [
        (re.compile(r"\binteractions\b"), "boardInteractions"),
        (re.compile(r"frameInWindow[.]maxY - window[.]contentLayoutRect[.]maxY"), "UIWindow.ak_toolbarBottomY - frameInWindow.minY"),
    ],
    # A UIScrollView is its own clip view, and vertical-only content has no sideways drift to pin.
    "NativeMessageTimelineView.swift": [
        (re.compile(r"/// Keeps the timeline's horizontal scroll position at zero[.].*?final class NativeTimelineClipView: NSClipView [{].*?\n[}]\n", re.S), ""),
        (re.compile(r"\n *// The timeline only scrolls vertically, wherever it is placed[.]\n *scrollView[.]contentView = NativeTimelineClipView\(\)"), ""),
    ],
    "FileTypeIconCache.swift": [
        (re.compile(r"NSWorkspace[.]shared[.]icon\(for: type\)[.]draw\(in: (CGRect\(x: 0, y: 0, width: pixels, height: pixels\))\)"),
         lambda m: f"if let icon = AKFileTypeIcon.cgImage(for: type) {{ context.draw(icon, in: {m.group(1)}) }}"),
    ],
    "ForumBoardAccessibility.swift": [
        (re.compile(r"subviews = subviews[.]filter [{] !\([$]0 is ForumBoardAccessibilityProxyView\) [}] [+] ordered"), "for proxy in ordered { addSubview(proxy) }"),
    ],
    "ForumChannelView.swift": [
        (re.compile(r"geometry[.]containerSize"), "geometry.container__KEEPSize"),
    ],
    "NativeTimelineCodeCopyControl.swift": [
        (re.compile(r"guard let layer else [{] return [}]"), "guard let layer: CALayer = layer else { return }"),
    ],
    "NativeTimelineCanvasDictionaryLookup.swift": [
        (re.compile(r"override func pressureChange"), "func pressureChange"),
    ],
    "NativeTimelineCanvasView.swift": [
        (re.compile(r"\n *pressureConfiguration = NSPressureConfiguration\([^\n]*"), ""),
    ],
    # NSLayoutManager's storage is optional on both platforms, unlike UITextView's.
    "ComposerLayoutManager.swift": [
        (re.compile(r"\btextStorage\b"), "textStorage__KEEP"),
    ],
    "ForumPostPreviewText.swift": [
        (re.compile(r"let resolved = NSColor\(cgColor: color[.]cgColor\)"), "let resolved = Optional(NSColor(cgColor: color.cgColor))"),
    ],
    "ForumSearchField.swift": [
        (re.compile(r"\bcontrol[.]stringValue = "), "(control as? NSTextField)?.stringValue = "),
    ],
    "DiscordLaunchIcon.swift": [
        (re.compile(r"var transform = AffineTransform\(translationByX: frame[.]minX, byY: frame[.]minY\)\s*transform[.]scale\(scale\)"),
         "let transform = CGAffineTransform(translationX: frame.minX, y: frame.minY).scaledBy(x: scale, y: scale)"),
        (re.compile(r"shape[.]transform\(using: transform\)"), "shape.apply(transform)"),
    ],
    # UIKit's text tables use different edge names and cannot be subclassed to draw,
    # so code blocks and quotes take plain fills and borders in the document viewer.
    "MarkdownDocumentLayout.swift": [
        (re.compile(r"\btextStorage\b"), "textStorage__KEEP"),
        (re.compile(r"[.]absoluteValueType"), ".absolute"),
        (re.compile(r"[.]percentageValueType"), ".percentage"),
        (re.compile(r"[.]fixedLayoutAlgorithm"), ".fixed"),
        (re.compile(r", edge: [.](min|max)([XY])\)"), lambda m: f", rectEdge: .{m.group(1)}{m.group(2)}Edge)"),
        (re.compile(r", edge: edge\)"), ", rectEdge: edge)"),
        (re.compile(r"\[NSRectEdge[.]min([XY]), [.]max([XY])\]"), lambda m: f"[CGRectEdge.min{m.group(1)}Edge, .max{m.group(2)}Edge]"),
        (re.compile(r"setBorderColor\([.]separatorColor, for: [.]minY\)"), "setBorderColor(.separatorColor, rectEdge: .minYEdge)"),
        (re.compile(r"override func drawBackground\(\s*withFrame"), "func drawBackground(\n        withFrame"),
        (re.compile(r"(block[.]setWidth\(px\(8\) [+] 1, type: [.]absolute, for: [.]padding\))"),
         lambda m: m.group(1) + "\n        block.backgroundColor = NativeTimelineRowPainter.discordCodeBackgroundColor"),
        (re.compile(r"(block[.]setWidth\(px\(16\), type: [.]absolute, for: [.]padding, rectEdge: [.]minXEdge\))"),
         lambda m: m.group(1) + "\n        block.setWidth(px(4), type: .absolute, for: .border, rectEdge: .minXEdge)\n        block.setBorderColor(.tertiaryLabel, rectEdge: .minXEdge)"),
    ],
    "MarkdownDocumentText.swift": [
        (re.compile(r"textView[.]textStorage[.]flatMap"), "Optional(textView.textStorage).flatMap"),
        (re.compile(r"textView[.]scroll\(NSPoint\("), "textView.enclosingScrollView?.scroll(to: NSPoint("),
    ],
    "NativeTimelineCanvasLinkContextMenu.swift": [
        (re.compile(r"\n *icon[.]size = NSSize\(width: 16, height: 16\)"), ""),
    ],
    # UIView already has `interactions`.
    "ForumBoardPointerInput.swift": [
        (re.compile(r"\binteractions\b"), "boardInteractions"),
    ],
    "ForumBoardPresentation.swift": [
        (re.compile(r"\binteractions\b"), "boardInteractions"),
    ],
    # macOS hangs these from the window's titlebar; iPadOS has none to reach, so the
    # same items sit over the window's top edge, on the toolbar's row.
    "WorkspaceTitlebar.swift": [
        (re.compile(r"guard let titlebar = window[?][.]standardWindowButton\([.]closeButton\)[?][.]superview else [{].*?titlebar[.]addSubview\(overlay\)\n", re.S),
         "installOverlay()\n"),
        (re.compile(r"(        let overlay = WorkspaceTitlebarView\(\)\n)"),
         lambda m: m.group(1) + """
        func installOverlay() {
            guard let content = window?.contentView else {
                overlay.removeFromSuperview()
                return
            }
            if overlay.superview !== content { content.addSubview(overlay) }
            let frame = CGRect(x: 0, y: 0, width: content.bounds.width, height: UIWindow.ak_toolbarCenterY * 2)
            if overlay.frame != frame { overlay.frame = frame }
            overlay.autoresizingMask = [.width]
        }
"""),
        (re.compile(r"(        )anchor[.]overlay[.]apply\("), lambda m: f"{m.group(1)}anchor.installOverlay()\n{m.group(1)}anchor.overlay.apply("),
        (re.compile(r"\n *// The toolbar re-hosts its search field, in fresh glass, whenever.*?for name in \[NSToolbar[^\n]*[{].*?\n        [}]\n", re.S), "\n"),
        (re.compile(r"    @objc private func toolbarItemsDidChange\(.*?\n    [}]\n", re.S), ""),
        (re.compile(r"private var measuredLeadingControlsMaxX: CGFloat [{].*?\n    [}]\n", re.S),
         "private var measuredLeadingControlsMaxX: CGFloat { 120 }\n"),
        (re.compile(r"private var searchItemView: NSView[?] [{].*?\n    [}]\n", re.S), "private var searchItemView: NSView? { nil }\n"),
        (re.compile(r"private var searchFieldMinX: CGFloat[?] [{].*?\n    [}]\n", re.S),
         """private var searchFieldMinX: CGFloat? {
        let metrics = PadToolbarSearch.shared.metrics
        return PadToolbarSearch.shared.isVisible && metrics.isValid ? bounds.maxX - metrics.trailingInset - metrics.fieldWidth : nil
    }
"""),
        (re.compile(r"translatesAutoresizingMaskIntoConstraints = false"), "translatesAutoresizingMaskIntoConstraints = true"),
    ],
    "WindowModalOverlay.swift": [
        (re.compile(r"override func resize\(withOldSuperviewSize"), "func resize(withOldSuperviewSize"),
    ],
    # iPadOS has no static code API and no way to run a downloaded app.
    "PRBuildRecovery.swift": [
        (re.compile(r"\n *var code: SecStaticCode[?].*?signatureVerificationFailed\(validationStatus\)\n\s*[}]", re.S), ""),
    ],
    "WindowModalCoordinator.swift": [
        (re.compile(r"\(responder as[?] NSText\)[.]flatMap [{][^\n]*?[}] [?][?] "), ""),
    ],
    # These views are placed by frame; UIKit would otherwise leave them to Auto Layout.
    "WorkspaceColumnsHost.swift": [
        (re.compile(r"translatesAutoresizingMaskIntoConstraints = false"), "translatesAutoresizingMaskIntoConstraints = true"),
    ],
    "ComposerTextView.swift": [
        (re.compile(r"guard let textView = responder as[?] NSTextView else [{] return false [}]"),
         "guard let textView = responder as? NSTextView else { return responder is UITextField }"),
        (re.compile(r"private func readAttachments\(from pasteboard: NSPasteboard\) -> Bool [{].*?\n    [}]\n", re.S),
         """private func readAttachments(from _: NSPasteboard) -> Bool {
        guard receivesAttachments, let onReceiveAttachments else { return false }
        let providers = PadPasteboardAttachments.providers()
        guard !providers.isEmpty else { return false }
        PadPasteboardAttachments.receive(providers) { batch in
            if !onReceiveAttachments(.owned(batch), false) { batch.discard() }
        }
        return true
    }

    override func paste(_ sender: Any?) {
        if !readAttachments(from: .general) { super.paste(sender) }
    }
"""),
    ],
    "InterfaceScale.swift": [
        (re.compile(r"let isDefault = InterfaceScale[.]factor == 1 [|][|] isNested"), "let isDefault = isNested"),
        (re.compile(r"if !isDefault [{] size = InterfaceScale[.]controlSize\(size\) [}]"), "if !isDefault { size = InterfaceScale.controlSize(size == .regular ? .small : size) }"),
        (re.compile(r"guard InterfaceScale[.]factor != 1 else [{]\s*return [.]system\(style, design: design, weight: weight\)\s*[}]\s*"), ""),
    ],
    "ChatChromeMetrics.swift": [
        (re.compile(r"static let sidebarTitleCenterY: CGFloat = 25"), "static var sidebarTitleCenterY: CGFloat { UIWindow.ak_toolbarCenterY }"),
    ],
    "SakuraCordSignInExperience.swift": [
        (re.compile(r"Rectangle\(\)\s*[.]fill\(colorScheme == [.]dark [?] Color\(hex: 0x101018\) : Color\(hex: 0xF6F5FA\)\)\s*[.]colorEffect\(ShaderLibrary[.]bundle\([.]module\)[.]sakuraSignInLight\(.*?\)\)\n", re.S),
         """MetalShaderSurface(
                function: "sakuraSignInLight",
                elapsed: elapsed,
                colors: [colors[0], colors[colors.count / 2], colors[colors.count - 1]],
                scalar: colorScheme == .dark ? 1 : 0,
                base: colorScheme == .dark ? Color(hex: 0x101018) : Color(hex: 0xF6F5FA)
            )
"""),
    ],
    "SakuraCordAuthenticationComponents.swift": [
        (re.compile(r"Rectangle\(\)\s*[.]fill\([.]white\)\s*[.]colorEffect\(ShaderLibrary[.]bundle\([.]module\)[.]sakuraAuthenticationLoading\(.*?\)\)\n", re.S),
         """MetalShaderSurface(
                            function: "sakuraAuthenticationLoading",
                            elapsed: elapsed,
                            colors: [colors[0], colors[colors.count - 1]],
                            scalar: intensity
                        )
"""),
    ],
    "SakuraCordWelcomeMetalView.swift": [
        (re.compile(r"try device[.]makeDefaultLibrary\(bundle: [.]module\)"), "try device.makeLibrary(source: SakuraMetalSources.welcomePetals, options: nil)"),
    ],
    "SettingsSidebar.swift": [
        (re.compile(r"List\(selection: [$]selection\) [{]"), "List(selection: Binding<SettingsPageID?>(get: { selection }, set: { if let value = $0 { selection = value } })) {"),
    ],
    "ProfileRichTextView.swift": [
        (re.compile(r"(?<![\w.])tracking\b|(?<=self[.])tracking\b"), "ownTrackingArea"),
    ],
    "NativeTimelineSendTransition.swift": [
        (re.compile(r"((?:[lL]ayer|Canvas[.]layer)[?]?[.]contents = )(?!nil)([^\n]+)"), lambda m: f"{m.group(1)}nsLayerContents({m.group(2)})"),
        (re.compile(r"let root = CALayer\(\)"), "let root = layer"),
        (re.compile(r"^\s*layer = root\n", re.M), ""),
    ],
    "NativeTimelineReactionTransition.swift": [
        (re.compile(r"^\s*layer = CALayer\(\)\n", re.M), ""),
    ],
    "NativeTimelineTextSpoilerGeometry.swift": [
        (re.compile(r"= view[.](textStorage|layoutManager|textContainer)(?=[, ])"), lambda m: f"= Optional(view.{m.group(1)})"),
    ],
    "SelectableMessageTextView.swift": [
        (re.compile(r"[$]0[.]rangeValue"), "$0"),
        (re.compile(r"textContainer[?][.](maximumNumberOfLines|lineBreakMode)"), lambda m: f"textContainer__KEEP?.{m.group(1)}"),
    ],
    "EmojiPickerView.swift": [
        (re.compile(r"(focusRequestIsScheduled = true\s*)Task [{] @MainActor \[weak self\] in"), lambda m: f"{m.group(1)}Task<Void, Never> {{ @MainActor [weak self] in"),
    ],
    "GIFPickerNativeGrid.swift": [
        (re.compile(r"max\(contentSize[.](width|height), layoutSize"), lambda m: f"max(nsContentSize.{m.group(1)}, layoutSize"),
        (re.compile(r"((?:[lL]ayer|Canvas[.]layer)[?]?[.]contents = )(?!nil)([^\n]+)"), lambda m: f"{m.group(1)}nsLayerContents({m.group(2)})"),
    ],
    "AnimatedRemoteImage.swift": [
        (re.compile(r"((?:[lL]ayer|Canvas[.]layer)[?]?[.]contents = )(?!nil)([^\n]+)"), lambda m: f"{m.group(1)}nsLayerContents({m.group(2)})"),
        (re.compile(r"var contentMode: ContentMode = [.]fit [{]"), "var nsContentMode: ContentMode = .fit {"),
        (re.compile(r"view[.]contentMode = contentMode"), "view.nsContentMode = contentMode"),
        (re.compile(r"^( +)contentMode == [.]fill [?]", re.M), lambda m: f"{m.group(1)}nsContentMode == .fill ?"),
    ],
}


def transform(text: str, name: str = "") -> str:
    text = REMOVED_IMPORTS.sub("", text.replace("\r\n", "\n"))
    for pattern, replacement in FILE_RULES.get(name, []):
        text = pattern.sub(replacement, text)
    for pattern, replacement in RULES:
        text = pattern.sub(replacement, text)
    text = text.replace("__KEEP", "")
    # SwiftUI re-exports AppKit on macOS, so files may rely on it implicitly.
    return "import AppKitShim\n" + text


def write_if_changed(path: pathlib.Path, text: str) -> None:
    if not path.exists() or path.read_text() != text:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)


def write_metal_sources(expected: set) -> None:
    sources = {
        "signInLight": MAC / "Resources/SignInLight.metal",
        "welcomePetals": MAC / "Resources/WelcomePetals.metal",
    }
    body = "".join(
        f'    static let {name} = #"""\n{path.read_text().replace(chr(13), "")}\n"""#\n'
        for name, path in sources.items()
    )
    relative = pathlib.Path("MetalSources.swift")
    expected.add(relative)
    write_if_changed(OUT / relative, f"enum SakuraMetalSources {{\n{body}}}\n")


def main() -> None:
    expected = set()
    write_metal_sources(expected)
    for folder in FOLDERS:
        for source in sorted((MAC / folder).rglob("*.swift")):
            relative = source.relative_to(MAC)
            override = OVERRIDES / relative
            expected.add(relative)
            text = override.read_text().replace("import AppKit\n", "import AppKitShim\n") if override.exists() else transform(source.read_text(), source.name)
            write_if_changed(OUT / relative, text)
    for stale in OUT.rglob("*.swift"):
        if stale.relative_to(OUT) not in expected:
            stale.unlink()


if __name__ == "__main__":
    main()
