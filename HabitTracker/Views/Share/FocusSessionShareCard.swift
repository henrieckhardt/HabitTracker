import SwiftUI

/// "I just focused for N minutes" — shown right after a linked focus run
/// ends (see `RootTabView`'s "Focus Ended" dialog), while the sense of
/// having actually done the thing is freshest.
struct FocusSessionShareCard: View {
    let run: FocusRun

    private var minutes: Int {
        guard let endedAt = run.endedAt else { return 0 }
        return max(0, Int(endedAt.timeIntervalSince(run.startedAt) / 60))
    }

    private var durationText: String {
        let hours = minutes / 60
        let mins = minutes % 60
        switch (hours, mins) {
        case (0, _): return String(localized: "\(mins) min")
        case (_, 0): return String(localized: "\(hours) hr")
        default: return String(localized: "\(hours) hr \(mins) min")
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: run.startedAt)
    }

    var body: some View {
        ShareCardFrame {
            VStack(spacing: 20) {
                Image(systemName: "timer")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())

                Text(run.linkedTitle ?? run.sessionTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                VStack(spacing: 2) {
                    Text(durationText)
                        .font(.system(size: 52, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Focused")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .textCase(.uppercase)
                        .tracking(1)
                }

                Text(dateText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}
