import Foundation

/// A 2D point or vector in layout coordinates (origin top-left, y down).
public struct Vec2: Equatable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }

    public var length: Double { (x * x + y * y).squareRoot() }

    public var normalized: Vec2 {
        let len = length
        return len > 0 ? Vec2(x / len, y / len) : .zero
    }

    public func distance(to other: Vec2) -> Double { (self - other).length }
    public func dot(_ other: Vec2) -> Double { x * other.x + y * other.y }
    public func lerp(to other: Vec2, _ t: Double) -> Vec2 { self + (other - self) * t }
}

/// An axis-aligned rectangle in layout coordinates.
public struct Box: Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var center: Vec2 { Vec2(x + width / 2, y + height / 2) }

    public func grown(by amount: Double) -> Box {
        Box(x: x - amount, y: y - amount, width: width + 2 * amount, height: height + 2 * amount)
    }

    public func contains(_ p: Vec2) -> Bool {
        p.x >= x && p.x <= maxX && p.y >= y && p.y <= maxY
    }
}
