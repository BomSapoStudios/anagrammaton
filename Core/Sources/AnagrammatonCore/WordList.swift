import Foundation

/// Word lists. The pop list holds every real word (5+ letters, no proper
/// nouns) that pops when spelled. The seed list holds common 5-letter words
/// used for planted stems and shooter hints. Blocked words never pop, never
/// get planted, and never appear in a generated chain.
public final class WordList {
    public static let minWordLength = 5
    /// Blocked words this short are too common inside clean words ("glass")
    /// to reject chains over, so only longer ones are checked as substrings.
    public static let minBlockedSubstring = 4

    public private(set) var maxLength = 0
    public private(set) var seedWords: [String] = []

    private var pop = Set<String>()
    private var seed = Set<String>()
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
        for word in words where word.count >= Self.minWordLength && !blocked.contains(word) {
            pop.insert(word)
            maxLength = max(maxLength, word.count)
        }
    }

    public func addSeedWords(_ words: [String]) {
        for word in words where word.count == Self.minWordLength && !blocked.contains(word) && !seed.contains(word) {
            seed.insert(word)
            seedWords.append(word)
        }
        addPopWords(words)
    }

    public func blockWords(_ words: [String]) {
        for word in words {
            blocked.insert(word)
            pop.remove(word)
            if seed.remove(word) != nil {
                seedWords.removeAll { $0 == word }
            }
        }
    }

    public func isWord(_ word: String) -> Bool { pop.contains(word) }
    public func isSeed(_ word: String) -> Bool { seed.contains(word) }
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
