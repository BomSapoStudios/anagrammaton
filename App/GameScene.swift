import AnagrammatonCore
import SpriteKit
import SwiftUI

/// Playable prototype of the core loop: one chain rolling along a generated
/// track toward a hole, a shooter, triple and word pops, chain reactions and
/// scoring.
///
/// Game logic works in layout units on a 720-wide canvas with y pointing
/// down (AnagrammatonCore's convention); `scenePoint` converts to SpriteKit,
/// where y points up.
///
/// Controls: drag to aim and release to fire. Tap the shooter to swap
/// letters. The buttons at the top toggle backward words and relaxed mode.
final class GameScene: SKScene {
    enum State {
        case playing, won, lost
    }

    static let layoutWidth: CGFloat = 720
    let diameter = 48.0
    let shotSpeed = 2200.0
    let introSpeedFactor = 5.0
    let introFraction = 0.3
    let continuePushback = 0.35
    let rotatingShooterFromLevel = 4
    /// Letters ordered by English frequency; a level's alphabet is a prefix.
    let frequencyOrder = Array("etaoinsrhldcumfpgwybvkxjqz")

    private let words: WordList
    private let score = ScoreKeeper()
    private let ads = AdService.shared
    private var dealer: LetterDealer!
    private var track: Track?

    private(set) var level = 1
    /// Chain letters, tail first (see ChainRules).
    private var letters: [Character] = []
    /// Arc length of the head bubble along the track.
    private var headS = 0.0
    /// Letters still to enter; the last one enters next.
    private var queue: [Character] = []
    private var chainSpeed = 40.0
    private var alphabet: [Character] = []
    private var introDone = false
    private var shooter = Vec2.zero
    private var aim = Vec2(0, -1)
    private var current: Character = "e"
    private var upcoming: [Character] = []
    private var shot: (position: Vec2, velocity: Vec2, letter: Character)?
    private var state = State.playing
    private var allowBackward = false
    private var relaxed = false
    /// Words read left to right (or top to bottom) as they look on screen.
    private var screenOrder = true
    private var aiming = false
    private var continuesUsed = 0
    private var lastUpdate: TimeInterval?

    /// Debug: fire at pairs automatically (launch argument -autoplayLevel N).
    var autoplay = false
    private var autoplayTimer = 0.0

    private var topInset: CGFloat = 0
    private var bottomInset: CGFloat = 0

    private let trackNode = SKShapeNode()
    private let holeNode = SKShapeNode(circleOfRadius: 38)
    private let aimLine = SKShapeNode()
    private let shooterBase = SKShapeNode(circleOfRadius: 38)
    private lazy var shooterBubble = BubbleNode(radius: CGFloat(diameter / 2))
    private lazy var shotNode = BubbleNode(radius: CGFloat(diameter / 2))
    private lazy var upcomingNodes = [BubbleNode(radius: 15), BubbleNode(radius: 15)]
    private var bubbleNodes: [BubbleNode] = []
    private let hudLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let messageLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let backwardButton = ButtonNode(action: "backward", size: CGSize(width: 260, height: 50))
    private let relaxedButton = ButtonNode(action: "relaxed", size: CGSize(width: 230, height: 50))
    private let primaryButton = ButtonNode(action: "next", size: CGSize(width: 260, height: 64))
    private let continueButton = ButtonNode(action: "continue", size: CGSize(width: 260, height: 64))

