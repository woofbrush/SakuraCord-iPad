import AppKit
import SakuraCordModels
import SwiftUI

// macOS reads NSToolbar's search item. On iPadOS `.searchable` treats losing focus as
// ending the search and erases the text, so a plain toolbar field keeps the macOS
// meaning: focus only decides whether suggestions are showing.

struct ToolbarSearchFieldLoadingStyler: View {
    let isActive: Bool

    var body: some View { EmptyView() }
}

struct ToolbarSearchFieldMetrics: Equatable {
    static let zero = ToolbarSearchFieldMetrics(fieldWidth: 0, trailingInset: 0)

    let fieldWidth: CGFloat
    let trailingInset: CGFloat
    var bottomInset: CGFloat = 0
    var toolbarCenterY: CGFloat = 0

    var isValid: Bool {
        fieldWidth.isFinite
            && trailingInset.isFinite
            && fieldWidth > 0
            && trailingInset >= 0
    }
}

@Observable
final class PadToolbarSearch {
    static let shared = PadToolbarSearch()

    var isVisible = false
    /// Fades as a thread pane moves over the field.
    var alpha: CGFloat = 1
    var metrics = ToolbarSearchFieldMetrics.zero
    @ObservationIgnored var autocompleteFrame = CGRect.null
}

struct ToolbarSearchFieldGeometryReader: View {
    @Binding var searchText: String
    @Binding var searchTokens: [MessageSearchToken]
    @Binding var isSearchFocused: Bool
    let isToolbarItemVisible: Bool
    let preferredFieldWidth: CGFloat
    let didUseBuiltInClear: @MainActor () -> Void
    let didEndEditing: @MainActor () -> Void
    let pasteCanonicalSyntax: @MainActor (String) -> MessageSearchTokenParser.Result
    let changed: @MainActor (ToolbarSearchFieldMetrics) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: isToolbarItemVisible, initial: true) { _, isVisible in
                PadToolbarSearch.shared.isVisible = isVisible
            }
            .onChange(of: PadToolbarSearch.shared.metrics) { _, metrics in
                changed(metrics)
            }
    }
}

/// macOS gives hosted content a safe area under its titlebar; here the toolbar is
/// part of the split view, which these separately hosted columns know nothing of.
struct PadToolbarSafeArea<Content: View>: View {
    let content: Content

    var body: some View {
        _ = PadToolbarSearch.shared.metrics
        return content
            .safeAreaPadding(.top, UIWindow.ak_toolbarBottomY)
            .ignoresSafeArea(.container, edges: .top)
    }
}

/// Stays in the toolbar while search is hidden, because it also measures the toolbar
/// row that the sidebar title lines up with.
struct PadToolbarSearchField: View {
    let model: AppModel
    @FocusState private var isFocused: Bool

    var body: some View {
        if PadToolbarSearch.shared.isVisible {
            field
        } else {
            Color.clear
                .frame(width: 1, height: 1)
                .background { PadSearchFieldAnchor(isFocused: false, endEditing: {}, deleteLastToken: { false }) }
        }
    }

