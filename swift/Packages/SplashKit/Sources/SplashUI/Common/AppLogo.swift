import SwiftUI

/// The app icon artwork clipped to a rounded square (iOS icon corner ratio).
public struct AppLogoView: View {
    private let size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        Image("AppLogo", bundle: .module)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Startup loader. The logo sits at the exact size and position of the launch screen
/// (`LaunchLogo`, 160pt, centered ignoring safe areas) so the hand-off is seamless;
/// the spinner hangs below it without shifting the logo. Always black: the launch screen
/// can't read the user's theme, and dark is the app default.
public struct SplashLoadingView: View {
    static let logoSize: CGFloat = 160

    public init() {}

    public var body: some View {
        ZStack {
            Color.black
            AppLogoView(size: Self.logoSize)
                .overlay(alignment: .bottom) {
                    ProgressView()
                        .controlSize(.large)
                        .offset(y: 56)
                }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .accessibilityElement()
        .accessibilityLabel("Loading")
    }
}

#Preview {
    SplashLoadingView()
}
