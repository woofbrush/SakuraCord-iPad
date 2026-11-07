import DiscordProtocol
import Foundation
import Observation
import SakuraCordModels

/// One signed-in Discord account shared by every iPad window. Windows keep
/// their own navigation in `PadWorkspace`; this owns the provider, the Gateway
/// projection and per-channel timelines.
@Observable
final class PadSession {
    enum Phase: Equatable {
        case restoring, signedOut, connecting, ready
    }

    struct Timeline {
        var messages: [Message] = []
        var pending: [PendingSend] = []
        var hasMoreBefore = true
        var isLoading = false
        var didLoad = false
    }

    struct PendingSend: Identifiable, Equatable {
        let nonce: String
        var content: String
        var failed = false
        var id: String { nonce }
    }

    private(set) var phase: Phase = .restoring
    private(set) var connection: ConnectionState = .disconnected
    var errorMessage: String?
    private(set) var currentUser: User?
    private(set) var guilds: [Guild] = []
    private(set) var channels: [ChannelID: Channel] = [:]
    private var channelOrder: [GuildID?: [ChannelID]] = [:]
    private(set) var readStates: [ChannelID: ChannelReadState] = [:]
    private(set) var timelines: [ChannelID: Timeline] = [:]
    private(set) var typing: [ChannelID: [UserID: TypingEntry]] = [:]
    private(set) var hasSavedAccount = false

    struct TypingEntry: Equatable {
        let user: User
        let expires: Date
    }

    let authenticator = DiscordSessionAuthenticator()
    private let credentials = KeychainCredentialStore()
    private var provider: (any ChatProvider)?
    private var eventTask: Task<Void, Never>?
    private var acknowledgementToken: String?
    private var lastTypingSent: [ChannelID: Date] = [:]
    private static let accountKey = "dev.sakuracord.pad.account"

    // MARK: Account lifetime

    func restore() async {
        guard phase == .restoring || phase == .signedOut else { return }
        let handles = (try? await credentials.handles()) ?? []
        hasSavedAccount = !handles.isEmpty
        let preferred = UserDefaults.standard.string(forKey: Self.accountKey)
        guard let handle = handles.first(where: { $0.accountID == preferred }) ?? handles.first else {
            phase = .signedOut
            return
        }
        phase = .connecting
        let installationID = await UserDefaultsDiscordFingerprintStore.shared.loadInstallationID()
        let provider = DiscordRESTProvider(credentials: credentials, handle: handle, installationID: installationID)
        do {
            try await start(provider) { try await provider.bootstrap() }
        } catch {
            await provider.disconnect()
            fail(error)
        }
    }

    func connect(_ credential: PendingDiscordCredential) async {
        phase = .connecting
        let installationID = await UserDefaultsDiscordFingerprintStore.shared.loadInstallationID()
        let provider = DiscordRESTProvider(pendingCredential: credential, installationID: installationID)
        do {
            try await provider.prepareAuthentication()
            try await start(provider) {
                let snapshot = try await provider.bootstrap()
                // Discord's READY.user is authoritative; only then is the token kept.
                let handle = try await provider.persistPendingCredential(
                    to: credentials, accountID: snapshot.currentUser.id.description
                )
                UserDefaults.standard.set(handle.accountID, forKey: Self.accountKey)
                return snapshot
            }
        } catch {
            await provider.discardPendingCredential()
            await provider.disconnect()
            fail(error)
        }
    }

    func signOut() async {
        if let accountID = currentUser?.id.description {
            try? await credentials.remove(CredentialHandle(accountID: accountID))
        }
        UserDefaults.standard.removeObject(forKey: Self.accountKey)
        await tearDown()
        hasSavedAccount = false
        phase = .signedOut
    }

    private func start(
        _ provider: any ChatProvider,
        bootstrap: () async throws -> BootstrapSnapshot
    ) async throws {
        // Subscribe before bootstrap so no dispatch between READY and the
        // first projection is lost.
        let stream = await provider.eventStream()
        let snapshot = try await bootstrap()
        self.provider = provider
        apply(snapshot)
        hasSavedAccount = true
        phase = .ready
        eventTask = Task { [weak self] in
            for await event in stream {
                self?.handle(event)
            }
        }
    }