    private var field: some View {
        @Bindable var model = model
        @Bindable var search = model.messageSearch
        @Bindable var onboarding = model.onboarding
        @Bindable var friends = model.friends
        let friendsSearch = model.isFriendsSearchActive
        let local = friendsSearch || model.isBrowsingGuildChannels
        let tokens = local ? [] : search.tokens
        let text = friendsSearch ? model.friendsSearchText : local ? onboarding.channelSearch : search.queryText
        let wantsFocus = friendsSearch ? friends.isSearchFocused
            : local ? onboarding.isChannelSearchFocused : search.isInputFocused
        let layout = PadLayout.shared
        let isCollapsed = layout.collapsesSearch && !isFocused && text.isEmpty && tokens.isEmpty
        return HStack(spacing: isCollapsed ? 0 : 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
            ForEach(tokens.suffix(2)) { chip($0) }
            TextField(
                "",
                text: friendsSearch ? $model.friendsSearchText
                    : local ? $onboarding.channelSearch : $model.messageSearchInputText,
                prompt: Text(model.isBrowsingGuildChannels ? "Search Channels" : model.messageSearchPromptTitle)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 17))
            .frame(width: isCollapsed ? 0 : nil)
            .opacity(isCollapsed ? 0 : 1)
            .focused($isFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit {
                if !local { model.submitMessageSearchInput() }
            }
            if !text.isEmpty || !tokens.isEmpty {
                Button {
                    if friendsSearch {
                        model.friendsSearchText = ""
                    } else if local {
                        onboarding.channelSearch = ""
                    } else {
                        model.clearMessageSearchUsingBuiltInButton()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, isCollapsed ? 0 : 12)
        .frame(
            width: isCollapsed ? 44
                : layout.collapsesSearch ? layout.expandedSearchWidth : ChatChromeMetrics.toolbarSearchMaximumFieldWidth,
            height: 44
        )
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
        .opacity(PadToolbarSearch.shared.alpha)
        .allowsHitTesting(PadToolbarSearch.shared.alpha > 0.01)
        .background {
            PadSearchFieldAnchor(
                isFocused: isFocused,
                endEditing: { isFocused = false },
                deleteLastToken: {
                    guard !local, search.queryText.isEmpty, !search.tokens.isEmpty else { return false }
                    search.tokens.removeLast()
                    return true
                }
            )
        }
        .onChange(of: wantsFocus, initial: true) { _, wanted in
            if isFocused != wanted { isFocused = wanted }
        }
        .onChange(of: isFocused) { _, focused in
            if friendsSearch {
                friends.isSearchFocused = focused
            } else if local {
                onboarding.isChannelSearchFocused = focused
            } else if focused {
                search.isInputFocused = true
            } else {
                model.messageSearchEditingDidEnd()
            }
        }
    }

    private func chip(_ token: MessageSearchToken) -> some View {
        Button {
            model.messageSearch.tokens.removeAll { $0 == token }
        } label: {
            Text(token.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 80)
    }
}

/// Reports the field's place in the window, and supplies what the macOS field editor
/// does on its own: clicking elsewhere ends editing, Backspace removes a token.
private struct PadSearchFieldAnchor: NSViewRepresentable {
    let isFocused: Bool
    let endEditing: () -> Void
    let deleteLastToken: () -> Bool

    func makeNSView(context: Context) -> AnchorView { AnchorView() }

    func updateNSView(_ view: AnchorView, context: Context) {
        view.endEditing = endEditing
        view.deleteLastToken = deleteLastToken
        view.fieldIsFocused = isFocused
        view.scheduleReport()
    }

    static func dismantleNSView(_ view: AnchorView, coordinator: ()) {
        view.stopObserving()
    }

    final class AnchorView: NSView {
        var endEditing: () -> Void = {}
        var deleteLastToken: () -> Bool = { false }
        var fieldIsFocused = false {
            didSet { if fieldIsFocused != oldValue { synchronizeMonitors() } }
        }
        private var mouseMonitor: Any?
        private var keyMonitor: Any?
        private var chromeObserver: NSObjectProtocol?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func layout() {
            super.layout()
            scheduleReport()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            synchronizeMonitors()
            scheduleReport()
            guard chromeObserver == nil else { return }
            // Entering or leaving full screen moves the toolbar without resizing this view.
            chromeObserver = NotificationCenter.default.addObserver(
                forName: UIWindow.ak_safeAreaDidChange, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.report() }
                }
            }
        }

        func scheduleReport() {
            DispatchQueue.main.async { [weak self] in self?.report() }
        }

        func stopObserving() {
            removeMonitors()
            if let chromeObserver { NotificationCenter.default.removeObserver(chromeObserver) }
            chromeObserver = nil
        }

        private func report() {
            guard let window, !bounds.isEmpty else { return }
            let frame = convert(bounds, to: nil)
            UIWindow.ak_toolbarCenterY = frame.midY
            UIWindow.ak_toolbarBottomY = frame.midY + 25
            let metrics = ToolbarSearchFieldMetrics(
                fieldWidth: frame.width,
                trailingInset: max(0, window.bounds.maxX - frame.maxX),
                bottomInset: frame.maxY,
                toolbarCenterY: frame.midY
            )
            if PadToolbarSearch.shared.metrics != metrics {
                PadToolbarSearch.shared.metrics = metrics
            }
        }

        private func removeMonitors() {
            if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            mouseMonitor = nil
            keyMonitor = nil
        }

        private func synchronizeMonitors() {
            removeMonitors()
            guard fieldIsFocused, window != nil else { return }
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self else { return event }
                if !bounds.contains(convert(event.locationInWindow, from: nil)),
                   !PadToolbarSearch.shared.autocompleteFrame.contains(event.locationInWindow)
                {
                    endEditing()
                }
                return event
            }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                event.keyCode == 51 && self?.deleteLastToken() == true ? nil : event
            }
        }
    }
}
