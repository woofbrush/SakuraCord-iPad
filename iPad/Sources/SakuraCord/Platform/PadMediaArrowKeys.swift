import AppKitShim
import SwiftUI

/// iPadOS spends the arrow keys on moving focus between controls before SwiftUI's
/// `onKeyPress` can see them, so the media viewer takes them first.
struct PadMediaArrowKeys: ViewModifier {
    let move: (Int) -> Void
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard event.keyCode == 123 || event.keyCode == 124,
                          event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift]),
                          !NSMenu.ak_isOpen,
                          !(event.window?.firstResponder is UITextField),
                          !(event.window?.firstResponder is UITextView)
                    else { return event }
                    move(event.keyCode == 123 ? -1 : 1)
                    return nil
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}
