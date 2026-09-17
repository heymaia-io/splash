import CoreGraphics
import SplashCore
import SplashImage

/// Layout math for a paged spread (`calculateScreenScale` / `getMaxPageSize` / `fitToScreenZoom`).
/// Pure, so it is unit-tested without UIKit.
public enum SpreadLayout {
    /// Display size (points) of each page in the spread, side by side.
    public static func pageSizes(
        contentSizes: [CGSize], area: CGSize, scaleType: LayoutScaleType, stretchToFit: Bool, screenScale: CGFloat
    ) -> [CGSize] {
        guard !contentSizes.isEmpty else { return [] }
        let maxPage = CGSize(width: area.width / CGFloat(contentSizes.count), height: area.height)
        return contentSizes.map { size in
            guard size.width > 0, size.height > 0 else { return maxPage }
            let native = CGSize(width: size.width / screenScale, height: size.height / screenScale)
            switch scaleType {
            case .screen:
                return ReaderLayout.fit(native, in: maxPage, stretch: stretchToFit)
            case .fitWidth:
                return scaled(native, by: maxPage.width / native.width, stretch: stretchToFit)
            case .fitHeight:
                return scaled(native, by: maxPage.height / native.height, stretch: stretchToFit)
            case .original:
                return native
            }
        }
    }

    private static func scaled(_ size: CGSize, by factor: CGFloat, stretch: Bool) -> CGSize {
        let f = stretch ? factor : min(factor, 1)
        return CGSize(width: (size.width * f).rounded(), height: (size.height * f).rounded())
    }

    /// Frames inside the spread's content box. Right-to-left spreads place the first page on the right.
    public static func frames(for sizes: [CGSize], rightToLeft: Bool) -> (content: CGSize, frames: [CGRect]) {
        let height = sizes.map(\.height).max() ?? 0
        var x: CGFloat = 0
        var frames: [CGRect] = []
        for size in (rightToLeft ? sizes.reversed() : sizes) {
            frames.append(CGRect(x: x, y: (height - size.height) / 2, width: size.width, height: size.height))
            x += size.width
        }
        if rightToLeft { frames.reverse() }
        return (CGSize(width: x, height: height), frames)
    }
}
