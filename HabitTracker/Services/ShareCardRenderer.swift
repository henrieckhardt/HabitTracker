import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

/// A rendered card's PNG bytes, typed as `.png` for `ShareLink`. Sharing a
/// plain file `URL` only ever offers "Save to Files" — the receiving
/// extension has no way to tell a generic file is actually an image.
/// Declaring the transfer as `.png` data is what makes Photos' "Save
/// Image" show up alongside it.
struct ShareCardPNG: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}

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
}
