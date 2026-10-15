extends RefCounted
## Running score for a level: repeated words score half, a word the player
## has never spelled before earns a bonus, and consecutive popping shots
## build a combo.

const Rules = preload("res://scripts/core/chain_rules.gd")
const Scoring = preload("res://scripts/core/scoring.gd")

var total := 0
var combo := 0
## Every word the player has ever spelled. Persisting it is future work.
var word_book: Dictionary = {}

var _level_words: Dictionary = {}


func reset_level() -> void:
	total = 0
	combo = 0
	_level_words.clear()


## Scores all pops caused by one shot and returns the points added. Each
## event gets a "points" entry for display.
func score_shot(events: Array) -> int:
	if events.is_empty():
		combo = 0
		return 0
	var points := 0
	for e in events:
		var event: Dictionary = e
		var p := Scoring.event_points(event)
		if event["kind"] == Rules.WORD:
			var word: String = event["word"]
			if _level_words.has(word):
				p = p / 2
			_level_words[word] = true
			if not word_book.has(word):
				word_book[word] = true
				p += Scoring.FIRST_WORD_BONUS
		event["points"] = p
		points += p
	var bonus := mini(combo, Scoring.COMBO_MAX_STEPS) * Scoring.COMBO_STEP
	points = int(round(points * (1.0 + bonus)))
	combo += 1
	total += points
	return points
