/// A track as a polyline, addressed by arc length from its start.
public struct Track {
    public let points: [Vec2]
    public let length: Double
    private let cumulative: [Double]

    public init(points: [Vec2]) {
        self.points = points
        var cumulative: [Double] = []
        var total = 0.0
        for i in points.indices {
            if i > 0 {
                total += points[i].distance(to: points[i - 1])
            }
            cumulative.append(total)
        }
        self.cumulative = cumulative
        length = total
    }

    public func position(at s: Double) -> Vec2 {
        guard let first = points.first, let last = points.last else { return .zero }
        if s <= 0 { return first }
        if s >= length { return last }
        // First index whose cumulative length is >= s.
        var lo = 1
        var hi = points.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if cumulative[mid] < s {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        let segment = cumulative[lo] - cumulative[lo - 1]
        let t = segment <= 0 ? 0 : (s - cumulative[lo - 1]) / segment
        return points[lo - 1].lerp(to: points[lo], t)
    }

    /// Unit direction of travel at arc length s.
    public func tangent(at s: Double) -> Vec2 {
        (position(at: s + 2) - position(at: s - 2)).normalized
    }
}
