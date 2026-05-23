import SwiftUI

extension View {
    @ViewBuilder
    func cfGlassCapsule(
        tint: Color = CFColors.secondarySurface.opacity(0.36),
        isInteractive: Bool = true
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular.tint(tint).interactive(isInteractive),
                in: Capsule(style: .continuous)
            )
        } else {
            self.background(.ultraThinMaterial, in: Capsule(style: .continuous))
        }
    }

    @ViewBuilder
    func cfGlassCircle(
        tint: Color = CFColors.secondarySurface.opacity(0.36),
        isInteractive: Bool = true
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular.tint(tint).interactive(isInteractive),
                in: Circle()
            )
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }
}
