/// macOS can focus the toolbar search field by itself; the iPad field takes focus only from the reader.
@MainActor
final class AutomaticSearchFocusGuard {
    private(set) var isArmed = false
    var focusFollowsReaderInput: Bool { true }

    func arm() { isArmed = true }
    func disarm() { isArmed = false }
    func releaseToolbarSearchFieldFocus() {}
}
