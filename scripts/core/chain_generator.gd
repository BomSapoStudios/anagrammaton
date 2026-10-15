extends RefCounted
## Builds the letters a level's chain is made of, in blocks. Each block holds
## a few handles (a pair, or a common word with one letter missing) plus
## frequency-weighted filler. The result never contains a ready-made triple
## or a blocked word.

const WordList = preload("res://scripts/core/word_list.gd")
const LetterDealer = preload("res://scripts/core/letter_dealer.gd")

const BLOCK_SIZE := 10
const MAX_FIX_PASSES := 50

var alphabet := "etaoinsrhldc"
var handles_per_block := 2
var rng := RandomNumberGenerator.new()

var _words: WordList
var _filler: LetterDealer


func _init(words: WordList, seed_value: int = 0) -> void:
	_words = words
	rng.seed = seed_value
	_filler = LetterDealer.new(words, seed_value + 1)


func generate(count: int) -> Array:
	var out: Array = []
	while out.size() < count:
		out.append_array(_make_block())
	out = out.slice(0, count)
	_sanitize(out)
	return out


func _make_block() -> Array:
	var chunks: Array = []
	var used := 0
	for i in handles_per_block:
		var handle := _make_handle()
		chunks.append(handle)
		used += handle.size()
	while used < BLOCK_SIZE:
		chunks.append([_filler.random_letter(alphabet)])
		used += 1
	_shuffle(chunks)
	var block: Array = []
	for chunk in chunks:
		block.append_array(chunk)
	return block


func _make_handle() -> Array:
	var seeds := _words.seed_words()
	if rng.randf() < 0.5 or seeds.is_empty():
		var c := _filler.random_letter(alphabet)
		return [c, c]
	var word: String = seeds[rng.randi_range(0, seeds.size() - 1)]
	var drop := rng.randi_range(0, word.length() - 1)
	var stem: Array = []
	for i in word.length():
		if i != drop:
			stem.append(word[i])
	return stem


## Breaks any run of three identical letters and any blocked word by
## swapping in a different filler letter.
func _sanitize(letters: Array) -> void:
	for pass_index in MAX_FIX_PASSES:
		var bad := _find_problem(letters)
		if bad < 0:
			return
		var current: String = letters[bad]
		var replacement := current
		while replacement == current:
			replacement = _filler.random_letter(alphabet)
		letters[bad] = replacement


## Index of a letter to replace, or -1 if the chain is clean.
func _find_problem(letters: Array) -> int:
	for i in range(2, letters.size()):
		if letters[i] == letters[i - 1] and letters[i] == letters[i - 2]:
			return i - 1
	var text := "".join(PackedStringArray(letters))
	if _words.contains_blocked(text):
		for i in text.length():
			# Find the window that holds the blocked word and break its middle.
			for length in range(WordList.MIN_BLOCKED_SUBSTRING, mini(16, text.length() - i) + 1):
				var piece := text.substr(i, length)
				if _words.is_blocked(piece) or _words.is_blocked(WordList.reverse_string(piece)):
					return i + length / 2
	return -1


func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
