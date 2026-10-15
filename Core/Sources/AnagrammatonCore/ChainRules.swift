/// Pure rules for the letter chain, with no rendering.
///
/// Letters are stored tail first: index 0 is the bubble farthest from the
/// hole and the last index is the head. Reading the array in order is reading
/// in the direction of travel.
///
/// A pop must cover a required span of indices. For a shot that span is the
/// landed bubble; for a chain reaction it is the two bubbles either side of
/// the closed gap, so only words formed by the gap closing pop, and letters
/// that were already sitting next to each other never pop on their own.
///
/// Words read in screen order: an optional `FlipTest` says when a span runs
/// right to left (or bottom to top) on screen, and that span is read reversed.

public enum PopKind: Equatable {
    case triple
    case word
}

public struct PopEvent: Equatable {
    public var kind: PopKind
    public var start: Int
    public var end: Int
    public var word: String?
    /// True when the word only reads backward on screen.
    public var backward = false
    /// 0 for a direct pop, 1+ for each link of a chain reaction.
    public var depth = 0
    public var removed: [Character] = []
    /// Filled in by ScoreKeeper.
    public var points = 0

    public init(kind: PopKind, start: Int, end: Int, word: String? = nil, backward: Bool = false, depth: Int = 0) {
        self.kind = kind
        self.start = start
        self.end = end
        self.word = word
        self.backward = backward
        self.depth = depth
    }
}

/// flips(start, end, chainCount) -> true when chain indices start...end run
/// right to left (or bottom to top) on screen.
public typealias FlipTest = (_ start: Int, _ end: Int, _ count: Int) -> Bool

public enum ChainRules {
    public static let minTriple = 3

    /// The pop that covers requiredLow...requiredHigh, or nil. Words beat
    /// triples, and longer words beat shorter ones.
    public static func findPop(
        _ letters: [Character], requiredLow: Int, requiredHigh: Int,
        words: WordList, allowBackward: Bool, flips: FlipTest? = nil
    ) -> PopEvent? {
        guard requiredLow >= 0, requiredHigh < letters.count, requiredLow <= requiredHigh else {
            return nil
        }
        if let word = findWord(letters, requiredLow, requiredHigh, words, allowBackward, flips) {
            return word
        }
        return findTriple(letters, requiredLow, requiredHigh)
    }

    /// Applies the pop at a shot (or any change) and every chain reaction
    /// after it. Mutates `letters` and returns the pops in order.
    public static func resolve(
        _ letters: inout [Character], requiredLow: Int, requiredHigh: Int,
        words: WordList, allowBackward: Bool, flips: FlipTest? = nil
    ) -> [PopEvent] {
        var events: [PopEvent] = []
        var low = requiredLow
        var high = requiredHigh
        while var pop = findPop(letters, requiredLow: low, requiredHigh: high,
                                words: words, allowBackward: allowBackward, flips: flips) {
            pop.depth = events.count
            pop.removed = Array(letters[pop.start...pop.end])
            letters.removeSubrange(pop.start...pop.end)
            events.append(pop)
            // The gap closes: the bubbles either side of it are now neighbours.
            low = pop.start - 1
            high = pop.start
        }
        return events
    }

    private static func findWord(
        _ letters: [Character], _ low: Int, _ high: Int,
        _ words: WordList, _ allowBackward: Bool, _ flips: FlipTest?
    ) -> PopEvent? {
        let n = letters.count
        let longest = min(n, words.maxLength)
        guard longest >= WordList.minWordLength else { return nil }
        for length in stride(from: longest, through: WordList.minWordLength, by: -1) {
            let first = max(0, high - length + 1)
            let last = min(low, n - length)
            guard first <= last else { continue }
            for start in first...last {
                let end = start + length - 1
                var forward = String(letters[start...end])
                var reversed = String(forward.reversed())
                if let flips, flips(start, end, n) {
                    swap(&forward, &reversed)
                }
                if words.isWord(forward) {
                    return PopEvent(kind: .word, start: start, end: end, word: forward)
                }
                if allowBackward && words.isWord(reversed) {
                    return PopEvent(kind: .word, start: start, end: end, word: reversed, backward: true)
                }
            }
        }
        return nil
    }

    private static func findTriple(_ letters: [Character], _ low: Int, _ high: Int) -> PopEvent? {
        let letter = letters[low]
        guard letters[low...high].allSatisfy({ $0 == letter }) else { return nil }
        var start = low
        while start > 0 && letters[start - 1] == letter {
            start -= 1
        }
        var end = high
        while end < letters.count - 1 && letters[end + 1] == letter {
            end += 1
        }
        guard end - start + 1 >= minTriple else { return nil }
        return PopEvent(kind: .triple, start: start, end: end)
    }
}
