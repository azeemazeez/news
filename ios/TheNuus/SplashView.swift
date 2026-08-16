import SwiftUI

struct SplashView: View {
    @State private var appeared = false
    @State private var bouncing = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                Text("The Nuus")
                    .font(.custom("ArchivoBlack-Regular", size: 54))
                    .kerning(-2.5)
                    .foregroundStyle(Theme.wordmark)
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)

                Text("Serving you bite-sized news, every day.")
                    .font(.system(size: 16, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.secondary)
                    .opacity(appeared ? 1 : 0)

                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Theme.wordmark)
                            .frame(width: 8, height: 8)
                            .offset(y: bouncing ? -6 : 2)
                            .animation(
                                .easeInOut(duration: 0.45)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.15),
                                value: bouncing
                            )
                    }
                }
                .padding(.top, 10)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.35)) { appeared = true }
            bouncing = true
        }
    }
}

#Preview {
    SplashView()
}
