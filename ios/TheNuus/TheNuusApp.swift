import SwiftUI

@main
struct TheNuusApp: App {
    init() {
        Analytics.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var model = FeedModel()
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            FeedView(model: model)
                .opacity(showingSplash ? 0 : 1)

            if showingSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .onOpenURL { url in
            guard url.scheme == "thenuus", url.host == "widget" else { return }
            let family = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "family" }?
                .value
            Analytics.widgetTapped(family: family)
        }
        .task {
            // Load and show the splash concurrently, so a fast network doesn't
            // mean a splash that flashes by too quickly to read.
            async let load: Void = model.load()
            async let minimumDisplay: Void = Task.sleep(for: .seconds(1.1))

            _ = await (load, try? minimumDisplay)

            withAnimation(.easeOut(duration: 0.35)) {
                showingSplash = false
            }
        }
    }
}
