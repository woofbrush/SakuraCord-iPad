import MessageRendering
import SakuraCordModels
import SwiftUI

struct ChatView: View {
    let workspace: PadWorkspace
    let channel: Channel
    @State private var pendingDeletion: Message?

    private var session: PadSession { workspace.session }
    private var timeline: PadSession.Timeline { session.timelines[channel.id] ?? .init() }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if timeline.hasMoreBefore, timeline.didLoad {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .onAppear { Task { await session.loadOlder(channel.id) } }
                    } else if timeline.didLoad {
                        ChannelIntro(title: session.title(for: channel), topic: channel.topic)
                    }
                    ForEach(Array(timeline.messages.enumerated()), id: \.element.id) { index, message in
                        MessageRow(
                            workspace: workspace,
                            message: message,
                            isGrouped: index > 0 && Self.groups(timeline.messages[index - 1], message),
                            onDelete: { pendingDeletion = message }
                        )
                    }
                    ForEach(timeline.pending) { pending in
                        PendingRow(pending: pending, author: session.currentUser) {
                            session.discardPending(pending.nonce, in: channel.id)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .overlay {
                if !timeline.didLoad { ProgressView() }
            }
            TypingIndicator(entries: session.typing[channel.id].map { Array($0.values) } ?? [])
            ComposerView(workspace: workspace, channel: channel)
        }
        .navigationTitle(session.title(for: channel))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ChannelMenu(session: session, channel: channel)
                } label: {
                    Label("Channel", systemImage: "ellipsis.circle")
                }
            }
        }
        .task { await session.loadLatest(channel.id) }
        .onChange(of: timeline.messages.last?.id, initial: true) {
            session.markRead(channel.id)
        }
        .confirmationDialog(
            "Delete this message?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { message in
            Button("Delete", role: .destructive) { Task { await session.delete(message) } }
        }
    }

    private static func groups(_ previous: Message, _ message: Message) -> Bool {
        previous.author.id == message.author.id && message.replyPreview == nil
            && message.timestamp.timeIntervalSince(previous.timestamp) < 7 * 60
    }
}

private struct ChannelIntro: View {
    let title: String
    let topic: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Welcome to \(title)").font(.title.bold())
            if let topic, !topic.isEmpty {
                Text(topic).foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }
}

struct MessageRow: View {
    let workspace: PadWorkspace
    let message: Message
    let isGrouped: Bool
    let onDelete: () -> Void
    @State private var isHovered = false

