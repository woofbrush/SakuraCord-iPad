import SakuraCordModels
import SwiftUI

struct WorkspaceView: View {
    @State private var workspace: PadWorkspace

    init(session: PadSession) {
        _workspace = State(initialValue: PadWorkspace(session: session))
    }

    var body: some View {
        @Bindable var workspace = workspace
        NavigationSplitView(columnVisibility: $workspace.columnVisibility) {
            SidebarView(workspace: workspace)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
                .toolbar(.hidden, for: .navigationBar)
        } detail: {
            NavigationStack {
                if let channel = workspace.selectedChannel {
                    ChatView(workspace: workspace, channel: channel)
                        .id(channel.id)
                } else {
                    ContentUnavailableView(
                        "No conversation selected",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Pick a channel, or press ⌘K to jump to one.")
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $workspace.isQuickSwitcherPresented) {
            QuickSwitcherView(workspace: workspace)
        }
        .focusedSceneValue(\.padWorkspace, workspace)
        .onAppear {
            if workspace.selectedChannelID == nil { workspace.selectGuild(nil) }
        }
    }
}

// MARK: Sidebar

private enum RailMetrics {
    static let width: CGFloat = 72
    static let icon: CGFloat = 48
}

/// Server rail beside the channel list. In windowed mode iPadOS draws its
/// close/minimize/tile controls over the window's top-leading corner; the
/// container corner insets report that area (zero in full screen), so the rail
/// and the channel header lay themselves out around it.
private struct SidebarView: View {
    let workspace: PadWorkspace

    var body: some View {
        GeometryReader { proxy in
            let controls = proxy.containerCornerInsets.topLeading
            HStack(spacing: 0) {
                ServerRail(workspace: workspace, topClearance: controls.height)
                    .frame(width: RailMetrics.width)
                Divider()
                ChannelColumn(
                    workspace: workspace,
                    headerLeadingClearance: max(0, controls.width - RailMetrics.width),
                    headerMinimumHeight: controls.height
                )
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

private struct ServerRail: View {
    let workspace: PadWorkspace
    let topClearance: CGFloat

    private var session: PadSession { workspace.session }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                RailButton(
                    title: "Direct Messages",
                    isSelected: workspace.selectedGuildID == nil,
                    hasUnread: session.channels(in: nil).contains(where: session.isUnread),
                    mentions: session.channels(in: nil).reduce(0) { $0 + session.mentionCount($1) }
                ) {
                    workspace.selectGuild(nil)
                } icon: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.sakura)
                }
                .contextMenu {
                    Button("Mark All as Read", systemImage: "envelope.open") { session.markGuildRead(nil) }
                }
                Divider().frame(width: 32)
                ForEach(session.guilds) { guild in
                    RailButton(
                        title: guild.name,
                        isSelected: workspace.selectedGuildID == guild.id,
                        hasUnread: session.guildHasUnread(guild.id),
                        mentions: session.guildMentionCount(guild.id)
                    ) {
                        workspace.selectGuild(guild.id)
                    } icon: {
                        RemoteImage(url: guild.iconURL) { Initials(text: guild.name) }
                    }
                    .contextMenu {
                        Button("Mark as Read", systemImage: "envelope.open") { session.markGuildRead(guild.id) }
                        Button("Copy Server ID", systemImage: "number") {
                            UIPasteboard.general.string = guild.id.description
                        }
                    }
                }
            }
            .padding(.top, max(12, topClearance + 4))
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .tertiarySystemBackground))
    }
}

private struct RailButton<Icon: View>: View {
    let title: String
    let isSelected: Bool
    let hasUnread: Bool
    let mentions: Int
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            icon()
                .frame(width: RailMetrics.icon, height: RailMetrics.icon)
                .clipShape(RoundedRectangle(cornerRadius: isSelected || isHovered ? 16 : 24, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if mentions > 0 { MentionBadge(count: mentions).offset(x: 4, y: 4) }
                }
        }
        .buttonStyle(.plain)
        // Trackpad: the pointer morphs into the icon's shape and lifts it.
        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 16, style: .continuous))
        .hoverEffect(.lift)
        .onHover { isHovered = $0 }
        .animation(.snappy(duration: 0.18), value: isHovered)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(.primary)
                .frame(width: 4, height: isSelected ? 36 : (isHovered ? 20 : (hasUnread ? 8 : 0)))
                .animation(.snappy(duration: 0.18), value: isSelected)
        }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ChannelColumn: View {
    let workspace: PadWorkspace
    let headerLeadingClearance: CGFloat
    let headerMinimumHeight: CGFloat

    private var session: PadSession { workspace.session }

    private var title: String {
        workspace.selectedGuildID.flatMap { id in session.guilds.first { $0.id == id }?.name } ?? "Direct Messages"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline).lineLimit(1)
                Spacer()
                Button("Quick Switch", systemImage: "magnifyingglass") {
                    workspace.isQuickSwitcherPresented = true
                }
                .hoverEffect(.highlight)
                // The sidebar hides its navigation bar, which would otherwise
                // carry the system toggle.
                Button("Hide Sidebar", systemImage: "sidebar.leading") { workspace.toggleSidebar() }
                    .hoverEffect(.highlight)
            }
            .labelStyle(.iconOnly)
            .padding(.leading, 16 + headerLeadingClearance)
            .padding(.trailing, 12)
            .frame(minHeight: max(52, headerMinimumHeight))
            Divider()
            ChannelList(workspace: workspace)
            Divider()
            AccountBar(session: session)
        }
    }
}

