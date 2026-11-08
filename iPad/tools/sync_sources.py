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
    (re.compile(r"\[[.]withSecurityScope[^\]]*\]"), "[]"),
    (re.compile(rf"\b({NON_OPTIONAL})\?(?=[.\[])"), r"\1"),
    (re.compile(r"\.selectedRange\(\)"), ".nsSelectedRange()"),
    (re.compile(r"\.nextResponder"), ".next"),
    (re.compile(r"(?<![A-Za-z_.])(textContainerInset)(?![A-Za-z_])"), "nsTextContainerInset"),
    (re.compile(r"[.]textContainerInset(?![A-Za-z_])"), ".nsTextContainerInset"),
    (re.compile(r"(?<![A-Za-z_])((?:[a-zA-Z]*[tT]extView|[a-zA-Z]*[Ff]ield|search)[?]?)[.]delegate(?![A-Za-z_])"), lambda m: m.group(1) + ".nsDelegate"),
    (re.compile(r"\[[.]withSecurityScope\]"), "[]"),
    (re.compile(r"(bookmarkData[(]\s*options: )[.]withSecurityScope"), lambda m: m.group(1) + "[]"),
    (re.compile(r"[.]withSecurityScope"), ".withoutUI"),
    (re.compile(r"((?:guard|if|,)\s+let )(textStorage|layoutManager|textContainer|layer)(?=\s*(?:,|else\b|\{))"), lambda m: f"{m.group(1)}{m.group(2)} = Optional({m.group(2)})"),
    (re.compile(r"((?:guard|if|,)\s+let \w+ = )(\w*[tT]extView\.(?:textStorage|layoutManager|textContainer))(?=\s*(?:,|else\b|\{|$))", re.M), lambda m: f"{m.group(1)}Optional({m.group(2)})"),
    (re.compile(r"override (func (?:draggingEntered|draggingUpdated|draggingExited|draggingEnded|prepareForDragOperation|performDragOperation|concludeDragOperation)\()"), lambda m: m.group(1)),
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
    (re.compile(r"let image = NSImage\(size: ([^\n]+)\)\s*image[.]addRepresentation\(representation\)"), lambda m: f"let image = NSImage(representation: representation, size: {m.group(1)})"),
    (re.compile(r"playerLayer[.]autoresizingMask = \[.*?\]", re.S), "_ = ()"),
    (re.compile(r"[.]withSymbolicTraits\("), ".nsWithSymbolicTraits("),
    (re.compile(r"progressIndicator[.]style = "), "progressIndicator.nsStyle = "),
    (re.compile(r"[.]buttonStyle\([.]link\)"), ".buttonStyle(NSLinkButtonStyle())"),
    (re.compile(r"(_ control: )NSControl(, textView:)"), lambda m: f"{m.group(1)}UIControl{m.group(2)}"),
    (re.compile(r"NSTextContainer\(\s*containerSize:"), "NSTextContainer(size:"),
    (re.compile(r"[.]containerSize\b"), ".size"),
    (re.compile(r"for: [.]windowToolbar"), "for: .navigationBar"),
    (re.compile(r"[.]gesture\(WindowDragGesture\(\)\)"), ""),
    (re.compile(r"[.]applying\([.]init\(paletteColors:"), ".applying(UIImage.SymbolConfiguration(paletteColors:"),
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
    (re.compile(r"NSFont\.preferredFont\("), "NSFont.macPreferredFont("),
]


# UIView already has a `contentMode`; this view's own property means SwiftUI's.
FILE_RULES = {
    "SettingsSidebar.swift": [
        (re.compile(r"List\(selection: [$]selection\) [{]"), "List(selection: Binding<SettingsPageID?>(get: { selection }, set: { if let value = $0 { selection = value } })) {"),
    ],
    "ProfileRichTextView.swift": [
        (re.compile(r"(?<![\w.])tracking\b|(?<=self[.])tracking\b"), "ownTrackingArea"),
    ],
    "NativeTimelineSendTransition.swift": [
        (re.compile(r"let root = CALayer\(\)"), "let root = layer"),
        (re.compile(r"^\s*layer = root\n", re.M), ""),
    ],
    "NativeTimelineReactionInteraction.swift": [
        (re.compile(r"(?<![\w])display\("), "setNeedsDisplay("),
    ],
    "NativeTimelineTextSpoilerGeometry.swift": [
        (re.compile(r"= view[.](textStorage|layoutManager|textContainer)(?=[, ])"), lambda m: f"= Optional(view.{m.group(1)})"),
    ],
    "SelectableMessageTextView.swift": [
        (re.compile(r"textContainer[?][.](maximumNumberOfLines|lineBreakMode)"), lambda m: f"textContainer__KEEP?.{m.group(1)}"),
    ],
    "EmojiPickerView.swift": [
        (re.compile(r"(focusRequestIsScheduled = true\s*)Task [{] @MainActor \[weak self\] in"), lambda m: f"{m.group(1)}Task<Void, Never> {{ @MainActor [weak self] in"),
    ],
    "AnimatedRemoteImage.swift": [
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
    return "import AppKit\n" + text


def write_if_changed(path: pathlib.Path, text: str) -> None:
    if not path.exists() or path.read_text() != text:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)


def main() -> None:
    expected = set()
    for folder in FOLDERS:
        for source in sorted((MAC / folder).rglob("*.swift")):
            relative = source.relative_to(MAC)
            override = OVERRIDES / relative
            expected.add(relative)
            text = override.read_text() if override.exists() else transform(source.read_text(), source.name)
            write_if_changed(OUT / relative, text)
    for stale in OUT.rglob("*.swift"):
        if stale.relative_to(OUT) not in expected:
            stale.unlink()


if __name__ == "__main__":
    main()
