extends RefCounted
## Pure rules for the letter chain, with no rendering.
##
## Letters are stored tail first: index 0 is the bubble farthest from the
## hole and the last index is the head. Reading the array in order is reading
## in the direction of travel.
##
## A pop must cover a required span of indices. For a shot that span is the
## landed bubble; for a chain reaction it is the two bubbles either side of
## the closed gap, so only words formed by the gap closing pop, and letters
## that were already sitting next to each other never pop on their own.
##
## Words normally read tail to head. An optional `flips` callable,
## flips(start, end) -> bool, says when a span reads the other way on screen
## (for example a row moving right to left), so words follow screen order.

const WordList = preload("res://scripts/core/word_list.gd")

const TRIPLE := "triple"
const WORD := "word"
const MIN_TRIPLE := 3


## Returns the pop that covers indices req_lo..req_hi, or {} if none.
## Words beat triples, and longer words beat shorter ones.
static func find_pop(letters: Array, req_lo: int, req_hi: int, words: WordList, allow_backward: bool, flips: Callable = Callable()) -> Dictionary:
	if req_lo < 0 or req_hi >= letters.size() or req_lo > req_hi:
		return {}
	var word := _find_word(letters, req_lo, req_hi, words, allow_backward, flips)
	if not word.is_empty():
		return word
	return _find_triple(letters, req_lo, req_hi)


## Applies the pop at a shot (or any change) and every chain reaction after
## it. Mutates `letters`. Returns the pops in order; each has kind, start,
## end, removed (letters), depth (0 = direct, 1+ = chain reaction), and for
## words also word and backward.
static func resolve(letters: Array, req_lo: int, req_hi: int, words: WordList, allow_backward: bool, flips: Callable = Callable()) -> Array:
	var events: Array = []
	var depth := 0
	var lo := req_lo
	var hi := req_hi
	while true:
		var pop := find_pop(letters, lo, hi, words, allow_backward, flips)
		if pop.is_empty():
			break
		var start: int = pop["start"]
		var end: int = pop["end"]
		pop["depth"] = depth
		pop["removed"] = letters.slice(start, end + 1)
		for i in range(end - start + 1):
			letters.remove_at(start)
		events.append(pop)
		depth += 1
		# The gap closes: the bubbles either side of it are now neighbours.
		lo = start - 1
		hi = start
	return events


static func _find_word(letters: Array, req_lo: int, req_hi: int, words: WordList, allow_backward: bool, flips: Callable) -> Dictionary:
	var n := letters.size()
	var text := "".join(PackedStringArray(letters))
	var longest := mini(n, words.max_length)
	for length in range(longest, WordList.MIN_WORD_LENGTH - 1, -1):
		var first := maxi(0, req_hi - length + 1)
		var last := mini(req_lo, n - length)
		for start in range(first, last + 1):
			var end := start + length - 1
			var forward := text.substr(start, length)
			var reversed := WordList.reverse_string(forward)
			if flips.is_valid() and flips.call(start, end):
				var swap := forward
				forward = reversed
				reversed = swap
			if words.is_word(forward):
				return {"kind": WORD, "start": start, "end": end, "word": forward, "backward": false}
			if allow_backward and words.is_word(reversed):
				return {"kind": WORD, "start": start, "end": end, "word": reversed, "backward": true}
	return {}


static func _find_triple(letters: Array, req_lo: int, req_hi: int) -> Dictionary:
	var letter: String = letters[req_lo]
	for i in range(req_lo, req_hi + 1):
		if letters[i] != letter:
			return {}
	var start := req_lo
	while start > 0 and letters[start - 1] == letter:
		start -= 1
	var end := req_hi
	while end < letters.size() - 1 and letters[end + 1] == letter:
		end += 1
	if end - start + 1 < MIN_TRIPLE:
		return {}
	return {"kind": TRIPLE, "start": start, "end": end}
