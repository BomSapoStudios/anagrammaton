/// A place where shooting a letter would spell a word.
public struct WordSpot: Equatable {
    /// Where the letter would be inserted (0...letters.count).
    public var insertIndex: Int
    public var word: String
    /// Chain indices (before the insert) of the existing bubbles the word uses.
    public var bubbles: ClosedRange<Int>?
    /// True when the word is on the common list.
    public var common: Bool
}

/// Helps players find words: where a letter fits, and what a shot will do.
public enum Hints {
    /// Every insert position where `letter` would pop a word, nearest the
    /// hole (highest index) first.
    public static func wordSpots(
        for letter: Character, in letters: [Character], words: WordList,
        allowBackward: Bool, flips: FlipTest? = nil
    ) -> [WordSpot] {
        var spots: [WordSpot] = []
        for index in stride(from: letters.count, through: 0, by: -1) {
            if let spot = wordSpot(inserting: letter, at: index, in: letters, words: words,
                                   allowBackward: allowBackward, flips: flips) {
                spots.append(spot)
            }
        }
        return spots
    }

    /// The word `letter` would spell if inserted at `index`, or nil.
    public static func wordSpot(
        inserting letter: Character, at index: Int, in letters: [Character], words: WordList,
        allowBackward: Bool, flips: FlipTest? = nil
    ) -> WordSpot? {
        guard index >= 0, index <= letters.count else { return nil }
        var candidate = letters
        candidate.insert(letter, at: index)
        guard let pop = ChainRules.findPop(candidate, requiredLow: index, requiredHigh: index,
                                           words: words, allowBackward: allowBackward, flips: flips),
              pop.kind == .word, let word = pop.word
        else { return nil }
        // Map the word's span back to chain indices without the inserted letter.
        let low = pop.start
        let high = pop.end - 1
        return WordSpot(insertIndex: index, word: word, bubbles: low <= high ? low...high : nil,
                        common: words.isCommon(word))
    }

    /// What a shot landing at `index` would do, without changing the chain.
    public static func preview(
        inserting letter: Character, at index: Int, in letters: [Character], words: WordList,
        allowBackward: Bool, flips: FlipTest? = nil
    ) -> [PopEvent] {
        guard index >= 0, index <= letters.count else { return [] }
        var working = letters
        working.insert(letter, at: index)
        return ChainRules.resolve(&working, requiredLow: index, requiredHigh: index, words: words,
                                  allowBackward: allowBackward, flips: flips)
    }
}
