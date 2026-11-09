import Observation
import SakuraCordModels
import SwiftUI

/// What a window too small for the macOS layout gives up. macOS holds its windows
/// to a minimum size; an iPadOS window can be as narrow as a phone.
@Observable
final class PadLayout {
    static let shared = PadLayout()

    /// Whether the search field waits as a button until it is used.
    var collapsesSearch = false
    /// The field's width while in use in a collapsing window.
    var expandedSearchWidth = ChatChromeMetrics.toolbarSearchMaximumFieldWidth

    @ObservationIgnored private var wasNarrow: Bool?
    @ObservationIgnored private var closedMemberList = false

    /// A workspace with too little room for the member list beside its conversation.
    static func isNarrow(_ width: CGFloat) -> Bool {
        width < ChatChromeMetrics.memberListWidth + InterfaceScale.metric(360)
    }

    /// Closes the member list as the window becomes too narrow and brings it back as
    /// the window widens. Opening it while narrow stays the reader's choice.
    func detailWidthChanged(_ width: CGFloat, model: AppModel) {
        guard width > 0 else { return }
        let collapses = width < ChatChromeMetrics.memberListWidth + InterfaceScale.metric(340)
        if collapsesSearch != collapses { collapsesSearch = collapses }
        let expanded = min(ChatChromeMetrics.toolbarSearchMaximumFieldWidth, max(160, width - 140))
        if expandedSearchWidth != expanded { expandedSearchWidth = expanded }

        let narrow = Self.isNarrow(width)
        guard narrow != wasNarrow else { return }
        wasNarrow = narrow
        let pane = model.workspacePresentation.supplementaryPane
        if narrow {
            if pane == .memberInspector {
                closedMemberList = true
                model.toggleMemberInspector()
            }
        } else {
            if closedMemberList, pane == nil { model.toggleMemberInspector() }
            closedMemberList = false
        }
    }
}

/// In a compact window the split view shows one column: opening a conversation goes
/// to it, while changing servers stays on the channel list to choose from.
struct PadCompactColumnFollower: ViewModifier {
    let model: AppModel
    @Binding var column: NavigationSplitViewColumn
    @State private var guildID: GuildID?

    func body(content: Content) -> some View {
        content
            .onAppear { guildID = model.selectedGuildID }
            .onChange(of: model.selectedChannelID) { _, channelID in
                let sameGuild = guildID == model.selectedGuildID
                guildID = model.selectedGuildID
                if sameGuild, channelID != nil { column = .detail }
            }
    }
}
