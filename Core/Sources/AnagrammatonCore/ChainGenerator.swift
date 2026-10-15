/// Builds the letters a level's chain is made of, in blocks. Each block holds
/// a few handles (a pair, or a common word with one letter missing) plus
/// frequency-weighted filler. The result never contains a ready-made triple
/// or a blocked word.
public final class ChainGenerator {
    public static let blockSize = 10
    static let maxFixPasses = 50

    public var alphabet: [Character] = Array("etaoinsrhldc")
    public var handlesPerBlock = 2

    private let words: WordList
    private var rng: SeededGenerator
    private let filler: LetterDealer

    public init(words: WordList, seed: UInt64) {
        self.words = words
        rng = SeededGenerator(seed: seed)
        filler = LetterDealer(words: words, seed: seed &+ 1)
    }

    public func generate(count: Int) -> [Character] {
        var out: [Character] = []
        while out.count < count {
            out.append(contentsOf: makeBlock())
        }
        out = Array(out.prefix(count))
        sanitize(&out)
        return out
    }

    private func makeBlock() -> [Character] {
        var chunks: [[Character]] = []
        var used = 0
        for _ in 0..<handlesPerBlock {
            let handle = makeHandle()
            chunks.append(handle)
            used += handle.count
        }
        while used < Self.blockSize {
            chunks.append([filler.randomLetter(alphabet)])
            used += 1
        }
        chunks.shuffle(using: &rng)
        return chunks.flatMap { $0 }
    }

    private func makeHandle() -> [Character] {
        let seeds = words.seedWords
        if seeds.isEmpty || rng.unit() < 0.5 {
            let c = filler.randomLetter(alphabet)
            return [c, c]
        }
        var word = Array(seeds[Int.random(in: 0..<seeds.count, using: &rng)])
        word.remove(at: Int.random(in: 0..<word.count, using: &rng))
        return word
    }

    /// Breaks any run of three identical letters and any blocked word by
    /// swapping in a different filler letter.
    private func sanitize(_ letters: inout [Character]) {
        for _ in 0..<Self.maxFixPasses {
            guard let bad = findProblem(letters) else { return }
            let current = letters[bad]
            var replacement = current
            while replacement == current {
                replacement = filler.randomLetter(alphabet)
            }
            letters[bad] = replacement
        }
    }

    /// Index of a letter to replace, or nil if the chain is clean.
    private func findProblem(_ letters: [Character]) -> Int? {
        if letters.count >= 3 {
            for i in 2..<letters.count where letters[i] == letters[i - 1] && letters[i] == letters[i - 2] {
                return i - 1
            }
        }
        guard words.containsBlocked(String(letters)) else { return nil }
        for i in letters.indices {
            let maxLength = min(16, letters.count - i)
            guard maxLength >= WordList.minBlockedSubstring else { break }
            for length in WordList.minBlockedSubstring...maxLength {
                let piece = String(letters[i..<(i + length)])
                if words.isBlocked(piece) || words.isBlocked(String(piece.reversed())) {
                    return i + length / 2
                }
            }
        }
        return nil
    }
}
