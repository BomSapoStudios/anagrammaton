import Foundation
import XCTest
@testable import AnagrammatonCore

final class CoreTests: XCTestCase {
    private func smallWords() -> WordList {
        let words = WordList()
        words.addSeedWords(["crane", "bacon", "sheep"])
        words.addPopWords(["cranes"])
        return words
    }

    private func chars(_ text: String) -> [Character] { Array(text) }

    private let alwaysFlipped: FlipTest = { _, _, _ in true }

    // MARK: Pops

    func testShotCompletesTriple() {
        var letters = chars("xaaaby")
        let events = ChainRules.resolve(&letters, requiredLow: 2, requiredHigh: 2, words: smallWords(), allowBackward: false)
        XCTAssertEqual(events.map(\.kind), [.triple])
        XCTAssertEqual(String(letters), "xby")
    }

    func testTripleElsewhereDoesNotPop() {
        var letters = chars("aaaxb")
        XCTAssertTrue(ChainRules.resolve(&letters, requiredLow: 4, requiredHigh: 4, words: smallWords(), allowBackward: false).isEmpty)
    }

    func testShotCompletesWord() {
        var letters = chars("zcranez")
        let events = ChainRules.resolve(&letters, requiredLow: 3, requiredHigh: 3, words: smallWords(), allowBackward: false)
        XCTAssertEqual(events.map(\.word), ["crane"])
        XCTAssertEqual(String(letters), "zz")
    }

    func testLongestWordWins() {
        var letters = chars("cranes")
        let events = ChainRules.resolve(&letters, requiredLow: 2, requiredHigh: 2, words: smallWords(), allowBackward: false)
        XCTAssertEqual(events.map(\.word), ["cranes"])
    }

    func testBackwardWordsOnlyWhenEnabled() {
        var letters = chars("nocab")
        XCTAssertTrue(ChainRules.resolve(&letters, requiredLow: 2, requiredHigh: 2, words: smallWords(), allowBackward: false).isEmpty)
        let events = ChainRules.resolve(&letters, requiredLow: 2, requiredHigh: 2, words: smallWords(), allowBackward: true)
        XCTAssertEqual(events.first?.word, "bacon")
        XCTAssertEqual(events.first?.backward, true)
    }

    func testScreenOrderReadsFlippedRows() {
        // On a row moving right to left, NOCAB in travel order shows as BACON.
        var letters = chars("nocab")
        let events = ChainRules.resolve(&letters, requiredLow: 2, requiredHigh: 2, words: smallWords(), allowBackward: false, flips: alwaysFlipped)
        XCTAssertEqual(events.first?.word, "bacon")
        XCTAssertEqual(events.first?.backward, false)
        var travel = chars("bacon")
        XCTAssertTrue(ChainRules.resolve(&travel, requiredLow: 2, requiredHigh: 2, words: smallWords(), allowBackward: false, flips: alwaysFlipped).isEmpty)
    }

    func testOutOfRangeAnchorIsIgnored() {
        var letters = chars("bacon")
        XCTAssertTrue(ChainRules.resolve(&letters, requiredLow: 5, requiredHigh: 5, words: smallWords(), allowBackward: false).isEmpty)
    }

    func testChainReactionSpellsWordAcrossGap() {
        // Shooting X between BAC and ON pops XXX; the gap closes and spells BACON.
        var letters = chars("bacxxxon")
        let events = ChainRules.resolve(&letters, requiredLow: 3, requiredHigh: 3, words: smallWords(), allowBackward: false)
        XCTAssertEqual(events.map(\.kind), [.triple, .word])
        XCTAssertEqual(events.last?.word, "bacon")
        XCTAssertEqual(events.last?.depth, 1)
        XCTAssertTrue(letters.isEmpty)
    }

    func testStaticWordDoesNotPopOnItsOwn() {
        var letters = chars("baconqqq")
        let events = ChainRules.resolve(&letters, requiredLow: 7, requiredHigh: 7, words: smallWords(), allowBackward: false)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(String(letters), "bacon")
    }

    func testBlockedWordsNeverPop() {
        let words = smallWords()
        words.blockWords(["crane"])
        XCTAssertFalse(words.isWord("crane"))
        XCTAssertFalse(words.isSeed("crane"))
        var letters = chars("crane")
        XCTAssertTrue(ChainRules.resolve(&letters, requiredLow: 2, requiredHigh: 2, words: words, allowBackward: false).isEmpty)
        XCTAssertTrue(words.containsBlocked("xxcranexx"))
        XCTAssertTrue(words.containsBlocked("enarc"))
    }

