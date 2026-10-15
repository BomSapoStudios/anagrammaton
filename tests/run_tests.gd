extends SceneTree
## Headless tests for the game rules. Run with:
##   godot --headless --path . -s tests/run_tests.gd

const WordList = preload("res://scripts/core/word_list.gd")
const Rules = preload("res://scripts/core/chain_rules.gd")
const Scoring = preload("res://scripts/core/scoring.gd")
const ScoreKeeper = preload("res://scripts/core/score_keeper.gd")
const LetterDealer = preload("res://scripts/core/letter_dealer.gd")
const ChainGenerator = preload("res://scripts/core/chain_generator.gd")
const TrackGenerator = preload("res://scripts/core/track_generator.gd")
const AdPolicy = preload("res://scripts/ads/ad_policy.gd")

var _checks := 0
var _failures := 0


func _init() -> void:
	test_triples()
	test_words()
	test_chain_reactions()
	test_blocklist()
	test_scoring()
	test_score_keeper()
	test_dealer()
	test_chain_generator()
	test_tracks()
	test_ad_policy()
	test_real_word_files()
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


func small_words() -> WordList:
	var w := WordList.new()
	w.add_seed_words(["crane", "bacon", "sheep"])
	w.add_pop_words(["cranes"])
	return w


func chars(text: String) -> Array:
	var out: Array = []
	for c in text:
		out.append(c)
	return out


func joined(letters: Array) -> String:
	return "".join(PackedStringArray(letters))


func test_triples() -> void:
	var w := small_words()
	var letters := chars("xaaaby")
	var events := Rules.resolve(letters, 2, 2, w, false)
	check(events.size() == 1 and events[0]["kind"] == Rules.TRIPLE, "shot completes a triple")
	check(joined(letters) == "xby", "triple removed, got %s" % joined(letters))
	letters = chars("aaaxb")
	check(Rules.resolve(letters, 4, 4, w, false).is_empty(), "triple elsewhere does not pop")


func test_words() -> void:
	var w := small_words()
	var letters := chars("zcranez")
	var events := Rules.resolve(letters, 3, 3, w, false)
	check(events.size() == 1 and events[0].get("word") == "crane", "shot completes CRANE")
	check(joined(letters) == "zz", "word removed, got %s" % joined(letters))
	letters = chars("cranes")
	events = Rules.resolve(letters, 2, 2, w, false)
	check(events.size() == 1 and events[0].get("word") == "cranes", "longest word wins")
	letters = chars("nocab")
	check(Rules.resolve(letters, 2, 2, w, false).is_empty(), "backward word ignored by default")
	letters = chars("nocab")
	events = Rules.resolve(letters, 2, 2, w, true)
	check(events.size() == 1 and events[0]["backward"] and events[0]["word"] == "bacon", "backward word pops when enabled")
	letters = chars("bacon")
	check(Rules.resolve(letters, 5, 5, w, false).is_empty(), "out-of-range anchor is ignored")


func test_chain_reactions() -> void:
	var w := small_words()
	# Shooting X between BAC and ON pops XXX; the gap closes and spells BACON.
	var letters := chars("bacxxxon")
	var events := Rules.resolve(letters, 3, 3, w, false)
	check(events.size() == 2, "triple then chain-reaction word, got %d events" % events.size())
	if events.size() == 2:
		check(events[1]["word"] == "bacon" and events[1]["depth"] == 1, "BACON pops as a chain reaction")
	check(letters.is_empty(), "chain cleared")
	# A word that was already sitting in the chain does not pop on its own.
	letters = chars("baconqqq")
	events = Rules.resolve(letters, 7, 7, w, false)
	check(events.size() == 1 and joined(letters) == "bacon", "static word stays, got %s" % joined(letters))


func test_blocklist() -> void:
	var w := small_words()
	w.block_words(["crane"])
	check(not w.is_word("crane") and not w.is_seed("crane"), "blocked word removed from lists")
	var letters := chars("crane")
	var events := Rules.resolve(letters, 2, 2, w, false)
	check(events.is_empty(), "blocked word never pops")
	check(w.contains_blocked("xxcranexx") and w.contains_blocked("enarc"), "blocked substring found either way")


func test_scoring() -> void:
	check(Scoring.word_points("bacon") == 109, "BACON scores 109, got %d" % Scoring.word_points("bacon"))
	check(Scoring.word_points("chocolate") == 446, "CHOCOLATE scores 446")
	check(Scoring.word_points("antidisestablishmentarianism") == 316828, "28-letter word scores 316,828")
	var triple := {"kind": Rules.TRIPLE, "depth": 0, "removed": ["a", "a", "a"]}
	check(Scoring.event_points(triple) == 30, "triple scores 30")
	var chained := {"kind": Rules.WORD, "depth": 1, "word": "bacon"}
	check(Scoring.event_points(chained) == (109 + 100) * 2, "chain-reaction word gets bonus and x2")


