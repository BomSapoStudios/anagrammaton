extends RefCounted
## Point values. Word score grows exponentially with length: every letter past
## five multiplies it by LENGTH_BASE, so long words dwarf short ones.

const Rules = preload("res://scripts/core/chain_rules.gd")

const WORD_BASE := 100
const LENGTH_BASE := 1.4
const TRIPLE_PER_BUBBLE := 10
const CHAIN_WORD_BONUS := 100
const FIRST_WORD_BONUS := 50
const COMBO_STEP := 0.1
const COMBO_MAX_STEPS := 10

const LETTER_VALUES := {
	"a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2, "h": 4, "i": 1,
	"j": 8, "k": 5, "l": 1, "m": 3, "n": 1, "o": 1, "p": 3, "q": 10, "r": 1,
	"s": 1, "t": 1, "u": 1, "v": 4, "w": 4, "x": 8, "y": 4, "z": 10,
}


static func letter_value(letter: String) -> int:
	return LETTER_VALUES.get(letter, 0)


static func word_points(word: String) -> int:
	var sum := 0
	for c in word:
		sum += letter_value(c)
	return int(round((WORD_BASE + sum) * pow(LENGTH_BASE, word.length() - 5)))


## 1 for a direct pop, then 2, 3, 4... for each link of a chain reaction.
static func chain_multiplier(depth: int) -> int:
	return depth + 1


## Points for one pop event from Rules.resolve, before per-level adjustments.
static func event_points(event: Dictionary) -> int:
	var depth: int = event["depth"]
	var base: int
	if event["kind"] == Rules.WORD:
		base = word_points(event["word"])
		if depth > 0:
			base += CHAIN_WORD_BONUS
	else:
		var removed: Array = event["removed"]
		base = TRIPLE_PER_BUBBLE * removed.size()
	return base * chain_multiplier(depth)
