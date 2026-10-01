import Foundation
import simd

/// Naive-Bayes archetype classifier over measured geometry.
///
///     score(a) = ln P(label | a)
///              + sum_k  -1/2 * ((ln x_k - ln mu_k) / sigma_k)^2      x = (long side, short side, height)
///              + -1/2 * ((s - mu_s) / sigma_s)^2                      s = functional surface height
///              + ln P(near wall | a)
///     P(a | obs) = softmax(score)
///
/// Log-normal size terms make the model scale-relative: 10 cm matters for a stool, not a bed.
/// Footprint sides are sorted so the score does not depend on the chosen front.
public struct ArchetypePrior: Sendable, Codable, Hashable {
    public var archetype: Archetype
    public var labels: [SurfaceLabel: Float]
    /// Typical (long side, short side, height) in meters.
    public var size: SIMD3<Float>
    /// Log-space standard deviation per size component.
    public var sigma: SIMD3<Float>
    public var surface: Float?
    public var surfaceSigma: Float
    /// Probability the object backs onto a wall.
    public var wallAffinity: Float

    public init(_ archetype: Archetype, labels: [SurfaceLabel: Float], size: SIMD3<Float>, sigma: SIMD3<Float>,
                surface: Float? = nil, surfaceSigma: Float = 0.08, wallAffinity: Float = 0.5) {
        self.archetype = archetype
        self.labels = labels
        self.size = size
        self.sigma = sigma
        self.surface = surface
        self.surfaceSigma = surfaceSigma
        self.wallAffinity = wallAffinity
    }
}

public struct ArchetypeClassifier: Sendable {
    public var priors: [ArchetypePrior]

    public init(priors: [ArchetypePrior] = ArchetypeClassifier.defaultPriors) { self.priors = priors }

    public struct Observation: Sendable {
        public var label: SurfaceLabel
        public var size: SIMD3<Float>
        public var surface: Float?
        public var nearWall: Bool
        public init(label: SurfaceLabel, size: SIMD3<Float>, surface: Float?, nearWall: Bool) {
            self.label = label; self.size = size; self.surface = surface; self.nearWall = nearWall
        }
    }

    public func logScore(_ p: ArchetypePrior, _ o: Observation) -> Float {
        let long = max(o.size.x, o.size.z), short = min(o.size.x, o.size.z)
        let x = SIMD3(max(long, 0.02), max(short, 0.02), max(o.size.y, 0.02))
        let z = (SIMD3(log(x.x), log(x.y), log(x.z)) - SIMD3(log(p.size.x), log(p.size.y), log(p.size.z))) / p.sigma
        var s = log(p.labels[o.label] ?? 0.01) - 0.5 * simd_length_squared(z)
        if let mu = p.surface, let obs = o.surface {
            let d = (obs - mu) / p.surfaceSigma
            s -= 0.5 * min(d * d, 16)
        }
        s += log(o.nearWall ? p.wallAffinity : 1 - p.wallAffinity)
        return s
    }

    /// Candidates sorted by posterior probability.
    public func classify(_ o: Observation) -> [DetectedObject.Candidate] {
        let scores = priors.map { logScore($0, o) }
        guard let mx = scores.max() else { return [] }
        let ex = scores.map { exp($0 - mx) }
        let z = ex.reduce(0, +)
        return zip(priors, ex).map { DetectedObject.Candidate(archetype: $0.archetype, probability: $1 / z) }
            .sorted { $0.probability > $1.probability }
    }

    public static let defaultPriors: [ArchetypePrior] = [
        .init(.diningTable, labels: [.table: 1], size: [1.5, 0.9, 0.75], sigma: [0.3, 0.3, 0.12], surface: 0.75, surfaceSigma: 0.06, wallAffinity: 0.3),
        .init(.coffeeTable, labels: [.table: 1], size: [1.0, 0.55, 0.42], sigma: [0.35, 0.35, 0.2], surface: 0.42, wallAffinity: 0.15),
        .init(.sideTable, labels: [.table: 0.8, .cabinet: 0.3], size: [0.5, 0.45, 0.58], sigma: [0.3, 0.3, 0.2], surface: 0.58, surfaceSigma: 0.1, wallAffinity: 0.6),
        .init(.desk, labels: [.table: 1], size: [1.3, 0.65, 0.75], sigma: [0.25, 0.25, 0.1], surface: 0.74, surfaceSigma: 0.05, wallAffinity: 0.85),
        .init(.counter, labels: [.table: 0.7, .cabinet: 0.6], size: [2.0, 0.62, 0.92], sigma: [0.45, 0.2, 0.08], surface: 0.92, surfaceSigma: 0.05, wallAffinity: 0.9),
        .init(.chair, labels: [.seat: 1], size: [0.5, 0.5, 0.88], sigma: [0.2, 0.2, 0.15], surface: 0.46, surfaceSigma: 0.06, wallAffinity: 0.3),
        .init(.armchair, labels: [.seat: 1], size: [0.85, 0.8, 0.9], sigma: [0.2, 0.2, 0.15], surface: 0.44, surfaceSigma: 0.07, wallAffinity: 0.4),
        .init(.sofa, labels: [.seat: 1], size: [2.0, 0.9, 0.85], sigma: [0.3, 0.2, 0.15], surface: 0.43, surfaceSigma: 0.07, wallAffinity: 0.6),
        .init(.stool, labels: [.seat: 0.8, .table: 0.2], size: [0.4, 0.38, 0.6], sigma: [0.25, 0.25, 0.35], wallAffinity: 0.2),
        .init(.bed, labels: [.bed: 1, .seat: 0.1], size: [2.0, 1.5, 0.6], sigma: [0.15, 0.3, 0.3], surface: 0.55, surfaceSigma: 0.12, wallAffinity: 0.9),
        .init(.lowCabinet, labels: [.cabinet: 1, .table: 0.1, .homeAppliance: 0.1], size: [1.0, 0.5, 0.85], sigma: [0.4, 0.3, 0.25], wallAffinity: 0.9),
        .init(.wardrobe, labels: [.cabinet: 1], size: [1.1, 0.6, 2.0], sigma: [0.35, 0.3, 0.12], wallAffinity: 0.95),
        .init(.shelf, labels: [.cabinet: 0.8], size: [0.9, 0.35, 1.8], sigma: [0.35, 0.3, 0.25], wallAffinity: 0.95),
        .init(.appliance, labels: [.homeAppliance: 1, .cabinet: 0.2], size: [0.6, 0.6, 0.88], sigma: [0.25, 0.25, 0.15], wallAffinity: 0.9),
        .init(.tallAppliance, labels: [.homeAppliance: 1, .cabinet: 0.2], size: [0.75, 0.72, 1.8], sigma: [0.2, 0.2, 0.12], wallAffinity: 0.9),
        .init(.tv, labels: [.tv: 1, .homeAppliance: 0.1], size: [1.2, 0.12, 0.7], sigma: [0.4, 0.8, 0.35], wallAffinity: 0.9),
        .init(.plant, labels: [.plant: 1], size: [0.5, 0.45, 0.9], sigma: [0.6, 0.6, 0.6], wallAffinity: 0.5),
        .init(.stairs, labels: [.stairs: 1], size: [2.5, 1.0, 2.0], sigma: [0.6, 0.6, 0.6], wallAffinity: 0.5),
        .init(.clutter, labels: [.none: 1, .table: 0.02, .seat: 0.02, .cabinet: 0.02, .homeAppliance: 0.02],
              size: [0.5, 0.4, 0.5], sigma: [1.0, 1.0, 1.0], wallAffinity: 0.5),
    ]
}