func test_score_keeper() -> void:
	var keeper := ScoreKeeper.new()
	var first := keeper.score_shot([{"kind": Rules.WORD, "depth": 0, "word": "bacon"}])
	check(first == 109 + Scoring.FIRST_WORD_BONUS, "first-ever word gets bonus, got %d" % first)
	var again := keeper.score_shot([{"kind": Rules.WORD, "depth": 0, "word": "bacon"}])
	check(again == int(round(54 * 1.1)), "repeat word halves, with combo step, got %d" % again)
	keeper.score_shot([])
	check(keeper.combo == 0, "a miss resets the combo")


func test_dealer() -> void:
	var w := small_words()
	var dealer := LetterDealer.new(w, 1)
	var useful := dealer.useful_letters(chars("qcrnez"))
	check(useful.has("a"), "stem CRNE needs A")
	useful = dealer.useful_letters(chars("qxxz"))
	check(useful.has("x"), "pair XX needs X")
	dealer.help_rate = 1.0
	for i in 20:
		var letter := dealer.deal(chars("qcrnezxx"), "abc")
		check(letter == "a" or letter == "x", "full help deals a useful letter, got %s" % letter)
	dealer.help_rate = 0.0
	dealer.pity_limit = 2
	var useful_count := 0
	for i in 30:
		var letter := dealer.deal(chars("qcrnez"), "qz")
		if letter == "a":
			useful_count += 1
	check(useful_count >= 10, "pity timer forces useful letters, got %d" % useful_count)


func test_chain_generator() -> void:
	var w := small_words()
	var gen := ChainGenerator.new(w, 42)
	gen.alphabet = "etaoinsrhl"
	var letters := gen.generate(80)
	check(letters.size() == 80, "generator makes the requested length")
	var triple := false
	for i in range(2, letters.size()):
		if letters[i] == letters[i - 1] and letters[i] == letters[i - 2]:
			triple = true
	check(not triple, "no ready-made triples")
	var dealer := LetterDealer.new(w, 3)
	check(not dealer.useful_letters(letters).is_empty(), "chain has handles")


func test_tracks() -> void:
	var d := 48.0
	for seed_value in [1, 2, 3, 4, 5]:
		var gen := TrackGenerator.new(seed_value)
		var shooter := Vector2(360, 1130)
		var serp := gen.generate(TrackGenerator.SERPENTINE, Rect2(0, 140, 720, 850), shooter, d)
		check(serp != null, "serpentine track for seed %d" % seed_value)
		var area := Rect2(16, 260, 688, 688)
		var spiral := gen.generate(TrackGenerator.SPIRAL, area, area.get_center(), d)
		check(spiral != null, "spiral track for seed %d" % seed_value)
		if spiral != null:
			check(spiral.length > d * 40, "spiral holds 40+ bubbles, %.0f" % (spiral.length / d))


func test_ad_policy() -> void:
	var p := AdPolicy.new()
	p.session_count = 2
	check(not p.can_show_interstitial(1000.0), "no interstitial before 3 levels")
	for i in 3:
		p.on_level_complete()
	check(p.can_show_interstitial(1000.0), "interstitial after 3 levels")
	p.record_interstitial(1000.0)
	for i in 3:
		p.on_level_complete()
	check(not p.can_show_interstitial(1100.0), "no interstitial within 3 minutes")
	check(p.can_show_interstitial(1200.0), "interstitial after 3 minutes")
	p.session_count = 1
	check(not p.can_show_interstitial(5000.0), "no interstitial in the first session")
	p.session_count = 2
	p.remove_ads = true
	check(not p.can_show_interstitial(5000.0), "remove-ads stops interstitials")
	check(not p.can_show_banner("menu"), "remove-ads stops banners")
	check(p.can_offer_rewarded(false), "rewarded still offered after remove-ads")
	check(p.can_offer_continue(0, false) and not p.can_offer_continue(1, false), "one continue per level")
	check(not p.can_offer_continue(0, true), "no continues on ranked levels")
	p.remove_ads = false
	check(p.can_show_banner("menu") and not p.can_show_banner("play"), "banners only off the play screen")


func test_real_word_files() -> void:
	var w := WordList.new()
	var start := Time.get_ticks_msec()
	w.load_files("res://data/words_pop.txt", "res://data/words_seed.txt", "res://data/blocklist.txt")
	print("Loaded %d words in %d ms" % [w.pop_count(), Time.get_ticks_msec() - start])
	check(w.pop_count() > 100000, "pop list loaded")
	check(w.seed_words().size() > 400, "seed list loaded")
	check(w.is_word("bacon") and w.is_word("antidisestablishmentarianism"), "common and very long words pop")
	check(w.is_word("xylyl"), "obscure words pop")
	var letters := chars("antidisestablishmentarianis")
	letters.append("m")
	var events := Rules.resolve(letters, 27, 27, w, false)
	check(events.size() == 1 and events[0]["word"] == "antidisestablishmentarianism", "28-letter word pops")
