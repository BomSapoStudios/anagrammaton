import SpriteKit
import UIKit

/// A lettered stone marble.
final class BubbleNode: SKNode {
    private let marble: SKSpriteNode
    private let shadow = SKSpriteNode(texture: StoneStyle.shadow)
    private let label = SKLabelNode()
    private let fontSize: CGFloat
    private let ring: SKShapeNode
    private(set) var letter: Character?

    enum Glow {
        case none
        /// Part of a word the shooter's letter could complete.
        case hint
        /// Would pop if the shot were fired now.
        case pop
        /// Part of the level's hidden word.
        case target
    }

    var glow = Glow.none {
        didSet {
            guard glow != oldValue else { return }
            switch glow {
            case .none:
                ring.isHidden = true
            case .hint:
                ring.isHidden = false
                ring.strokeColor = StoneStyle.rgb(0xF2CF72).withAlphaComponent(0.75)
                ring.lineWidth = 3
            case .pop:
                ring.isHidden = false
                ring.strokeColor = .white
                ring.lineWidth = 5
            case .target:
                ring.isHidden = false
                ring.strokeColor = StoneStyle.rgb(0x7FE3F0)
                ring.lineWidth = 4
            }
        }
    }

    init(radius: CGFloat) {
        marble = SKSpriteNode(texture: nil, color: .white, size: CGSize(width: radius * 2, height: radius * 2))
        ring = SKShapeNode(circleOfRadius: radius + 2)
        fontSize = radius * 1.3
        super.init()
        ring.fillColor = .clear
        ring.glowWidth = 4
        ring.zPosition = 3
        ring.isHidden = true
        shadow.size = CGSize(width: radius * 2.3, height: radius * 2.3)
        shadow.position = CGPoint(x: radius * 0.12, y: -radius * 0.2)
        shadow.zPosition = -5
        addChild(shadow)
        addChild(marble)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        // Explicit layer: draw order between siblings at the same z isn't guaranteed.
        label.zPosition = 2
        addChild(label)
        addChild(ring)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func show(_ letter: Character) {
        guard letter != self.letter else { return }
        self.letter = letter
        let stone = StoneStyle.stone(for: letter)
        marble.texture = StoneStyle.marble(for: letter)
        // A bold sans serif with a contrasting outline reads on any stone.
        let font = UIFont(name: StoneStyle.letterFont, size: fontSize) ?? .systemFont(ofSize: fontSize, weight: .heavy)
        label.attributedText = NSAttributedString(string: String(letter).uppercased(), attributes: [
            .font: font,
            .foregroundColor: stone.ink,
            .strokeColor: stone.outline,
            // Negative width draws the outline and fills the letter.
            .strokeWidth: -5,
        ])
    }
}

/// A tappable rectangle with a label. Its `name` is the action it triggers.
final class ButtonNode: SKShapeNode {
    private let label = SKLabelNode(fontNamed: StoneStyle.uiFont)

    init(action: String, size: CGSize) {
        super.init()
        path = CGPath(roundedRect: CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size),
                      cornerWidth: 10, cornerHeight: 10, transform: nil)
        fillColor = StoneStyle.rgb(0x3B3833)
        strokeColor = StoneStyle.brass
        lineWidth = 2
        name = action
        label.fontSize = 26
        label.fontColor = StoneStyle.cream
        label.verticalAlignmentMode = .center
        label.name = action
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var text: String {
        get { label.text ?? "" }
        set { label.text = newValue }
    }
}


/// One kind of polished stone: its body colors, vein color and letter colors.
struct Stone {
    let light: UIColor
    let mid: UIColor
    let dark: UIColor
    let vein: UIColor
    let veins: Int
    let speckles: Int
    /// Light stones get dark carved letters; dark stones get a pale inlay.
    let carvedInk: Bool

    var ink: UIColor {
        carvedInk ? StoneStyle.rgb(0x14110E) : .white
    }

    var outline: UIColor {
        carvedInk ? UIColor(white: 1, alpha: 0.85) : UIColor(white: 0, alpha: 0.85)
    }
}

/// Procedural textures for the polished-stone look, drawn once and cached.
enum StoneStyle {
    static let letterFont = "AvenirNext-Heavy"
    static let uiFont = "Optima-Bold"
    static let cream = rgb(0xF4E6C2)
    static let brass = rgb(0xA88B5C)
    static let slate = rgb(0x2C2F34)

