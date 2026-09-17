import CoreGraphics
import Foundation
import ImageIO

/// ImageIO / Core Graphics replacements for the libvips operations used by the reader
/// (`SplashImage.resize`, `extractArea`, `findTrim`).
enum ReaderImageDecoder {
    static func pixelSize(of source: CGImageSource) -> CGSize? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        // EXIF orientations 5–8 swap axes (thumbnails below are created with the transform applied).
        return orientation >= 5 ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }

    /// Downsampled decode (`CGImageSourceCreateThumbnailAtIndex` decodes JPEG at a reduced scale directly).
    static func decode(source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// `extractArea` — `rect` is in original pixels; the bitmap may be downsampled.
    static func crop(_ image: CGImage, to rect: CGRect, originalSize: CGSize) -> CGImage {
        guard rect.size != originalSize else { return image }
        let sx = CGFloat(image.width) / originalSize.width
        let sy = CGFloat(image.height) / originalSize.height
        let scaled = CGRect(x: rect.minX * sx, y: rect.minY * sy, width: rect.width * sx, height: rect.height * sy)
            .integral
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return image.cropping(to: scaled) ?? image
    }

    /// Port of libvips `find_trim` (used by `CropBordersStep`): background = top-left pixel, a pixel is
    /// "content" when any channel differs by more than `threshold`. Analysed on a ≤512 px thumbnail.
    /// Returns nil when no meaningful border exists (or the page is blank).
    static func findTrim(in thumb: CGImage, originalSize: CGSize, threshold: Int = 24) -> CGRect? {
        let width = thumb.width, height = thumb.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { return false }
            context.draw(thumb, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        let bg = (Int(pixels[0]), Int(pixels[1]), Int(pixels[2]))
        func isContent(_ x: Int, _ y: Int) -> Bool {
            let i = (y * width + x) * 4
            return abs(Int(pixels[i]) - bg.0) > threshold || abs(Int(pixels[i + 1]) - bg.1) > threshold
                || abs(Int(pixels[i + 2]) - bg.2) > threshold
        }
        func rowHasContent(_ y: Int) -> Bool { (0..<width).contains { isContent($0, y) } }
        func columnHasContent(_ x: Int, _ rows: ClosedRange<Int>) -> Bool { rows.contains { isContent(x, $0) } }

        guard let top = (0..<height).first(where: rowHasContent),
              let bottom = (0..<height).reversed().first(where: rowHasContent)
        else { return nil }
        let rows = top...bottom
        guard let left = (0..<width).first(where: { columnHasContent($0, rows) }),
              let right = (0..<width).reversed().first(where: { columnHasContent($0, rows) })
        else { return nil }

        let sx = originalSize.width / CGFloat(width)
        let sy = originalSize.height / CGFloat(height)
        let rect = CGRect(
            x: CGFloat(left) * sx, y: CGFloat(top) * sy,
            width: CGFloat(right - left + 1) * sx, height: CGFloat(bottom - top + 1) * sy
        ).integral.intersection(CGRect(origin: .zero, size: originalSize))
        // Ignore trims that would remove almost nothing or almost everything.
        let kept = (rect.width * rect.height) / (originalSize.width * originalSize.height)
        guard kept < 0.98, kept > 0.2 else { return nil }
        return rect
    }
}
