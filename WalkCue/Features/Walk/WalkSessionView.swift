import SwiftUI

struct WalkSessionView: View {
    @ObservedObject var session: WalkSession
    @EnvironmentObject var history: HistoryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics

    var body: some View {
        VStack(spacing: 16) {
            topBar
            Spacer()
            elapsedBlock
            intervalBlock
            Spacer()
            controls
        }
        .padding(24)
        .background(Theme.cardBackground.ignoresSafeArea())
        .onAppear {
            if session.state == .idle { session.start() }
        }
        .onChange(of: session.state) { newValue in
            if newValue == .finished { finalize() }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                let summary = session.end()
                history.add(summary)
                analytics.track(.walkCompleted, properties: ["seconds": "\(summary.totalSeconds)"])
                dismiss()
            } label: {
                Label("End", systemImage: "xmark.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(session.engine.routine.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var elapsedBlock: some View {
        VStack(spacing: 4) {
            Text("Elapsed").font(.caption).foregroundStyle(.secondary)
            Text(TimeFormat.clock(session.elapsed))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    private var intervalBlock: some View {
        VStack(spacing: 8) {
            if let current = session.currentInterval {
                Text(current.label)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.accent)
                if !current.kind.paceHint.isEmpty {
                    Text(current.kind.paceHint)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Next cue in \(TimeFormat.clock(session.remainingInCurrent))")
                    .font(.headline)
                    .monospacedDigit()
                    .padding(.top, 8)
                if let next = session.nextInterval {
                    Text("Up next: \(next.label) · \(TimeFormat.compactDuration(Int(next.duration)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if session.state == .finished {
                Text("Nice work.")
                    .font(.title.weight(.bold))
                Text("Session complete.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            if session.state == .running {
                controlButton(label: "Pause", icon: "pause.circle.fill", color: .orange) {
                    session.pause()
                }
            } else if session.state == .paused {
                controlButton(label: "Resume", icon: "play.circle.fill", color: Theme.accent) {
                    session.resume()
                }
            }
            controlButton(label: "End", icon: "stop.circle.fill", color: .red) {
                let summary = session.end()
                history.add(summary)
                analytics.track(.walkCompleted, properties: ["seconds": "\(summary.totalSeconds)"])
                dismiss()
            }
        }
    }

    private func controlButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 44))
                Text(label).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func finalize() {
        let summary = session.summary()
        history.add(summary)
        analytics.track(.walkCompleted, properties: ["seconds": "\(summary.totalSeconds)"])
    }
}
