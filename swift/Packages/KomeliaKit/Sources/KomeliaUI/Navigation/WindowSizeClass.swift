import CoreGraphics

/// Port of `snd.komelia.ui.platform.WindowSizeClass` — thresholds verbatim (600/840/1200 pt),
/// evaluated against the *window* width so Split View / Stage Manager behave correctly on iPad.
public enum WindowSizeClass: Int, Comparable, Sendable {
    case compact, medium, expanded, full

    public static func from(width: CGFloat) -> WindowSizeClass {
        switch width {
        case ..<600: .compact
        case ..<840: .medium
        case ..<1200: .expanded
        default: .full
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
