import SakuraCordModels
import SwiftUI
import UIKit

struct ComposerView: View {
    let workspace: PadWorkspace
    let channel: Channel
    @State private var text = ""

    private var session: PadSession { workspace.session }

    var body: some View {
        VStack(spacing: 0) {
            if let banner {
                HStack {
                    Text(banner).font(.caption).lineLimit(1)
                    Spacer()
                    Button("Cancel", systemImage: "xmark.circle.fill", action: cancel)
                        .labelStyle(.iconOnly)
                        .keyboardShortcut(.cancelAction)
                        .hoverEffect(.highlight)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ComposerTextView(
                    text: $text,
                    placeholder: placeholder,
                    focusRequest: workspace.composerFocusRequest,
                    onSubmit: submit,
                    onEscape: cancel,
                    onEditLast: workspace.editLatestOwnMessage,
                    onNavigate: navigate
                )
                .onChange(of: text) { _, value in
                    if !value.isEmpty, workspace.editing == nil { session.noteTyping(in: channel.id) }
                }
                Button(workspace.editing == nil ? "Send" : "Save", systemImage: "arrow.up.circle.fill", action: submit)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .hoverEffect(.lift)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .onChange(of: workspace.editing?.id, initial: true) {
            if let editing = workspace.editing { text = editing.content }
        }
    }

    private var placeholder: String {
        channel.guildID == nil ? "Message @\(session.title(for: channel))" : "Message #\(channel.name)"
    }

    private var banner: String? {
        if workspace.editing != nil { return "Editing message — Esc to cancel, Return to save" }
        if let reply = workspace.replyingTo {
            return "Replying to \(reply.guildMember?.nickname ?? reply.author.displayName)"
        }
        return nil
    }

    private func submit() {
        if let editing = workspace.editing {
            let content = text
            workspace.editing = nil
            text = ""
            Task { await session.edit(editing, content: content) }
        } else {
            session.send(text, in: channel.id, replyingTo: workspace.replyingTo)
            workspace.replyingTo = nil
            text = ""
        }
    }

    private func navigate(_ chord: NavigationChord) {
        switch chord {
        case .conversation(let offset): workspace.stepConversation(by: offset)
        case .unread(let offset): workspace.stepConversation(by: offset, unreadOnly: true)
        case .server(let offset): workspace.stepServer(by: offset)
        }
    }

    private func cancel() {
        if workspace.editing != nil { text = "" }
        workspace.editing = nil
        workspace.replyingTo = nil
    }
}

/// Multi-line composer with desktop key handling for hardware keyboards:
/// Return sends, Shift-Return breaks the line, Up Arrow in an empty field
/// edits your last message and Escape cancels. The software keyboard keeps
/// its normal Return so on-screen typing still inserts new lines.
private struct ComposerTextView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focusRequest: Int
    let onSubmit: () -> Void
    let onEscape: () -> Void
    let onEditLast: () -> Bool
    let onNavigate: (NavigationChord) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> KeyCommandTextView {
        let view = KeyCommandTextView()
        view.delegate = context.coordinator
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: KeyCommandTextView, context: Context) {
        if view.text != text {
            view.text = text
            view.setNeedsDisplay()
        }
        view.placeholder = placeholder
        view.onSubmit = onSubmit
        view.onEscape = onEscape
        view.onEditLast = onEditLast
        view.onNavigate = onNavigate
        if context.coordinator.focusRequest != focusRequest {
            context.coordinator.focusRequest = focusRequest
            DispatchQueue.main.async { view.becomeFirstResponder() }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: KeyCommandTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 400
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let maximum: CGFloat = 220
        uiView.isScrollEnabled = fitted.height > maximum
        return CGSize(width: width, height: min(fitted.height, maximum))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var focusRequest = 0

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            (textView as? KeyCommandTextView)?.setNeedsDisplay()
        }
    }
}

/// Channel and server navigation chords. UITextView claims Option-arrows for
/// caret movement, so the composer forwards them itself; otherwise the menu
/// commands would never fire while typing.
enum NavigationChord {
    case conversation(Int), unread(Int), server(Int)

    fileprivate init?(_ command: UIKeyCommand) {
        let offset = command.input == UIKeyCommand.inputUpArrow ? -1 : 1
        switch command.modifierFlags {
        case .alternate: self = .conversation(offset)
        case [.alternate, .shift]: self = .unread(offset)
        case [.command, .alternate]: self = .server(offset)
        default: return nil
        }
    }
}

final class KeyCommandTextView: UITextView {
    var onSubmit: () -> Void = {}
    var onEscape: () -> Void = {}
    var onEditLast: () -> Bool = { false }
    var onNavigate: (NavigationChord) -> Void = { _ in }
    var placeholder = "" { didSet { if placeholder != oldValue { setNeedsDisplay() } } }

    override var keyCommands: [UIKeyCommand]? {
        var commands = [
            command("\r", [], #selector(submit)),
            command("\r", .shift, #selector(insertLineBreak)),
            command(UIKeyCommand.inputEscape, [], #selector(escape))
        ]
        for input in [UIKeyCommand.inputUpArrow, UIKeyCommand.inputDownArrow] {
            for modifiers: UIKeyModifierFlags in [.alternate, [.alternate, .shift], [.command, .alternate]] {
                commands.append(command(input, modifiers, #selector(navigate(_:))))
            }
        }
        if text.isEmpty {
            commands.append(command(UIKeyCommand.inputUpArrow, [], #selector(editLast)))
        }
        return commands
    }

    @objc private func navigate(_ sender: UIKeyCommand) {
        NavigationChord(sender).map(onNavigate)
    }

    private func command(_ input: String, _ modifiers: UIKeyModifierFlags, _ action: Selector) -> UIKeyCommand {
        let command = UIKeyCommand(input: input, modifierFlags: modifiers, action: action)
        command.wantsPriorityOverSystemBehavior = true
        return command
    }

    @objc private func submit() {
        // Return first commits an in-progress IME composition.
        if markedTextRange != nil {
            unmarkText()
        } else {
            onSubmit()
        }
    }

    @objc private func insertLineBreak() {
        insertText("\n")
    }

    @objc private func escape() {
        onEscape()
    }

    @objc private func editLast() {
        _ = onEditLast()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard text.isEmpty else { return }
        let origin = CGPoint(x: textContainerInset.left + textContainer.lineFragmentPadding, y: textContainerInset.top)
        (placeholder as NSString).draw(at: origin, withAttributes: [
            .font: font ?? .preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.placeholderText
        ])
    }
}
