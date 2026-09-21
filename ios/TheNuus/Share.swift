import SwiftUI
import UIKit

/// The system share sheet, presented straight from UIKit.
///
/// `ShareLink` is not used because it has no completion callback, and a gesture
/// attached to it never fires inside a context menu — a share started from the
/// feed could not be reported at all.
///
/// The activity controller is also not wrapped in a SwiftUI `.sheet`: that
/// nests it in a second sheet, and swiping the outer one away tears the
/// controller down without ever running its completion handler, losing the
/// event entirely.
enum Share {
    static func story(_ story: Story, url: URL, editionDate: String?) {
        guard let presenter = topViewController() else { return }

        let controller = UIActivityViewController(
            activityItems: [story.cleanIntro, url],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { activity, completed, _, _ in
            Analytics.storyShared(
                story,
                editionDate: editionDate,
                activity: activity?.rawValue,
                completed: completed
            )
        }

        // On iPad this is a popover, and presenting one without an anchor traps.
        if let popover = controller.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.maxY - 60,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        presenter.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?
            .rootViewController

        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
