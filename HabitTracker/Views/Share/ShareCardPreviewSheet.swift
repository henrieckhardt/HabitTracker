import SwiftUI

/// A live, scaled-down preview of a share card plus a `ShareLink` to send
/// it — the one presentation every card type (habit streak, weekly
/// review, focus session) is shown through.
///
/// `card()` is called twice: once directly in the view hierarchy for the
/// on-screen preview, and once inside `.task` for the actual off-screen
/// PNG render. `ShareLink`'s `Transferable` item has to be a concrete file
/// already on disk, not a live view, so re-rendering the same content
/// off-screen is simpler than trying to snapshot the preview instance
/// that's already on screen.
struct ShareCardPreviewSheet<CardContent: View>: View {
    @Environment(\.dismiss) private var dismiss
    let fileName: String
    @ViewBuilder let card: () -> CardContent

    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                card()
                    .scaleEffect(0.8)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
                Spacer()
                if let exportURL, let preview = UIImage(contentsOfFile: exportURL.path) {
                    ShareLink(item: exportURL, preview: SharePreview(fileName, image: Image(uiImage: preview))) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                } else {
                    ProgressView()
                        .padding()
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                exportURL = ShareCardRenderer.writeTemporaryPNG(named: fileName) { card() }
            }
        }
    }
}
