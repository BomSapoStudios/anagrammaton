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
/// letters. The buttons at the top toggle relaxed mode and word hints.
/// Words count in both directions, so a word never stops working because
/// the chain turned a corner.
///
/// Hints: bubbles that the shooter's letter can turn into a common word glow,
/// with a small copy of the letter in the gap it belongs in. While aiming,
/// the bubbles the shot would pop light up and the word is shown.
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
    /// Always on: words spell forward or backward wherever the chain runs.
    private let allowBackward = true
    private var relaxed = false
    /// Words read left to right (or top to bottom) as they look on screen.
    private var screenOrder = true
    private var aiming = false
    private var hintsOn = true
    /// Hints show at most this many spots, nearest the hole first.
    let maxHintSpots = 3
    private var hintSpots: [WordSpot] = []
    private var nextLetterHasSpots = false
    private var hintKey: (letters: [Character], current: Character, next: Character?, backward: Bool)?
    private var previewKey: (letters: [Character], letter: Character, index: Int)?
    private var previewEvents: [PopEvent] = []
    private var continuesUsed = 0
    private var lastUpdate: TimeInterval?

    /// Debug: fire at pairs automatically (launch argument -autoplayLevel N).
    var autoplay = false
    private var autoplayTimer = 0.0

    private var topInset: CGFloat = 0
    private var bottomInset: CGFloat = 0

    private let trackNode = SKShapeNode()
    private let trackEdge = SKShapeNode()
    private let holeNode = SKShapeNode(circleOfRadius: 38)
    private let aimLine = SKShapeNode()
    private let shooterBase = SKShapeNode(circleOfRadius: 38)
    private lazy var shooterBubble = BubbleNode(radius: CGFloat(diameter / 2))
    private lazy var shotNode = BubbleNode(radius: CGFloat(diameter / 2))
    private lazy var upcomingNodes = [BubbleNode(radius: 15), BubbleNode(radius: 15)]
    private var bubbleNodes: [BubbleNode] = []
    private let hudLabel = SKLabelNode(fontNamed: StoneStyle.uiFont)
    private let messageLabel = SKLabelNode(fontNamed: StoneStyle.uiFont)
    private let relaxedButton = ButtonNode(action: "relaxed", size: CGSize(width: 230, height: 50))
    private let hintsButton = ButtonNode(action: "hints", size: CGSize(width: 166, height: 50))
    private var gapMarkers: [BubbleNode] = []
    private let previewLabel = SKLabelNode(fontNamed: StoneStyle.uiFont)
    /// Big word shown the moment it pops, in open space near the track.
    private let wordBanner = SKNode()
    private let bannerWord = SKLabelNode(fontNamed: StoneStyle.letterFont)
    private let bannerDetail = SKLabelNode(fontNamed: StoneStyle.uiFont)
    private var bannerPoint = Vec2.zero
    /// Dims the board behind the end-of-level message so it stays readable.
    private let overlay = SKSpriteNode(color: UIColor(white: 0, alpha: 0.65), size: .zero)
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
        backgroundColor = StoneStyle.rgb(0x1C1E21)
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
        let board = SKSpriteNode(texture: StoneStyle.board(size: size))
        board.size = size
        board.position = CGPoint(x: size.width / 2, y: size.height / 2)
        board.zPosition = -30
        addChild(board)
        // The track is a groove cut into the slate: a dark edge around a lighter floor.
        let grooves: [(SKShapeNode, Double, UIColor)] = [(trackEdge, 1.3, UIColor(white: 0, alpha: 0.5)),
                                     (trackNode, 1.12, StoneStyle.rgb(0x26282C))]
        for (node, width, color) in grooves {
            node.strokeColor = color
            node.lineWidth = CGFloat(diameter * width)
            node.lineCap = .round
            node.lineJoin = .round
            node.zPosition = node === trackEdge ? -21 : -20
            addChild(node)
        }
        holeNode.fillColor = .black
        holeNode.strokeColor = StoneStyle.brass
        holeNode.lineWidth = 4
        holeNode.zPosition = -19
        addChild(holeNode)
        aimLine.strokeColor = StoneStyle.cream.withAlphaComponent(0.35)
        aimLine.lineWidth = 3
        addChild(aimLine)
        shooterBase.fillColor = StoneStyle.slate
        shooterBase.strokeColor = StoneStyle.brass
        shooterBase.lineWidth = 3
        shooterBase.zPosition = -19
        addChild(shooterBase)
        addChild(shooterBubble)
        upcomingNodes.forEach { addChild($0) }
        shotNode.isHidden = true
        addChild(shotNode)

        hudLabel.fontSize = 30
        hudLabel.fontColor = StoneStyle.cream
        hudLabel.horizontalAlignmentMode = .left
        hudLabel.position = scenePoint(Vec2(16, Double(topInset) + 40))
        addChild(hudLabel)
        let buttonY = Double(topInset) + 90
        relaxedButton.position = scenePoint(Vec2(16 + 115, buttonY))
        hintsButton.position = scenePoint(Vec2(262 + 83, buttonY))
        addChild(relaxedButton)
        addChild(hintsButton)
        for _ in 0..<maxHintSpots {
            let marker = BubbleNode(radius: 12)
            marker.zPosition = 5
            marker.alpha = 0.9
            marker.run(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.5), .scale(to: 1, duration: 0.5)])))
            marker.isHidden = true
            addChild(marker)
            gapMarkers.append(marker)
        }
        bannerWord.fontSize = 64
        bannerWord.fontColor = StoneStyle.cream
        bannerWord.verticalAlignmentMode = .center
        bannerDetail.fontSize = 28
        bannerDetail.fontColor = StoneStyle.rgb(0xF2CF72)
        bannerDetail.verticalAlignmentMode = .center
        bannerDetail.position = CGPoint(x: 0, y: -50)
        wordBanner.addChild(bannerWord)
        wordBanner.addChild(bannerDetail)
        wordBanner.zPosition = 8
        wordBanner.alpha = 0
        addChild(wordBanner)
        previewLabel.fontSize = 34
        previewLabel.fontColor = StoneStyle.rgb(0xF2CF72)
        previewLabel.zPosition = 6
        previewLabel.isHidden = true
        addChild(previewLabel)
        overlay.size = size
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 20
        overlay.isHidden = true
        addChild(overlay)
        for node in [messageLabel, primaryButton, continueButton] as [SKNode] {
            node.zPosition = 21
        }
        messageLabel.fontSize = 40
        messageLabel.fontColor = StoneStyle.cream
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
        dealer.allowBackward = allowBackward
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
            bannerPoint = Vec2(Double(Self.layoutWidth) / 2, area.y - 70)
            track = generator.generate(.spiral, area: area, shooter: shooter, diameter: diameter)
        } else {
            let top = Double(topInset) + 140
            shooter = Vec2(Double(Self.layoutWidth) / 2, height - Double(bottomInset) - 150)
            let area = Box(x: 0, y: top, width: Double(Self.layoutWidth), height: shooter.y - top - 290)
            // The open space between the bottom of the track and the shooter.
            bannerPoint = Vec2(Double(Self.layoutWidth) / 2, shooter.y - 180)
            track = generator.generate(.serpentine, area: area, shooter: shooter, diameter: diameter)
        }
        guard let track else {
            assertionFailure("No valid track for level \(n)")
            return
        }
        let path = CGMutablePath()
        path.addLines(between: track.points.map(scenePoint))
        trackNode.path = path
        trackEdge.path = path
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
        guard var flying = shot, track != nil else { return }
        let positions = bubblePositions()
        // Small steps so a fast shot can't skip past a bubble (and so the
        // aim preview, which steps the same way, matches what happens).
        let distance = (flying.velocity * dt).length
        let steps = max(1, Int((distance / (diameter * 0.25)).rounded(.up)))
        for _ in 0..<steps {
            flying.position = flying.position + flying.velocity * (dt / Double(steps))
            guard playBounds.contains(flying.position) else {
                shot = nil
                score.recordMiss()
                return
            }
            if let hit = nearestBubble(to: flying.position, in: positions) {
                land(beside: hit, at: flying.position, letter: flying.letter)
                return
            }
        }
        shot = flying
    }

    private var playBounds: Box {
        Box(x: 0, y: 0, width: Double(size.width), height: Double(size.height)).grown(by: diameter)
    }

    /// Positions of the bubbles on the track; nil for those not yet out.
    private func bubblePositions() -> [Vec2?] {
        guard let track else { return [] }
        return letters.indices.map { i in
            let s = bubbleS(i)
            return s >= 0 ? track.position(at: s) : nil
        }
    }

    /// The bubble a shot at `point` touches, if any.
    private func nearestBubble(to point: Vec2, in positions: [Vec2?]) -> Int? {
        var hit: Int?
        var best = diameter * 0.85
        for (i, position) in positions.enumerated() {
            guard let position else { continue }
            let distance = point.distance(to: position)
            if distance < best {
                best = distance
                hit = i
            }
        }
        return hit
    }

    /// Which side of bubble `hit` a shot at `position` goes in.
    private func landingIndex(beside hit: Int, at position: Vec2) -> Int {
        guard let track else { return hit }
        let s = bubbleS(hit)
        let ahead = (position - track.position(at: s)).dot(track.tangent(at: s)) > 0
        return ahead ? hit + 1 : hit
    }

    /// Where a shot fired now would land, stepping along the aim like a real shot.
    private func predictLanding() -> (index: Int, position: Vec2)? {
        let positions = bubblePositions()
        var point = shooter
        let step = aim * (diameter * 0.25)
        for _ in 0..<2000 {
            point = point + step
            guard playBounds.contains(point) else { return nil }
            if let hit = nearestBubble(to: point, in: positions) {
                return (landingIndex(beside: hit, at: point), point)
            }
        }
        return nil
    }

    /// Inserts the shot next to bubble `hit` and resolves pops. Bubbles ahead
    /// of the landing spot are pushed forward one slot, as in Zuma.
    private func land(beside hit: Int, at position: Vec2, letter: Character) {
        let index = landingIndex(beside: hit, at: position)
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
        showWordBanner(events)
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
        for button in [relaxedButton, hintsButton, primaryButton, continueButton]
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
        case "relaxed":
            relaxed.toggle()
        case "hints":
            hintsOn.toggle()
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

    /// Debug autoplay for screenshots: fires at the first hinted word spot,
    /// otherwise loads the letter that completes a visible pair and fires at it.
    private func runAutoplay(_ dt: Double) {
        autoplayTimer += dt
        guard autoplayTimer >= 0.66, shot == nil, let track else { return }
        autoplayTimer = 0
        guard letters.count >= 2 else { return }
        // Keep the aim preview on so screenshots show it.
        aiming = true
        if let spot = hintSpots.first, gapS(spot.insertIndex) > 0 {
            aim(at: track.position(at: gapS(spot.insertIndex)))
            fire()
            return
        }
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
        let landing = state == .playing && shot == nil ? predictLanding() : nil
        renderHints(landing)
        let aimPath = CGMutablePath()
        aimPath.move(to: scenePoint(shooter))
        aimPath.addLine(to: scenePoint(landing?.position ?? shooter + aim * 240))
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
        relaxedButton.text = "Relaxed: \(relaxed ? "on" : "off")"
        hintsButton.text = "Hints: \(hintsOn ? "on" : "off")"
        switch state {
        case .playing:
            overlay.isHidden = true
            messageLabel.isHidden = true
            primaryButton.isHidden = true
            continueButton.isHidden = true
        case .won:
            messageLabel.text = "Level clear!"
            overlay.isHidden = false
            messageLabel.isHidden = false
            primaryButton.text = "Next level"
            primaryButton.isHidden = false
            continueButton.isHidden = true
        case .lost:
            messageLabel.text = "The chain reached the hole"
            overlay.isHidden = false
            messageLabel.isHidden = false
            primaryButton.text = "Retry"
            primaryButton.isHidden = false
            continueButton.isHidden = !ads.policy.canOfferContinue(continuesUsed: continuesUsed, ranked: false)
        }
    }

    // MARK: - Hints

    private func renderHints(_ landing: (index: Int, position: Vec2)?) {
        var glow = [BubbleNode.Glow](repeating: .none, count: letters.count)
        updateHintSpots()
        let showHints = hintsOn && state == .playing
        let shown = showHints ? Array(hintSpots.prefix(maxHintSpots)) : []
        for (k, marker) in gapMarkers.enumerated() {
            marker.isHidden = true
            guard k < shown.count, let track else { continue }
            let spot = shown[k]
            let s = gapS(spot.insertIndex)
            guard s >= 0 else { continue }
            marker.isHidden = false
            marker.show(current)
            marker.position = scenePoint(track.position(at: s))
            if let bubbles = spot.bubbles {
                for i in bubbles where i < glow.count {
                    glow[i] = .hint
                }
            }
        }
        // Nothing for this letter but the next one fits somewhere: nudge a swap.
        let nudge = showHints && shown.isEmpty && nextLetterHasSpots
        if nudge, upcomingNodes[0].action(forKey: "nudge") == nil {
            upcomingNodes[0].run(.repeatForever(.sequence([.scale(to: 1.35, duration: 0.4),
                                                           .scale(to: 1, duration: 0.4)])), withKey: "nudge")
        } else if !nudge {
            upcomingNodes[0].removeAction(forKey: "nudge")
            upcomingNodes[0].setScale(1)
        }

        previewLabel.isHidden = true
        if aiming, let landing {
            let events = previewPops(inserting: current, at: landing.index)
            if let first = events.first {
                for j in first.start...first.end where j != landing.index {
                    let i = j < landing.index ? j : j - 1
                    if i < glow.count {
                        glow[i] = .pop
                    }
                }
                var text = first.kind == .word ? (first.word ?? "").uppercased() : "Triple"
                if events.count > 1 {
                    text += " + chain x\(events.count)"
                }
                previewLabel.text = text
                previewLabel.position = scenePoint(landing.position + Vec2(0, -56))
                previewLabel.isHidden = false
            }
        }
        for (node, style) in zip(bubbleNodes, glow) {
            node.glow = style
        }
    }

    /// Recomputes where the shooter's letter spells a common word, when the chain or letter changed.
    private func updateHintSpots() {
        let next = upcoming.first
        if let key = hintKey, key.letters == letters, key.current == current, key.next == next,
           key.backward == allowBackward {
            return
        }
        hintKey = (letters, current, next, allowBackward)
        let flips = flipTest()
        hintSpots = Hints.wordSpots(for: current, in: letters, words: words, allowBackward: allowBackward,
                                    flips: flips).filter(\.common)
        nextLetterHasSpots = next.map {
            Hints.wordSpots(for: $0, in: letters, words: words, allowBackward: allowBackward, flips: flips)
                .contains(where: \.common)
        } ?? false
    }

    private func previewPops(inserting letter: Character, at index: Int) -> [PopEvent] {
        if let key = previewKey, key.letters == letters, key.letter == letter, key.index == index {
            return previewEvents
        }
        previewKey = (letters, letter, index)
        previewEvents = Hints.preview(inserting: letter, at: index, in: letters, words: words,
                                      allowBackward: allowBackward, flips: flipTest())
        return previewEvents
    }

    /// Arc length of the gap a letter inserted at `index` would fill.
    private func gapS(_ index: Int) -> Double {
        if letters.isEmpty {
            return -1
        }
        if index <= 0 {
            return bubbleS(0) - diameter / 2
        }
        if index >= letters.count {
            return bubbleS(letters.count - 1) + diameter / 2
        }
        return (bubbleS(index - 1) + bubbleS(index)) / 2
    }

    private func describe(_ event: PopEvent) -> String {
        var text: String
        switch event.kind {
        case .word:
            text = (event.word ?? "").uppercased()
        case .triple:
            text = "Triple"
        }
        if event.depth > 0 {
            text += " chain x\(event.depth + 1)"
        }
        return "\(text) +\(event.points)"
    }

    /// Shows the words a shot spelled, large, right as they pop.
    private func showWordBanner(_ events: [PopEvent]) {
        let spelled = events.compactMap { $0.kind == .word ? $0.word?.uppercased() : nil }
        guard !spelled.isEmpty else { return }
        bannerWord.text = spelled.joined(separator: " + ")
        // Long chains of words shrink to fit the screen.
        let width = max(bannerWord.frame.width / max(bannerWord.xScale, 0.01), 1)
        bannerWord.setScale(min(1, (size.width - 40) / width))
        let points = events.reduce(0) { $0 + $1.points }
        bannerDetail.text = events.count > 1 ? "+\(points)  chain x\(events.count)" : "+\(points)"
        wordBanner.position = scenePoint(bannerPoint)
        wordBanner.removeAllActions()
        wordBanner.alpha = 1
        wordBanner.setScale(0.6)
        wordBanner.run(.sequence([
            .scale(to: 1, duration: 0.15),
            .wait(forDuration: 1.6),
            .fadeOut(withDuration: 0.5),
        ]))
    }

    private func showPopup(_ text: String, at point: Vec2) {
        let label = SKLabelNode(fontNamed: StoneStyle.uiFont)
        label.text = text
        label.fontSize = 30
        label.fontColor = StoneStyle.rgb(0xF2CF72)
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
