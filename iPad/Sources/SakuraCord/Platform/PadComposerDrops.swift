import UIKit

/// The message box takes files through the attach button and paste. UITextView would
/// otherwise accept whatever the system drops on it, such as a video being moved.
@MainActor
final class PadComposerDrops: NSObject, UITextDropDelegate {
    static let refusing = PadComposerDrops()

    func textDroppableView(
        _: UIView & UITextDroppable, proposalForDrop _: UITextDropRequest
    ) -> UITextDropProposal {
        UITextDropProposal(operation: .cancel)
    }
}
