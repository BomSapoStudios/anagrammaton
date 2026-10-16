/// Chooses the shooter's letters. Most of the time it deals a letter that
/// completes a handle on the chain (a pair, or a common word missing one
/// letter), preferring handles close to the hole. A pity timer guarantees a
/// useful letter after a few unhelpful ones.
public final class LetterDealer {
    public static let alphabet: [Character] = Array("abcdefghijklmnopqrstuvwxyz")
    /// Scrabble tile counts, used as English letter-frequency weights.
    public static let frequency: [Character: Int] = [
        "a": 9, "b": 2, "c": 2, "d": 4, "e": 12, "f": 2, "g": 3, "h": 2, "i": 9,
        "j": 1, "k": 1, "l": 4, "m": 2, "n": 6, "o": 8, "p": 2, "q": 1, "r": 6,
        "s": 4, "t": 6, "u": 4, "v": 2, "w": 2, "x": 1, "y": 2, "z": 1,
    ]

    public var helpRate = 0.8
    public var pityLimit = 2
    /// Also count stems that spell a word read the other way.
    public var allowBackward = false
    /// The level's hidden word. When the chain holds it with one letter
    /// missing, the dealer often hands over that letter.
    public var targetWord: String?
    public var targetRate = 0.5

    private let words: WordList
    private var rng: SeededGenerator
    private var dryStreak = 0

    public init(words: WordList, seed: UInt64) {
        self.words = words
        rng = SeededGenerator(seed: seed)
    }

    /// Letters that would pop something if shot into the right spot, mapped
    /// to the chain index of the handle nearest the hole.
    public func usefulLetters(_ letters: [Character], flips: FlipTest? = nil) -> [Character: Int] {
        var out: [Character: Int] = [:]
        let n = letters.count
        if n >= 2 {
            for i in 0..<(n - 1) where letters[i] == letters[i + 1] {
                mark(&out, letters[i], i + 1)
            }
        }
        // Stems one letter short of a common word, for every word length.
        for length in (WordList.minWordLength - 1)..<WordList.minDictionaryLength where n >= length {
            for i in 0...(n - length) {
                var stem = Array(letters[i..<(i + length)])
                if let flips, flips(i, i + length - 1, n) {
                    stem.reverse()
                }
                for pos in 0...length {
                    for c in Self.alphabet {
                        var candidate = stem
                        candidate.insert(c, at: pos)
                        if words.isCommon(String(candidate))
                            || (allowBackward && words.isCommon(String(candidate.reversed()))) {
                            mark(&out, c, i + length - 1)
                        }
                    }
                }
            }
        }
        return out
    }

    public func deal(_ letters: [Character], alphabet: [Character], flips: FlipTest? = nil) -> Character {
        if let missing = targetLetter(letters), rng.unit() < targetRate {
            dryStreak = 0
            return missing
        }
        let useful = usefulLetters(letters, flips: flips)
        if !useful.isEmpty && (rng.unit() < helpRate || dryStreak >= pityLimit) {
            dryStreak = 0
            return pickUrgent(useful, chainCount: letters.count)
        }
        let letter = randomLetter(alphabet, onBoard: letters)
        dryStreak = useful[letter] != nil ? 0 : dryStreak + 1
        return letter
    }

    /// A frequency-weighted letter from `alphabet`, limited to letters on the
    /// board when there is a board, so the player never holds a dead letter.
    public func randomLetter(_ alphabet: [Character], onBoard letters: [Character] = []) -> Character {
        var pool = alphabet.filter { letters.isEmpty || letters.contains($0) }
        if pool.isEmpty {
            pool = alphabet
        }
        let total = pool.reduce(0) { $0 + (Self.frequency[$1] ?? 1) }
        var roll = Int.random(in: 1...max(total, 1), using: &rng)
        for c in pool {
            roll -= Self.frequency[c] ?? 1
            if roll <= 0 {
                return c
            }
        }
        return pool.last ?? "e"
    }

    /// A letter that moves the target word closer to popping: the letter of
    /// a run splitting a whole copy, else the letter a copy is missing.
    /// Prefers the copy nearest the hole.
    public func targetLetter(_ letters: [Character]) -> Character? {
        guard let target = targetWord.map({ Array($0) }), target.count >= 2 else { return nil }
        let readings = allowBackward ? [letters, Array(letters.reversed())] : [letters]
        for canMiss in [false, true] {
            for (r, chain) in readings.enumerated() {
                let starts = r == 0 ? Array(stride(from: chain.count - 1, through: 0, by: -1)) : Array(chain.indices)
                for start in starts {
                    if let letter = Self.matchTarget(chain, start, target, 0, canMiss: canMiss, missing: nil, blocker: nil) {
                        return letter
                    }
                }
            }
        }
        return nil
    }

    /// Matches `target` in `chain` from `i`, skipping runs (2 or more) of a
    /// letter inside the word and, if `canMiss`, one missing letter.
    /// Returns the letter to shoot next (the missing one first), or nil if
    /// there is no match or the word is already whole.
    static func matchTarget(_ chain: [Character], _ i: Int, _ target: [Character], _ j: Int,
                            canMiss: Bool, missing: Character?, blocker: Character?) -> Character? {
        if j == target.count {
            return missing ?? blocker
        }
        if i < chain.count && chain[i] == target[j],
           let found = matchTarget(chain, i + 1, target, j + 1, canMiss: canMiss, missing: missing, blocker: blocker) {
            return found
        }
        if j > 0, i + 1 < chain.count, chain[i] == chain[i + 1], chain[i] != target[j] {
            var k = i
            while k < chain.count && chain[k] == chain[i] {
                k += 1
            }
            if let found = matchTarget(chain, k, target, j, canMiss: canMiss, missing: missing,
                                       blocker: blocker ?? chain[i]) {
                return found
            }
        }
        if canMiss, missing == nil, j > 0 || i < chain.count,
           let found = matchTarget(chain, i, target, j + 1, canMiss: canMiss, missing: target[j], blocker: blocker) {
            return found
        }
        return nil
    }

    private func mark(_ out: inout [Character: Int], _ letter: Character, _ index: Int) {
        out[letter] = max(out[letter] ?? -1, index)
    }

    /// Weighted toward handles near the head, which are the most urgent.
    private func pickUrgent(_ useful: [Character: Int], chainCount: Int) -> Character {
        // Sort so the pick depends only on the seed, not dictionary order.
        let entries = useful.sorted { $0.key < $1.key }
        let weights = entries.map { urgency($0.value, chainCount) }
        var roll = rng.unit() * weights.reduce(0, +)
        for (entry, weight) in zip(entries, weights) {
            roll -= weight
            if roll <= 0 {
                return entry.key
            }
        }
        return entries[entries.count - 1].key
    }

    private func urgency(_ index: Int, _ chainCount: Int) -> Double {
        let t = Double(index + 1) / Double(max(chainCount, 1))
        return t * t + 0.05
    }
}
