import SwiftUI

struct IPodProgressBar: View {
    var progress: Double // 0...1
    var currentTime: TimeInterval
    var totalDuration: TimeInterval
    var isInteractive: Bool = false
    var onSeekRequested: ((Double) -> Void)? = nil

    @State private var sliderProgress: Double?

    var body: some View {
        VStack(spacing: 4) {
            if isInteractive {
                Slider(
                    value: Binding(
                        get: { sliderProgress ?? clampedProgress },
                        set: { sliderProgress = min(max($0, 0), 1) }
                    ),
                    in: 0...1,
                    onEditingChanged: handleSliderEditingChanged
                )
                .disabled(totalDuration <= 0)
                .tint(IPodTheme.progressFill)
            } else {
                GeometryReader { geo in
                    let currentWidth = max(12, geo.size.width * displayProgress)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(IPodTheme.progressBackground)

                        Capsule()
                            .fill(IPodTheme.progressFill)
                            .frame(width: currentWidth)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(IPodTheme.highlightEnd.opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                            .offset(x: min(max(0, currentWidth - 6), max(0, geo.size.width - 12)))
                    }
                }
                .frame(height: 14)
            }

            HStack {
                Text(formatTime(displayCurrentTime))
                    .font(IPodTheme.font(10))
                    .foregroundColor(IPodTheme.textSecondary)
                Spacer()
                Text(remainingTimeLabel)
                    .font(IPodTheme.font(10))
                    .foregroundColor(IPodTheme.textSecondary)
            }
        }
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var displayProgress: Double {
        min(max(sliderProgress ?? clampedProgress, 0), 1)
    }

    private var displayCurrentTime: TimeInterval {
        guard totalDuration > 0 else { return currentTime }
        return totalDuration * displayProgress
    }

    private var remainingTimeLabel: String {
        guard totalDuration > 0 else { return "--:--" }
        return "-\(formatTime(totalDuration - displayCurrentTime))"
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        guard !isEditing else { return }
        guard let sliderProgress else { return }
        guard totalDuration > 0 else {
            self.sliderProgress = nil
            return
        }
        onSeekRequested?(sliderProgress)
        self.sliderProgress = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let total = max(0, Int(time))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