    // MARK: Scoring

    func testWordPoints() {
        XCTAssertEqual(Scoring.wordPoints("bacon"), 109)
        XCTAssertEqual(Scoring.wordPoints("chocolate"), 446)
        XCTAssertEqual(Scoring.wordPoints("antidisestablishmentarianism"), 316_828)
    }

    func testEventPoints() {
        var triple = PopEvent(kind: .triple, start: 0, end: 2)
        triple.removed = ["a", "a", "a"]
        XCTAssertEqual(Scoring.eventPoints(triple), 30)
        let chained = PopEvent(kind: .word, start: 0, end: 4, word: "bacon", depth: 1)
        XCTAssertEqual(Scoring.eventPoints(chained), (109 + 100) * 2)
    }

    func testScoreKeeper() {
        let keeper = ScoreKeeper()
        var first = [PopEvent(kind: .word, start: 0, end: 4, word: "bacon")]
        XCTAssertEqual(keeper.scoreShot(&first), 109 + Scoring.firstWordBonus)
        var again = [PopEvent(kind: .word, start: 0, end: 4, word: "bacon")]
        XCTAssertEqual(keeper.scoreShot(&again), Int((54 * 1.1).rounded()))
        keeper.recordMiss()
        XCTAssertEqual(keeper.combo, 0)
    }

    func testCommonFourLetterWordsPop() {
        let words = smallWords()
        words.addSeedWords(["tree"])
        words.addPopWords(["toea"])
        XCTAssertTrue(words.isWord("tree"))
        XCTAssertTrue(words.isCommon("tree"))
        XCTAssertFalse(words.isWord("toea"), "4-letter words pop only when common")
        var letters = chars("xtreex")
        let events = ChainRules.resolve(&letters, requiredLow: 3, requiredHigh: 3, words: words, allowBackward: false)
        XCTAssertEqual(events.map(\.word), ["tree"])
    }

    func testDealerFindsFourLetterStems() {
        let words = smallWords()
        words.addSeedWords(["tree"])
        let dealer = LetterDealer(words: words, seed: 1)
        XCTAssertNotNil(dealer.usefulLetters(chars("qtrez"))["e"])
    }

    // MARK: Hints

    func testWordSpotsFindWhereALetterFits() {
        let spots = Hints.wordSpots(for: "a", in: chars("qcrnez"), words: smallWords(), allowBackward: false)
        XCTAssertEqual(spots, [WordSpot(insertIndex: 3, word: "crane", bubbles: 1...4, common: true)])
        XCTAssertTrue(Hints.wordSpots(for: "x", in: chars("qcrnez"), words: smallWords(), allowBackward: false).isEmpty)
    }

    func testWordSpotsFlagUncommonWords() {
        let spots = Hints.wordSpots(for: "s", in: chars("crane"), words: smallWords(), allowBackward: false)
        XCTAssertEqual(spots.map(\.word), ["cranes"])
        XCTAssertEqual(spots.first?.common, false)
    }

    func testPreviewLeavesChainUnchanged() {
        let letters = chars("qcrnez")
        let events = Hints.preview(inserting: "a", at: 3, in: letters, words: smallWords(), allowBackward: false)
        XCTAssertEqual(events.map(\.word), ["crane"])
        XCTAssertEqual(String(letters), "qcrnez")
    }

    // MARK: Dealing and generation

    func testUsefulLetters() {
        let dealer = LetterDealer(words: smallWords(), seed: 1)
        XCTAssertNotNil(dealer.usefulLetters(chars("qcrnez"))["a"])
        XCTAssertNotNil(dealer.usefulLetters(chars("qxxz"))["x"])
        XCTAssertNotNil(dealer.usefulLetters(chars("qenrcz"), flips: alwaysFlipped)["a"])
        XCTAssertNil(dealer.usefulLetters(chars("qenrcz"))["a"])
        dealer.allowBackward = true
        XCTAssertNotNil(dealer.usefulLetters(chars("qenrcz"))["a"])
    }

    func testFullHelpDealsUsefulLetters() {
        let dealer = LetterDealer(words: smallWords(), seed: 1)
        dealer.helpRate = 1
        for _ in 0..<20 {
            let letter = dealer.deal(chars("qcrnezxx"), alphabet: Array("abc"))
            XCTAssertTrue(letter == "a" || letter == "x", "got \(letter)")
        }
    }