    private var session: PadSession { workspace.session }
    private var isOwn: Bool { message.author.id == session.currentUser?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let reply = message.replyPreview {
                ReplyLine(preview: reply).padding(.leading, 56)
            }
            HStack(alignment: .top, spacing: 12) {
                if isGrouped {
                    Text(message.timestamp, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 40)
                        .opacity(isHovered ? 1 : 0)
                } else {
                    RemoteImage(url: message.author.avatarURL) { Initials(text: message.author.displayName) }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    if !isGrouped {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(message.guildMember?.nickname ?? message.author.displayName)
                                .font(.body.weight(.semibold))
                            if message.author.isBot { BotTag() }
                            Text(message.timestamp, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !message.content.isEmpty {
                        if message.editedTimestamp == nil {
                            Text(DiscordMarkdown.attributed(message.content))
                        } else {
                            let edited = Text("(edited)").font(.caption2).foregroundStyle(.tertiary)
                            Text("\(DiscordMarkdown.attributed(message.content)) \(edited)")
                        }
                    }
                    ForEach(message.attachments, id: \.id) { attachment in
                        AttachmentView(attachment: attachment)
                    }
                    if !message.reactions.isEmpty {
                        ReactionBar(message: message, session: session)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, isGrouped ? 2 : 12)
        .padding(.bottom, 2)
        .background(highlight)
        .contentShape(Rectangle())
        // Trackpad: hovering reveals the desktop action bar.
        .onHover { isHovered = $0 }
        .overlay(alignment: .topTrailing) {
            if isHovered { hoverActions.offset(y: -14).padding(.trailing, 16) }
        }
        // Secondary click (two-finger click) and long press.
        .contextMenu { menu }
    }

    private var highlight: Color {
        if session.mentionsCurrentUser(message) { return .yellow.opacity(0.12) }
        if workspace.replyingTo?.id == message.id || workspace.editing?.id == message.id { return .sakura.opacity(0.12) }
        return isHovered ? Color.primary.opacity(0.04) : .clear
    }

    private var hoverActions: some View {
        HStack(spacing: 2) {
            ForEach(["👍", "❤️", "😂"], id: \.self) { emoji in
                Button(emoji) { Task { await session.toggleReaction(emoji, on: message) } }
                    .help("React with \(emoji)")
            }
            Divider().frame(height: 20)
            Button("Reply", systemImage: "arrowshape.turn.up.left") {
                workspace.replyingTo = message
                workspace.focusComposer()
            }
            if isOwn {
                Button("Edit", systemImage: "pencil") {
                    workspace.editing = message
                    workspace.focusComposer()
                }
            }
            Menu { menu } label: { Label("More", systemImage: "ellipsis") }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
        .hoverEffect(.highlight)
    }

    @ViewBuilder private var menu: some View {
        Button("Reply", systemImage: "arrowshape.turn.up.left") {
            workspace.replyingTo = message
            workspace.focusComposer()
        }
        if isOwn {
            Button("Edit Message", systemImage: "pencil") {
                workspace.editing = message
                workspace.focusComposer()
            }
        }
        Button("Copy Text", systemImage: "doc.on.doc") { UIPasteboard.general.string = message.content }
        Button("Copy Message Link", systemImage: "link") {
            let guild = message.guildID?.description ?? workspace.selectedChannel?.guildID?.description ?? "@me"
            UIPasteboard.general.string = "https://discord.com/channels/\(guild)/\(message.channelID)/\(message.id)"
        }
        Button("Copy Message ID", systemImage: "number") { UIPasteboard.general.string = message.id.description }
        if isOwn {
            Divider()
            Button("Delete Message", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

private struct BotTag: View {
    var body: some View {
        Text("APP")
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .background(Color.indigo, in: RoundedRectangle(cornerRadius: 3))
    }
}

private struct ReplyLine: View {
    let preview: MessageReplyPreview

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.up.right").font(.caption2)
            Text(preview.guildMember?.nickname ?? preview.author.displayName).font(.caption.weight(.semibold))
            Text(preview.content).font(.caption).lineLimit(1)
        }
        .foregroundStyle(.secondary)
    }
}

private struct AttachmentView: View {
    let attachment: Attachment
    @Environment(\.openURL) private var openURL

    var body: some View {
        if attachment.mediaType?.hasPrefix("image/") == true, !attachment.isSpoiler {
            let size = fittedSize
            AsyncImage(url: attachment.proxyURL ?? attachment.url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture { openURL(attachment.url) }
            .hoverEffect(.highlight)
        } else {
            Link(destination: attachment.url) {
                Label(attachment.isSpoiler ? "Spoiler: \(attachment.filename)" : attachment.filename,
                      systemImage: "doc")
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
            .hoverEffect(.highlight)
        }
    }

    private var fittedSize: CGSize {
        let width = CGFloat(attachment.width ?? 400), height = CGFloat(attachment.height ?? 300)
        let scale = min(1, 400 / max(width, 1), 300 / max(height, 1))
        return CGSize(width: width * scale, height: height * scale)
    }
}

private struct ReactionBar: View {
    let message: Message
    let session: PadSession

    var body: some View {
        HStack(spacing: 4) {
            ForEach(message.reactions, id: \.id) { reaction in
                Button {
                    Task { await session.toggleReaction(reaction.emoji, on: message) }
                } label: {
                    Text("\(reaction.emoji) \(reaction.count)")
                        .font(.callout)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            reaction.didCurrentUserReact ? Color.sakura.opacity(0.25) : Color.secondary.opacity(0.15),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
            }
        }
    }
}

private struct PendingRow: View {
    let pending: PadSession.PendingSend
    let author: User?
    let discard: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Color.clear.frame(width: 40, height: 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(DiscordMarkdown.attributed(pending.content))
                    .foregroundStyle(pending.failed ? .red : .secondary)
                if pending.failed {
                    Button("Not sent — dismiss", action: discard).font(.caption)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}

private struct TypingIndicator: View {
    let entries: [PadSession.TypingEntry]

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
            .padding(.horizontal, 16)
    }

    private var text: String {
        let names = entries.map(\.user.displayName).sorted()
        switch names.count {
        case 0: return ""
        case 1: return "\(names[0]) is typing…"
        case 2: return "\(names[0]) and \(names[1]) are typing…"
        default: return "Several people are typing…"
        }
    }
}