    private func fail(_ error: any Error) {
        errorMessage = error.localizedDescription
        phase = .signedOut
    }

    private func tearDown() async {
        eventTask?.cancel()
        eventTask = nil
        await provider?.disconnect()
        provider = nil
        currentUser = nil
        guilds = []
        channels = [:]
        channelOrder = [:]
        readStates = [:]
        timelines = [:]
        typing = [:]
        acknowledgementToken = nil
    }

    func setActive(_ isActive: Bool) {
        guard let provider else { return }
        Task { await provider.updateClientAppState(isFocused: isActive) }
    }

    // MARK: Projection

    private func apply(_ snapshot: BootstrapSnapshot) {
        currentUser = snapshot.currentUser
        guilds = Self.railOrder(snapshot.guilds, snapshot.guildRailItems)
        channels = Dictionary(snapshot.channels.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
        rebuildChannelOrder()
        readStates = Dictionary(snapshot.readStates.map { ($0.channelID, $0) }, uniquingKeysWith: { $1 })
    }

    private static func railOrder(_ guilds: [Guild], _ rail: [GuildRailItem]) -> [Guild] {
        let byID = Dictionary(guilds.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
        var ordered: [Guild] = []
        var seen = Set<GuildID>()
        for item in rail {
            let ids: [GuildID] = switch item {
            case .guild(let id): [id]
            case .folder(let folder): folder.guildIDs
            }
            for id in ids where seen.insert(id).inserted {
                if let guild = byID[id] { ordered.append(guild) }
            }
        }
        return ordered + guilds.filter { !seen.contains($0.id) }
    }

    private func handle(_ event: ClientEvent) {
        switch event {
        case .connectionChanged(let state):
            connection = state
        case .sessionInvalidated(let reason):
            errorMessage = reason
            Task {
                await tearDown()
                phase = .restoring
                await restore()
            }
        case .messageCreated(let message):
            insert(message)
        case .messageUpdated(let message):
            replace(message.channelID, message.id) { $0 = message }
        case .messagePatched(let update):
            replace(update.channelID, update.messageID) { update.apply(to: &$0) }
        case .messageReactionUpdated(let update):
            let userID = currentUser?.id
            replace(update.channelID, update.messageID) {
                $0.applyReactionUpdate(update, currentUserID: userID)
            }
        case .messageDeleted(let channelID, let messageID):
            timelines[channelID]?.messages.removeAll { $0.id == messageID }
        case .readStateSnapshot(let states, _):
            readStates = Dictionary(states.map { ($0.channelID, $0) }, uniquingKeysWith: { $1 })
        case .readStateChanged(let state):
            readStates[state.channelID] = state
        case .typing(let channelID, let user) where user.id != currentUser?.id:
            typing[channelID, default: [:]][user.id] = TypingEntry(user: user, expires: .now.addingTimeInterval(10))
            Task {
                try? await Task.sleep(for: .seconds(10.5))
                if let entry = typing[channelID]?[user.id], entry.expires <= .now {
                    typing[channelID]?[user.id] = nil
                }
            }
        case .channelsChanged(let guildID, let changed):
            channels = channels.filter { $0.value.guildID != guildID }
            for channel in changed { channels[channel.id] = channel }
            rebuildChannelOrder()
        case .snapshotChanged(let snapshot):
            apply(snapshot)
        case .guildChanged(let guild):
            if let index = guilds.firstIndex(where: { $0.id == guild.id }) {
                guilds[index] = guild
            } else {
                guilds.append(guild)
            }
        case .guildLayoutChanged(let guilds, let railItems):
            self.guilds = Self.railOrder(guilds, railItems)
        case .currentUserChanged(let user):
            currentUser = user
        default:
            break
        }
    }

    private func insert(_ message: Message) {
        channels[message.channelID]?.lastMessageID = message.id
        typing[message.channelID]?[message.author.id] = nil
        guard var timeline = timelines[message.channelID], timeline.didLoad else { return }
        if let nonce = message.nonce {
            timeline.pending.removeAll { $0.nonce == nonce }
        }
        if let index = timeline.messages.firstIndex(where: { $0.id == message.id }) {
            timeline.messages[index] = message
        } else {
            timeline.messages.append(message)
        }
        timelines[message.channelID] = timeline
        if message.author.id != currentUser?.id, mentionsCurrentUser(message) {
            readStates[message.channelID, default: ChannelReadState(
                channelID: message.channelID, lastAcknowledgedMessageID: nil
            )].mentionCount += 1
        }
    }

    private func replace(_ channelID: ChannelID, _ messageID: MessageID, _ change: (inout Message) -> Void) {
        guard let index = timelines[channelID]?.messages.firstIndex(where: { $0.id == messageID }) else { return }
        change(&timelines[channelID]!.messages[index])
    }

    func mentionsCurrentUser(_ message: Message) -> Bool {
        guard let id = currentUser?.id else { return false }
        return message.mentionsEveryone || message.mentionedUsers.contains { $0.id == id }
    }

    // MARK: Queries

    func channels(in guildID: GuildID?) -> [Channel] {
        let values = (channelOrder[guildID] ?? []).compactMap { channels[$0] }
        guard guildID == nil else { return values }
        // Direct messages follow recency, which changes with every message.
        return values.sorted { Self.snowflake($0.lastMessageID) > Self.snowflake($1.lastMessageID) }
    }

    /// Sidebar order per server, rebuilt only when membership changes so the
    /// rail's unread badges do not rescan every channel on each message.
    private func rebuildChannelOrder() {
        channelOrder = Dictionary(grouping: channels.values, by: \.guildID).mapValues { values in
            values
                .filter { $0.guildID != nil || $0.kind == .directMessage || $0.kind == .groupDirectMessage }
                .sorted {
                    ($0.categoryPosition, $0.category ?? "", $0.kind == .voice ? 1 : 0, $0.position, $0.name)
                        < ($1.categoryPosition, $1.category ?? "", $1.kind == .voice ? 1 : 0, $1.position, $1.name)
                }
                .map(\.id)
        }
    }

    /// Text-like conversations in sidebar order; voice-only rooms are skipped
    /// because the iPad build has no voice transport yet.
    func conversations(in guildID: GuildID?) -> [Channel] {
        channels(in: guildID).filter { $0.kind != .voice && $0.kind != .unknown }
    }

    func isUnread(_ channel: Channel) -> Bool {
        guard !channel.isMuted, let last = channel.lastMessageID else { return false }
        guard let acknowledged = readStates[channel.id]?.lastAcknowledgedMessageID else { return false }
        return Self.snowflake(last) > Self.snowflake(acknowledged)
    }

    func mentionCount(_ channel: Channel) -> Int {
        readStates[channel.id]?.mentionCount ?? 0
    }

    func guildHasUnread(_ guildID: GuildID) -> Bool {
        conversations(in: guildID).contains(where: isUnread)
    }

    func guildMentionCount(_ guildID: GuildID) -> Int {
        conversations(in: guildID).reduce(0) { $0 + mentionCount($1) }
    }

    func title(for channel: Channel) -> String {
        if channel.guildID != nil || channel.hasExplicitName, !channel.name.isEmpty {
            return channel.name
        }
        return channel.recipients.map(\.displayName).joined(separator: ", ")
    }

    private static func snowflake(_ id: MessageID?) -> UInt64 {
        id.flatMap { UInt64($0.description) } ?? 0
    }

    // MARK: Messages

    func loadLatest(_ channelID: ChannelID) async {
        guard let provider, timelines[channelID]?.didLoad != true, timelines[channelID]?.isLoading != true else { return }
        timelines[channelID, default: Timeline()].isLoading = true
        do {
            let page = try await provider.messages(in: channelID, anchoredAt: .newest, limit: 50)
            var timeline = timelines[channelID] ?? Timeline()
            timeline.messages = page.messages.sorted { $0.timestamp < $1.timestamp }
            timeline.hasMoreBefore = page.hasMoreBefore
            timeline.didLoad = true
            timeline.isLoading = false
            timelines[channelID] = timeline
        } catch {
            timelines[channelID]?.isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func loadOlder(_ channelID: ChannelID) async {
        guard let provider, let timeline = timelines[channelID], timeline.didLoad, timeline.hasMoreBefore,
              !timeline.isLoading, let oldest = timeline.messages.first else { return }
        timelines[channelID]?.isLoading = true
        do {
            let page = try await provider.messages(in: channelID, anchoredAt: .before(oldest.id), limit: 50)
            let known = Set(timelines[channelID]?.messages.map(\.id) ?? [])
            let older = page.messages.filter { !known.contains($0.id) }.sorted { $0.timestamp < $1.timestamp }
            timelines[channelID]?.messages.insert(contentsOf: older, at: 0)
            timelines[channelID]?.hasMoreBefore = page.hasMoreBefore
        } catch {
            errorMessage = error.localizedDescription
        }
        timelines[channelID]?.isLoading = false
    }

    func send(_ content: String, in channelID: ChannelID, replyingTo reply: Message?) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let provider, !trimmed.isEmpty else { return }
        let draft = SendMessageDraft(channelID: channelID, content: trimmed, replyTo: reply?.id)
        timelines[channelID, default: Timeline()].pending.append(PendingSend(nonce: draft.nonce, content: trimmed))
        lastTypingSent[channelID] = nil
        Task {
            do {
                let message = try await provider.send(draft)
                insert(message)
                timelines[channelID]?.pending.removeAll { $0.nonce == draft.nonce }
            } catch {
                if let index = timelines[channelID]?.pending.firstIndex(where: { $0.nonce == draft.nonce }) {
                    timelines[channelID]?.pending[index].failed = true
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    func discardPending(_ nonce: String, in channelID: ChannelID) {
        timelines[channelID]?.pending.removeAll { $0.nonce == nonce }
    }

    func edit(_ message: Message, content: String) async {
        guard let provider else { return }
        do {
            let edited = try await provider.edit(messageID: message.id, channelID: message.channelID, content: content)
            replace(message.channelID, message.id) { $0 = edited }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ message: Message) async {
        guard let provider else { return }
        do {
            try await provider.delete(messageID: message.id, channelID: message.channelID)
            timelines[message.channelID]?.messages.removeAll { $0.id == message.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleReaction(_ emoji: String, on message: Message) async {
        guard let provider else { return }
        do {
            try await provider.toggleReaction(emoji, messageID: message.id, channelID: message.channelID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Discord accepts a typing pulse every few seconds while the user types.
    func noteTyping(in channelID: ChannelID) {
        guard let provider else { return }
        if let last = lastTypingSent[channelID], last.timeIntervalSinceNow > -8 { return }
        lastTypingSent[channelID] = .now
        Task { try? await provider.sendTyping(in: channelID) }
    }

    func markRead(_ channelID: ChannelID) {
        guard let provider, let channel = channels[channelID], let last = channel.lastMessageID,
              isUnread(channel) || mentionCount(channel) > 0 else { return }
        readStates[channelID] = ChannelReadState(channelID: channelID, lastAcknowledgedMessageID: last)
        let token = acknowledgementToken
        Task {
            if let response = try? await provider.acknowledge(channelID: channelID, messageID: last, token: token) {
                acknowledgementToken = response.token ?? acknowledgementToken
            }
        }
    }

    func markGuildRead(_ guildID: GuildID?) {
        guard let provider else { return }
        let states = conversations(in: guildID).compactMap { channel -> BulkReadStateAcknowledgement? in
            guard let last = channel.lastMessageID, isUnread(channel) || mentionCount(channel) > 0 else { return nil }
            readStates[channel.id] = ChannelReadState(channelID: channel.id, lastAcknowledgedMessageID: last)
            return BulkReadStateAcknowledgement(channelID: channel.id, messageID: last)
        }
        guard !states.isEmpty else { return }
        Task { try? await provider.acknowledgeBulk(states) }
    }
}
