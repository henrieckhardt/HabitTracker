import SwiftUI

/// A single icon/title/message page, reused for the two purely explanatory
/// onboarding pages (the app's backbone, Focus). The permission-priming and
/// starter-habit pages are their own views since they need real state and
/// controls, not just text.
struct OnboardingPageView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .padding(.bottom, 40)
    }
}
