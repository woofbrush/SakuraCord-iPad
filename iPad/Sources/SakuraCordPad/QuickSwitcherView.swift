import SakuraCordModels
import SwiftUI
import UIKit

/// Command-K switcher: type to filter, Up/Down to move, Return to open,
/// Escape to close, all without leaving the hardware keyboard.
struct QuickSwitcherView: View {
    let workspace: PadWorkspace
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var highlighted = 0

    private var session: PadSession { workspace.session }

    private struct Result: Identifiable {
        let channel: Channel
        let title: String
        let subtitle: String?
        var id: ChannelID { channel.id }
    }

    private var results: [Result] {
        let guildNames = Dictionary(session.guilds.map { ($0.id, $0.name) }, uniquingKeysWith: { $1 })
        let all = session.conversations(in: nil) + session.guilds.flatMap { session.conversations(in: $0.id) }
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let matches = all.lazy.map { channel in
            Result(channel: channel, title: session.title(for: channel), subtitle: channel.guildID.flatMap { guildNames[$0] })
        }
        guard !needle.isEmpty else {
            return Array(matches.filter { session.isUnread($0.channel) }.prefix(20))
        }
        return Array(matches.filter { $0.title.lowercased().contains(needle) }
            .sorted { $0.title.lowercased().hasPrefix(needle) && !$1.title.lowercased().hasPrefix(needle) }
            .prefix(30))
    }

    var body: some View {
        let results = results
        VStack(spacing: 0) {
            SwitcherField(
                text: $query,
                onMove: { offset in
                    guard !results.isEmpty else { return }
                    highlighted = (highlighted + offset + results.count) % results.count
                },
                onSubmit: { open(results.indices.contains(highlighted) ? results[highlighted] : nil) },
                onEscape: { dismiss() }
            )
            .frame(height: 52)
            .padding(.horizontal, 16)
            Divider()
            ScrollViewReader { proxy in
                List {
                    if query.isEmpty, !results.isEmpty {
                        Text("Unread").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        Button { open(result) } label: {
                            HStack {
                                Image(systemName: result.channel.symbol).foregroundStyle(.secondary)
                                Text(result.title)
                                Spacer()
                                if let subtitle = result.subtitle {
                                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(index == highlighted ? Color.sakura.opacity(0.2) : nil)
                        .onHover { if $0 { highlighted = index } }
                        .id(index)
                    }
                }
                .listStyle(.plain)
                .onChange(of: highlighted) { _, index in proxy.scrollTo(index) }
            }
        }
        .onChange(of: query) { highlighted = 0 }
        .presentationSizing(.form)
    }

    private func open(_ result: Result?) {
        guard let result else { return }
        workspace.open(result.channel.id)
        dismiss()
    }
}

private struct SwitcherField: UIViewRepresentable {
    @Binding var text: String
    let onMove: (Int) -> Void
    let onSubmit: () -> Void
    let onEscape: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, onSubmit: onSubmit) }

    func makeUIView(context: Context) -> KeyCommandTextField {
        let field = KeyCommandTextField()
        field.placeholder = "Where would you like to go?"
        field.font = .preferredFont(forTextStyle: .title3)
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .go
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ field: KeyCommandTextField, context: Context) {
        if field.text != text { field.text = text }
        field.onMove = onMove
        field.onEscape = onEscape
        context.coordinator.onSubmit = onSubmit
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        @objc func changed(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return false
        }
    }
}

final class KeyCommandTextField: UITextField {
    var onMove: (Int) -> Void = { _ in }
    var onEscape: () -> Void = {}

    override var keyCommands: [UIKeyCommand]? {
        [
            command(UIKeyCommand.inputUpArrow, #selector(moveUp)),
            command(UIKeyCommand.inputDownArrow, #selector(moveDown)),
            command(UIKeyCommand.inputEscape, #selector(escape))
        ]
    }

    private func command(_ input: String, _ action: Selector) -> UIKeyCommand {
        let command = UIKeyCommand(input: input, modifierFlags: [], action: action)
        command.wantsPriorityOverSystemBehavior = true
        return command
    }

    @objc private func moveUp() { onMove(-1) }
    @objc private func moveDown() { onMove(1) }
    @objc private func escape() { onEscape() }
}