    /// Builds a scene for a view of `safeSize` plus `insets`.
    static func make(safeSize: CGSize, insets: EdgeInsets) -> GameScene {
        let fullWidth = safeSize.width + insets.leading + insets.trailing
        let fullHeight = safeSize.height + insets.top + insets.bottom
        let scale = layoutWidth / max(fullWidth, 1)
        let scene = GameScene(size: CGSize(width: layoutWidth, height: fullHeight * scale))
        scene.scaleMode = .aspectFit
        scene.topInset = insets.top * scale
        scene.bottomInset = insets.bottom * scale
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-autoplayLevel"), i + 1 < args.count, let level = Int(args[i + 1]) {
            scene.autoplay = true
            scene.level = level
        }
        return scene
    }

    override init(size: CGSize) {
        words = Self.loadWords()
        super.init(size: size)
        backgroundColor = UIColor(red: 0.114, green: 0.141, blue: 0.2, alpha: 1)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private static func loadWords() -> WordList {
        guard let pop = Bundle.main.url(forResource: "words_pop", withExtension: "txt"),
              let seed = Bundle.main.url(forResource: "words_seed", withExtension: "txt"),
              let block = Bundle.main.url(forResource: "blocklist", withExtension: "txt"),
              let words = try? WordList(popURL: pop, seedURL: seed, blockURL: block)
        else {
            assertionFailure("Word lists missing from the app bundle")
            return WordList()
        }
        return words
    }

    override func didMove(to view: SKView) {
        trackNode.strokeColor = UIColor(red: 0.17, green: 0.21, blue: 0.31, alpha: 1)
        trackNode.lineWidth = CGFloat(diameter * 1.15)
        trackNode.lineCap = .round
        trackNode.lineJoin = .round
        addChild(trackNode)
        holeNode.fillColor = UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1)
        holeNode.lineWidth = 0
        addChild(holeNode)
        aimLine.strokeColor = UIColor(white: 1, alpha: 0.35)
        aimLine.lineWidth = 3
        addChild(aimLine)
        shooterBase.fillColor = UIColor(red: 0.24, green: 0.29, blue: 0.42, alpha: 1)
        shooterBase.lineWidth = 0
        addChild(shooterBase)
        addChild(shooterBubble)
        upcomingNodes.forEach { addChild($0) }
        shotNode.isHidden = true
        addChild(shotNode)

        hudLabel.fontSize = 30
        hudLabel.horizontalAlignmentMode = .left
        hudLabel.position = scenePoint(Vec2(16, Double(topInset) + 40))
        addChild(hudLabel)
        let buttonY = Double(topInset) + 90
        backwardButton.position = scenePoint(Vec2(16 + 130, buttonY))
        relaxedButton.position = scenePoint(Vec2(292 + 115, buttonY))
        addChild(backwardButton)
        addChild(relaxedButton)
        messageLabel.fontSize = 40
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 30)
        addChild(messageLabel)
        primaryButton.position = CGPoint(x: size.width / 2, y: size.height / 2 - 60)
        continueButton.position = CGPoint(x: size.width / 2, y: size.height / 2 - 140)
        continueButton.text = "Continue (ad)"
        addChild(primaryButton)
        addChild(continueButton)

        startLevel(level)
    }

    // MARK: - Level setup

    func startLevel(_ n: Int) {
        level = n
        let t = min(max(Double(n - 1) / 9, 0), 1)
        let seed = UInt64(n) &* 7919
        buildTrack(n, seed: seed)
        alphabet = Array(frequencyOrder.prefix(Int((lerp(12, 26, t)).rounded())))
        let generator = ChainGenerator(words: words, seed: seed)
        generator.alphabet = alphabet
        generator.handlesPerBlock = Int(lerp(3, 1, t).rounded())
        queue = generator.generate(count: Int(lerp(50, 120, t).rounded()))
        dealer = LetterDealer(words: words, seed: seed &+ 2)
        dealer.helpRate = lerp(0.8, 0.4, t)
        dealer.pityLimit = Int(lerp(2, 4, t).rounded())
        chainSpeed = lerp(40, 90, t)
        letters = []
        headS = 0
        introDone = false
        shot = nil
        score.resetLevel()
        continuesUsed = 0
        state = .playing
        let preview = Array(queue.suffix(20))
        current = dealer.deal(preview, alphabet: alphabet)
        upcoming = [dealer.deal(preview, alphabet: alphabet), dealer.deal(preview, alphabet: alphabet)]
        refreshHUD()
    }

    private func buildTrack(_ n: Int, seed: UInt64) {
        let generator = TrackGenerator(seed: seed)
        let height = Double(size.height)
        if n >= rotatingShooterFromLevel {
            let side = Double(Self.layoutWidth) - 32
            let area = Box(x: 16, y: (height - side) / 2 + 40, width: side, height: side)
            shooter = area.center
            track = generator.generate(.spiral, area: area, shooter: shooter, diameter: diameter)
        } else {
            let top = Double(topInset) + 140
            shooter = Vec2(Double(Self.layoutWidth) / 2, height - Double(bottomInset) - 150)
            let area = Box(x: 0, y: top, width: Double(Self.layoutWidth), height: shooter.y - top - 290)
            track = generator.generate(.serpentine, area: area, shooter: shooter, diameter: diameter)
        }
        guard let track else {
            assertionFailure("No valid track for level \(n)")
            return
        }
        let path = CGMutablePath()
        path.addLines(between: track.points.map(scenePoint))
        trackNode.path = path
        holeNode.position = scenePoint(track.points[track.points.count - 1])
        shooterBase.position = scenePoint(shooter)
        shooterBubble.position = scenePoint(shooter)
        for (k, node) in upcomingNodes.enumerated() {
            // Just below the shooter, inside the gap a spiral's hole leaves.
            node.position = scenePoint(shooter + Vec2(diameter * 0.55 * Double(2 * k - 1), diameter * 1.2))
        }
    }

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        let dt = min(currentTime - (lastUpdate ?? currentTime), 1.0 / 20)
        lastUpdate = currentTime
        if state == .playing, track != nil {
            if autoplay {
                runAutoplay(dt)
            }
            advanceChain(dt)
            updateShot(dt)
            checkEnd()
        }
        render()
    }

    private func advanceChain(_ dt: Double) {
        guard let track else { return }
        if !(relaxed && aiming) {
            headS += chainSpeed * (introDone ? 1 : introSpeedFactor) * dt
            if headS >= track.length * introFraction {
                introDone = true
            }
        }
        if letters.isEmpty, let next = queue.popLast() {
            headS = 0
            letters.append(next)
        }
        while !queue.isEmpty && bubbleS(0) >= diameter {
            letters.insert(queue.removeLast(), at: 0)
        }
    }

    private func updateShot(_ dt: Double) {
        guard var flying = shot, let track else { return }
        flying.position = flying.position + flying.velocity * dt
        shot = flying
        let bounds = Box(x: 0, y: 0, width: Double(size.width), height: Double(size.height)).grown(by: diameter)
        guard bounds.contains(flying.position) else {
            shot = nil
            score.recordMiss()
            return
        }
        var hit: Int?
        var best = diameter * 0.85
        for i in letters.indices {
            let s = bubbleS(i)
            guard s >= 0 else { continue }
            let distance = flying.position.distance(to: track.position(at: s))
            if distance < best {
                best = distance
                hit = i
            }
        }
        if let hit {
            land(beside: hit, at: flying.position, letter: flying.letter)
        }
    }

    /// Inserts the shot next to bubble `hit` and resolves pops. Bubbles ahead
    /// of the landing spot are pushed forward one slot, as in Zuma.
    private func land(beside hit: Int, at position: Vec2, letter: Character) {
        guard let track else { return }
        let s = bubbleS(hit)
        let ahead = (position - track.position(at: s)).dot(track.tangent(at: s)) > 0
        let index = ahead ? hit + 1 : hit
        letters.insert(letter, at: index)
        headS += diameter
        shot = nil
        // Resolve on a copy so the flip test can read scene state safely.
        var working = letters
        var events = ChainRules.resolve(&working, requiredLow: index, requiredHigh: index,
                                        words: words, allowBackward: allowBackward, flips: flipTest())
        let sizeBefore = letters.count
        letters = working
        score.scoreShot(&events)
        var size = sizeBefore
        for (k, event) in events.enumerated() {
            // If the head end popped, the rest of the chain stays where it was.
            if event.end == size - 1 {
                headS -= Double(event.removed.count) * diameter
            }
            size -= event.removed.count
            showPopup(describe(event), at: position + Vec2(0, -50 - 44 * Double(k)))
        }
        if events.isEmpty {
            score.recordMiss()
        }
    }

    private func checkEnd() {
        guard let track else { return }
        if !letters.isEmpty && headS >= track.length {
            state = .lost
        } else if letters.isEmpty && queue.isEmpty && shot == nil {
            state = .won
            ads.levelCompleted()
        }
    }

    private func bubbleS(_ i: Int, count: Int? = nil) -> Double {
        headS - Double((count ?? letters.count) - 1 - i) * diameter
    }

    private func flipTest() -> FlipTest? {
        guard screenOrder, let track else { return nil }
        let head = headS
        let d = diameter
        return { start, end, count in
            let a = track.position(at: head - Double(count - 1 - start) * d)
            let b = track.position(at: head - Double(count - 1 - end) * d)
            let delta = b - a
            if abs(delta.x) >= abs(delta.y) {
                return delta.x < 0
            }
            return delta.y < 0
        }
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        for button in [backwardButton, relaxedButton, primaryButton, continueButton]
        where !button.isHidden && button.contains(location) {
            press(button.name ?? "")
            return
        }
        guard state == .playing else { return }
        let point = layoutPoint(location)
        if point.distance(to: shooter) < diameter {
            swapLetters()
            return
        }
        aiming = true
        aim(at: point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard aiming, let touch = touches.first else { return }
        aim(at: layoutPoint(touch.location(in: self)))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard aiming, let touch = touches.first else { return }
        aiming = false
        aim(at: layoutPoint(touch.location(in: self)))
        fire()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        aiming = false
    }

    private func press(_ action: String) {
        switch action {
        case "backward":
            allowBackward.toggle()
        case "relaxed":
            relaxed.toggle()
        case "next":
            startLevel(state == .won ? level + 1 : level)
        case "continue":
            guard state == .lost, ads.policy.canOfferContinue(continuesUsed: continuesUsed, ranked: false) else { return }
            ads.showRewarded { [weak self] earned in
                guard let self, earned, self.state == .lost, let track = self.track else { return }
                self.continuesUsed += 1
                self.headS -= track.length * self.continuePushback
                self.state = .playing
            }
        default:
            break
        }
        refreshHUD()
    }

    private func aim(at target: Vec2) {
        let direction = target - shooter
        if direction.length > 1 {
            aim = direction.normalized
        }
    }

    private func fire() {
        guard shot == nil, state == .playing, !upcoming.isEmpty else { return }
        shot = (shooter, aim * shotSpeed, current)
        current = upcoming.removeFirst()
        upcoming.append(dealer.deal(letters, alphabet: alphabet, flips: flipTest()))
    }

    private func swapLetters() {
        guard !upcoming.isEmpty else { return }
        let next = upcoming[0]
        upcoming[0] = current
        current = next
    }

    /// Debug autoplay for screenshots: loads the letter that completes a
    /// visible pair and fires at it.
    private func runAutoplay(_ dt: Double) {
        autoplayTimer += dt
        guard autoplayTimer >= 0.66, shot == nil, let track else { return }
        autoplayTimer = 0
        guard letters.count >= 2 else { return }
        for i in stride(from: letters.count - 2, through: 0, by: -1)
        where letters[i] == letters[i + 1] && bubbleS(i) > 0 {
            current = letters[i]
            aim(at: track.position(at: bubbleS(i)))
            fire()
            return
        }
    }

    // MARK: - Rendering

    private func render() {
        guard let track else { return }
        while bubbleNodes.count < letters.count {
            let node = BubbleNode(radius: CGFloat(diameter / 2))
            addChild(node)
            bubbleNodes.append(node)
        }
        for (i, node) in bubbleNodes.enumerated() {
            guard i < letters.count, bubbleS(i) >= 0 else {
                node.isHidden = true
                continue
            }
            node.isHidden = false
            node.position = scenePoint(track.position(at: bubbleS(i)))
            node.show(letters[i])
        }
        shooterBubble.show(current)
        for (node, letter) in zip(upcomingNodes, upcoming) {
            node.show(letter)
        }
        if let shot {
            shotNode.isHidden = false
            shotNode.position = scenePoint(shot.position)
            shotNode.show(shot.letter)
        } else {
            shotNode.isHidden = true
        }
        let aimPath = CGMutablePath()
        aimPath.move(to: scenePoint(shooter))
        aimPath.addLine(to: scenePoint(shooter + aim * 240))
        aimLine.path = aimPath.copy(dashingWithPhase: 0, lengths: [12, 12])
        aimLine.isHidden = state != .playing
        refreshHUD()
    }

    private func refreshHUD() {
        var hud = "Level \(level)    Score \(score.total)"
        if score.combo > 1 {
            hud += "    Combo \(score.combo)"
        }
        hudLabel.text = hud
        backwardButton.text = "Backward: \(allowBackward ? "on" : "off")"
        relaxedButton.text = "Relaxed: \(relaxed ? "on" : "off")"
        switch state {
        case .playing:
            messageLabel.isHidden = true
            primaryButton.isHidden = true
            continueButton.isHidden = true
        case .won:
            messageLabel.text = "Level clear!"
            messageLabel.isHidden = false
            primaryButton.text = "Next level"
            primaryButton.isHidden = false
            continueButton.isHidden = true
        case .lost:
            messageLabel.text = "The chain reached the hole"
            messageLabel.isHidden = false
            primaryButton.text = "Retry"
            primaryButton.isHidden = false
            continueButton.isHidden = !ads.policy.canOfferContinue(continuesUsed: continuesUsed, ranked: false)
        }
    }

    private func describe(_ event: PopEvent) -> String {
        var text: String
        switch event.kind {
        case .word:
            text = (event.word ?? "").uppercased()
            if event.backward {
                text += " (backward)"
            }
        case .triple:
            text = "Triple"
        }
        if event.depth > 0 {
            text += " chain x\(event.depth + 1)"
        }
        return "\(text) +\(event.points)"
    }

    private func showPopup(_ text: String, at point: Vec2) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 30
        label.fontColor = UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1)
        label.position = scenePoint(point)
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 40, duration: 1.4), .fadeOut(withDuration: 1.4)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Coordinates

    private func scenePoint(_ p: Vec2) -> CGPoint {
        CGPoint(x: p.x, y: Double(size.height) - p.y)
    }

    private func layoutPoint(_ p: CGPoint) -> Vec2 {
        Vec2(Double(p.x), Double(size.height - p.y))
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}
