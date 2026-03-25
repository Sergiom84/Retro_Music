import SwiftUI

struct IPodProgressBar: View {
    var progress: Double // 0...1
    var currentTime: TimeInterval
    var totalDuration: TimeInterval

    private let blockCount = 30
    private let blockSpacing: CGFloat = 1.5

    var body: some View {
        VStack(spacing: 4) {
            // Segmented bar
            GeometryReader { geo in
                let filledBlocks = Int(Double(blockCount) * min(max(progress, 0), 1))
                HStack(spacing: blockSpacing) {
                    ForEach(0..<blockCount, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(i < filledBlocks ? IPodTheme.progressFill : IPodTheme.progressBackground)
                    }
                }
                .frame(height: geo.size.height)
            }
            .frame(height: 8)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(IPodTheme.progressBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))

            // Time labels
            HStack {
                Text(formatTime(currentTime))
                    .font(IPodTheme.font(10))
                    .foregroundColor(IPodTheme.textSecondary)
                Spacer()
                Text("-\(formatTime(totalDuration - currentTime))")
                    .font(IPodTheme.font(10))
                    .foregroundColor(IPodTheme.textSecondary)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let total = max(0, Int(time))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
