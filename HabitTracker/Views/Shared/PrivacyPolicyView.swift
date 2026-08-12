import SwiftUI
import WebKit

/// Renders the bundled `privacy.html` (also the source for GitHub Pages —
/// see `docs/privacy.html`) directly in-app, rather than linking out to a
/// URL whose hosting status this app has no way to guarantee. Since the
/// policy's entire point is "nothing leaves your device," serving it from
/// the app bundle itself is the more honest choice anyway.
struct PrivacyPolicyView: View {
    var body: some View {
        PrivacyWebView()
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        if let url = Bundle.main.url(forResource: "privacy", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