    static let stones: [Stone] = [
        // Carrara marble
        Stone(light: rgb(0xFDFCF8), mid: rgb(0xE6E3DC), dark: rgb(0xA9A398), vein: rgb(0x6F6B68),
              veins: 5, speckles: 0, carvedInk: true),
        // Jade
        Stone(light: rgb(0xA8E0BD), mid: rgb(0x3F9C6C), dark: rgb(0x174F35), vein: rgb(0x0E3423),
              veins: 6, speckles: 0, carvedInk: false),
        // Lapis lazuli with gold flecks
        Stone(light: rgb(0x7393E2), mid: rgb(0x23408F), dark: rgb(0x0F1C4C), vein: rgb(0xE2C36E),
              veins: 1, speckles: 26, carvedInk: false),
        // Carnelian
        Stone(light: rgb(0xF6AE88), mid: rgb(0xC24A2C), dark: rgb(0x631B10), vein: rgb(0xF8D9C2),
              veins: 4, speckles: 0, carvedInk: false),
        // Tiger's eye
        Stone(light: rgb(0xF8D88E), mid: rgb(0xC48A2E), dark: rgb(0x5E3A0E), vein: rgb(0x40260A),
              veins: 7, speckles: 0, carvedInk: true),
        // Rose quartz
        Stone(light: rgb(0xFDE8EB), mid: rgb(0xE6AAB3), dark: rgb(0x9E6070), vein: rgb(0xFFFFFF),
              veins: 3, speckles: 0, carvedInk: true),
        // Onyx
        Stone(light: rgb(0x5C5C63), mid: rgb(0x222226), dark: rgb(0x08080A), vein: rgb(0xCFCFD6),
              veins: 3, speckles: 0, carvedInk: false),
        // Amethyst
        Stone(light: rgb(0xD3BAF0), mid: rgb(0x7E56B4), dark: rgb(0x35205D), vein: rgb(0xEDE2F8),
              veins: 4, speckles: 0, carvedInk: false),
        // Turquoise with matrix
        Stone(light: rgb(0xBDF1E9), mid: rgb(0x46B4AA), dark: rgb(0x1B6460), vein: rgb(0x4E3B2A),
              veins: 5, speckles: 0, carvedInk: true),
        // Travertine
        Stone(light: rgb(0xF4E6CA), mid: rgb(0xD2B886), dark: rgb(0x86704B), vein: rgb(0x9C8257),
              veins: 2, speckles: 40, carvedInk: true),
    ]

    static func stone(for letter: Character) -> Stone {
        stones[(letterIndex(letter) * 7) % stones.count]
    }

    private static var marbleCache: [Character: SKTexture] = [:]

    /// The marble for a letter. Same letter, same stone and veining.
    static func marble(for letter: Character) -> SKTexture {
        if let texture = marbleCache[letter] { return texture }
        let texture = SKTexture(image: drawMarble(stone(for: letter), seed: UInt64(letterIndex(letter) + 1)))
        marbleCache[letter] = texture
        return texture
    }

    static let shadow: SKTexture = {
        let d: CGFloat = 64
        let image = renderer(CGSize(width: d, height: d)).image { ctx in
            let c = CGPoint(x: d / 2, y: d / 2)
            let gradient = makeGradient([UIColor(white: 0, alpha: 0.5), UIColor(white: 0, alpha: 0)], [0.55, 1])
            ctx.cgContext.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c,
                                             endRadius: d / 2, options: [])
        }
        return SKTexture(image: image)
    }()

    /// A dark slate table with faint grain and a vignette.
    static func board(size: CGSize) -> SKTexture {
        let image = renderer(size, scale: 1).image { ctx in
            let cg = ctx.cgContext
            let base = makeGradient([rgb(0x34373C), rgb(0x1C1E21)], [0, 1])
            cg.drawLinearGradient(base, start: .zero, end: CGPoint(x: size.width * 0.3, y: size.height), options: [])
            var random = Lcg(seed: 7)
            cg.setLineCap(.round)
            for _ in 0..<14 {
                let color = UIColor(white: 1, alpha: 0.025 + 0.03 * random.next())
                let width = 1 + 3 * random.next()
                strokeVein(cg, in: CGRect(origin: .zero, size: size), random: &random, color: color, width: width)
            }
            for _ in 0..<Int(size.width * size.height / 260) {
                let shade = random.next() < 0.5 ? UIColor(white: 1, alpha: 0.035) : UIColor(white: 0, alpha: 0.08)
                cg.setFillColor(shade.cgColor)
                let r = 0.6 + 1.6 * random.next()
                cg.fillEllipse(in: CGRect(x: random.next() * size.width, y: random.next() * size.height, width: r, height: r))
            }
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let vignette = makeGradient([UIColor(white: 0, alpha: 0), UIColor(white: 0, alpha: 0.55)], [0.45, 1])
            cg.drawRadialGradient(vignette, startCenter: c, startRadius: 0, endCenter: c,
                                  endRadius: hypot(size.width, size.height) / 2, options: [.drawsAfterEndLocation])
        }
        return SKTexture(image: image)
    }

    // MARK: - Drawing

