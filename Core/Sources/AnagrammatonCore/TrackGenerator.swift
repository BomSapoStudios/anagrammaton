import Foundation

/// Procedural tracks from shape families, with random parameters. A candidate
/// is rejected and regenerated if parallel stretches are too close, it passes
/// too near the shooter, or it leaves the play area.
public final class TrackGenerator {
    public enum Family {
        case serpentine
        case spiral
    }

    static let maxAttempts = 40
    static let minGap = 1.3          // parallel stretches, in bubble diameters
    static let minShooterGap = 2.5   // track to shooter, in bubble diameters
    static let minLength = 20.0      // in bubble diameters

    private var rng: SeededGenerator

    public init(seed: UInt64) {
        rng = SeededGenerator(seed: seed)
    }

    public func generate(_ family: Family, area: Box, shooter: Vec2, diameter: Double) -> Track? {
        for _ in 0..<Self.maxAttempts {
            let points: [Vec2]
            switch family {
            case .serpentine: points = serpentine(area, diameter)
            case .spiral: points = spiral(area, diameter)
            }
            if Self.isValid(points, area: area, shooter: shooter, diameter: diameter) {
                return Track(points: points)
            }
        }
        return nil
    }

    public static func isValid(_ points: [Vec2], area: Box, shooter: Vec2, diameter: Double) -> Bool {
        let track = Track(points: points)
        guard track.length >= diameter * minLength else { return false }
        var samples: [Vec2] = []
        var arcs: [Double] = []
        var s = 0.0
        while s <= track.length {
            samples.append(track.position(at: s))
            arcs.append(s)
            s += diameter * 0.5
        }
        let bounds = area.grown(by: diameter)
        for i in samples.indices {
            let p = samples[i]
            if p.distance(to: shooter) < diameter * minShooterGap || !bounds.contains(p) {
                return false
            }
            for j in (i + 1)..<samples.count
            where arcs[j] - arcs[i] > diameter * 3 && p.distance(to: samples[j]) < diameter * minGap {
                return false
            }
        }
        return true
    }

    private func random(_ range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &rng)
    }

    /// Back-and-forth rows filling the area from the top down, entering from
    /// the left edge. The hole is at the end of the lowest row, nearest the
    /// shooter.
    private func serpentine(_ area: Box, _ diameter: Double) -> [Vec2] {
        let gap = diameter * random(1.5...1.9)
        let rows = max(3, Int((area.height - diameter * 2) / gap) + 1)
        let radius = gap / 2
        let left = area.x + radius + diameter * random(0.6...1.4)
        let right = area.maxX - radius - diameter * random(0.6...1.4)
        var y = area.y + diameter
        var points = [Vec2(area.x - diameter * 0.5, y)]
        var goingRight = true
        for row in 0..<rows {
            var xEnd = goingRight ? right : left
            if row == rows - 1 {
                // Stop the last row short so the hole sits inside the screen.
                xEnd = goingRight ? left + (right - left) * 0.7 : left + (right - left) * 0.3
            }
            points.append(Vec2(xEnd, y))
            if row == rows - 1 { break }
            let side = goingRight ? 1.0 : -1.0
            for k in 1...16 {
                let a = -Double.pi / 2 + Double.pi * Double(k) / 16
                points.append(Vec2(xEnd + side * radius * cos(a), y + radius + radius * sin(a)))
            }
            y += gap
            goingRight.toggle()
        }
        return points
    }

    /// An inward spiral around the area's centre, where a rotating shooter
    /// sits.
    private func spiral(_ area: Box, _ diameter: Double) -> [Vec2] {
        let center = area.center
        let outer = min(area.width, area.height) / 2 - diameter * 0.6
        let inner = diameter * random(2.8...3.4)
        let ringGap = diameter * random(1.5...1.8)
        let maxAngle = (outer - inner) / ringGap * 2 * Double.pi
        let phase = random(0...(2 * Double.pi))
        let direction = rng.unit() < 0.5 ? 1.0 : -1.0
        var points: [Vec2] = []
        var angle = 0.0
        while angle <= maxAngle {
            let r = outer - ringGap * angle / (2 * Double.pi)
            let a = phase + direction * angle
            points.append(center + Vec2(cos(a), sin(a)) * r)
            angle += 0.04
        }
        return points
    }
}
