import SwiftUI

// MARK: - iPod-style button that shows blue highlight on press

struct IPodButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? AnyShapeStyle(IPodTheme.highlightGradient) : AnyShapeStyle(Color.clear))
            .environment(\.ipodIsPressed, configuration.isPressed)
    }
}

// Environment key to pass press state to children
private struct IPodIsPressedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var ipodIsPressed: Bool {
        get { self[IPodIsPressedKey.self] }
        set { self[IPodIsPressedKey.self] = newValue }
    }
}

// MARK: - Menu row

struct IPodMenuRow: View {
    let label: String
    var icon: String? = nil
    var showChevron: Bool = true

    @Environment(\.ipodIsPressed) private var isPressed

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isPressed ? IPodTheme.textOnHighlight : IPodTheme.textPrimary)
                    .frame(width: 24)
            }

            Text(label)
                .font(IPodTheme.font(16))
                .foregroundColor(isPressed ? IPodTheme.textOnHighlight : IPodTheme.textPrimary)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isPressed ? IPodTheme.textOnHighlight.opacity(0.7) : IPodTheme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Track row (artwork + metadata)

struct IPodTrackRow: View {
    let track: AudioTrack

    @Environment(\.ipodIsPressed) private var isPressed

    var body: some View {
        HStack(spacing: 10) {
            IPodArtworkView(artworkData: track.artworkData)
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(IPodTheme.font(15))
                    .foregroundColor(isPressed ? IPodTheme.textOnHighlight : IPodTheme.textPrimary)
                    .lineLimit(1)
                Text(track.artist ?? "Unknown Artist")
                    .font(IPodTheme.font(12))
                    .foregroundColor(isPressed ? IPodTheme.textOnHighlight.opacity(0.8) : IPodTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Title bar

struct IPodTitleBar: View {
    let title: String

    var body: some View {
        Text(title)
            .font(IPodTheme.font(17, weight: .bold))
            .foregroundColor(IPodTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(IPodTheme.titleBarGradient)
            .overlay(
                VStack {
                    Divider().background(IPodTheme.separatorColor)
                    Spacer()
                    Divider().background(IPodTheme.separatorColor)
                }
            )
    }
}

// MARK: - Separator

struct IPodSeparator: View {
    var body: some View {
        Rectangle()
            .fill(IPodTheme.separatorColor)
            .frame(height: 0.5)
            .padding(.leading, 12)
    }
}
