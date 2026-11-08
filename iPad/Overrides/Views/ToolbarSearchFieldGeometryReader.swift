import AppKit
import SakuraCordModels
import SwiftUI

// macOS reads NSToolbar's search item to size the results panel. iPadOS has no
// NSToolbar; SwiftUI's `.searchable` owns the field, so only its metrics remain.

struct ToolbarSearchFieldLoadingStyler: View {
    let isActive: Bool

    var body: some View { EmptyView() }
}

struct ToolbarSearchFieldMetrics: Equatable {
    static let zero = ToolbarSearchFieldMetrics(fieldWidth: 0, trailingInset: 0)

    let fieldWidth: CGFloat
    let trailingInset: CGFloat

    var isValid: Bool {
        fieldWidth.isFinite
            && trailingInset.isFinite
            && fieldWidth > 0
            && trailingInset >= 0
    }
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
            .onChange(of: preferredFieldWidth, initial: true) { _, width in
                changed(ToolbarSearchFieldMetrics(fieldWidth: width, trailingInset: 16))
            }
    }
}
