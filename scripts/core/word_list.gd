extends RefCounted
## Word lists. The pop list holds every real word (5+ letters, no proper
## nouns) that pops when spelled. The seed list holds common 5-letter words
## used for planted stems and shooter hints. Blocked words never pop, never
## get planted, and never appear in a generated chain.

const MIN_WORD_LENGTH := 5
## Blocked words this short are too common inside clean words ("glass") to
## reject chains over, so only longer ones are checked as substrings.
const MIN_BLOCKED_SUBSTRING := 4

var max_length := 0

var _pop: Dictionary = {}
var _seed: Dictionary = {}
var _seed_list: Array[String] = []
var _blocked: Dictionary = {}


func load_files(pop_path: String, seed_path: String, block_path: String) -> void:
	block_words(_read_lines(block_path))
	add_pop_words(_read_lines(pop_path))
	add_seed_words(_read_lines(seed_path))


func add_pop_words(words) -> void:
	for w in words:
		var word: String = w
		if word.length() >= MIN_WORD_LENGTH and not _blocked.has(word):
			_pop[word] = true
			max_length = maxi(max_length, word.length())


func add_seed_words(words) -> void:
	for w in words:
		var word: String = w
		if word.length() == MIN_WORD_LENGTH and not _blocked.has(word) and not _seed.has(word):
			_seed[word] = true
			_seed_list.append(word)
	add_pop_words(words)


func block_words(words) -> void:
	for w in words:
		var word: String = w
		_blocked[word] = true
		_pop.erase(word)
		if _seed.has(word):
			_seed.erase(word)
			_seed_list.erase(word)


func is_word(word: String) -> bool:
	return _pop.has(word)


func is_seed(word: String) -> bool:
	return _seed.has(word)


func is_blocked(word: String) -> bool:
	return _blocked.has(word)


func seed_words() -> Array[String]:
	return _seed_list


func pop_count() -> int:
	return _pop.size()


## True if a blocked word appears in `text`, read either way.
func contains_blocked(text: String) -> bool:
	var reversed := reverse_string(text)
	for w in _blocked:
		var word: String = w
		if word.length() < MIN_BLOCKED_SUBSTRING:
			continue
		if text.contains(word) or reversed.contains(word):
			return true
	return false


static func reverse_string(text: String) -> String:
	var out := ""
	for i in range(text.length() - 1, -1, -1):
		out += text[i]
	return out


func _read_lines(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Could not open word file %s" % path)
		return out
	for line in f.get_as_text().split("\n", false):
		var word := line.strip_edges().to_lower()
		if not word.is_empty():
			out.append(word)
	return out
