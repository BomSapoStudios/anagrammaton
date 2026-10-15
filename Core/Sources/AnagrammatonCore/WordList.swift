import Foundation

/// Word lists. The pop list holds every real word (5+ letters, no proper
/// nouns) that pops when spelled. The common list holds familiar 4- and
/// 5-letter words: 4-letter words pop only if they are common (so obscure
/// Scrabble words like "toea" don't), and the 5-letter ones are used for
/// planted stems. Blocked words never pop, never get planted, and never
/// appear in a generated chain.
public final class WordList {
    /// The shortest word that pops. Words this short must be common.
    public static let minWordLength = 4
    /// Words this long or longer pop from the full dictionary.
    public static let minDictionaryLength = 5
    /// Blocked words this short are too common inside clean words ("glass")
    /// to reject chains over, so only longer ones are checked as substrings.
    public static let minBlockedSubstring = 4

    public private(set) var maxLength = 0
    public private(set) var seedWords: [String] = []

    private var pop = Set<String>()
    private var seed = Set<String>()
    private var commonShort = Set<String>()
    private var blocked = Set<String>()

    public init() {}

    public convenience init(popURL: URL, seedURL: URL, blockURL: URL) throws {
        self.init()
        blockWords(try Self.readLines(blockURL))
        addPopWords(try Self.readLines(popURL))
        addSeedWords(try Self.readLines(seedURL))
    }

    public var popCount: Int { pop.count }

    public func addPopWords(_ words: [String]) {
        for word in words where word.count >= Self.minDictionaryLength && !blocked.contains(word) {
            pop.insert(word)
            maxLength = max(maxLength, word.count)
        }
    }

    /// Adds common words: 5-letter ones become seeds, shorter ones (down to
    /// `minWordLength`) become poppable.
    public func addSeedWords(_ words: [String]) {
        for word in words where !blocked.contains(word) {
            if word.count == Self.minDictionaryLength && !seed.contains(word) {
                seed.insert(word)
                seedWords.append(word)
            } else if word.count >= Self.minWordLength && word.count < Self.minDictionaryLength {
                commonShort.insert(word)
                pop.insert(word)
                maxLength = max(maxLength, word.count)
            }
        }
        addPopWords(words)
    }

    public func blockWords(_ words: [String]) {
        for word in words {
            blocked.insert(word)
            pop.remove(word)
            commonShort.remove(word)
            if seed.remove(word) != nil {
                seedWords.removeAll { $0 == word }
            }
        }
    }

    public func isWord(_ word: String) -> Bool { pop.contains(word) }
    public func isSeed(_ word: String) -> Bool { seed.contains(word) }
    /// A familiar word: a seed word or a common short word.
    public func isCommon(_ word: String) -> Bool { seed.contains(word) || commonShort.contains(word) }
    public func isBlocked(_ word: String) -> Bool { blocked.contains(word) }

    /// True if a blocked word appears in `text`, read either way.
    public func containsBlocked(_ text: String) -> Bool {
        let reversed = String(text.reversed())
        for word in blocked where word.count >= Self.minBlockedSubstring {
            if text.contains(word) || reversed.contains(word) {
                return true
            }
        }
        return false
    }

    static func readLines(_ url: URL) throws -> [String] {
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }
}
