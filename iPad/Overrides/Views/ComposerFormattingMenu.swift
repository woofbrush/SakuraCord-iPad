import AppKit

extension ComposerNSTextView {
    // Rich-text edits must never become a second document format.
    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard replacementString != nil else { return false }
        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }
}
