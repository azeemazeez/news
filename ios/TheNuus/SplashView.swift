import SwiftUI

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("The Nuus")
                    .font(.system(size: 54, weight: .black, design: .default))
                    .kerning(-1.5)
                    .foregroundStyle(Theme.wordmark)

                Text("Serving you bite-sized news, every day.")
                    .font(.system(size: 16, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.secondary)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.96)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}

#Preview {
    SplashView()
}
