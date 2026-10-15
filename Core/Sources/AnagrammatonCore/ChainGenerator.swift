/// Builds the letters a level's chain is made of, in blocks. Each block holds
/// a few handles (a pair, or a common word with one letter missing) plus
/// frequency-weighted filler. The result never contains a ready-made triple
/// or a blocked word.
public final class ChainGenerator {
    public static let blockSize = 10
    static let maxFixPasses = 50

    public var alphabet: [Character] = Array("etaoinsrhldc")
    public var handlesPerBlock = 2
    /// The level's hidden word. Copies of it with one letter missing are
    /// planted along the chain so the player can spell it.
    public var targetWord: String?
    public var targetCopies = 3

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
        let protected = plantTarget(&out)
        sanitize(&out, protected: protected)
        return out
    }

    /// Writes target stems at evenly spaced spots and returns their indices.
    private func plantTarget(_ letters: inout [Character]) -> Set<Int> {
        guard let target = targetWord, target.count >= 2 else { return [] }
        var protected = Set<Int>()
        for k in 0..<targetCopies {
            var stem = Array(target)
            stem.remove(at: Int.random(in: 0..<stem.count, using: &rng))
            let start = letters.count * (k + 1) / (targetCopies + 1) - stem.count / 2
            guard start >= 0, start + stem.count <= letters.count else { continue }
            for (j, c) in stem.enumerated() {
                letters[start + j] = c
                protected.insert(start + j)
            }
        }
        return protected
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
    private func sanitize(_ letters: inout [Character], protected: Set<Int> = []) {
        for _ in 0..<Self.maxFixPasses {
            guard let found = findProblem(letters) else { return }
            // Fix a neighbour instead of a planted target letter.
            let candidates = [found, found - 1, found + 1, found - 2, found + 2]
            guard let bad = candidates.first(where: { letters.indices.contains($0) && !protected.contains($0) })
            else { return }
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
