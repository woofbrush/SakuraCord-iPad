import Observation
import SakuraCordModels
import SwiftUI

/// Navigation state for one iPad window. Every window shares the account in
/// `PadSession` but browses it independently, as on macOS.
@Observable
final class PadWorkspace {
    /// `nil` is the Direct Messages home.
    var selectedGuildID: GuildID?
    var selectedChannelID: ChannelID?
    var columnVisibility: NavigationSplitViewVisibility = .all
    var isQuickSwitcherPresented = false
    var replyingTo: Message?
    var editing: Message?
    /// Incremented to move keyboard focus into the composer.
    private(set) var composerFocusRequest = 0

    private var lastChannelByGuild: [GuildID?: ChannelID] = [:]
    private var lastGuildID: GuildID?
    private var back: [ChannelID] = []
    private var forward: [ChannelID] = []
    private var previousTextChannel: ChannelID?

    let session: PadSession

    init(session: PadSession) {
        self.session = session
    }

    var selectedChannel: Channel? {
        selectedChannelID.flatMap { session.channels[$0] }
    }

    // MARK: Selection

    func selectGuild(_ guildID: GuildID?) {
        if let current = selectedGuildID { lastGuildID = current }
        selectedGuildID = guildID
        let remembered = lastChannelByGuild[guildID].flatMap { session.channels[$0] }
        open(remembered?.id ?? session.conversations(in: guildID).first?.id, recordsHistory: true)
    }

    func open(_ channelID: ChannelID?, recordsHistory: Bool = true) {
        guard channelID != selectedChannelID else { return }
        if recordsHistory, let current = selectedChannelID {
            back.append(current)
            forward.removeAll()
            previousTextChannel = current
        }
        replyingTo = nil
        editing = nil
        selectedChannelID = channelID
        if let channelID, let channel = session.channels[channelID] {
            selectedGuildID = channel.guildID
            lastChannelByGuild[channel.guildID] = channelID
        }
        focusComposer()
    }

    func focusComposer() {
        composerFocusRequest &+= 1
    }

    // MARK: Keyboard and menu commands

    func navigateBack() {
        guard let target = back.popLast() else { return }
        if let current = selectedChannelID { forward.append(current) }
        open(target, recordsHistory: false)
    }

    func navigateForward() {
        guard let target = forward.popLast() else { return }
        if let current = selectedChannelID { back.append(current) }
        open(target, recordsHistory: false)
    }

    func returnToPreviousTextChannel() {
        open(previousTextChannel)
    }

    func stepConversation(by offset: Int, unreadOnly: Bool = false) {
        let list = session.conversations(in: selectedGuildID)
        guard !list.isEmpty else { return }
        let start = list.firstIndex { $0.id == selectedChannelID } ?? (offset > 0 ? -1 : list.count)
        var index = start
        for _ in list.indices {
            index = (index + offset + list.count) % list.count
            if !unreadOnly || session.isUnread(list[index]) {
                open(list[index].id)
                return
            }
        }
    }

    /// Cycles the rail, treating Direct Messages as its first entry.
    func stepServer(by offset: Int) {
        let rail: [GuildID?] = [nil] + session.guilds.map(\.id)
        let current = rail.firstIndex(of: selectedGuildID) ?? 0
        selectGuild(rail[(current + offset + rail.count) % rail.count])
    }

    func toggleDirectMessages() {
        selectGuild(selectedGuildID == nil ? (lastGuildID ?? session.guilds.first?.id) : nil)
    }

    /// Command-1 is Direct Messages and Command-2 through 9 the first servers.
    func navigate(toShortcut number: Int) {
        if number == 1 {
            selectGuild(nil)
        } else if session.guilds.indices.contains(number - 2) {
            selectGuild(session.guilds[number - 2].id)
        }
    }

    func toggleSidebar() {
        withAnimation {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
    }

    func markServerRead() {
        session.markGuildRead(selectedGuildID)
    }

    func replyToLatest() {
        guard let channelID = selectedChannelID else { return }
        replyingTo = session.timelines[channelID]?.messages.last
        focusComposer()
    }

    /// Up Arrow in an empty composer edits the newest message you sent.
    func editLatestOwnMessage() -> Bool {
        guard let channelID = selectedChannelID, let userID = session.currentUser?.id,
              let message = session.timelines[channelID]?.messages.last(where: { $0.author.id == userID })
        else { return false }
        editing = message
        replyingTo = nil
        focusComposer()
        return true
    }
}

extension FocusedValues {
    @Entry var padWorkspace: PadWorkspace?
}
