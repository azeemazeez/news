import SwiftUI

/// The website's mobile masthead, recreated natively: gradient utility bar
/// with today's date, the eyebrow line, the Archivo Black gradient wordmark,
/// and the italic serif tagline.
struct SiteHeaderView: View {
    let onMenu: (MenuScreen) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(Self.dateLine)
                    .font(.system(size: 12, weight: .semibold))
                    .kerning(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)

                HStack {
                    Spacer()
                    Menu {
                        Button {
                            onMenu(.archive)
                        } label: {
                            Label("Archive", systemImage: "calendar")
                        }
                        Button {
                            onMenu(.saved)
                        } label: {
                            Label("Saved", systemImage: "bookmark")
                        }
                        Button {
                            onMenu(.settings)
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        Button {
                            onMenu(.about)
                        } label: {
                            Label("About", systemImage: "info.circle")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                            .accessibilityLabel("Menu")
                    }
                }
                .padding(.trailing, 4)
            }
            .padding(.vertical, 2)
            .background(Theme.headerGradient)

            VStack(spacing: 0) {
                Text("Est. 2026 · Daily Edition")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.eyebrow)

                Text("The Nuus")
                    .font(.custom("ArchivoBlack-Regular", size: 56))
                    .kerning(-2.5)
                    .foregroundStyle(Theme.wordmark)
                    .padding(.top, 6)

                Text("Serving you bite-sized news, every day.")
                    .font(.system(size: 17, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.secondary)
                    .padding(.top, 8)
            }
            .padding(.top, 26)
            .padding(.bottom, 24)
            .padding(.horizontal, 16)
        }
        .background(Theme.background)
    }

    /// "Tuesday · July 28, 2026" — same format as the website's utility bar.
    static var dateLine: String {
        let now = Date()
        let weekday = now.formatted(.dateTime.weekday(.wide))
        let rest = now.formatted(.dateTime.month(.wide).day().year())
        return "\(weekday) · \(rest)"
    }
}

#Preview {
    SiteHeaderView { _ in }
}
