import SwiftUI

@main
struct SakuraCordPadApp: App {
    @State private var session = PadSession()

    var body: some Scene {
        WindowGroup("SakuraCord") {
            PadRootView()
                .environment(session)
                .tint(.sakura)
        }
        .commands { PadCommands() }
    }
}

extension Color {
    static let sakura = Color(red: 0.85, green: 0.34, blue: 0.55)
}

/// Menu-bar commands, also listed in the Command-key overlay. Bindings match
/// SakuraCord's macOS defaults so muscle memory carries over.
struct PadCommands: Commands {
    @FocusedValue(\.padWorkspace) private var workspace

    var body: some Commands {
        CommandGroup(replacing: .sidebar) {
            item("Toggle Channel Sidebar", "s", [.command, .control]) { $0.toggleSidebar() }
            Divider()
            item("Back", "[") { $0.navigateBack() }
            item("Forward", "]") { $0.navigateForward() }
            item("Return to Previous Text Channel", "b", .control) { $0.returnToPreviousTextChannel() }
            Divider()
            item("Previous Conversation", .upArrow, .option) { $0.stepConversation(by: -1) }
            item("Next Conversation", .downArrow, .option) { $0.stepConversation(by: 1) }
            item("Previous Unread Conversation", .upArrow, [.option, .shift]) {
                $0.stepConversation(by: -1, unreadOnly: true)
            }
            item("Next Unread Conversation", .downArrow, [.option, .shift]) {
                $0.stepConversation(by: 1, unreadOnly: true)
            }
            Divider()
            item("Previous Server", .upArrow, [.command, .option]) { $0.stepServer(by: -1) }
            item("Next Server", .downArrow, [.command, .option]) { $0.stepServer(by: 1) }
            item("Switch Between Server and Direct Messages", .rightArrow, [.command, .option]) {
                $0.toggleDirectMessages()
            }
        }

        CommandMenu("Navigate") {
            item("Quick Switch…", "k") { $0.isQuickSwitcherPresented = true }
            Divider()
            item("Direct Messages", "1") { $0.navigate(toShortcut: 1) }
            ForEach(2 ... 9, id: \.self) { number in
                item("Server \(number - 1)", KeyEquivalent(Character(String(number)))) {
                    $0.navigate(toShortcut: number)
                }
            }
        }

        CommandMenu("Message") {
            item("Focus Message Field", "t", [.command, .shift]) { $0.focusComposer() }
            item("Reply to Latest Message", "r", [.command, .shift]) { $0.replyToLatest() }
            Divider()
            item("Mark Server Read", .escape, .shift) { $0.markServerRead() }
        }
    }

    private func item(
        _ title: LocalizedStringKey,
        _ key: KeyEquivalent,
        _ modifiers: EventModifiers = .command,
        perform: @escaping (PadWorkspace) -> Void
    ) -> some View {
        Button(title) { workspace.map(perform) }
            .keyboardShortcut(key, modifiers: modifiers)
            .disabled(workspace == nil)
    }
}
