import Foundation

/// Point values. Word score grows exponentially with length: every letter
/// past five multiplies it by `lengthBase`, so long words dwarf short ones.
public enum Scoring {
    public static let wordBase = 100
    public static let lengthBase = 1.4
    public static let triplePerBubble = 10
    public static let chainWordBonus = 100
    public static let firstWordBonus = 50
    public static let comboStep = 0.1
    public static let comboMaxSteps = 10

    public static let letterValues: [Character: Int] = [
        "a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2, "h": 4, "i": 1,
        "j": 8, "k": 5, "l": 1, "m": 3, "n": 1, "o": 1, "p": 3, "q": 10, "r": 1,
        "s": 1, "t": 1, "u": 1, "v": 4, "w": 4, "x": 8, "y": 4, "z": 10,
    ]

    public static func wordPoints(_ word: String) -> Int {
        let sum = word.reduce(0) { $0 + (letterValues[$1] ?? 0) }
        return Int((Double(wordBase + sum) * pow(lengthBase, Double(word.count - 5))).rounded())
    }

    /// 1 for a direct pop, then 2, 3, 4... for each link of a chain reaction.
    public static func chainMultiplier(depth: Int) -> Int { depth + 1 }

    /// Points for one pop, before per-level adjustments.
    public static func eventPoints(_ event: PopEvent) -> Int {
        var base: Int
        switch event.kind {
        case .word:
            base = wordPoints(event.word ?? "")
            if event.depth > 0 {
                base += chainWordBonus
            }
        case .triple:
            base = triplePerBubble * event.removed.count
        }
        return base * chainMultiplier(depth: event.depth)
    }
}

/// Running score for a level: repeated words score half, a word the player
/// has never spelled before earns a bonus, and consecutive popping shots
/// build a combo.
public final class ScoreKeeper {
    public private(set) var total = 0
    public private(set) var combo = 0
    /// Every word the player has ever spelled. Persisting it is future work.
    public private(set) var wordBook = Set<String>()

    private var levelWords = Set<String>()

    public init() {}

    public func resetLevel() {
        total = 0
        combo = 0
        levelWords.removeAll()
    }

    /// Scores all pops caused by one shot, fills in each event's points, and
    /// returns the points added.
    @discardableResult
    public func scoreShot(_ events: inout [PopEvent]) -> Int {
        guard !events.isEmpty else {
            combo = 0
            return 0
        }
        var points = 0
        for i in events.indices {
            var p = Scoring.eventPoints(events[i])
            if events[i].kind == .word, let word = events[i].word {
                if levelWords.contains(word) {
                    p /= 2
                }
                levelWords.insert(word)
                if wordBook.insert(word).inserted {
                    p += Scoring.firstWordBonus
                }
            }
            events[i].points = p
            points += p
        }
        let bonus = Double(min(combo, Scoring.comboMaxSteps)) * Scoring.comboStep
        points = Int((Double(points) * (1 + bonus)).rounded())
        combo += 1
        total += points
        return points
    }

    /// A shot that popped nothing breaks the combo.
    public func recordMiss() {
        combo = 0
    }
}