    func testPityTimerForcesUsefulLetters() {
        let dealer = LetterDealer(words: smallWords(), seed: 1)
        dealer.helpRate = 0
        dealer.pityLimit = 2
        let useful = (0..<30).filter { _ in dealer.deal(chars("qcrnez"), alphabet: Array("qz")) == "a" }.count
        XCTAssertGreaterThanOrEqual(useful, 10)
    }

    func testChainGenerator() {
        let words = smallWords()
        let generator = ChainGenerator(words: words, seed: 42)
        generator.alphabet = Array("etaoinsrhl")
        let letters = generator.generate(count: 80)
        XCTAssertEqual(letters.count, 80)
        for i in 2..<letters.count {
            XCTAssertFalse(letters[i] == letters[i - 1] && letters[i] == letters[i - 2], "triple at \(i)")
        }
        XCTAssertFalse(LetterDealer(words: words, seed: 3).usefulLetters(letters).isEmpty)
    }

    func testTracks() {
        let diameter = 48.0
        for seed in UInt64(1)...5 {
            let generator = TrackGenerator(seed: seed)
            let serpentine = generator.generate(.serpentine, area: Box(x: 0, y: 140, width: 720, height: 850),
                                                shooter: Vec2(360, 1130), diameter: diameter)
            XCTAssertNotNil(serpentine, "serpentine for seed \(seed)")
            let area = Box(x: 16, y: 260, width: 688, height: 688)
            let spiral = generator.generate(.spiral, area: area, shooter: area.center, diameter: diameter)
            XCTAssertNotNil(spiral, "spiral for seed \(seed)")
            XCTAssertGreaterThan(spiral?.length ?? 0, diameter * 40)
        }
    }

    // MARK: Ads

    func testAdPolicy() {
        let policy = AdPolicy()
        policy.sessionCount = 2
        XCTAssertFalse(policy.canShowInterstitial(now: 1000))
        for _ in 0..<3 { policy.levelCompleted() }
        XCTAssertTrue(policy.canShowInterstitial(now: 1000))
        policy.recordInterstitial(now: 1000)
        for _ in 0..<3 { policy.levelCompleted() }
        XCTAssertFalse(policy.canShowInterstitial(now: 1100))
        XCTAssertTrue(policy.canShowInterstitial(now: 1200))
        policy.sessionCount = 1
        XCTAssertFalse(policy.canShowInterstitial(now: 5000), "no interstitial in the first session")
        policy.sessionCount = 2
        policy.removeAds = true
        XCTAssertFalse(policy.canShowInterstitial(now: 5000))
        XCTAssertFalse(policy.canShowBanner(on: "menu"))
        XCTAssertTrue(policy.canOfferRewarded(ranked: false))
        XCTAssertTrue(policy.canOfferContinue(continuesUsed: 0, ranked: false))
        XCTAssertFalse(policy.canOfferContinue(continuesUsed: 1, ranked: false))
        XCTAssertFalse(policy.canOfferContinue(continuesUsed: 0, ranked: true))
        policy.removeAds = false
        XCTAssertTrue(policy.canShowBanner(on: "menu"))
        XCTAssertFalse(policy.canShowBanner(on: "play"))
    }

    // MARK: Real word files

    func testRealWordFiles() throws {
        let data = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("data")
        let start = Date()
        let words = try WordList(
            popURL: data.appendingPathComponent("words_pop.txt"),
            seedURL: data.appendingPathComponent("words_seed.txt"),
            blockURL: data.appendingPathComponent("blocklist.txt"))
        print("Loaded \(words.popCount) words in \(Int(Date().timeIntervalSince(start) * 1000)) ms")
        XCTAssertGreaterThan(words.popCount, 100_000)
        XCTAssertGreaterThan(words.seedWords.count, 400)
        XCTAssertTrue(words.isWord("bacon"))
        XCTAssertTrue(words.isWord("xylyl"), "obscure words pop")
        XCTAssertTrue(words.isWord("tree"), "common 4-letter words pop")
        XCTAssertFalse(words.isWord("toea"), "obscure 4-letter words don't")
        var letters = Array("antidisestablishmentarianis")
        letters.append("m")
        let events = ChainRules.resolve(&letters, requiredLow: 27, requiredHigh: 27, words: words, allowBackward: false)
        XCTAssertEqual(events.first?.word, "antidisestablishmentarianism")
    }
}
