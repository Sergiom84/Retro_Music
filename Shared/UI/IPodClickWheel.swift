#if os(iOS)
import SwiftUI

struct IPodClickWheel: View {
    var onMenu: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onSelect: (() -> Void)?

    private let outerSize: CGFloat = 280
    private let innerSize: CGFloat = 100

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.78),
                            Color(white: 0.72),
                            Color(white: 0.68)
                        ],
                        center: .center,
                        startRadius: innerSize / 2,
                        endRadius: outerSize / 2
                    )
                )
                .frame(width: outerSize, height: outerSize)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

            // Tap zones overlay
            VStack(spacing: 0) {
                // MENU (top)
                Button(action: { onMenu?() }) {
                    Text("MENU")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(white: 0.35))
                        .frame(maxWidth: .infinity)
                        .frame(height: outerSize * 0.22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ClickWheelZoneStyle())

                HStack(spacing: 0) {
                    // Previous (left)
                    Button(action: { onPrevious?() }) {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(white: 0.35))
                            .frame(width: outerSize * 0.22, height: outerSize * 0.56)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ClickWheelZoneStyle())

                    Spacer()

                    // Next (right)
                    Button(action: { onNext?() }) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(white: 0.35))
                            .frame(width: outerSize * 0.22, height: outerSize * 0.56)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ClickWheelZoneStyle())
                }

                // Play/Pause (bottom)
                Button(action: { onPlayPause?() }) {
                    Image(systemName: "playpause.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(white: 0.35))
                        .frame(maxWidth: .infinity)
                        .frame(height: outerSize * 0.22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ClickWheelZoneStyle())
            }
            .frame(width: outerSize, height: outerSize)

            // Center button
            Button(action: { onSelect?() }) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(white: 0.92),
                                Color(white: 0.85),
                                Color(white: 0.82)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: innerSize / 2
                        )
                    )
                    .frame(width: innerSize, height: innerSize)
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
            }
            .buttonStyle(CenterButtonStyle())
        }
    }
}

private struct ClickWheelZoneStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

private struct CenterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
#endif
