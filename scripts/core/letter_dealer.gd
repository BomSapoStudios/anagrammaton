extends RefCounted
## Chooses the shooter's letters. Most of the time it deals a letter that
## completes a handle on the chain (a pair, or a common word missing one
## letter), preferring handles close to the hole. A pity timer guarantees a
## useful letter after a few unhelpful ones.

const WordList = preload("res://scripts/core/word_list.gd")

const ALPHABET := "abcdefghijklmnopqrstuvwxyz"
## Scrabble tile counts, used as English letter-frequency weights.
const FREQUENCY := {
	"a": 9, "b": 2, "c": 2, "d": 4, "e": 12, "f": 2, "g": 3, "h": 2, "i": 9,
	"j": 1, "k": 1, "l": 4, "m": 2, "n": 6, "o": 8, "p": 2, "q": 1, "r": 6,
	"s": 4, "t": 6, "u": 4, "v": 2, "w": 2, "x": 1, "y": 2, "z": 1,
}

var help_rate := 0.8
var pity_limit := 2
var rng := RandomNumberGenerator.new()

var _words: WordList
var _dry_streak := 0


func _init(words: WordList, seed_value: int = 0) -> void:
	_words = words
	rng.seed = seed_value


## Letters that would pop something if shot into the right spot, mapped to
## the chain index of the handle nearest the hole. `flips` is the same
## screen-direction callable chain_rules.gd takes.
func useful_letters(letters: Array, flips: Callable = Callable()) -> Dictionary:
	var out: Dictionary = {}
	var n := letters.size()
	for i in range(n - 1):
		if letters[i] == letters[i + 1]:
			_mark(out, letters[i], i + 1)
	var text := "".join(PackedStringArray(letters))
	for i in range(n - 3):
		var stem := text.substr(i, 4)
		if flips.is_valid() and flips.call(i, i + 3):
			stem = WordList.reverse_string(stem)
		for pos in range(5):
			for c in ALPHABET:
				if _words.is_seed(stem.substr(0, pos) + c + stem.substr(pos)):
					_mark(out, c, i + 3)
	return out


func deal(letters: Array, alphabet: String, flips: Callable = Callable()) -> String:
	var useful := useful_letters(letters, flips)
	if not useful.is_empty() and (rng.randf() < help_rate or _dry_streak >= pity_limit):
		_dry_streak = 0
		return _pick_urgent(useful, letters.size())
	var letter := random_letter(alphabet, letters)
	if useful.has(letter):
		_dry_streak = 0
	else:
		_dry_streak += 1
	return letter


## A frequency-weighted letter from `alphabet`, limited to letters on the
## board when there is a board, so the player never holds a dead letter.
func random_letter(alphabet: String, letters: Array = []) -> String:
	var pool: Array[String] = []
	for c in alphabet:
		if letters.is_empty() or letters.has(c):
			pool.append(c)
	if pool.is_empty():
		for c in alphabet:
			pool.append(c)
	var total := 0
	for c in pool:
		total += FREQUENCY.get(c, 1)
	var roll := rng.randi_range(1, total)
	for c in pool:
		roll -= FREQUENCY.get(c, 1)
		if roll <= 0:
			return c
	return pool[-1]


func _mark(out: Dictionary, letter: String, index: int) -> void:
	out[letter] = maxi(out.get(letter, -1), index)


## Weighted toward handles near the head, which are the most urgent.
func _pick_urgent(useful: Dictionary, chain_size: int) -> String:
	var total := 0.0
	for c in useful:
		total += _urgency(useful[c], chain_size)
	var roll := rng.randf() * total
	for c in useful:
		roll -= _urgency(useful[c], chain_size)
		if roll <= 0.0:
			return c
	return useful.keys()[-1]


func _urgency(index: int, chain_size: int) -> float:
	var t := float(index + 1) / float(maxi(chain_size, 1))
	return t * t + 0.05
