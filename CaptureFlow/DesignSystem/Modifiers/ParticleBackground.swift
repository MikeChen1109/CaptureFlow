import SwiftUI

extension View {
    func captureFlowParticleBackground(
        count: Int = 240,
        opacityRange: ClosedRange<Double> = 0.04...0.42
    ) -> some View {
        modifier(
            CaptureFlowParticleBackground(
                count: count,
                opacityRange: opacityRange
            )
        )
    }
}

private struct CaptureFlowParticleBackground: ViewModifier {
    let count: Int
    let opacityRange: ClosedRange<Double>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    CFColors.background.ignoresSafeArea()

                    ParticleBackground(
                        count: count,
                        config: .init(
                            sizeRange: 1.4...4.2,
                            sharpBlurRange: 0...0.6,
                            softBlurRange: 1.6...4.8,
                            speedRange: 0.55...1.05,
                            opacityRange: opacityRange,
                            driftXRange: 0.015...0.07,
                            driftYRange: 0.035...0.14,
                            fps: 30,
                            color: CFColors.destructive
                        ),
                        isAnimated: !reduceMotion
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }
    }
}

struct ParticleBackground: View {
    struct Config {
        var sizeRange: ClosedRange<CGFloat> = 2...6
        var sharpBlurRange: ClosedRange<CGFloat> = 0...0.8
        var softBlurRange: ClosedRange<CGFloat> = 2...4
        var speedRange: ClosedRange<Double> = 0.8...1.2
        var opacityRange: ClosedRange<Double> = 0.1...0.8
        var driftXRange: ClosedRange<Double> = 0.01...0.07
        var driftYRange: ClosedRange<Double> = 0.04...0.16
        var fps: Double = 30
        var color: Color = CFColors.orangeHighlight
    }

    var width: CGFloat?
    var height: CGFloat?
    var count: Int
    var config: Config
    var isAnimated: Bool

    private let referenceDate = Date()
    private let particles: [Particle]

    init(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        count: Int = 70,
        config: Config = .init(),
        isAnimated: Bool = true
    ) {
        self.width = width
        self.height = height
        self.count = count
        self.config = config
        self.isAnimated = isAnimated
        self.particles = Particle.makeParticles(count: count, config: config)
    }

    var body: some View {
        Group {
            if width == nil && height == nil {
                particleLayer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            } else {
                particleLayer
                    .frame(width: width, height: height)
                    .clipped()
            }
        }
    }

    private var particleLayer: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / max(config.fps, 1))) { timeline in
                let time = isAnimated ? timeline.date.timeIntervalSince(referenceDate) : 0

                ZStack {
                    ForEach(particles) { particle in
                        let px = clamp(
                            particle.x + particle.driftX * sin(time * particle.speed + particle.phase),
                            0,
                            1
                        )
                        let py = clamp(
                            particle.y + particle.driftY * cos(time * particle.speed * 1.3 + particle.phase),
                            0,
                            1
                        )
                        let opacity = particle.opacity * (0.7 + 0.3 * sin(time * particle.speed * 2.1 + particle.phase))

                        Circle()
                            .fill(config.color)
                            .frame(width: particle.size, height: particle.size)
                            .blur(radius: particle.blur)
                            .opacity(opacity)
                            .position(x: px * geometry.size.width, y: py * geometry.size.height)
                    }
                }
                .drawingGroup()
            }
        }
    }

    private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}

private struct Particle: Identifiable {
    let id: Int
    let x: Double
    let y: Double
    let size: CGFloat
    let blur: CGFloat
    let opacity: Double
    let speed: Double
    let phase: Double
    let driftX: Double
    let driftY: Double

    static func makeParticles(count: Int, config: ParticleBackground.Config) -> [Particle] {
        (0..<count).map { index in
            let seed = Double(index + 1)
            let blur = normalized(seed * 7.193) > 0.62
                ? sample(config.softBlurRange, seed: seed * 19.191)
                : sample(config.sharpBlurRange, seed: seed * 19.191)

            return Particle(
                id: index,
                x: normalized(seed * 12.9898),
                y: normalized(seed * 78.233),
                size: sample(config.sizeRange, seed: seed * 37.719),
                blur: blur,
                opacity: sample(config.opacityRange, seed: seed * 91.173),
                speed: sample(config.speedRange, seed: seed * 63.731),
                phase: normalized(seed * 45.164) * .pi * 2,
                driftX: sample(config.driftXRange, seed: seed * 21.817),
                driftY: sample(config.driftYRange, seed: seed * 11.413)
            )
        }
    }

    private static func sample(_ range: ClosedRange<CGFloat>, seed: Double) -> CGFloat {
        range.lowerBound + CGFloat(normalized(seed)) * (range.upperBound - range.lowerBound)
    }

    private static func sample(_ range: ClosedRange<Double>, seed: Double) -> Double {
        range.lowerBound + normalized(seed) * (range.upperBound - range.lowerBound)
    }

    private static func normalized(_ value: Double) -> Double {
        let raw = sin(value) * 43_758.5453
        return raw - floor(raw)
    }
}
