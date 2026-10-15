import SpriteKit

/// A lettered bubble.
final class BubbleNode: SKNode {
    private let circle: SKShapeNode
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private(set) var letter: Character?

    init(radius: CGFloat) {
        circle = SKShapeNode(circleOfRadius: radius)
        super.init()
        circle.lineWidth = 0
        addChild(circle)
        label.fontSize = radius * 1.15
        label.fontColor = UIColor(white: 0.1, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func show(_ letter: Character) {
        guard letter != self.letter else { return }
        self.letter = letter
        label.text = String(letter).uppercased()
        circle.fillColor = Self.color(for: letter)
    }

    static func color(for letter: Character) -> UIColor {
        let index = Int(letter.asciiValue ?? 97) - 97
        return UIColor(hue: CGFloat((index * 7) % 26) / 26, saturation: 0.38, brightness: 1, alpha: 1)
    }
}

/// A tappable rectangle with a label. Its `name` is the action it triggers.
final class ButtonNode: SKShapeNode {
    private let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    init(action: String, size: CGSize) {
        super.init()
        path = CGPath(roundedRect: CGRect(origin: CGPoint(x: -size.width / 2, y: -size.height / 2), size: size),
                      cornerWidth: 10, cornerHeight: 10, transform: nil)
        fillColor = UIColor(red: 0.2, green: 0.255, blue: 0.37, alpha: 1)
        lineWidth = 0
        name = action
        label.fontSize = 26
        label.fontColor = .white
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
