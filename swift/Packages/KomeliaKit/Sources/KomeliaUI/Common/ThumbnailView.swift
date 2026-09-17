import KomeliaCore
import SwiftUI

extension EnvironmentValues {
    /// Injected by the composition root; nil in previews (placeholder shown).
    @Entry public var thumbnailLoader: ThumbnailLoader?
}

/// Cover/thumbnail cell image (Coil `AsyncImage` equivalent).
public struct ThumbnailView: View {
    let request: ThumbnailRequest
    var contentMode: ContentMode = .fill

    @Environment(\.thumbnailLoader) private var loader
    @Environment(\.displayScale) private var displayScale
    @State private var image: DecodedImage?
    @State private var failed = false

    public init(_ request: ThumbnailRequest, contentMode: ContentMode = .fill) {
        self.request = request
        self.contentMode = contentMode
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle().fill(.quaternary)
                if let image {
                    Image(decorative: image.cgImage, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .transition(.opacity)
                } else if failed {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .task(id: TaskKey(request: request, maxPixelSize: pixelSize(for: proxy.size))) {
                await load(maxPixelSize: pixelSize(for: proxy.size))
            }
        }
    }

    private struct TaskKey: Hashable {
        let request: ThumbnailRequest
        let maxPixelSize: Int
    }

    /// Buckets the target size so small layout changes reuse the cached decode.
    private func pixelSize(for size: CGSize) -> Int {
        let longest = max(size.width, size.height) * displayScale
        return max(128, Int((longest / 128).rounded(.up)) * 128)
    }

    private func load(maxPixelSize: Int) async {
        guard let loader else { return }
        do {
            let loaded = try await loader.image(for: request, maxPixelSize: maxPixelSize)
            withAnimation(.easeOut(duration: 0.15)) {
                image = loaded
                failed = loaded == nil
            }
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}