private struct ChannelList: View {
    let workspace: PadWorkspace

    private var session: PadSession { workspace.session }

    private var sections: [(title: String?, channels: [Channel])] {
        let channels = session.channels(in: workspace.selectedGuildID)
        guard workspace.selectedGuildID != nil else { return [(nil, channels)] }
        var result: [(title: String?, channels: [Channel])] = []
        for channel in channels {
            if result.last?.title == channel.category, !result.isEmpty {
                result[result.count - 1].channels.append(channel)
            } else {
                result.append((channel.category, [channel]))
            }
        }
        return result
    }

    var body: some View {
        // List selection gives hardware-keyboard arrow navigation and the
        // standard trackpad hover highlight for free.
        List(selection: Binding(get: { workspace.selectedChannelID }, set: { workspace.open($0) })) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                Section {
                    ForEach(section.channels) { channel in
                        ChannelRow(session: session, channel: channel)
                            .tag(channel.id)
                            .selectionDisabled(channel.kind == .voice)
                            .contextMenu { ChannelMenu(session: session, channel: channel) }
                    }
                } header: {
                    if let title = section.title { Text(title) }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
}

private struct ChannelRow: View {
    let session: PadSession
    let channel: Channel

    var body: some View {
        let unread = session.isUnread(channel)
        HStack(spacing: 10) {
            if channel.guildID == nil {
                RemoteImage(url: channel.iconURL ?? channel.recipients.first?.avatarURL) {
                    Initials(text: session.title(for: channel))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Image(systemName: channel.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }
            Text(session.title(for: channel))
                .fontWeight(unread ? .semibold : .regular)
                .foregroundStyle(unread || channel.guildID == nil ? .primary : .secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if session.mentionCount(channel) > 0 {
                MentionBadge(count: session.mentionCount(channel))
            }
        }
        .opacity(channel.kind == .voice ? 0.45 : (channel.isMuted ? 0.6 : 1))
    }
}

struct ChannelMenu: View {
    let session: PadSession
    let channel: Channel

    var body: some View {
        Button("Mark as Read", systemImage: "envelope.open") { session.markRead(channel.id) }
        Button("Copy Link", systemImage: "link") {
            UIPasteboard.general.url = channel.link
        }
        Button("Copy Channel ID", systemImage: "number") {
            UIPasteboard.general.string = channel.id.description
        }
    }
}

private struct AccountBar: View {
    let session: PadSession

    var body: some View {
        HStack(spacing: 10) {
            RemoteImage(url: session.currentUser?.avatarURL) {
                Initials(text: session.currentUser?.displayName ?? "?")
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(session.currentUser?.displayName ?? "").font(.subheadline.weight(.semibold))
                Text(session.connection.label).font(.caption).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer()
            Menu {
                Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    Task { await session.signOut() }
                }
            } label: {
                Image(systemName: "gearshape")
            }
            .hoverEffect(.highlight)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: Shared pieces

struct MentionBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.red, in: Capsule())
    }
}

struct Initials: View {
    let text: String

    var body: some View {
        Text(text.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined())
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray)
    }
}

struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                placeholder()
            }
        }
    }
}

extension Channel {
    var symbol: String {
        switch kind {
        case .announcement: "megaphone"
        case .forum: "text.bubble"
        case .voice: "speaker.wave.2"
        case .directMessage, .groupDirectMessage: "at"
        default: "number"
        }
    }

    var link: URL? {
        URL(string: "https://discord.com/channels/\(guildID?.description ?? "@me")/\(id.description)")
    }
}

extension ConnectionState {
    var label: LocalizedStringKey {
        switch self {
        case .ready: "Online"
        case .connecting: "Connecting…"
        case .resuming: "Reconnecting…"
        case .backingOff: "Waiting to reconnect"
        case .disconnected: "Offline"
        case .authenticationFailed: "Signed out"
        }
    }
}
