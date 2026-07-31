import PostHog
import SwiftUI

@main
struct TheNuusApp: App {
    init() {
        let config = PostHogConfig(
            apiKey: "phc_rq8yTiZJXnUNeVbK7Uxar5Qe9nJKE6VFxXDsSeUANHdC",
            host: "https://us.i.posthog.com"
        )
        PostHogSDK.shared.setup(config)
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
