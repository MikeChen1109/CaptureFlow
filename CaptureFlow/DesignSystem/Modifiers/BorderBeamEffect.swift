import SwiftUI

extension View {
    func borderBeam(
        border: Color,
        beam: [Color],
        beamBlur: CGFloat,
        cornerRadius: CGFloat,
        isEnabled: Bool = true
    ) -> some View {
        modifier(
            BorderBeamEffect(
                border: border,
                beam: beam,
                beamBlur: beamBlur,
                cornerRadius: cornerRadius,
                isEnabled: isEnabled
            )
        )
    }
}

struct BorderBeamEffect: ViewModifier {
    var border: Color
    var beam: [Color]
    var beamBlur: CGFloat
    var cornerRadius: CGFloat
    var isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isEnabled {
                    BorderBeamOverlay(
                        border: border,
                        beam: beam,
                        beamBlur: beamBlur,
                        cornerRadius: cornerRadius
                    )
                    .allowsHitTesting(false)
                }
            }
    }
}

private struct BorderBeamOverlay: View {
    let border: Color
    let beam: [Color]
    let beamBlur: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(border.opacity(0.35), lineWidth: 0.6)

            KeyframeAnimator(initialValue: 0.0, repeating: true) { value in
                let rotation = value * 360
                let borderGradient = AngularGradient(
                    colors: [.clear, border, .clear],
                    center: .center,
                    startAngle: .degrees(140 + rotation),
                    endAngle: .degrees(270 + rotation)
                )
                let beamGradient = LinearGradient(
                    colors: beamColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(beamGradient)
                        .mask {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(borderGradient, lineWidth: beamLineWidth)
                                .blur(radius: beamBlur / 1.5)
                                .padding(-beamBlur * 2)
                        }

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(borderGradient, lineWidth: 0.6)
                }
            } keyframes: { _ in
                LinearKeyframe(1, duration: 2.5)
            }
        }
        .padding(0.5)
    }

    private var beamColors: [Color] {
        beam.isEmpty ? [.clear] : beam
    }

    private var beamLineWidth: CGFloat {
        max(beamBlur * 2, 1)
    }
}
