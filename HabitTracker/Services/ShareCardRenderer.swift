import SwiftUI

/// Renders a share card view into a PNG file, off-screen and at a fixed
/// pixel size — independent of the exporting device's actual screen size
/// or Dynamic Type setting, so the same card looks identical no matter
/// which device produced it.
///
/// Cards are built at `cardPointSize` (a 4:5 portrait ratio, the safest
/// aspect for both Instagram feed/story and Messages/Files previews) and
/// rendered at `renderScale`, producing exactly 1080×1350px output.
enum ShareCardRenderer {
    static let cardPointSize = CGSize(width: 360, height: 450)
    static let renderScale: CGFloat = 3

    @MainActor
    static func renderPNG<Content: View>(@ViewBuilder content: () -> Content) -> Data? {
        let renderer = ImageRenderer(content: content().frame(width: cardPointSize.width, height: cardPointSize.height))
        renderer.scale = renderScale
        renderer.isOpaque = false
        guard let uiImage = renderer.uiImage else { return nil }
        return uiImage.pngData()
    }

    /// Writes the rendered PNG to a uniquely-named temp file and returns
    /// its URL, for `ShareLink` — the same "render once, hand off a file
    /// URL" pattern `DataExportService.exportURL` already uses.
    @MainActor
    static func writeTemporaryPNG<Content: View>(named name: String, @ViewBuilder content: () -> Content) -> URL? {
        guard let data = renderPNG(content: content) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(Int(Date.now.timeIntervalSince1970))")
            .appendingPathExtension("png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
