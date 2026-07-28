import SafariServices
import SwiftUI

/// Opens articles in an in-app Safari sheet rather than kicking the user out to
/// the browser. Reader mode is preferred where the article supports it.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = true

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredControlTintColor = UIColor(Theme.purple)
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