    private static func drawMarble(_ stone: Stone, seed: UInt64) -> UIImage {
        let d: CGFloat = 96
        return renderer(CGSize(width: d, height: d)).image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(x: 0, y: 0, width: d, height: d)
            let center = CGPoint(x: d / 2, y: d / 2)
            cg.addEllipse(in: rect)
            cg.clip()

            // Body, lit from the upper left.
            let body = makeGradient([stone.light, stone.mid, stone.dark], [0, 0.55, 1])
            cg.drawRadialGradient(body, startCenter: CGPoint(x: d * 0.36, y: d * 0.3), startRadius: 0,
                                  endCenter: center, endRadius: d * 0.62, options: [.drawsAfterEndLocation])

            // Veins: a soft wide pass under a sharp thin one.
            var random = Lcg(seed: seed &* 2_654_435_761)
            cg.setLineCap(.round)
            for _ in 0..<stone.veins {
                var copy = random
                strokeVein(cg, in: rect, random: &copy, color: stone.vein.withAlphaComponent(0.14), width: 5)
                let alpha = 0.35 + 0.3 * random.next()
                let width = 0.7 + 1.6 * random.next()
                strokeVein(cg, in: rect, random: &random, color: stone.vein.withAlphaComponent(alpha), width: width)
            }
            for _ in 0..<stone.speckles {
                cg.setFillColor(stone.vein.withAlphaComponent(0.5 + 0.5 * random.next()).cgColor)
                let r = 0.8 + 1.8 * random.next()
                cg.fillEllipse(in: CGRect(x: random.next() * d, y: random.next() * d, width: r, height: r))
            }

            // A calm face behind the letter: fade the veins toward the body color.
            let face = makeGradient([stone.mid.withAlphaComponent(0.7), stone.mid.withAlphaComponent(0)], [0.4, 1])
            cg.drawRadialGradient(face, startCenter: center, startRadius: 0, endCenter: center,
                                  endRadius: d * 0.36, options: [])

            // Darker rim gives the sphere its depth.
            let rim = makeGradient([UIColor(white: 0, alpha: 0), UIColor(white: 0, alpha: 0.42)], [0.7, 1])
            cg.drawRadialGradient(rim, startCenter: center, startRadius: 0, endCenter: center, endRadius: d / 2, options: [])

            // Light bouncing up from the table.
            let bounce = makeGradient([UIColor(white: 1, alpha: 0.2), UIColor(white: 1, alpha: 0)], [0, 1])
            let bounceCenter = CGPoint(x: d * 0.64, y: d * 0.8)
            cg.drawRadialGradient(bounce, startCenter: bounceCenter, startRadius: 0, endCenter: bounceCenter,
                                  endRadius: d * 0.24, options: [])

            // Polished highlight.
            cg.saveGState()
            cg.translateBy(x: d * 0.33, y: d * 0.17)
            cg.rotate(by: -0.45)
            let highlight = CGRect(x: -d * 0.16, y: -d * 0.08, width: d * 0.32, height: d * 0.16)
            cg.addEllipse(in: highlight)
            cg.clip()
            let shine = makeGradient([UIColor(white: 1, alpha: 0.85), UIColor(white: 1, alpha: 0.05)], [0, 1])
            cg.drawLinearGradient(shine, start: CGPoint(x: 0, y: highlight.minY), end: CGPoint(x: 0, y: highlight.maxY),
                                  options: [])
            cg.restoreGState()

            cg.setStrokeColor(UIColor(white: 0, alpha: 0.35).cgColor)
            cg.setLineWidth(1.5)
            cg.strokeEllipse(in: rect.insetBy(dx: 0.75, dy: 0.75))
        }
    }

    /// A wandering line from one side of `rect` to the other.
    private static func strokeVein(_ cg: CGContext, in rect: CGRect, random: inout Lcg, color: UIColor, width: CGFloat) {
        let path = CGMutablePath()
        var point = CGPoint(x: rect.minX - 4, y: rect.minY + random.next() * rect.height)
        path.move(to: point)
        let steps = 4
        for step in 1...steps {
            let x = rect.minX + rect.width * CGFloat(step) / CGFloat(steps) + (step == steps ? 4 : 0)
            let y = min(max(point.y + (random.next() - 0.5) * rect.height * 0.5, rect.minY), rect.maxY)
            let control = CGPoint(x: (point.x + x) / 2, y: point.y + (random.next() - 0.5) * rect.height * 0.4)
            point = CGPoint(x: x, y: y)
            path.addQuadCurve(to: point, control: control)
        }
        cg.addPath(path)
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.strokePath()
    }

    // MARK: - Helpers

    static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    private static func letterIndex(_ letter: Character) -> Int {
        max(0, Int(letter.asciiValue ?? 97) - 97)
    }

    private static func renderer(_ size: CGSize, scale: CGFloat = 2) -> UIGraphicsImageRenderer {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format)
    }

    private static func makeGradient(_ colors: [UIColor], _ locations: [CGFloat]) -> CGGradient {
        CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray,
                   locations: locations)!
    }
}

/// Small deterministic generator so every marble draws the same way each launch.
private struct Lcg {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> CGFloat {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return CGFloat(state >> 33) / CGFloat(UInt64(1) << 31)
    }
}
